import Foundation
import CoreLocation
import AVFoundation
import UIKit

class LocationManager: NSObject, CLLocationManagerDelegate {
    var locationManager = CLLocationManager()
    var latestLocation: CLLocation?
    var latestHeading: CLHeading?

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

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Pick the location with best (= smallest value) horizontal accuracy
        latestLocation = locations.sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }.first
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            startUpdatingLocation()
        } else {
            stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        latestHeading = newHeading

//        print("Magnetic heading: \(newHeading.magneticHeading)")
//        print("True heading: \(newHeading.trueHeading)")
//        print("Orientation heading: \(manager.headingOrientation.rawValue)")
//        print("Accuracy heading: \(newHeading.headingAccuracy)")
//        latestLocation = manager.location
//        print("Manager course: \(String(describing: manager.location?.course))")
////        latestLocation?.course = newHeading.trueHeading
//
//        if let adjustment = latestLocation?.headingAdjusted(latestHeading?.trueHeading ?? 0) {
////        let adjustment = Double(orientationAdjustment())
//            let adjustedHeading = (newHeading.trueHeading + adjustment).truncatingRemainder(dividingBy: 360)
//            print("Adjustment: \(adjustment)  Adjusted heading: \(adjustedHeading)")
//        }
    }

}
