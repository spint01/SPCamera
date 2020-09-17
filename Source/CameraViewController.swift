/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
View controller for camera interface.
*/

import UIKit
import AVFoundation
import Photos
import MediaPlayer

let NotificationPhotoLibUnavailable = NSNotification.Name(rawValue: "photoLibUnavailable")

open class CameraViewController: UIViewController {

	// MARK: View Controller Life Cycle
    private lazy var assets = [PHAsset]()
    private var statusBarHidden = true
    private var capturingPhoto = false

    private var locationManager: LocationManager?
    open var configuration = Configuration()
    private var capturedPhotoAssets = [PHAsset]()
    private let onCancel: (() -> Void)?
    private let onCapture: ((PHAsset) -> Void)?
    private let onFinish: (([PHAsset]) -> Void)?
    private let onPreview: (([PHAsset]) -> Void)?
    // MARK: - Initialization

    public init(configuration: Configuration? = nil,
                onCancel: @escaping () -> Void,
                onCapture: @escaping (PHAsset) -> Void,
                onFinish: @escaping ([PHAsset]) -> Void,
                onPreview: @escaping ([PHAsset]) -> Void) {
        if let configuration = configuration {
            self.configuration = configuration
        }
        self.onCancel = onCancel
        self.onCapture = onCapture
        self.onFinish = onFinish
        self.onPreview = onPreview
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
		super.viewDidLoad()

        view.backgroundColor = configuration.bottomContainerColor

        // recreate storyboard
        if configuration.inlineMode {
            [previewView, cameraUnavailableLabel, photoLibUnavailableLabel, bottomContainer].forEach {
                view.addSubview($0)
                $0.translatesAutoresizingMaskIntoConstraints = false
            }
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(capturePhoto))
            previewView.addGestureRecognizer(tapGesture)
        } else {
            [previewView, cameraUnavailableLabel, photoLibUnavailableLabel, bottomContainer, topContainer].forEach {
                view.addSubview($0)
                $0.translatesAutoresizingMaskIntoConstraints = false
            }
            if !Helper.runningOnIpad {
                [zoomButton].forEach {
                    view.addSubview($0)
                    $0.translatesAutoresizingMaskIntoConstraints = false
                }
            }
            view.addSubview(volumeView)
            view.sendSubviewToBack(volumeView)
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusAndExposeTap))
            previewView.addGestureRecognizer(tapGesture)
        }

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchGestureRecognizerHandler(_:)))
        previewView.addGestureRecognizer(pinchGesture)

        setupConstraints()

        updateZoomButtonTitle(minZoomFactor)

        // Disable UI. The UI is enabled if and only if the session starts running.
		bottomContainer.cameraButton.isEnabled = false

		// Set up the video preview view.
		previewView.session = session

		/*
			Check video authorization status. Video access is required and audio
			access is optional. If audio access is denied, audio is not recorded
			during movie recording.
		*/
		switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
				// The user has previously granted access to the camera.
				break

			case .notDetermined:
				/*
					The user has not yet been presented with the option to grant
					video access. We suspend the session queue to delay session
					setup until the access request has completed.

					Note that audio access will be implicitly requested when we
					create an AVCaptureDeviceInput for audio during session setup.
				*/
				sessionQueue.suspend()
				AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
					if !granted {
						self.setupResult = .notAuthorized
					}
					self.sessionQueue.resume()
				})

			default:
				// The user has previously denied access.
				setupResult = .notAuthorized
		}

		/*
			Setup the capture session.
			In general it is not safe to mutate an AVCaptureSession or any of its
			inputs, outputs, or connections from multiple threads at the same time.

			Why not do all of this on the main queue?
			Because AVCaptureSession.startRunning() is a blocking call which can
			take a long time. We dispatch session setup to the sessionQueue so
			that the main queue isn't blocked, which keeps the UI responsive.
		*/
        #if targetEnvironment(simulator)
        print("Camera is not available on Simulator")
        #else
        sessionQueue.async {
            self.configureSession()
        }
        #endif
	}

	open override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

        statusBarHidden = UIApplication.shared.isStatusBarHidden
