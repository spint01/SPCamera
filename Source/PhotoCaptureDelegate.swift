/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
Photo capture delegate.
*/

import AVFoundation
import Photos

class PhotoCaptureProcessor: NSObject {

	private(set) var requestedPhotoSettings: AVCapturePhotoSettings
	private let willCapturePhotoAnimation: () -> Void
	private let completionHandler: (PhotoCaptureProcessor, PHAsset?) -> Void
	private var photoData: Data?
	private var locationManager: LocationManager?
    private var latestLocation: CLLocation?
    private var albumName: String? = "AVCam"

	init(with requestedPhotoSettings: AVCapturePhotoSettings,
         locationManager: LocationManager?,
	     willCapturePhotoAnimation: @escaping () -> Void,
	     completionHandler: @escaping (PhotoCaptureProcessor, PHAsset?) -> Void) {
		self.requestedPhotoSettings = requestedPhotoSettings
        self.locationManager = locationManager
		self.willCapturePhotoAnimation = willCapturePhotoAnimation
		self.completionHandler = completionHandler
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
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    /*
     This extension includes all the delegate callbacks for AVCapturePhotoCaptureDelegate protocol
    */
    
//    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
//    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
    }
    
//    @available(iOS 11.0, *)
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//        if let error = error {
//            print("Error capturing photo: \(error)")
//        } else {
//            photoData = photo.fileDataRepresentation()
//        }
//    }

//    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
//    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let error = error {
            print("Error occurered while capturing photo: \(error)")
            didFinish(nil)
            return
        }

        guard let photoSampleBuffer = photoSampleBuffer else { return }

        // Add location metadata
        if let location = locationManager?.latestLocation, var metaDict = CMCopyDictionaryOfAttachments(nil, photoSampleBuffer, kCMAttachmentMode_ShouldPropagate) as? [String: Any] {
            // Get the existing metadata dictionary (if there is one)

            // Append the GPS metadata to the existing metadata
            metaDict[kCGImagePropertyGPSDictionary as String] = location.exifMetadata(heading: locationManager?.latestHeading)

            // Save the new metadata back to the buffer without duplicating any data
            CMSetAttachments(photoSampleBuffer, metaDict as CFDictionary, kCMAttachmentMode_ShouldPropagate)
            latestLocation = location
        }

        photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: nil)
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
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                var localIdentifier: String?
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    let creationRequest = PHAssetCreationRequest.forAsset()

                    if #available(iOS 11.0, *) {
                        options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType.map { $0.rawValue }
                    }
                    creationRequest.addResource(with: .photo, data: photoData, options: options)
                    creationRequest.creationDate = Date()
                    creationRequest.location = self.latestLocation

                    // save photo in given named album if set
                    if let albumName = self.albumName, !albumName.isEmpty {
                        var albumChangeRequest: PHAssetCollectionChangeRequest?

                        if let assetCollection = self.fetchAssetCollectionForAlbum(albumName) {
                            albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
                        } else {
                            albumChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                        }
                        if let albumChangeRequest = albumChangeRequest, let assetPlaceholder = creationRequest.placeholderForCreatedAsset {
                            localIdentifier = assetPlaceholder.localIdentifier
                            let enumeration: NSArray = [assetPlaceholder]
                            albumChangeRequest.addAssets(enumeration)
                        }
                    }
                }, completionHandler: { _, error in
                    if let error = error {
                        print("Error occurered while saving photo to photo library: \(error)")
                    }

                    self.didFinish(localIdentifier)
                })
            } else {
                self.didFinish(nil)
            }
        }
    }
}
