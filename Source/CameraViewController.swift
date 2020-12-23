/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
View controller for camera interface.
*/

import UIKit
import AVFoundation
import Photos
import MediaPlayer

public class CameraViewController: UIViewController {

    private lazy var previewView: PreviewView = {
        let view = PreviewView()
        view.backgroundColor = configuration.bottomContainerViewColor

        return view
    }()
    private var previewViewOffset: CGFloat {
        if Helper.runningOnIpad {
            return 0
        } else {
            if ScreenSize.SCREEN_MAX_LENGTH >= 896.0 { // IPHONE_X_MAX
                return 50
            } else if ScreenSize.SCREEN_MAX_LENGTH >= 812.0 { // IPHONE_X
                return 34
            } else if ScreenSize.SCREEN_MAX_LENGTH >= 736.0 { // IPHONE_PLUS
                return 50
            } else {
                return 42
            }
        }
    }

    // All of this is needed to support photo capture with volume buttons
    private lazy var volumeView: MPVolumeView = { [unowned self] in
        let view = MPVolumeView()
        view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)

        return view
        }()

    private var volume = AVAudioSession.sharedInstance().outputVolume
    private lazy var assets = [PHAsset]()

    private lazy var cameraOverlay: CameraOverlay = {
        return CameraOverlay(parentView: self.view)
    }()
    private var photoManager = PhotoManager()
    private var locationManager: LocationManager?
    private var configuration = Configuration()
    private var capturedPhotoAssets = [PHAsset]()
    private let onCancel: (() -> Void)?
    private let onCapture: ((PHAsset) -> Void)?
    private let onFinish: (([PHAsset]) -> Void)?
    private let onPreview: (([PHAsset]) -> Void)?

    private var pivotPinchScale: CGFloat = 0.5

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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: View Controller Life Cycle

    open override func viewDidLoad() {
		super.viewDidLoad()

        setupUI()

        photoManager.setupAVDevice(previewView: previewView)
        photoManager.delegate = self
	}

	open override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

        #if targetEnvironment(simulator)
        cameraOverlay.isCameraAvailable = false
        cameraOverlay.photoUnavailableText = "Camera is not available on Simulator"
        #else
        photoManager.start(completion: { (result) in
            switch result {
            case .success:
                self.cameraOverlay.isCameraAvailable = self.photoManager.isSessionRunning
                // will ask permission the first time
                self.locationManager = LocationManager(delegate: self)
                self.addObserver()
                self.updateCameraAvailability(nil)
            case .notAuthorized:
                self.cameraOverlay.isCameraAvailable = false
                let alertController = UIAlertController(title: self.configuration.cameraPermissionTitle, message: self.configuration.cameraPermissionMessage, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle,
                                                        style: .cancel,
                                                        handler: nil))
                alertController.addAction(UIAlertAction(title: self.configuration.settingsButtonTitle,
                                                        style: .`default`,
                                                        handler: { _ in
                                                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                                                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                                            }
                }))

                self.present(alertController, animated: true, completion: nil)
            case .configurationFailed:
                self.cameraOverlay.isCameraAvailable = false
                self.cameraOverlay.photoUnavailableText = self.configuration.mediaCaptureFailer

                let alertController = UIAlertController(title: Bundle.main.displayName, message: self.configuration.mediaCaptureFailer, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle,
                                                        style: .cancel,
                                                        handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        })
        #endif
    }

	open override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
        photoManager.stop()

        self.locationManager?.stopUpdatingLocation()
	}

    open override var prefersStatusBarHidden: Bool {
        return true
    }

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

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bounds = view.layer.bounds
        previewView.videoPreviewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY - previewViewOffset)
//        print("bounds: \(bounds)  \nvideoPreviewLayer.bounds: \(previewView.videoPreviewLayer.bounds)")

        //                let rect = self.previewView.videoPreviewLayer.frame
        //                let fromTop: CGFloat = self.phoneOverlayView.bottomContainerHeight - 44
        //                self.previewView.videoPreviewLayer.frame = CGRect(x: rect.minX, y: -fromTop, width: rect.width, height: rect.height)
    }

    // MARK: private methods

    private func setupUI() {
//        previewView.layer.borderColor = UIColor.green.cgColor
//        previewView.layer.borderWidth = 2.0

//        previewView.videoPreviewLayer.borderColor = UIColor.green.cgColor
//        previewView.videoPreviewLayer.borderWidth = 2.0

        print("Device \(UIDevice.current.localizedModel) size - w: \(ScreenSize.SCREEN_WIDTH) h: \(ScreenSize.SCREEN_HEIGHT)")
        print("Device \(UIDevice.current.model) size - min: \(ScreenSize.SCREEN_MIN_LENGTH) max: \(ScreenSize.SCREEN_MAX_LENGTH)")

        view.backgroundColor = configuration.bottomContainerViewColor

        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        NSLayoutConstraint.activate([
            previewView.leftAnchor.constraint(equalTo: view.leftAnchor),
            previewView.rightAnchor.constraint(equalTo: view.rightAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: CameraOverlay.bottomContainerViewHeight)
            // NOTE: doing this causes the bluetooth picker to display in the upper left corner
//            previewView.topAnchor.constraint(equalTo: topContainer.bottomAnchor),
//            previewView.bottomAnchor.constraint(equalTo: bottomContainer.topAnchor)
        ])

        view.addSubview(volumeView)
        view.sendSubviewToBack(volumeView)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(photoManager.focusAndExposeTap))
        previewView.addGestureRecognizer(tapGesture)

