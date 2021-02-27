//
//  EXIFHelper.swift
//  ImagePicker
//
//  Created by Steven G Pint on 5/5/17.
//  Copyright © 2017 Hyper Interaktiv AS. All rights reserved.
//

import UIKit
import CoreLocation
import ImageIO
import MediaPlayer

extension CLLocation {

    func exifMetadata(heading: CLHeading? = nil) -> NSMutableDictionary {
        let GPSMetadata = NSMutableDictionary()
        let altitudeRef = Int(altitude < 0.0 ? 1 : 0)
        let latitudeRef = coordinate.latitude < 0.0 ? "S" : "N"
        let longitudeRef = coordinate.longitude < 0.0 ? "W" : "E"

        // GPS metadata
        GPSMetadata[(kCGImagePropertyGPSLatitude as String)] = abs(coordinate.latitude)
        GPSMetadata[(kCGImagePropertyGPSLongitude as String)] = abs(coordinate.longitude)
        GPSMetadata[(kCGImagePropertyGPSLatitudeRef as String)] = latitudeRef
        GPSMetadata[(kCGImagePropertyGPSLongitudeRef as String)] = longitudeRef
        GPSMetadata[(kCGImagePropertyGPSAltitude as String)] = Int(abs(altitude))
        GPSMetadata[(kCGImagePropertyGPSAltitudeRef as String)] = altitudeRef
        GPSMetadata[(kCGImagePropertyGPSTimeStamp as String)] = timestamp.isoTime()
        GPSMetadata[(kCGImagePropertyGPSDateStamp as String)] = timestamp.isoDate()
        GPSMetadata[(kCGImagePropertyGPSVersion as String)] = "2.2.0.0"

        if let heading = heading {
            let trueHeading = heading.trueHeading.headingAdjusted
            GPSMetadata[(kCGImagePropertyGPSImgDirection as String)] = trueHeading
            GPSMetadata[(kCGImagePropertyGPSImgDirectionRef as String)] = "T"

            if course <= 0 {
                GPSMetadata[(kCGImagePropertyGPSDestBearing as String)] = trueHeading
                GPSMetadata[(kCGImagePropertyGPSDestBearingRef as String)] = "T"
            } else {
                GPSMetadata[(kCGImagePropertyGPSDestBearing as String)] = course.headingAdjusted
                GPSMetadata[(kCGImagePropertyGPSDestBearingRef as String)] = "T"
            }
        }
        return GPSMetadata
    }
}

extension CLLocationDirection {
    var headingAdjusted: CLLocationDirection {
        let adjAngle: CLLocationDirection = {
            switch UIDevice.current.orientation {
                case .landscapeLeft:  return 90
                case .landscapeRight: return -90
                case .portraitUpsideDown: return -180
                default: return 0 // .portrait, .faceDown, .faceUp
            }
        }()
        print("heading: \(self) adjusted: \((self + adjAngle).truncatingRemainder(dividingBy: 360))")
        return (self + adjAngle).truncatingRemainder(dividingBy: 360)
    }

}

extension Date {

    func isoDate() -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyy:MM:dd"
        return f.string(from: self)
    }

    func isoTime() -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "HH:mm:ss.SSSSSS"
        return f.string(from: self)
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

enum Direction: String, CaseIterable {
    case n, nne, ne, ene, e, ese, se, sse, s, ssw, sw, wsw, w, wnw, nw, nnw
}

extension Direction: CustomStringConvertible  {
    init<D: BinaryFloatingPoint>(_ direction: D) {
        self =  Self.allCases[Int((direction.angle+11.25).truncatingRemainder(dividingBy: 360)/22.5)]
    }
    var description: String { rawValue.uppercased() }
}

extension BinaryFloatingPoint {
    var angle: Self {
        (truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
    }
    var direction: Direction { .init(self) }
}
