import Foundation
import CoreLocation
import AVFoundation
import UIKit

final class LocationManager: NSObject, CLLocationManagerDelegate {
    var locationManager = CLLocationManager()
    var latestLocation: CLLocation?
    var latestHeading: CLHeading?

    var accuracyAuthorization: CLAccuracyAuthorization {
        if #available(iOS 14.0, *) {
            return locationManager.accuracyAuthorization
        } else {
            return CLAccuracyAuthorization.fullAccuracy
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    func authorizeAccuracy(purposeKey: String, authorizationStatus: @escaping (CLAccuracyAuthorization) -> Void) {
        if #available(iOS 14.0, *) {
            locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: purposeKey) { (error) in
                authorizationStatus(self.locationManager.accuracyAuthorization)
            }
        } else {
            authorizationStatus(.fullAccuracy)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Pick the location with best (= smallest value) horizontal accuracy
        latestLocation = locations.sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }.first
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            if #available(iOS 14.0, *) {
                if locationManager.accuracyAuthorization == .fullAccuracy {
                    startUpdatingLocation()
                } else {
                    authorizeAccuracy(purposeKey: "PhotoLocation", authorizationStatus: { (accuracy) in
                        if accuracy == .fullAccuracy {
                            self.startUpdatingLocation()
                        }
                    })
                }
            } else {
                startUpdatingLocation()
            }
        } else {
            stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        latestHeading = newHeading

        #if DEBUG_HEADING
        print("Magnetic heading: \(newHeading.magneticHeading)")
        print("True heading: \(newHeading.trueHeading)")
        print("Orientation heading: \(manager.headingOrientation.rawValue)")
        print("Accuracy heading: \(newHeading.headingAccuracy)")
        latestLocation = manager.location
        print("Manager course: \(String(describing: manager.location?.course))")
//        latestLocation?.course = newHeading.trueHeading

        if let adjustment = latestLocation?.headingAdjusted(latestHeading?.trueHeading ?? 0) {
//        let adjustment = Double(orientationAdjustment())
            let adjustedHeading = (newHeading.trueHeading + adjustment).truncatingRemainder(dividingBy: 360)
            print("Adjustment: \(adjustment)  Adjusted heading: \(adjustedHeading)")
        }
        #endif
    }

}