//        UIApplication.shared.isStatusBarHidden = true

        #if targetEnvironment(simulator)
        cameraUnavailableLabel.isHidden = false
        cameraUnavailableLabel.text = "Camera is not available on Simulator"
        #else
        sessionQueue.async {
			switch self.setupResult {
                case .success:
				    // Only setup observers and start the session running if setup succeeded.
                    self.addObservers()
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning

                    DispatchQueue.main.async {
                        self.cameraUnavailableLabel.isHidden = self.isSessionRunning
                        // will ask permission the first time
                        self.locationManager = LocationManager(delegate: self)
                    }

                case .notAuthorized:
                    DispatchQueue.main.async {
                        self.cameraUnavailableLabel.isHidden = false
                        self.cameraUnavailableLabel.text = self.configuration.cameraPermissionLabel
                        let alertController = UIAlertController(title: self.configuration.cameraPermissionTitle, message: self.configuration.cameraPermissionMessage, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle,
                                                                style: .cancel,
                                                                handler: nil))
                        alertController.addAction(UIAlertAction(title: self.configuration.settingsButtonTitle,
                                                                style: .`default`,
                                                                handler: { _ in
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
                        }))

                        self.present(alertController, animated: true, completion: nil)
                    }

                case .configurationFailed:
                    DispatchQueue.main.async {
                        self.cameraUnavailableLabel.isHidden = false
                        self.cameraUnavailableLabel.text = self.configuration.mediaCaptureFailer

                        let alertController = UIAlertController(title: Bundle.main.displayName, message: self.configuration.mediaCaptureFailer, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle,
                                                                style: .cancel,
                                                                handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    }
			}
		}
        #endif
    }

	open override func viewWillDisappear(_ animated: Bool) {
		sessionQueue.async {
			if self.setupResult == .success {
				self.session.stopRunning()
				self.isSessionRunning = self.session.isRunning
				self.removeObservers()
			}
            self.locationManager?.stopUpdatingLocation()
		}

		super.viewWillDisappear(animated)
//        UIApplication.shared.isStatusBarHidden = statusBarHidden
	}

    open override var prefersStatusBarHidden: Bool {
        return true
    }

    open override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }

    // MARK: - Rotation

//    open override var shouldAutorotate: Bool {
//        return true
//    }

    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if Helper.runningOnIpad {
            return .all
        } else {
            return .portrait
        }
    }
	open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)

		if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
			let deviceOrientation = UIDevice.current.orientation
			guard let newVideoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation),
				deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
				return
			}

			videoPreviewLayerConnection.videoOrientation = newVideoOrientation
		}
	}

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = view.layer.bounds
        previewView.videoPreviewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY - previewViewOffset)
