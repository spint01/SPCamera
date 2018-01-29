import UIKit
import AVFoundation

public struct Helper {

    static let runningOnIpad = UIDevice.current.userInterfaceIdiom == .pad

    public static func rotationTransform() -> CGAffineTransform {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return CGAffineTransform(rotationAngle: CGFloat.pi * 0.5)
        case .landscapeRight:
            return CGAffineTransform(rotationAngle: -(CGFloat.pi * 0.5))
        case .portraitUpsideDown:
            return CGAffineTransform(rotationAngle: CGFloat.pi)
        default:
            return CGAffineTransform.identity
        }
    }

    public static func videoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }
}

extension Bundle {
    
    var displayName: String {
        let name = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        return name ?? object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
    }
}

class AssetManager {

    open static func getImage(_ name: String) -> UIImage {
        let traitCollection = UITraitCollection(displayScale: 3)
        var bundle = Bundle(for: AssetManager.self)

        if let resource = bundle.resourcePath, let resourceBundle = Bundle(path: resource + "/SPCamera.bundle") {
            bundle = resourceBundle
        }

        return UIImage(named: name, in: bundle, compatibleWith: traitCollection) ?? UIImage()
    }
}

extension CGFloat {

    var degreesToRadians: CGFloat {
        return self * .pi / 180
    }

    var radiansToDegrees: CGFloat {
        return self * 180 / .pi
    }
}

