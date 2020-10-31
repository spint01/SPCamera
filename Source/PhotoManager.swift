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

extension Notification.Name {
    static let CameraPermissionGranted = Notification.Name("CameraPermissionGranted")
    static let CameraPermissionDenied = Notification.Name("CameraPermissionDenied")
    static let CameraPermissionFailed = Notification.Name("CameraPermissionFailed")
    static let CameraUnavailable = Notification.Name("CameraUnavailable")
    static let PhotoEnabled = Notification.Name("PhotoEnabled")
    static let RecordEnabled = Notification.Name("RecordEnabled")

    static let UpdateCameraAvailability = Notification.Name("UpdateCameraAvailability")
    static let PhotoLibUnavailable = NSNotification.Name("PhotoLibUnavailable")
}

protocol PhotoManagerDelegate: class {
    func capturedAsset(_ asset: PHAsset)
}

class PhotoManager: NSObject {

    static let shared: PhotoManager = PhotoManager()

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    private let session = AVCaptureSession()

    var isSessionRunning = false
    private var capturingPhoto = false
    private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    private var setupResult: SessionSetupResult = .success
    var videoDeviceInput: AVCaptureDeviceInput?

    private var currentCaptureMode: CaptureMode = .none
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera], mediaType: .video, position: .unspecified)

    private let photoOutput = AVCapturePhotoOutput()
    private var inProgressPhotoCaptureProcessors = [Int64: PhotoCaptureProcessor]()

    private var movieFileOutput: AVCaptureMovieFileOutput?
    var backgroundRecordingID: UIBackgroundTaskIdentifier?

    private var keyValueObservations = [NSKeyValueObservation]()

    private var previewView: PreviewView?

    weak var delegate: PhotoManagerDelegate?

    private override init() {
    }

    func setupAVDevice(previewView: PreviewView) {
        self.previewView = previewView
        setupResult = .success
        #if targetEnvironment(simulator)
        print("Camera is not available on Simulator")
        return
        #endif

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

    // Call this on the session queue.
    private func configureSession() {
        guard setupResult == .success, let previewView = previewView else { return }
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

                    previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
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

    func viewWillAppearSetup(completion: @escaping (_ result: PhotoManagerSetup) -> Void) {
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

    func viewWillDisappear() {
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

    func setCaptureMode(_ captureMode: CaptureMode, completion: @escaping (_ didEnable: Bool) -> Void) {
        if captureMode == .photo, currentCaptureMode != .photo {
            sessionQueue.async {
                /*
                    Remove the AVCaptureMovieFileOutput from the session because movie recording is
                    not supported with AVCaptureSession.Preset.Photo.
                */
                self.session.beginConfiguration()
                if let movieFileOutput = self.movieFileOutput {
                    self.session.removeOutput(movieFileOutput)
                }
                self.session.sessionPreset = .photo
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
                DispatchQueue.main.async {
                    self.currentCaptureMode = .photo
                    completion(true)
                }
            }
        } else if captureMode == .movie, currentCaptureMode != .movie {
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
                    self.movieFileOutput = movieFileOutput
                    DispatchQueue.main.async {
                        self.currentCaptureMode = .movie
                        completion(true)
                    }
                }
            }
        } else {
            completion(false)
        }
    }

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
    func zoomView(_ zoom: CGFloat, minZoomFactor: CGFloat) -> CGFloat {
        guard let videoDeviceInput = videoDeviceInput else { return zoom }

        let device = videoDeviceInput.device
        var factor = zoom
        factor = max(minZoomFactor, min(factor, device.activeFormat.videoMaxZoomFactor))

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = factor
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
        return factor
    }

    @objc func focusAndExposeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard isSessionRunning, let previewView = previewView else { return }

        let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
    }

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

    func capturePhoto(locationManager: LocationManager?) {
        guard !capturingPhoto, let previewView = previewView else { return }
        guard let videoDeviceInput = videoDeviceInput else { return }

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
            if videoDeviceInput.device.isFlashAvailable {
                photoSettings.flashMode = .auto
            }
            photoSettings.isHighResolutionPhotoEnabled = true
            
            if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
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
                        previewView.videoPreviewLayer.opacity = 0
                        UIView.animate(withDuration: 0.25) {
                            previewView.videoPreviewLayer.opacity = 1
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

    #if DepthDataSupport
    private enum DepthDataDeliveryMode {
        case on
        case off
    }
    private var depthDataDeliveryMode: DepthDataDeliveryMode = .off
    @IBOutlet private weak var depthDataDeliveryButton: UIButton!
    @IBAction func toggleDepthDataDeliveryMode(_ depthDataDeliveryButton: UIButton) {
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

    // MARK: Recording Movies

    func toggleMovieRecording(recordingDelegate: AVCaptureFileOutputRecordingDelegate) {
        guard let previewView = previewView, let movieFileOutput = self.movieFileOutput else { return }
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
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation

        sessionQueue.async {
            if !movieFileOutput.isRecording {
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
                let movieFileOutputConnection = movieFileOutput.connection(with: .video)
                movieFileOutputConnection?.videoOrientation = videoPreviewLayerOrientation!

                let availableVideoCodecTypes = movieFileOutput.availableVideoCodecTypes

                if availableVideoCodecTypes.contains(.hevc) {
                    movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
                }

                // Start recording to a temporary file.
                let outputFileName = NSUUID().uuidString
                let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
                movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: recordingDelegate)
            } else {
                movieFileOutput.stopRecording()
            }
        }
    }

    // MARK: KVO and Notifications

    private func addObservers() {
        guard let videoDeviceInput = videoDeviceInput else { return }

        let keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            let isDepthDeliveryDataSupported = self.photoOutput.isDepthDataDeliverySupported
            let isDepthDeliveryDataEnabled = self.photoOutput.isDepthDataDeliveryEnabled

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