//        phoneOverlayView.layer.borderColor = UIColor.green.cgColor
//        phoneOverlayView.layer.borderWidth = 2.0

        cameraOverlay.delegate = self
        cameraOverlay.configure(configuration: configuration)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchGestureRecognizerHandler))
        previewView.addGestureRecognizer(pinchGesture)
        cameraOverlay.updateZoomButtonTitle(Constants.minZoomFactor)

        // Disable UI. The UI is enabled if and only if the session starts running.
        cameraOverlay.cameraButton.isEnabled = false
    }

    private func addObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(volumeChanged), name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(photoLibUnavailable), name: .PhotoLibUnavailable, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(updateCameraAvailability), name: .UpdateCameraAvailability, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(zoomValueChanged), name: .ZoomValueChanged, object: nil)
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

    // MARK: notifications

    @objc private func volumeChanged(_ notification: Notification) {
        guard !configuration.allowMultiplePhotoCapture, cameraOverlay.isCameraAvailable else { return }

        guard let slider = volumeView.subviews.filter({ $0 is UISlider }).first as? UISlider,
            let userInfo = (notification as NSNotification).userInfo,
            let changeReason = userInfo["AVSystemController_AudioVolumeChangeReasonNotificationParameter"] as? String, changeReason == "ExplicitVolumeChange" else { return }

        slider.setValue(volume, animated: false)
        photoManager.capturePhoto(locationManager: locationManager)
    }

    @objc private func updateCameraAvailability(_ notification: Notification?) {
        let isSessionRunning = photoManager.isSessionRunning
        // Only enable the ability to change camera if the device has more than one camera.
        cameraOverlay.cameraButton.isEnabled = isSessionRunning && photoManager.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
//        phoneOverlayView.recordButton.isEnabled = isSessionRunning // && self.movieFileOutput != nil
//                self.captureModeControl?.isEnabled = isSessionRunning
        #if DepthDataSupport
        self.depthDataDeliveryButton.isEnabled = isSessionRunning && isDepthDeliveryDataEnabled
        self.depthDataDeliveryButton.isHidden = !(isSessionRunning && isDepthDeliveryDataSupported)
        #endif
        if isSessionRunning {
            cameraOverlay.isCameraAvailable = true
        } else {
            cameraOverlay.isCameraAvailable = false
            cameraOverlay.photoUnavailableText = "Camera is not available in split window view"
        }
    }

    @objc private func photoLibUnavailable(_ notification: Notification) {
        DispatchQueue.main.async {
            self.cameraOverlay.isPhotoLibraryAvailable = false
            let alertController = UIAlertController(title: self.configuration.photoPermissionTitle, message: self.configuration.photoPermissionMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle,
                                                    style: .cancel,
                                                    handler: nil))
            alertController.addAction(UIAlertAction(title: self.configuration.settingsButtonTitle,
                                                    style: .`default`,
                                                    handler: { _ in
                                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                                        }
            }))

            self.present(alertController, animated: true, completion: nil)
        }
    }

    @objc private func zoomValueChanged(_ notification: Notification) {
        guard let value = notification.userInfo?["newValue"] as? CGFloat else { return }
        cameraOverlay.updateZoomButtonTitle(value)
    }

    // MARK: - gestures

    @objc func pinchGestureRecognizerHandler(_ gesture: UIPinchGestureRecognizer) {
        guard cameraOverlay.isCameraAvailable, photoManager.isSessionRunning else { return }

        switch gesture.state {
        case .began:
            pivotPinchScale = photoManager.currentZoomFactor
        case .changed:
            let newValue: CGFloat = pivotPinchScale * gesture.scale
            let factor = newValue < Constants.minZoomFactor ? Constants.minZoomFactor : newValue > Constants.maxZoomFactor ? Constants.maxZoomFactor : newValue

            if factor != photoManager.currentZoomFactor {
                print("pinchGesture: \(gesture.scale) new: \(factor)")
                photoManager.currentZoomFactor = factor
            }
        case .failed, .ended:
            break
        default:
            break
        }
    }

}

