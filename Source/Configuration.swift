import UIKit
import Photos

public struct Configuration {

    public init() {
        // This initializer intentionally left empty
    }

    public var inlineMode = false

    // MARK: Colors

    public var backgroundColor = UIColor(red: 0.15, green: 0.19, blue: 0.24, alpha: 1)
    public var mainColor = UIColor(red: 0.09, green: 0.11, blue: 0.13, alpha: 1)
    public var noCameraColor = UIColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1)
    public var bottomContainerColor = UIColor(red: 0.09, green: 0.11, blue: 0.13, alpha: 1)
    public var photoTypesLabelColor = UIColor(red: 0.99, green: 0.94, blue: 0.21, alpha: 1)
    // MARK: Fonts

    public var noCameraFont = UIFont.systemFont(ofSize: 18, weight: UIFont.Weight.medium)
    public var doneButton = UIFont.systemFont(ofSize: 19, weight: UIFont.Weight.medium)

    // MARK: Titles

    public var OKButtonTitle = "OK"
    public var cancelButtonTitle = "Cancel"
    public var doneButtonTitle = "Done"
    public var noImagesTitle = "No images available"
    public var noCameraTitle = "Camera is not available"
    public var noPhotoLibraryTitle = "No Photo Library Access"
    public var requestPermissionTitle = "Permission denied"
    public var requestPermissionMessage = "Please, allow the application to access to your photo library."

    // MARK: Custom behaviour

    public var recordLocation = true
    public var photoAlbumName: String?
}
