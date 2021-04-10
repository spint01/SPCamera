/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
Photo capture processor.
*/

import AVFoundation
import Photos

class PhotoCaptureProcessor: NSObject {

	private(set) var requestedPhotoSettings: AVCapturePhotoSettings
	private let willCapturePhotoAnimation: (() -> Void)?
	private let completionHandler: (PhotoCaptureProcessor, PHAsset?) -> Void
	private var photoData: Data?
	private var locationManager: LocationManager?
    private var latestLocation: CLLocation?
    private var albumName: String? = Bundle.main.displayName

    // MARK: Video
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    private let didStartRecordingVideo: (() -> Void)?
    private let didFinishRecordingVideo: (() -> Void)?

    // for still photos
	init(with requestedPhotoSettings: AVCapturePhotoSettings,
         locationManager: LocationManager?,
	     willCapturePhotoAnimation: @escaping () -> Void,
	     completionHandler: @escaping (PhotoCaptureProcessor, PHAsset?) -> Void) {
		self.requestedPhotoSettings = requestedPhotoSettings
        self.locationManager = locationManager
		self.willCapturePhotoAnimation = willCapturePhotoAnimation
		self.completionHandler = completionHandler

        self.didStartRecordingVideo = nil
        self.didFinishRecordingVideo = nil
    }

    /// for video recording
    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         backgroundRecordingID: UIBackgroundTaskIdentifier?,
         locationManager: LocationManager?,
         didStartRecordingVideo: @escaping () -> Void,
         didFinishRecordingVideo: @escaping () -> Void,
         completionHandler: @escaping (PhotoCaptureProcessor, PHAsset?) -> Void) {
        self.requestedPhotoSettings = requestedPhotoSettings
        self.backgroundRecordingID = backgroundRecordingID
        self.locationManager = locationManager
        self.didStartRecordingVideo = didStartRecordingVideo
        self.didFinishRecordingVideo = didFinishRecordingVideo
        self.completionHandler = completionHandler

        self.willCapturePhotoAnimation = nil
    }

    private func didFinish(_ assetIdentifer: String?) {
        if let identifier = assetIdentifer, let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject {
            completionHandler(self, asset)
        } else {
            completionHandler(self, nil)
        }
	}

    // MARK: Helper

    func fetchAssetCollectionForAlbum(_ albumName: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        return collection.firstObject
    }

    /// save photo in given named album if set
    func localIdentifier(for creationRequest: PHAssetCreationRequest) -> String? {
        // save photo in given named album if set
        if let albumName = self.albumName, !albumName.isEmpty {
            var albumChangeRequest: PHAssetCollectionChangeRequest?

            if let assetCollection = self.fetchAssetCollectionForAlbum(albumName) {
                albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
            } else {
                albumChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            }
            if let albumChangeRequest = albumChangeRequest, let assetPlaceholder = creationRequest.placeholderForCreatedAsset {
                let localIdentifier = assetPlaceholder.localIdentifier
                let enumeration: NSArray = [assetPlaceholder]
                albumChangeRequest.addAssets(enumeration)
                return localIdentifier
            }
        }
        return nil
    }
}

// MARK: still photo capture

extension PhotoCaptureProcessor: AVCapturePhotoFileDataRepresentationCustomizer {
    func replacementMetadata(for photo: AVCapturePhoto) -> [String : Any]? {
        // get image metadata
        var properties = photo.metadata

        if let location = locationManager?.latestLocation,
           locationManager?.accuracyAuthorization == .fullAccuracy,
           let locationMetaData = location.exifMetadata(heading: locationManager?.latestHeading) {
            // Get the existing metadata dictionary (if there is one)
            properties[kCGImagePropertyGPSDictionary as String] = locationMetaData
            latestLocation = location
        }
        return properties
    }
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    // This extension includes all the delegate callbacks for AVCapturePhotoCaptureDelegate protocol

//    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
//    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation?()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error occurered while capturing photo: \(String(describing: error))")
            didFinish(nil)
            return
        }
        photoData = photo.fileDataRepresentation(with: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            didFinish(nil)
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data resource")
            didFinish(nil)
            return
        }
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    noAddPhotoPermission(status)
                    return
                }
                addPhoto()
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else {
                    noAddPhotoPermission(status)
                    return
                }
                addPhoto()
            }
        }

        func addPhoto() {
            var localIdentifier: String?
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                let creationRequest = PHAssetCreationRequest.forAsset()

                options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType.map { $0.rawValue }
                creationRequest.addResource(with: .photo, data: photoData, options: options)
                creationRequest.creationDate = Date()
                creationRequest.location = self.latestLocation
                localIdentifier = self.localIdentifier(for: creationRequest)
            }, completionHandler: { _, error in
                if let error = error {
                    print("Error occurered while saving photo to photo library: \(error)")
                }
                self.didFinish(localIdentifier)
            })
        }

        func noAddPhotoPermission(_ status: PHAuthorizationStatus) {
            if status != .notDetermined {
                // unable to save photo
                print("unable to save photo to library")
                NotificationCenter.default.post(name: .PhotoLibUnavailable, object: nil)
            }
            self.didFinish(nil)
        }
    }
}

extension PhotoCaptureProcessor: AVCaptureFileOutputRecordingDelegate {

    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.didStartRecordingVideo?()
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
            if let currentBackgroundRecordingID = backgroundRecordingID {
                backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
                if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                    UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                }
            }
        }
        let success: Bool = (((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue) ?? true
        if error != nil || !success {
            print("Movie file finishing error: \(String(describing: error))")
            DispatchQueue.main.async {
                self.didFinishRecordingVideo?()
            }
            cleanUp()
            return
        }

        // Check authorization status.
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                cleanUp()
                return
            }
            var localIdentifier: String?
            // Save the movie file to the photo library and cleanup.
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
//                creationRequest.creationDate = Date()
                creationRequest.location = self.latestLocation
                localIdentifier = self.localIdentifier(for: creationRequest)
            }, completionHandler: { success, error in
                if !success {
                    print("Could not save movie to photo library: \(String(describing: error))")
                }
                self.didFinish(localIdentifier)
                cleanUp()
            })
        }

        // Enable the Camera and Record buttons to let the user switch camera and start another recording.
        DispatchQueue.main.async {
            self.didFinishRecordingVideo?()
        }
    }
}
