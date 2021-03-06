//
//  PhotoManager.swift
//  SPCamera
//
//  Created by Steven G Pint on 10/24/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import MediaPlayer

enum PhotoManagerSetup {
    case success
    case notAuthorized
    case configurationFailed
}

enum CaptureMode: Int {
    case none = -1
    case photo = 0
    case movie = 1
}

enum Constants {
    static let maxZoomFactor: CGFloat = 5.0
    static let minZoomFactor: CGFloat = 1.0
}

extension Notification.Name {
    static let CameraPermissionGranted = Notification.Name("CameraPermissionGranted")
    static let CameraPermissionDenied = Notification.Name("CameraPermissionDenied")
    static let CameraPermissionFailed = Notification.Name("CameraPermissionFailed")
    static let CameraUnavailable = Notification.Name("CameraUnavailable")
    static let PhotoEnabled = Notification.Name("PhotoEnabled")
    static let RecordEnabled = Notification.Name("RecordEnabled")

    static let UpdateCameraAvailability = Notification.Name("UpdateCameraAvailability")
    static let PhotoLibUnavailable = NSNotification.Name("PhotoLibUnavailable")

    static let ZoomValueChanged = NSNotification.Name("ZoomValueChanged")
}

protocol PhotoManagerDelegate: class {
    func capturedAsset(_ asset: PHAsset)
    func didStartRecordingVideo()
    func didFinishRecordingVideo()
}

public class PhotoManager: NSObject {

    // MARK: public variables

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    // MARK: private variables

    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    private let session = AVCaptureSession()
    private var capturingPhoto = false
    private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    private var setupResult: SessionSetupResult = .success
    private (set)var currentCaptureMode: CaptureMode = .none
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureProcessors = [Int64: PhotoCaptureProcessor]()
    private var movieFileOutput: AVCaptureMovieFileOutput?
    var videoDuration: CMTime {
        return movieFileOutput?.recordedDuration ?? CMTime.zero
    }
    private var keyValueObservations = [NSKeyValueObservation]()

    private let previewView: PreviewView
    private let configuration: Configuration
    private var albumName: String? = Bundle.main.displayName

    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera], mediaType: .video, position: .unspecified)
    private (set)var isSessionRunning = false

    weak var delegate: PhotoManagerDelegate?