// MARK: - LocationManagerAccuracyDelegate methods

extension CameraViewController: LocationManagerAccuracyDelegate {

    func authorizatoonStatusDidChange(authorizationStatus: CLAuthorizationStatus) {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse && locationManager?.accuracyAuthorization == CLAccuracyAuthorization.reducedAccuracy {
            self.cameraOverlay.locationAccuracyButton.isHidden = false
            if self.configuration.alwaysAskForPreciseLocation {
                self.accuracyButtonDidPress()
            }
        }
    }
}


// MARK: - CameraButtonDelegate methods

extension CameraViewController: CameraOverlayDelegate {

    func cameraButtonDidPress(_ mode: CameraMode) {
        switch mode {
        case .photo:
            cameraOverlay.cameraButton.isEnabled = false
            photoManager.setCaptureMode(.photo, completion: { _ in
                self.photoManager.capturePhoto(locationManager: self.locationManager)
                self.cameraOverlay.cameraButton.isEnabled = true
            })
        case .video:
            cameraOverlay.cameraButton.isEnabled = false
            photoManager.setCaptureMode(.movie, completion: { _ in
                self.cameraOverlay.cameraButton.isEnabled = true
                self.photoManager.toggleMovieRecording(recordingDelegate: self)
            })
        }
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

    func accuracyButtonDidPress() {
        // TODO: Display dialog tell user why we are asking for precise location
        locationManager?.authorizeAccuracy(purposeKey: "PhotoLocation", authorizationStatus: { (accuracy) in
            if accuracy == .fullAccuracy {
                self.cameraOverlay.locationAccuracyButton.isHidden = true
            } else {
                self.cameraOverlay.updateLocationAccuracyButton(true)
                self.showPreciseLocationUnavailableMessage()
            }
        })
    }

    func zoomButtonDidPress() {
        guard cameraOverlay.isCameraAvailable, photoManager.isSessionRunning else { return }
        photoManager.toggleZoom()
    }

}

extension CameraViewController: PhotoManagerDelegate {

    func capturedAsset(_ asset: PHAsset) {
        if self.configuration.allowMultiplePhotoCapture {
            assets.append(asset)
            cameraOverlay.photoPreviewTitle("\(self.assets.count)")
         }
         onCapture?(asset)
    }
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {

    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Enable the Record button to let the user stop the recording.
        DispatchQueue.main.async {
            self.cameraOverlay.cameraButton.isEnabled = true
            self.cameraOverlay.cameraButton.setTitle("Stop", for: .normal)
        }
    }

    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        /*
            Note that currentBackgroundRecordingID is used to end the background task
            associated with this recording. This allows a new recording to be started,
            associated with a new UIBackgroundTaskIdentifier, once the movie file output's
            `isRecording` property is back to false — which happens sometime after this method
            returns.

            Note: Since we use a unique file path for each recording, a new recording will
            not overwrite a recording currently being saved.
        */
        func cleanUp() {
            let path = outputFileURL.path
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch {
                    print("Could not remove file at url: \(outputFileURL)")
                }
            }

            if let currentBackgroundRecordingID = photoManager.backgroundRecordingID {
                photoManager.backgroundRecordingID = UIBackgroundTaskIdentifier.invalid

                if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                    UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                }
            }
        }

        var success = true

        if error != nil {
            print("Movie file finishing error: \(String(describing: error))")
            success = (((error! as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue)!
        }

        if success {
            // Check authorization status.
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    // Save the movie file to the photo library and cleanup.
                    PHPhotoLibrary.shared().performChanges({
                            let options = PHAssetResourceCreationOptions()
                            options.shouldMoveFile = true
                            let creationRequest = PHAssetCreationRequest.forAsset()
                            creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
                        }, completionHandler: { success, error in
                            if !success {
                                print("Could not save movie to photo library: \(String(describing: error))")
                            }
                            cleanUp()
                        }
                    )
                } else {
                    cleanUp()
                }
            }
        } else {
            cleanUp()
        }

        // Enable the Camera and Record buttons to let the user switch camera and start another recording.
        DispatchQueue.main.async {
            // Only enable the ability to change camera if the device has more than one camera.
            self.cameraOverlay.cameraButton.isEnabled = self.photoManager.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
//            self.captureModeControl?.isEnabled = true
//            self.phoneOverlayView.recordButton.setTitle("Rec", for: .normal)
        }
    }

}
