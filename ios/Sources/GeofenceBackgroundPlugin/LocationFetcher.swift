import Foundation
import CoreLocation

/// Gets the device's location once, for getCurrentLocation. Same result fields as the Android plugin.
/// It has its own CLLocationManager so it doesn't disturb the one watching the geofence.
final class LocationFetcher: NSObject, CLLocationManagerDelegate {

    enum Failure: String {
        case permissionDenied = "PERMISSION_DENIED"
        case locationDisabled = "LOCATION_DISABLED"
        case timeout = "TIMEOUT"
        case unavailable = "UNAVAILABLE"
    }

    typealias Completion = (Result<CLLocation, FetchError>) -> Void

    struct FetchError: Error {
        let failure: Failure
        let message: String
    }

    /// Keeps each fetch alive until it finishes.
    private static var active: [LocationFetcher] = []

    private let manager = CLLocationManager()
    private var completion: Completion?
    private var isWaitingForAuthorization = false

    /// Call on the main thread.
    static func fetch(highAccuracy: Bool, timeout: TimeInterval, maximumAge: TimeInterval, completion: @escaping Completion) {
        let fetcher = LocationFetcher()
        active.append(fetcher)
        fetcher.start(highAccuracy: highAccuracy, timeout: timeout, maximumAge: maximumAge, completion: completion)
    }

    private func start(highAccuracy: Bool, timeout: TimeInterval, maximumAge: TimeInterval, completion: @escaping Completion) {
        self.completion = completion
        manager.delegate = self
        manager.desiredAccuracy = highAccuracy ? kCLLocationAccuracyBest : kCLLocationAccuracyHundredMeters

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finish(.failure(FetchError(failure: .timeout, message: "Could not get a location within \(Int(timeout * 1000)) ms")))
        }

        if maximumAge > 0, let known = manager.location, -known.timestamp.timeIntervalSinceNow <= maximumAge {
            finish(.success(known))
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            isWaitingForAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            failForDeniedAccess()
        default:
            manager.requestLocation()
        }
    }

    private var authorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return manager.authorizationStatus
        }
        return CLLocationManager.authorizationStatus()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard isWaitingForAuthorization, status != .notDetermined else { return }
        isWaitingForAuthorization = false
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.requestLocation()
        } else {
            failForDeniedAccess()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            finish(.success(location))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied {
            failForDeniedAccess()
        } else {
            finish(.failure(FetchError(failure: .unavailable, message: "Could not get the location: \(error.localizedDescription)")))
        }
    }

    /// iOS reports both "permission denied" and "Location Services off" as denied; tell them apart.
    private func failForDeniedAccess() {
        DispatchQueue.global().async {
            let servicesOn = CLLocationManager.locationServicesEnabled()
            DispatchQueue.main.async {
                self.finish(.failure(servicesOn
                    ? FetchError(failure: .permissionDenied, message: "Location permission is required")
                    : FetchError(failure: .locationDisabled, message: "Location is switched off on the device")))
            }
        }
    }

    private func finish(_ result: Result<CLLocation, FetchError>) {
        guard let completion = completion else { return }
        self.completion = nil
        manager.delegate = nil
        LocationFetcher.active.removeAll { $0 === self }
        completion(result)
    }
}