//        print("bounds: \(bounds)  \nvideoPreviewLayer.bounds: \(previewView.videoPreviewLayer.bounds)")
    }

    private func setupConstraints() {
        let margins = view.safeAreaLayoutGuide

//        previewView.layer.borderColor = UIColor.green.cgColor
//        previewView.layer.borderWidth = 1.0

        NSLayoutConstraint.activate([
            previewView.leftAnchor.constraint(equalTo: view.leftAnchor),
            previewView.rightAnchor.constraint(equalTo: view.rightAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            // NOTE: doing this causes the bluetooth picker to display in the upper left corner
//            previewView.topAnchor.constraint(equalTo: topContainer.bottomAnchor),
//            previewView.bottomAnchor.constraint(equalTo: bottomContainer.topAnchor)
            ])

        // cameraUnavailableLabel
        NSLayoutConstraint.activate([
            cameraUnavailableLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor, constant: -64),
            cameraUnavailableLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 32),
            cameraUnavailableLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -32),
            ])
        // photoLibUnavailableLabel
        NSLayoutConstraint.activate([
            photoLibUnavailableLabel.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            photoLibUnavailableLabel.centerYAnchor.constraint(equalTo: previewView.centerYAnchor, constant: -64),
            photoLibUnavailableLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            ])

        if configuration.inlineMode {
            // bottomContainer
            NSLayoutConstraint.activate([
                bottomContainer.rightAnchor.constraint(equalTo: view.rightAnchor),
                bottomContainer.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
                bottomContainer.leftAnchor.constraint(equalTo: view.leftAnchor),
                bottomContainer.heightAnchor.constraint(equalToConstant: BottomContainerView.CompactDimensions.height)
                ])
        } else {
            // bottomContainer
            if Helper.runningOnIpad {
                NSLayoutConstraint.activate([
                    bottomContainer.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0),
                    bottomContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
                    bottomContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
                    bottomContainer.widthAnchor.constraint(equalToConstant: bottomContainer.containerHeight),
                    ])
                // topContainer
                NSLayoutConstraint.activate([
                    topContainer.topAnchor.constraint(equalTo: view.topAnchor),
                    topContainer.rightAnchor.constraint(equalTo: bottomContainer.leftAnchor),
                    topContainer.leftAnchor.constraint(equalTo: view.leftAnchor),
                    topContainer.heightAnchor.constraint(equalToConstant: topContainer.containerHeight)
                    ])
            } else {
                NSLayoutConstraint.activate([
                    bottomContainer.leftAnchor.constraint(equalTo: view.leftAnchor),
                    bottomContainer.rightAnchor.constraint(equalTo: view.rightAnchor),
                    bottomContainer.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
                    bottomContainer.heightAnchor.constraint(equalToConstant: bottomContainer.containerHeight)
                    ])

                // topContainer
                NSLayoutConstraint.activate([
                    topContainer.topAnchor.constraint(equalTo: margins.topAnchor),
                    topContainer.rightAnchor.constraint(equalTo: view.rightAnchor),
                    topContainer.leftAnchor.constraint(equalTo: view.leftAnchor),
                    topContainer.heightAnchor.constraint(equalToConstant: topContainer.containerHeight)
                    ])

                // zoom button
                NSLayoutConstraint.activate([
                    zoomButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    zoomButton.bottomAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: -20),
                    zoomButton.widthAnchor.constraint(equalToConstant: Constant.zoomButtonSize),
                    zoomButton.heightAnchor.constraint(equalToConstant: Constant.zoomButtonSize)
                    ])
            }
        }
    }

    // MARK: Session Management

	private enum SessionSetupResult {
		case success
		case notAuthorized
		case configurationFailed
	}

	private let session = AVCaptureSession()
	private var isSessionRunning = false
	private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
	private var setupResult: SessionSetupResult = .success
	private var videoDeviceInput: AVCaptureDeviceInput!
    lazy private var previewView: PreviewView = {
        let view = PreviewView()
        view.backgroundColor = configuration.bottomContainerColor

        return view
    }()

	// Call this on the session queue.
	private func configureSession() {
		if setupResult != .success {
			return
		}

		session.beginConfiguration()

		/*
			We do not create an AVCaptureMovieFileOutput when setting up the session because the
			AVCaptureMovieFileOutput does not support movie recording with AVCaptureSession.Preset.Photo.
		*/
		session.sessionPreset = .photo

		// Add video input.
		do {
			var defaultVideoDevice: AVCaptureDevice?

			// Choose the back dual camera if available, otherwise default to a wide angle camera.

            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
                // This is iOS 13 only and isn't the camera we want for photos
//                } else if let backCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
//                    // If the back dual camera is not available, default to the back wide angle camera.
//                    defaultVideoDevice = backCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If the back dual camera is not available, default to the back wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                /*
                 In some cases where users break their phones, the back wide angle camera is not available.
                 In this case, we should default to the front wide angle camera.
                 */
                defaultVideoDevice = frontCameraDevice
            }

            if defaultVideoDevice == nil {
                print("No AVCaptureDevice")
                return
            }

            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)

			if session.canAddInput(videoDeviceInput) {
				session.addInput(videoDeviceInput)
				self.videoDeviceInput = videoDeviceInput

				DispatchQueue.main.async {
					/*
						Why are we dispatching this to the main queue?
						Because AVCaptureVideoPreviewLayer is the backing layer for PreviewView and UIView
						can only be manipulated on the main thread.
						Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
						on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.

						Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
						handled by CameraViewController.viewWillTransition(to:with:).
					*/
					let statusBarOrientation = UIApplication.shared.statusBarOrientation
					var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
					if statusBarOrientation != .unknown {
						if let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: statusBarOrientation) {
							initialVideoOrientation = videoOrientation
						}
					}

                    self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
				}
			} else {
				print("Could not add video device input to the session")
				setupResult = .configurationFailed
				session.commitConfiguration()
				return
			}
		} catch {
			print("Could not create video device input: \(error)")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}

		// Add photo output.
		if session.canAddOutput(photoOutput) {
			session.addOutput(photoOutput)

			photoOutput.isHighResolutionCaptureEnabled = true
		} else {
			print("Could not add photo output to the session")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}

		session.commitConfiguration()
	}

	// MARK: Device Configuration

    private var previewViewOffset: CGFloat {
        if Helper.runningOnIpad || configuration.inlineMode {
            return 0
        } else {
            if DeviceType.IS_IPHONE_X_MAX {
                return 50
            } else if DeviceType.IS_IPHONE_X {
                return 34
            } else if DeviceType.IS_IPHONE_PLUS {
                return 50
            } else {
                return 42
            }
        }
    }
    lazy private var cameraUnavailableLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = self.configuration.noPermissionsTextColor

        return label
    }()
    lazy private var photoLibUnavailableLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = self.configuration.noPermissionsTextColor
        label.text = self.configuration.photoPermissionLabel
        label.backgroundColor = UIColor.black.withAlphaComponent(0.50)
        label.isHidden = true

        return label
    }()
    enum Constant {
        static let zoomButtonSize: CGFloat = 42
    }

    lazy var zoomButton: UIButton = { [unowned self] in
        let button = UIButton()
        button.addTarget(self, action: #selector(zoomButtonDidPress(_:)), for: .touchUpInside)
        button.backgroundColor = self.configuration.bottomContainerColor.withAlphaComponent(0.40)
        button.layer.cornerRadius = Constant.zoomButtonSize / 2

        return button
    }()

    private func updateZoomButtonTitle(_ zoom: CGFloat) {
        var factorStr = String(format: "%.1f", zoom)
        if factorStr.hasSuffix(".0") {
            // don't show trailing .0
            factorStr = String(factorStr.dropLast(2))
        }
        let attribute = [ NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14, weight: .medium),
                          NSAttributedString.Key.foregroundColor: UIColor.white ]
        zoomButton.setAttributedTitle(NSAttributedString(string: "\(factorStr)x", attributes: attribute), for: .normal)
    }

    @objc private func zoomButtonDidPress(_ button: UIButton) {
        if !cameraUnavailableLabel.isHidden, !isSessionRunning { return }
        zoomFactor(zoomFactor() == 1.0 ? 2.0 : 1.0)
    }

    @objc private func focusAndExposeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if !cameraUnavailableLabel.isHidden, !isSessionRunning { return }

        let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
    }

    private func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        guard videoDeviceInput != nil else { return }
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()

                /*
					Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
					Call set(Focus/Exposure)Mode() to apply the new point of interest.
				*/
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }

                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }

                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }

    // MARK: pinch to zoom

    var pivotPinchScale: CGFloat = 0.5
    var maxZoomFactor: CGFloat = 5.0
    var minZoomFactor: CGFloat = 1.0

    @objc func pinchGestureRecognizerHandler(_ gesture: UIPinchGestureRecognizer) {
        if !cameraUnavailableLabel.isHidden, !isSessionRunning { return }

        switch gesture.state {
        case .began:
            pivotPinchScale = zoomFactor()
        //        print("pivotPinchScale: \(pivotPinchScale) maxZoom: \(cameraMan.maxZoomFactor())")
        case .changed:
            let newValue: CGFloat = pivotPinchScale * gesture.scale
            let factor = newValue < minZoomFactor ? minZoomFactor : newValue > maxZoomFactor ? maxZoomFactor : newValue

            if factor != zoomFactor() {
                print("pinchGesture: \(gesture.scale) new: \(factor)")
                zoomFactor(factor)
                // NotificationCenter.default.post(name: Notification.Name(rawValue: ZoomView.Notifications.zoomValueChanged), object: self, userInfo: ["newValue": newValue])
            }
        case .failed, .ended:
            break
        default:
            break
        }
    }

    func zoomFactor(_ zoom: CGFloat) {
        let device = videoDeviceInput.device
        var factor = zoom
        factor = max(self.minZoomFactor, min(factor, device.activeFormat.videoMaxZoomFactor))
        updateZoomButtonTitle(factor)

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = factor
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }

    func zoomFactor() -> CGFloat {
        let device = videoDeviceInput.device
        return device.videoZoomFactor
    }

	// MARK: Capturing Photos

	private let photoOutput = AVCapturePhotoOutput()

	private var inProgressPhotoCaptureProcessors = [Int64: PhotoCaptureProcessor]()

    open lazy var topContainer: TopContainerView = { [unowned self] in
        let view = TopContainerView(configuration: self.configuration)
        view.backgroundColor = Helper.runningOnIpad || configuration.inlineMode ? UIColor.clear : self.configuration.topContainerColor
        view.delegate = self
//        view.layer.borderColor = UIColor.green.cgColor
//        view.layer.borderWidth = 1.0

        return view
        }()

    open lazy var bottomContainer: BottomContainerView = { [unowned self] in
        let view = BottomContainerView(configuration: self.configuration)
        view.backgroundColor = Helper.runningOnIpad ? self.configuration.bottomContainerColor.withAlphaComponent(0.10) : configuration.inlineMode ? UIColor.clear : self.configuration.bottomContainerColor
        view.delegate = self
//        view.layer.borderColor = UIColor.green.cgColor
//        view.layer.borderWidth = 1.0

        return view
        }()

    // All of this is needed to support photo capture with volume buttons
    lazy var volumeView: MPVolumeView = { [unowned self] in
        let view = MPVolumeView()
        view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)

        return view
        }()

    var volume = AVAudioSession.sharedInstance().outputVolume
    @objc private func volumeChanged(_ notification: Notification) {
        guard let slider = volumeView.subviews.filter({ $0 is UISlider }).first as? UISlider,
            let userInfo = (notification as NSNotification).userInfo,
            let changeReason = userInfo["AVSystemController_AudioVolumeChangeReasonNotificationParameter"] as? String, changeReason == "ExplicitVolumeChange" else { return }

        slider.setValue(volume, animated: false)
        capturePhoto()
    }

    @objc private func capturePhoto() {
        if (!configuration.allowMultiplePhotoCapture && capturingPhoto) || !cameraUnavailableLabel.isHidden {
            return
        }
        capturingPhoto = true
        /*
			Retrieve the video preview layer's video orientation on the main queue before
			entering the session queue. We do this to ensure UI elements are accessed on
			the main thread and session configuration is done on the session queue.
		*/
        let videoPreviewLayerOrientation = Helper.videoOrientation() // previewView.videoPreviewLayer.connection?.videoOrientation

		sessionQueue.async {
			// Update the photo output's connection to match the video orientation of the video preview layer.
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
			}

            let photoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
// Capture HEIF photo when supported, with flash set to auto and high resolution photo enabled.
//                if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
//                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
//                }
            if self.videoDeviceInput.device.isFlashAvailable {
                photoSettings.flashMode = .auto
            }
			photoSettings.isHighResolutionPhotoEnabled = true

			// Use a separate object for the photo capture delegate to isolate each capture life cycle.
            let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, locationManager: self.locationManager, willCapturePhotoAnimation: {
					DispatchQueue.main.async {
						self.previewView.videoPreviewLayer.opacity = 0
						UIView.animate(withDuration: 0.25) {
							self.previewView.videoPreviewLayer.opacity = 1
						}
					}
				}, completionHandler: { (photoCaptureProcessor, asset) in
					// When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
					self.sessionQueue.async {
						self.inProgressPhotoCaptureProcessors[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
					}
                    DispatchQueue.main.async {
                        if let asset = asset {
                            if self.configuration.allowMultiplePhotoCapture {
                                self.assets.append(asset)
                                self.bottomContainer.previewTitle("\(self.assets.count)")
                            }
                            self.onCapture?(asset)
                        }
                    }
                    self.capturingPhoto = false
				}
			)

			/*
				The Photo Output keeps a weak reference to the photo capture delegate so
				we store it in an array to maintain a strong reference to this object
				until the capture is completed.
			*/
			self.inProgressPhotoCaptureProcessors[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
			self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
		}
	}

	// MARK: KVO and Notifications

	private var keyValueObservations = [NSKeyValueObservation]()

	private func addObservers() {
		let keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
			guard let isSessionRunning = change.newValue else { return }

			DispatchQueue.main.async {
				// Only enable the ability to change camera if the device has more than one camera.
				self.bottomContainer.cameraButton.isEnabled = isSessionRunning

                if isSessionRunning {
                    self.cameraUnavailableLabel.isHidden = true
                } else {
                    self.cameraUnavailableLabel.isHidden = false
                    self.cameraUnavailableLabel.text = "Camera is not available in split window view"
                }
                self.cameraUnavailableLabel.setNeedsLayout()
			}
		}
		keyValueObservations.append(keyValueObservation)

		NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)
		NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)

		/*
			A session can only run when the app is full screen. It will be interrupted
			in a multi-app layout, introduced in iOS 9, see also the documentation of
			AVCaptureSessionInterruptionReason. Add observers to handle these session
			interruptions and show a preview is paused message. See the documentation
			of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
		*/
		NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: session)

        if !configuration.inlineMode {
            _ = try? AVAudioSession.sharedInstance().setActive(true)
           NotificationCenter.default.addObserver(self, selector: #selector(volumeChanged(_:)), name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"), object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(photoLibUnavailable(_:)), name: NotificationPhotoLibUnavailable, object: nil)
	}

    private func removeObservers() {
		NotificationCenter.default.removeObserver(self)

		for keyValueObservation in keyValueObservations {
			keyValueObservation.invalidate()
		}
		keyValueObservations.removeAll()
        _ = try? AVAudioSession.sharedInstance().setActive(false)
	}

	@objc
	func subjectAreaDidChange(notification: NSNotification) {
		let devicePoint = CGPoint(x: 0.5, y: 0.5)
		focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
	}

	@objc
	func sessionRuntimeError(notification: NSNotification) {
		guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

		print("Capture session runtime error: \(error)")

		/*
			Automatically try to restart the session running if media services were
			reset and the last start running succeeded. Otherwise, enable the user
			to try to resume the session running.
		*/
		if error.code == .mediaServicesWereReset {
			sessionQueue.async {
				if self.isSessionRunning {
					self.session.startRunning()
					self.isSessionRunning = self.session.isRunning
				} else {
				}
			}
		}
	}

	@objc
	func sessionInterruptionEnded(notification: NSNotification) {
		print("Capture session interruption ended")

		if !cameraUnavailableLabel.isHidden {
			UIView.animate(withDuration: 0.25,
			    animations: {
					self.cameraUnavailableLabel.alpha = 0
				}, completion: { _ in
					self.cameraUnavailableLabel.isHidden = true
				}
			)
		}
	}

    @objc
    private func photoLibUnavailable(_ notification: Notification) {
        DispatchQueue.main.async {
            self.photoLibUnavailableLabel.isHidden = false
            self.photoLibUnavailableLabel.text = self.configuration.photoPermissionLabel
            let alertController = UIAlertController(title: self.configuration.photoPermissionTitle, message: self.configuration.photoPermissionMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle,
                                                    style: .cancel,
                                                    handler: nil))
            alertController.addAction(UIAlertAction(title: self.configuration.settingsButtonTitle,
                                                    style: .`default`,
                                                    handler: { _ in
                                                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
            }))

            self.present(alertController, animated: true, completion: nil)
        }
    }

    private func showPreciseLocationUnavailableMessage() {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: nil, message: self.configuration.preciseLocationDeniedMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle,
                                                    style: .cancel,
                                                    handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - LocationManagerAccuracyDelegate methods

extension CameraViewController: LocationManagerAccuracyDelegate {

    func authorizatoonStatusDidChange(authorizationStatus: CLAuthorizationStatus) {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse && locationManager?.accuracyAuthorization == CLAccuracyAuthorization.reducedAccuracy {
            self.topContainer.locationAccuracyButton.isHidden = false
            if self.configuration.alwaysAskForPreciseLocation {
                self.accuracyButtonDidPress()
            }
        }
    }
}


// MARK: - CameraButtonDelegate methods

extension CameraViewController: BottomContainerViewDelegate {

    func cameraButtonDidPress() {
        capturePhoto()
    }

    func doneButtonDidPress() {
        onFinish?(assets)
    }

    func cancelButtonDidPress() {
        onCancel?()
    }

    func previewButtonDidPress() {
        onPreview?(assets)
    }
}

extension CameraViewController: TopContainerViewDelegate {
    func accuracyButtonDidPress() {
        // TODO: Display dialog tell user why we are asking for precise location
        locationManager?.authorizeAccuracy(purposeKey: "PhotoLocation", authorizationStatus: { (accuracy) in
            if accuracy == .fullAccuracy {
                self.topContainer.locationAccuracyButton.isHidden = true
            } else {
                self.topContainer.updateLocationAccuracyButton(true)
                self.showPreciseLocationUnavailableMessage()
            }
        })
    }

}

extension AVCaptureVideoOrientation {
	init?(deviceOrientation: UIDeviceOrientation) {
		switch deviceOrientation {
			case .portrait: self = .portrait
			case .portraitUpsideDown: self = .portraitUpsideDown
			case .landscapeLeft: self = .landscapeRight
			case .landscapeRight: self = .landscapeLeft
			default: return nil
		}
	}

	init?(interfaceOrientation: UIInterfaceOrientation) {
		switch interfaceOrientation {
			case .portrait: self = .portrait
			case .portraitUpsideDown: self = .portraitUpsideDown
			case .landscapeLeft: self = .landscapeLeft
			case .landscapeRight: self = .landscapeRight
			default: return nil
		}
	}
}

extension AVCaptureDevice.DiscoverySession {
	var uniqueDevicePositionsCount: Int {
        var uniqueDevicePositions: [AVCaptureDevice.Position] = []

        for device in devices {
            if !uniqueDevicePositions.contains(device.position) {
                uniqueDevicePositions.append(device.position)
            }
        }

        return uniqueDevicePositions.count
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