//    private override init() {}

    init(previewView: PreviewView, configuration: Configuration) {
        self.previewView = previewView
        self.configuration = configuration
        setupResult = .success

        // Set up the video preview view.
        previewView.session = session
        super.init()
        #if targetEnvironment(simulator)
        print("Camera is not available on Simulator")
        #else
        setup()
        #endif
    }

    private func setup() {
        /*
            Check video authorization status. Video access is required and audio
            access is optional. If audio access is denied, audio is not recorded
            during movie recording.
        */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
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
        default: // The user has previously denied access.
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

    // Call this on the session queue.
    private func configureSession() {
        guard setupResult == .success else { return }
        session.beginConfiguration()

        /*
            We do not create an AVCaptureMovieFileOutput when setting up the session because the
            AVCaptureMovieFileOutput does not support movie recording with AVCaptureSession.Preset.Photo.
        */
        session.sessionPreset = .photo

        // Add video input.
        do {
            let defaultVideoDevice: AVCaptureDevice

            // TODO: allow builtInDualWideCamera for iPhone 11 and greater. It uses a 0.5 zoom factor 
//            if let backCameraDevice = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .back) {
//                defaultVideoDevice = backCameraDevice
//            } else if let backCameraDevice = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
//                defaultVideoDevice = backCameraDevice
//            } else if let backCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
//                defaultVideoDevice = backCameraDevice
//            } else
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If the back dual camera is not available, default to the back wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else {
                print("No AVCaptureDevice")
                return
            }

            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice)

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
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if let statusBarOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation,
                       let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: statusBarOrientation) {
                        initialVideoOrientation = videoOrientation
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

        // Add audio input.
        // TODO: move this to first time a video is recorded
        if configuration.isVideoAllowed {
            do {
                let audioDevice = AVCaptureDevice.default(for: .audio)
                let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)

                if session.canAddInput(audioDeviceInput) {
                    session.addInput(audioDeviceInput)
                } else {
                    print("Could not add audio device input to the session")
                }
            } catch {
                print("Could not create audio device input: \(error)")
            }
        }

        // Add photo output.
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)

            photoOutput.isHighResolutionCaptureEnabled = true
            #if DepthDataSupport
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            depthDataDeliveryMode = photoOutput.isDepthDataDeliverySupported ? .on : .off
            #endif
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()
    }

    func start(completion: @escaping (_ result: PhotoManagerSetup) -> Void) {
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
                self.addObservers()

                DispatchQueue.main.async {
                    completion(.success)
                }

            case .notAuthorized:
                DispatchQueue.main.async {
                    completion(.notAuthorized)
                }

            case .configurationFailed:
                DispatchQueue.main.async {
                    completion(.configurationFailed)
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                if let videoDeviceInput = self.videoDeviceInput {
                    self.session.removeInput(videoDeviceInput)
                }
                self.session.removeOutput(self.photoOutput)
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
    }

    // MARK: Zoom

    var currentZoomFactor: CGFloat {
        get {
            guard let device = videoDeviceInput?.device else { return Constants.minZoomFactor }
            return device.videoZoomFactor
        }
        set {
            guard let device = videoDeviceInput?.device else { return }
            let factor: CGFloat = max(Constants.minZoomFactor, min(newValue, device.activeFormat.videoMaxZoomFactor))

            sessionQueue.async {
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = factor
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .ZoomValueChanged, object: nil, userInfo: ["newValue": factor])
                    }
                } catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
        }
    }

    func toggleZoom() {
        currentZoomFactor = currentZoomFactor == 1.0 ? 2.0 : 1.0
    }

    // MARK: Session Management

    #if VideoResumeSupported
    @IBOutlet private weak var resumeButton: UIButton!

    private func resumeInterruptedSession(_ resumeButton: UIButton) {
        sessionQueue.async {
            /*
                The session might fail to start running, e.g., if a phone or FaceTime call is still
                using audio or video. A failure to start the session running will be communicated via
                a session runtime error notification. To avoid repeatedly failing to start the session
                running, we only try to restart the session running in the session runtime error handler
                if we aren't trying to resume the session running.
            */
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
            if !self.session.isRunning {
                DispatchQueue.main.async {
                    let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            } else {
                DispatchQueue.main.async {
                    self.resumeButton.isHidden = true
                }
            }
        }
    }
    #endif

    /*
    @IBOutlet private weak var captureModeControl: UISegmentedControl!
    // NOTE: This switches between photo and video mode
    @IBAction private func toggleCaptureMode(_ captureModeControl: UISegmentedControl) {
        captureModeControl.isEnabled = false

        if captureModeControl.selectedSegmentIndex == CaptureMode.photo.rawValue {
            bottomContainer.recordButton.isEnabled = false

            sessionQueue.async {
                /*
                    Remove the AVCaptureMovieFileOutput from the session because movie recording is
                    not supported with AVCaptureSession.Preset.Photo.
                */
                self.session.beginConfiguration()
                self.session.removeOutput(self.movieFileOutput!)
                self.session.sessionPreset = .photo

                DispatchQueue.main.async {
                    captureModeControl.isEnabled = true
                }

                self.movieFileOutput = nil

                #if DepthDataSupport
                if self.photoOutput.isDepthDataDeliverySupported {
                    self.photoOutput.isDepthDataDeliveryEnabled = true

                    DispatchQueue.main.async {
                        self.depthDataDeliveryButton.isHidden = false
                        self.depthDataDeliveryButton.isEnabled = true
                    }
                }
                #endif
                self.session.commitConfiguration()
            }
        } else if captureModeControl.selectedSegmentIndex == CaptureMode.movie.rawValue {
            #if DepthDataSupport
            depthDataDeliveryButton.isHidden = true
            #endif

            sessionQueue.async {
                 let movieFileOutput = AVCaptureMovieFileOutput()

                if self.session.canAddOutput(movieFileOutput) {
                    self.session.beginConfiguration()
                    self.session.addOutput(movieFileOutput)
                    self.session.sessionPreset = .high
                    if let connection = movieFileOutput.connection(with: .video) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    self.session.commitConfiguration()

                    DispatchQueue.main.async {
                        captureModeControl.isEnabled = true
                    }

                    self.movieFileOutput = movieFileOutput

                    DispatchQueue.main.async {
                        self.bottomContainer.recordButton.isEnabled = true
                    }
                }
            }
        }
    }
