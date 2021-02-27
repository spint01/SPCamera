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
        guard !Helper.runningOnIpad else { return 0 }
        switch ScreenSize.SCREEN_MAX_LENGTH {
        case 896...10000: // IPHONE_X_MAX
            return 50
        case 812..<896: // IPHONE_X
            return 34
        case 736..<812: // IPHONE_PLUS
            return 50
        default:
            return 42
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

    private lazy var cameraControlsOverlay: CameraControlsOverlay = { [weak self] in
        return CameraControlsOverlay(parentView: view, configuration: configuration)
    }()
    private lazy var photoManager: PhotoManager = { [weak self] in
        let photoManager = PhotoManager(previewView: previewView, configuration: configuration)
        photoManager.delegate = self
        return photoManager
    }()
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
	}

	open override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
        preparePhotoManager()
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

    private func preparePhotoManager() {
        #if targetEnvironment(simulator)
        cameraControlsOverlay.isCameraAvailable = false
        cameraControlsOverlay.photoUnavailableText = "Camera is not available on Simulator"
        return
        #endif

        photoManager.start(completion: { (result) in
            switch result {
            case .success:
                self.cameraControlsOverlay.isCameraAvailable = self.photoManager.isSessionRunning
                // will ask permission the first time
                self.locationManager = LocationManager(delegate: self)
                self.addObserver()
                self.updateCameraAvailability(nil)
            case .notAuthorized:
                self.cameraControlsOverlay.isCameraAvailable = false
                let alertController = UIAlertController(title: self.configuration.cameraPermissionTitle, message: self.configuration.cameraPermissionMessage, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle, style: .cancel, handler: nil))
                alertController.addAction(UIAlertAction(title: self.configuration.settingsButtonTitle, style: .`default`, handler: { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }))
                self.present(alertController, animated: true, completion: nil)
            case .configurationFailed:
                self.cameraControlsOverlay.isCameraAvailable = false
                self.cameraControlsOverlay.photoUnavailableText = self.configuration.mediaCaptureFailer
                let alertController = UIAlertController(title: Bundle.main.displayName, message: self.configuration.mediaCaptureFailer, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle, style: .cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        })
    }

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
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: CameraControlsOverlay.bottomContainerViewHeight)
            // NOTE: doing this causes the bluetooth picker to display in the upper left corner
