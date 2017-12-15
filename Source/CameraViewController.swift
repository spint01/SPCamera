/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
View controller for camera interface.
*/

import UIKit
import AVFoundation
import Photos

// MARK: - CameraButtonDelegate methods

open class CameraViewController: UIViewController {

	// MARK: View Controller Life Cycle

    private var locationManager: LocationManager?
    open var configuration = Configuration()
    private var capturedPhotoAssets = [PHAsset]()
    private let onCancel: (() -> Void)?
    private let onCapture: ((PHAsset) -> Void)?
    private let onFinish: (([PHAsset]) -> Void)?
    // MARK: - Initialization

    public init(configuration: Configuration? = nil,
                onCancel: @escaping () -> Void,
                onCapture: @escaping (PHAsset) -> Void,
                onFinish: @escaping ([PHAsset]) -> Void) {
        if let configuration = configuration {
            self.configuration = configuration
        }
        self.onCancel = onCancel
        self.onCapture = onCapture
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        self.onCancel = nil
        self.onCapture = nil
        self.onFinish = nil
        super.init(coder: aDecoder)
    }

    open override func viewDidLoad() {
		super.viewDidLoad()

        // recreate storyboard
        [previewView, doneButton, borderCameraButton, cameraButton, cameraUnavailableLabel].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        if configuration.compactMode {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(capturePhoto(_:)))
            previewView.addGestureRecognizer(tapGesture)
        } else {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(focusAndExposeTap))
            previewView.addGestureRecognizer(tapGesture)
        }

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchGestureRecognizerHandler(_:)))
        previewView.addGestureRecognizer(pinchGesture)

        setupConstraints()

        // Disable UI. The UI is enabled if and only if the session starts running.
		cameraButton.isEnabled = false

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
		sessionQueue.async {
			self.configureSession()
		}
	}

	open override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		sessionQueue.async {
			switch self.setupResult {
                case .success:
				    // Only setup observers and start the session running if setup succeeded.
                    self.addObservers()
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning

                case .notAuthorized:
                    DispatchQueue.main.async {
                        let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                        let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                        let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)

                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                                style: .cancel,
                                                                handler: nil))

                        alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                                style: .`default`,
                                                                handler: { _ in
                            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                        }))

                        self.present(alertController, animated: true, completion: nil)
                    }

                case .configurationFailed:
                    DispatchQueue.main.async {
                        let alertMsg = "Alert message when something goes wrong during capture session configuration"
                        let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                        let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)

                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                                style: .cancel,
                                                                handler: nil))

                        self.present(alertController, animated: true, completion: nil)
                    }
			}
		}

        // will ask permission the first time
        locationManager = LocationManager()
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
	}

    open override var shouldAutorotate: Bool {
		return true
	}

    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .all
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

    private func setupConstraints() {
        var margins: UILayoutGuide!
        if #available(iOS 11.0, *) {
            margins = view.safeAreaLayoutGuide
        } else {
            margins = view.layoutMarginsGuide
        }

        NSLayoutConstraint.activate([
            previewView.leftAnchor.constraint(equalTo: margins.leftAnchor, constant: 8),
            previewView.rightAnchor.constraint(equalTo: margins.rightAnchor, constant: -8),
            previewView.topAnchor.constraint(equalTo: margins.topAnchor, constant: 8),
            previewView.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -8)
            ])
        // cameraUnavailableLabel
        NSLayoutConstraint.activate([
            cameraUnavailableLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cameraUnavailableLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        // cameraButton
        NSLayoutConstraint.activate([
            cameraButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cameraButton.widthAnchor.constraint(equalToConstant: configuration.compactMode ? CameraButton.CompactDimensions.buttonSize : CameraButton.Dimensions.buttonSize),
            cameraButton.heightAnchor.constraint(equalToConstant: configuration.compactMode ? CameraButton.CompactDimensions.buttonSize : CameraButton.Dimensions.buttonSize),
            cameraButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: configuration.compactMode ? -20 : -20)
            ])
        // borderCameraButton
        NSLayoutConstraint.activate([
            borderCameraButton.centerXAnchor.constraint(equalTo: cameraButton.centerXAnchor),
            borderCameraButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
            borderCameraButton.widthAnchor.constraint(equalToConstant: configuration.compactMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize),
            borderCameraButton.heightAnchor.constraint(equalToConstant: configuration.compactMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize)
            ])
        if !configuration.compactMode {
            // doneButton
            NSLayoutConstraint.activate([
                doneButton.centerYAnchor.constraint(equalTo: cameraButton.centerYAnchor),
                doneButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 14)
                ])
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
	var videoDeviceInput: AVCaptureDeviceInput!
//    @IBOutlet private weak var previewView: PreviewView!
//    @IBOutlet weak var containerView: UIView!
    lazy private var previewView: PreviewView = {
        let view = PreviewView()
        view.backgroundColor = UIColor.black

        return view
    }()
//    var containerView: UIView!

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
            if #available(iOS 10.2, *) {
                if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                    defaultVideoDevice = dualCameraDevice
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
            } else {
                if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    // If the back dual camera is not available, default to the back wide angle camera.
                    defaultVideoDevice = backCameraDevice
                } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                    /*
                     In some cases where users break their phones, the back wide angle camera is not available.
                     In this case, we should default to the front wide angle camera.
                     */
                    defaultVideoDevice = frontCameraDevice
                }
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

    lazy private var cameraUnavailableLabel: UILabel = {
        let label = UILabel()
        label.tintColor = UIColor.yellow

        return label
    }()
    @objc private func focusAndExposeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
    }

    private func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
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
    open lazy var doneButton: UIButton = { [unowned self] in
        let button = UIButton()
        button.setTitle(self.configuration.cancelButtonTitle, for: UIControlState())
        button.titleLabel?.font = self.configuration.doneButton
        button.addTarget(self, action: #selector(doneButtonDidPress(_:)), for: .touchUpInside)

        return button
        }()
    @objc func doneButtonDidPress(_ button: UIButton) {
        if button.currentTitle == configuration.cancelButtonTitle {
            onCancel?()
//            delegate?.cancelButtonDidPress()
        } else {
//            delegate?.doneButtonDidPress()
        }
    }

    // MARK: pinch to zoom

    var pivotPinchScale: CGFloat = 1.0
    var maxZoomFactor: CGFloat = 3.5

    @objc func pinchGestureRecognizerHandler(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            pivotPinchScale = zoomFactor()
        //        print("pivotPinchScale: \(pivotPinchScale) maxZoom: \(cameraMan.maxZoomFactor())")
        case .changed:
            let newValue: CGFloat = pivotPinchScale * gesture.scale
            let factor = newValue < 1 ? 1 : newValue > maxZoomFactor ? maxZoomFactor : newValue

            if factor != zoomFactor() {
                // print("pinchGesture: \(gesture.scale) new: \(factor)")
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

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                var factor = zoom
                factor = max(1, min(factor, device.activeFormat.videoMaxZoomFactor))
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

	private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()

    lazy var cameraButton: CameraButton = { [unowned self] in
        let button = CameraButton(configuration: self.configuration)
        button.setTitleColor(UIColor.white, for: UIControlState())
        button.delegate = self

        return button
        }()

    lazy var borderCameraButton: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = configuration.compactMode ? CameraButton.CompactDimensions.borderWidth : CameraButton.Dimensions.borderWidth
        view.layer.cornerRadius = (configuration.compactMode ? CameraButton.CompactDimensions.buttonBorderSize : CameraButton.Dimensions.buttonBorderSize) / 2

        return view
    }()

    @objc
    private func capturePhoto(_ photoButton: UIButton) {
        /*
			Retrieve the video preview layer's video orientation on the main queue before
			entering the session queue. We do this to ensure UI elements are accessed on
			the main thread and session configuration is done on the session queue.
		*/
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation

		sessionQueue.async {
			// Update the photo output's connection to match the video orientation of the video preview layer.
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
			}

            let photoSettings = AVCapturePhotoSettings()
            // Capture HEIF photo when supported, with flash set to auto and high resolution photo enabled.
//            if #available(iOS 11.0, *) {
//                if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
//                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
//                }
//            }

            if self.videoDeviceInput.device.isFlashAvailable {
                photoSettings.flashMode = .auto
            }

			photoSettings.isHighResolutionPhotoEnabled = true
			if !photoSettings.availablePreviewPhotoPixelFormatTypes.isEmpty {
				photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.availablePreviewPhotoPixelFormatTypes.first!]
			}

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
						self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
					}
                    DispatchQueue.main.async {
                        if let asset = asset {
                            self.onCapture?(asset)
                        }
                    }
				}
			)

			/*
				The Photo Output keeps a weak reference to the photo capture delegate so
				we store it in an array to maintain a strong reference to this object
				until the capture is completed.
			*/
			self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
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
				self.cameraButton.isEnabled = isSessionRunning
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
	}

	private func removeObservers() {
		NotificationCenter.default.removeObserver(self)

		for keyValueObservation in keyValueObservations {
			keyValueObservation.invalidate()
		}
		keyValueObservations.removeAll()
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
}

extension CameraViewController: CameraButtonDelegate {

    func buttonDidPress() {
        capturePhoto(cameraButton)
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
