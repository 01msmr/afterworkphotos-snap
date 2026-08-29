import CoreLocation
import SnapCore

/// Runs while the viewfinder is live; hands out the latest fix as plain
/// numbers, or nil when there is none good enough.
final class LocationSource: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var latest: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func start() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.startUpdatingLocation()
    }
    func stop() { manager.stopUpdatingLocation() }

    /// (latitude, longitude) of a usable fix, else nil.
    var usableFix: (Double, Double)? {
        guard let l = latest,
              LocationFreshness.isUsable(age: -l.timestamp.timeIntervalSinceNow,
                                         accuracy: l.horizontalAccuracy) else { return nil }
        return (l.coordinate.latitude, l.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latest = locations.last
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse { manager.startUpdatingLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
