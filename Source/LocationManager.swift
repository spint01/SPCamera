import Foundation
import CoreLocation
import AVFoundation
import UIKit

final class LocationManager: NSObject, CLLocationManagerDelegate {
    var manager = CLLocationManager()
    var latestLocation: CLLocation?
    var latestHeading: CLHeading?

    var accuracyAuthorization: CLAccuracyAuthorization {
        if #available(iOS 14.0, *) {
            return manager.accuracyAuthorization
        } else {
            return CLAccuracyAuthorization.fullAccuracy
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func authorizeAccuracy(purposeKey: String, authorizationStatus: @escaping (CLAccuracyAuthorization) -> Void) {
        if #available(iOS 14.0, *) {
            manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: purposeKey) { (error) in
                self.startUpdatingLocation()
                authorizationStatus(self.manager.accuracyAuthorization)
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
                if manager.accuracyAuthorization == .fullAccuracy {
                    startUpdatingLocation()
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
