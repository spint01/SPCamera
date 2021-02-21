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

struct ScreenSize {
    static let SCREEN_WIDTH         = UIScreen.main.bounds.size.width
    static let SCREEN_HEIGHT        = UIScreen.main.bounds.size.height
    static let SCREEN_MAX_LENGTH    = max(ScreenSize.SCREEN_WIDTH, ScreenSize.SCREEN_HEIGHT)
    static let SCREEN_MIN_LENGTH    = min(ScreenSize.SCREEN_WIDTH, ScreenSize.SCREEN_HEIGHT)
}

struct DeviceType {
    static let RUNNING_ON_IPAD      = UIDevice.current.userInterfaceIdiom == .pad
}