//            previewView.topAnchor.constraint(equalTo: topContainer.bottomAnchor),
//            previewView.bottomAnchor.constraint(equalTo: bottomContainer.topAnchor)
        ])

        view.addSubview(volumeView)
        view.sendSubviewToBack(volumeView)

        let tapGesture = UITapGestureRecognizer(target: photoManager, action: #selector(photoManager.focusAndExposeTap))
        previewView.addGestureRecognizer(tapGesture)

//        phoneOverlayView.layer.borderColor = UIColor.green.cgColor
//        phoneOverlayView.layer.borderWidth = 2.0

        cameraControlsOverlay.delegate = self

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchGestureRecognizerHandler))
        previewView.addGestureRecognizer(pinchGesture)
        cameraControlsOverlay.updateZoomButtonTitle(Constants.minZoomFactor)
    }

    private func addObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(volumeChanged), name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(photoLibUnavailable), name: .PhotoLibUnavailable, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateCameraAvailability), name: .UpdateCameraAvailability, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(zoomValueChanged), name: .ZoomValueChanged, object: nil)
    }

    private func showPreciseLocationUnavailableMessage() {
        let alertController = UIAlertController(title: nil, message: configuration.preciseLocationDeniedMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: self.configuration.OKButtonTitle,
                                                style: .cancel,
                                                handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    // MARK: notifications

    @objc private func volumeChanged(_ notification: Notification) {
        guard !configuration.allowMultiplePhotoCapture, cameraControlsOverlay.isCameraAvailable else { return }

        guard let slider = volumeView.subviews.filter({ $0 is UISlider }).first as? UISlider,
            let userInfo = (notification as NSNotification).userInfo,
            let changeReason = userInfo["AVSystemController_AudioVolumeChangeReasonNotificationParameter"] as? String, changeReason == "ExplicitVolumeChange" else { return }

        slider.setValue(volume, animated: false)
        photoManager.capturePhoto(locationManager: locationManager, completion: nil)
    }

    @objc private func updateCameraAvailability(_ notification: Notification?) {
        let isSessionRunning = photoManager.isSessionRunning
        #if DepthDataSupport
        self.depthDataDeliveryButton.isEnabled = isSessionRunning && isDepthDeliveryDataEnabled
        self.depthDataDeliveryButton.isHidden = !(isSessionRunning && isDepthDeliveryDataSupported)
        #endif
        if isSessionRunning {
            // Only enable the ability to change camera if the device has more than one camera.
            cameraControlsOverlay.isCameraAvailable = isSessionRunning && photoManager.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
    //        phoneOverlayView.recordButton.isEnabled = isSessionRunning // && self.movieFileOutput != nil
    //                self.captureModeControl?.isEnabled = isSessionRunning
        } else {
            cameraControlsOverlay.isCameraAvailable = false
            cameraControlsOverlay.photoUnavailableText = "Camera is not available in split window view"
        }
    }

    @objc private func photoLibUnavailable(_ notification: Notification) {
        DispatchQueue.main.async {
            self.cameraControlsOverlay.isPhotoLibraryAvailable = false
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
        cameraControlsOverlay.updateZoomButtonTitle(value)
    }

    // MARK: - gestures

    @objc func pinchGestureRecognizerHandler(_ gesture: UIPinchGestureRecognizer) {
        guard cameraControlsOverlay.isCameraAvailable, photoManager.isSessionRunning else { return }

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

extension CameraViewController {
    func showSettingsAlert(_ title: String?, message: String?) -> Void {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Settings", style: .`default`, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        present(alertController, animated: true, completion: nil)
    }
}

// MARK: - LocationManagerAccuracyDelegate methods

extension CameraViewController: LocationManagerAccuracyDelegate {
    func authorizatoonStatusDidChange(authorizationStatus: CLAuthorizationStatus) {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            cameraControlsOverlay.isLocationAuthorized = true
            guard locationManager?.accuracyAuthorization == CLAccuracyAuthorization.reducedAccuracy else { return }
            cameraControlsOverlay.isPreciseLocationAuthorized = false
            if configuration.alwaysAskForPreciseLocation {
                locationButtonDidPress(true)
            }
        case .notDetermined:
            break
        default:
            cameraControlsOverlay.isLocationAuthorized = false
        }
    }
}

// MARK: - CameraButtonDelegate methods

extension CameraViewController: CameraOverlayDelegate {
    func cameraButtonDidPress(_ mode: CameraMode) {
        switch mode {
        case .photo:
            cameraControlsOverlay.isCapturingPhoto = true
            photoManager.capturePhoto(locationManager: self.locationManager, completion: {
                self.cameraControlsOverlay.isCapturingPhoto = false
            })
        case .video:
            photoManager.toggleMovieRecording()
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

    func locationButtonDidPress(_ isLocationAuthorized: Bool) {
        guard isLocationAuthorized else {
            // Settings dialog
            showSettingsAlert("Allow access to your location so photos can be geo-coded", message: "Access was previously denied, please grant access from Settings")
            return
        }
        // TODO: Display dialog tell user why we are asking for precise location
        locationManager?.authorizeAccuracy(purposeKey: "PhotoLocation", authorizationStatus: { (accuracy) in
            if accuracy == .fullAccuracy {
                self.cameraControlsOverlay.isPreciseLocationAuthorized = true
            } else {
                self.cameraControlsOverlay.updateLocationAccuracyButton(true)
                self.showPreciseLocationUnavailableMessage()
            }
        })
    }

    func zoomButtonDidPress() {
        guard cameraControlsOverlay.isCameraAvailable, photoManager.isSessionRunning else { return }
        photoManager.toggleZoom()
    }

}

extension CameraViewController: PhotoManagerDelegate {
    func capturedAsset(_ asset: PHAsset) {
        if self.configuration.allowMultiplePhotoCapture {
            assets.append(asset)
            cameraControlsOverlay.photoPreviewTitle("\(self.assets.count)")
         }
         onCapture?(asset)
    }

    func didStartRecordingVideo() {
        // Enable the Record button to let the user stop the recording.
        cameraControlsOverlay.isCapturingVideo = true
    }

    func didFinishRecordingVideo() {
        // Only enable the ability to change camera if the device has more than one camera.
        cameraControlsOverlay.isCameraAvailable = photoManager.isSessionRunning && photoManager.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1
        cameraControlsOverlay.isCapturingVideo = false
    }
}
