import UIKit
import Photos

public struct Configuration {

    public init() {
        // This initializer intentionally left empty
    }

    // MARK: Colors

    public var backgroundColor = UIColor(red: 0.15, green: 0.19, blue: 0.24, alpha: 1)
    public var noPermissionsTextColor = UIColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1)
    public var topContainerViewColor = UIColor(red: 0.09, green: 0.11, blue: 0.13, alpha: 1)
    public var bottomContainerViewColor = UIColor(red: 0.09, green: 0.11, blue: 0.13, alpha: 1)
    public var photoTypesLabelColor = UIColor(red: 0.99, green: 0.94, blue: 0.21, alpha: 1)

    // MARK: Label, message and button text

    public var OKButtonTitle = "OK"
    public var cancelButtonTitle = "Cancel"
    public var doneButtonTitle = "Done"
    public var settingsButtonTitle = "Settings"
    public var noImagesTitle = "No images available"
    public var mediaCaptureFailer = "Unable to capture media"

    public var cameraPermissionLabel = "No permission to use the camera, please change privacy settings"
    public var cameraPermissionTitle = "Allow access to your camera"
    public var cameraPermissionMessage = "Access was previously denied, please grant access from Settings"

    public var photoPermissionLabel = "No permission to access photos, please change privacy settings"
    public var photoPermissionTitle = "Allow access to your photos"
    public var photoPermissionMessage = "Access was previously denied, please grant access from Settings"

//    public var locationPrecisePermissionTitle = "Precise Location"
    public var preciseLocationDeniedMessage = "No location or direction metadata will be added to your photo"

    // MARK: Custom behaviour

//    public var recordLocation = true
    public var inlineMode = false
    public var photoAlbumName: String?
    public var allowMultiplePhotoCapture = false
    public var alwaysAskForPreciseLocation = true
    public var isVideoAllowed = false
    public var showCompass = true
}