*/

/*
    @IBAction private func changeCamera(_ cameraButton: UIButton) {
        cameraButton.isEnabled = false
//        recordButton.isEnabled = false
//        captureModeControl.isEnabled = false

        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position

            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType

            switch currentPosition {
                case .unspecified, .front:
                    preferredPosition = .back
                    preferredDeviceType = .builtInDualCamera

                case .back:
                    preferredPosition = .front
                    preferredDeviceType = .builtInWideAngleCamera
            @unknown default:
                fatalError()
            }

            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil

            // First, look for a device with both the preferred position and device type. Otherwise, look for a device with only the preferred position.
            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition }) {
                newVideoDevice = device
            }

            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

                    self.session.beginConfiguration()

                    // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
                    self.session.removeInput(self.videoDeviceInput)

                    if self.session.canAddInput(videoDeviceInput) {
                        NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice)

                        NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)

                        self.session.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.session.addInput(self.videoDeviceInput)
                    }

                    if let connection = self.movieFileOutput?.connection(with: .video) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    self.photoOutput.isDepthDataDeliveryEnabled = self.photoOutput.isDepthDataDeliverySupported

                    self.session.commitConfiguration()
                } catch {
                    print("Error occured while creating video device input: \(error)")
                }
            }

            DispatchQueue.main.async {
                self.bottomContainer.cameraButton.isEnabled = true
                self.bottomContainer.recordButton.isEnabled = self.movieFileOutput != nil
//                self.captureModeControl?.isEnabled = true
                #if DepthDataSupport
                self.depthDataDeliveryButton.isEnabled = self.photoOutput.isDepthDataDeliveryEnabled
                self.depthDataDeliveryButton.isHidden = !self.photoOutput.isDepthDataDeliverySupported
                #endif
            }
        }
    }
*/

    private func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        guard let videoDeviceInput = videoDeviceInput else { return }
        sessionQueue.async {
            let device = videoDeviceInput.device
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

    // MARK: Capturing Photos

    func updateCameraMode(_ captureMode: CameraMode) {
        if captureMode == .photo {
            photoCaptureMode()
        } else {
            videoMode()
        }
    }

    private func photoCaptureMode() {
        guard currentCaptureMode != .photo else { return }
        // Remove the AVCaptureMovieFileOutput from the session because movie recording is
        // not supported with AVCaptureSession.Preset.Photo.
        session.beginConfiguration()
        if let movieFileOutput = movieFileOutput {
            session.removeOutput(movieFileOutput)
        }
        session.sessionPreset = .photo
        movieFileOutput = nil

        #if DepthDataSupport
        if photoOutput.isDepthDataDeliverySupported {
            photoOutput.isDepthDataDeliveryEnabled = true

            DispatchQueue.main.async {
                depthDataDeliveryButton.isHidden = false
                depthDataDeliveryButton.isEnabled = true
            }
        }
        #endif
        session.commitConfiguration()
        currentCaptureMode = .photo
    }

    func capturePhoto(locationManager: LocationManager?, completion: (() -> Void)? = nil) {
        guard !capturingPhoto, let videoDeviceInput = videoDeviceInput else { return }
        capturingPhoto = true
        // Retrieve the video preview layer's video orientation on the main queue before
        // entering the session queue. We do this to ensure UI elements are accessed on
        // the main thread and session configuration is done on the session queue.
        let videoPreviewLayerOrientation = Helper.videoOrientation() // previewView.videoPreviewLayer.connection?.videoOrientation

        sessionQueue.async {
            // make sure we are in the correct mode
            self.photoCaptureMode()
            // Update the photo output's connection to match the video orientation of the video preview layer.
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
            }

            let photoSettings: AVCapturePhotoSettings
            // Capture HEIF photo when supported, with flash set to auto and high resolution photo enabled.
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            }
            if videoDeviceInput.device.isFlashAvailable {
                photoSettings.flashMode = .auto
            }
            photoSettings.isHighResolutionPhotoEnabled = true

            if let availableType = photoSettings.__availablePreviewPhotoPixelFormatTypes.first {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: availableType]
            }

            #if DepthDataSupport
            if self.depthDataDeliveryMode == .on && self.photoOutput.isDepthDataDeliverySupported {
                photoSettings.isDepthDataDeliveryEnabled = true
            } else {
                photoSettings.isDepthDataDeliveryEnabled = false
            }
            #endif
            // Use a separate object for the photo capture delegate to isolate each capture life cycle.
            let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, locationManager: locationManager, willCapturePhotoAnimation: {
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
                        if let asset = asset, let delegate = self.delegate {
                            delegate.capturedAsset(asset)
                        }
                    }
                }
            )
            /*
                The Photo Output keeps a weak reference to the photo capture delegate so
                we store it in an array to maintain a strong reference to this object
                until the capture is completed.
            */
            self.inProgressPhotoCaptureProcessors[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
            DispatchQueue.main.async {
                self.capturingPhoto = false
                completion?()
            }
        }
    }

    // MARK: Recording Movies

    private func videoMode() {
        guard currentCaptureMode != .movie else { return }
        #if DepthDataSupport
        depthDataDeliveryButton.isHidden = true
        #endif

        let movieFileOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieFileOutput) {
            session.beginConfiguration()
            session.addOutput(movieFileOutput)
            session.sessionPreset = .high
            if let connection = movieFileOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            session.commitConfiguration()
            self.movieFileOutput = movieFileOutput
            currentCaptureMode = .movie
        }
    }

    func toggleMovieRecording(locationManager: LocationManager?) {
        /*
            Disable the Camera button until recording finishes, and disable
            the Record button until recording starts or finishes.
            See the AVCaptureFileOutputRecordingDelegate methods.
        */
//        captureModeControl.isEnabled = false

        /*
            Retrieve the video preview layer's video orientation on the main queue
            before entering the session queue. We do this to ensure UI elements are
            accessed on the main thread and session configuration is done on the session queue.
        */
        let videoPreviewLayerOrientation = Helper.videoOrientation() // previewView.videoPreviewLayer.connection?.videoOrientation

        sessionQueue.async {
            self.videoMode()
            guard let movieFileOutput = self.movieFileOutput else { return }
            guard !movieFileOutput.isRecording else {
                movieFileOutput.stopRecording()
                return
            }
            guard let videoDeviceInput = self.videoDeviceInput else { return }

            if UIDevice.current.isMultitaskingSupported {
                /*
                    Setup background task.
                    This is needed because the `capture(_:, didFinishRecordingToOutputFileAt:, fromConnections:, error:)`
                    callback is not received until AVCam returns to the foreground unless you request background execution time.
                    This also ensures that there will be time to write the file to the photo library when AVCam is backgrounded.
                    To conclude this background execution, endBackgroundTask(_:) is called in
                    `capture(_:, didFinishRecordingToOutputFileAt:, fromConnections:, error:)` after the recorded file has been saved.
                */
                self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
            }

            // Update the orientation on the movie file output video connection before starting recording.
            if let movieFileOutputConnection = movieFileOutput.connection(with: .video) {
                movieFileOutputConnection.videoOrientation = videoPreviewLayerOrientation
                if movieFileOutputConnection.isVideoStabilizationSupported {
                    movieFileOutputConnection.preferredVideoStabilizationMode = .auto
                }
                let availableVideoCodecTypes = movieFileOutput.availableVideoCodecTypes
                if availableVideoCodecTypes.contains(.hevc) {
                    movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection)
                }
            }
            // Start recording to a temporary file.
            let outputFilePath = "\(NSTemporaryDirectory())/\(NSUUID().uuidString).mov"
            let outputFileURL = URL(fileURLWithPath: outputFilePath)

            // TODO: using this in order to create the photoCaptureProcessor and get a unique id
            let photoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            let device = videoDeviceInput.device
            if device.isFlashAvailable, device.isTorchAvailable {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = .auto
//                    if device.torchMode == .auto {
//                        try device.setTorchModeOn(level: 0.7)
//                    }
                    device.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }

//            let item = AVMutableMetadataItem()
//            AVMetadataItem.
//            item.
//            movieFileOutput

            // Use a separate object for the video record delegate to isolate each recording life cycle.
            let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, backgroundRecordingID: self.backgroundRecordingID, locationManager: locationManager) {
                self.delegate?.didStartRecordingVideo()
            } didFinishRecordingVideo: {
                self.delegate?.didFinishRecordingVideo()
            } completionHandler: { (photoCaptureProcessor, asset) in
                // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
                self.sessionQueue.async {
                    self.inProgressPhotoCaptureProcessors[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
                }
                DispatchQueue.main.async {
                    if let asset = asset, let delegate = self.delegate {
                        delegate.capturedAsset(asset)
                    }
                }
            }
            /*
                The Photo Output keeps a weak reference to the photo capture delegate so
                we store it in an array to maintain a strong reference to this object
                until the capture is completed.
            */
            self.inProgressPhotoCaptureProcessors[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
            movieFileOutput.startRecording(to: outputFileURL, recordingDelegate: photoCaptureProcessor)
        }
    }

    #if DepthDataSupport
    private enum DepthDataDeliveryMode {
        case on
        case off
    }
    private var depthDataDeliveryMode: DepthDataDeliveryMode = .off
    private weak var depthDataDeliveryButton: UIButton!
    @objc func toggleDepthDataDeliveryMode(_ depthDataDeliveryButton: UIButton) {
        sessionQueue.async {
            self.depthDataDeliveryMode = (self.depthDataDeliveryMode == .on) ? .off : .on
            let depthDataDeliveryMode = self.depthDataDeliveryMode

            DispatchQueue.main.async {
                if depthDataDeliveryMode == .on {
                    self.depthDataDeliveryButton.setTitle(NSLocalizedString("Depth Data Delivery: On", comment: "Depth Data Delivery button on title"), for: [])
                } else {
                    self.depthDataDeliveryButton.setTitle(NSLocalizedString("Depth Data Delivery: Off", comment: "Depth Data Delivery button off title"), for: [])
                }
            }
        }
    }
    #endif

    // MARK: - gestures

    @objc func focusAndExposeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard isSessionRunning else { return }

        let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
    }

    // MARK: KVO and Notifications

    private func addObservers() {
        guard let videoDeviceInput = videoDeviceInput else { return }

        let keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
//            guard let isSessionRunning = change.newValue else { return }
//            let isDepthDeliveryDataSupported = self.photoOutput.isDepthDataDeliverySupported
//            let isDepthDeliveryDataEnabled = self.photoOutput.isDepthDataDeliveryEnabled
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .UpdateCameraAvailability, object: nil)
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
        _ = try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)

        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
        _ = try? AVAudioSession.sharedInstance().setActive(false)
    }

    @objc func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }

    @objc func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

        print("Capture session runtime error: \(error)")

        /*
            Automatically try to restart the session running if media services were
            reset and the last start running succeeded. Otherwise, enable the user
            to try to resume the session running.
        */
        #if VideoResumeSupported
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                } else {
                    DispatchQueue.main.async {
                        self.resumeButton.isHidden = false
                    }
                }
            }
        } else {
            resumeButton.isHidden = false
        }
        #endif
    }

    @objc func sessionInterruptionEnded(notification: NSNotification) {
        print("Capture session interruption ended")

        #if VideoResumeSupported
        if !resumeButton.isHidden {
            UIView.animate(withDuration: 0.25,
                animations: {
                    self.resumeButton.alpha = 0
                }, completion: { _ in
                    self.resumeButton.isHidden = true
                }
            )
        }
        #endif
        // TODO: what to do here
//        if !cameraUnavailableLabel.isHidden {
//            UIView.animate(withDuration: 0.25,
//                animations: {
//                    self.cameraUnavailableLabel.alpha = 0
//                }, completion: { _ in
//                    self.cameraUnavailableLabel.isHidden = true
//                }
//            )
//        }
    }
}



