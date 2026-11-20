import Foundation
import CoreLocation
import UIKit

class ContinuesLocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = ContinuesLocationManager()
    private static let regionIdentifier = "dynamicRegion"

    private let locationManager = CLLocationManager()
    var myLocation: CLLocation?
    var isTrackUser: Bool = false
    private var monitoredRegion: CLCircularRegion?
    private static let alwaysRequestedKey = "GeofenceBackgroundAlwaysRequested"

    /// Called on the main thread for each entry or exit, before the request is sent.
    var onTransition: ((CheckInRequest) -> Void)?
    /// Called on the main thread whenever the location authorization changes.
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    /// While true, the automatic "Always" request after "While Using" is skipped, because
    /// requestPermissions is asking for it itself.
    var suppressAutoAlwaysRequest = false

    var authorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return locationManager.authorizationStatus
        }
        return CLLocationManager.authorizationStatus()
    }

    /// iOS shows the "Always" prompt only once, so after that a missing "Always" means denied.
    var hasRequestedAlways: Bool {
        UserDefaults.standard.bool(forKey: ContinuesLocationManager.alwaysRequestedKey)
    }

    func requestWhenInUse() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlways() {
        UserDefaults.standard.set(true, forKey: ContinuesLocationManager.alwaysRequestedKey)
        locationManager.requestAlwaysAuthorization()
    }

    /// The values saved by startTrackUser, or nil when tracking is off.
    func savedArea() -> (latitude: Double, longitude: Double, radius: Double, apiEndPoint: String, userID: Int)? {
        let defaults = UserDefaults.standard
        guard let endpoint = defaults.string(forKey: "StoredAPIEndpoint"), !endpoint.isEmpty else {
            return nil
        }
        return (
            defaults.double(forKey: "StoredLatitude"),
            defaults.double(forKey: "StoredLongitude"),
            defaults.double(forKey: "StoredRadius"),
            endpoint,
            defaults.integer(forKey: "StoredUserID")
        )
    }

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func clearStoredUserDefaults() {
        let defaults = UserDefaults.standard
        let keys = [
            "StoredLatitude",
            "StoredLongitude",
            "StoredRadius",
            "StoredAPIEndpoint",
            "StoredUserID",
            "auth_token"
        ]
        
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        
        defaults.synchronize() // Optional
    }

    func startTrackUser(lat: Double, long: Double, radius: Double = 5.0, apiEndPoint: String, userID: Int, auth_token: String) {
        // Clear old stored values
        clearStoredUserDefaults()
        
        let defaults = UserDefaults.standard
        defaults.set(lat, forKey: "StoredLatitude")
        defaults.set(long, forKey: "StoredLongitude")
        defaults.set(radius, forKey: "StoredRadius")
        defaults.set(apiEndPoint, forKey: "StoredAPIEndpoint")
        defaults.set(userID, forKey: "StoredUserID")
        defaults.set(auth_token, forKey: "auth_token")
        defaults.synchronize()

        print("User id startTrackUser \(userID)")

    //    if isTrackUser { return }
    //    isTrackUser = true

        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.startUpdatingLocation()
        createRegion(lat: lat, long: long, radius: radius)
    }

    func stopTrackUser() {
        isTrackUser = false
        locationManager.stopUpdatingLocation()

        // iOS keeps monitored regions across app restarts, so look them up instead of relying on
        // monitoredRegion, which is nil after a relaunch. Only touch this plugin's region: the
        // list is shared with any other location manager in the host app.
        for region in locationManager.monitoredRegions where region.identifier == ContinuesLocationManager.regionIdentifier {
            locationManager.stopMonitoring(for: region)
        }
        monitoredRegion = nil

        // Without a stored endpoint, checkInOrCheckOutUser sends nothing for any late region event.
        clearStoredUserDefaults()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        onAuthorizationChange?(status)

        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .restricted, .denied:
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                self.showAlert(
                    title: "Location Required",
                    message: "Please enable location services for better functionality."
                )
            }

        case .authorizedWhenInUse:
            guard !suppressAutoAlwaysRequest else { break }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                guard !self.suppressAutoAlwaysRequest, self.authorizationStatus == .authorizedWhenInUse else { return }
                self.requestAlways()
            }

        case .authorizedAlways:
            manager.startUpdatingLocation()

        @unknown default:
            print("Unknown authorization status")
        }
    }

    // MARK: - Show Alert
    func showAlert(title: String, message: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(settingsURL) {
                    UIApplication.shared.open(settingsURL)
                }
            })

//            UIApplication.getTopViewController()?.present(alertController, animated: true)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//         guard let location = locations.last else { return }

// //        Constants.long = location.coordinate.longitude
// //        Constants.lat = location.coordinate.latitude

//         if location.horizontalAccuracy <= 65.0 {
//             myLocation = location
//             createRegion(location: location)
//         } else {
//             manager.stopUpdatingLocation()
//             manager.startUpdatingLocation()
//         }
    }

    func createRegion(lat:Double, long:Double, radius: Double = 5.0) {

        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {

            if let region = monitoredRegion {
                locationManager.stopMonitoring(for: region)
            }
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
            // let regionRadius = 50.0
            let regionRadius = radius
            let region = CLCircularRegion(center: coordinate, radius: regionRadius, identifier: ContinuesLocationManager.regionIdentifier)
            region.notifyOnEntry = true
            region.notifyOnExit = true

            locationManager.startMonitoring(for: region)
            monitoredRegion = region
        } else {
            print("System can't track regions")
        }
    }

    private func updateLocation(location: CLLocation) {
        let content = UNMutableNotificationContent()
        content.title = "Location Update:"
        content.body = getFormattedDate()
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "location_notification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func getFormattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, dd/MM/yyyy hh:mm:ss a"
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        return dateFormatter.string(from: Date())
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == ContinuesLocationManager.regionIdentifier else { return }
        print("User entered the region")
        checkInOrCheckOutUser(isCheckin: true)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == ContinuesLocationManager.regionIdentifier else { return }
        print("User exited the region")
        checkInOrCheckOutUser(isCheckin: false)
    }

    func checkInOrCheckOutUser(isCheckin: Bool) {
        let defaults = UserDefaults.standard
        let storedAPIEndpoint = defaults.string(forKey: "StoredAPIEndpoint") ?? ""
        print(isCheckin)
        guard !storedAPIEndpoint.isEmpty else {
            print("Invalid API Endpoint")
            return
        }

        let request = CheckInRequest(
            eventID: UUID().uuidString.lowercased(),
            endpoint: storedAPIEndpoint,
            authToken: defaults.string(forKey: "auth_token") ?? "",
            userID: defaults.integer(forKey: "StoredUserID"),
            latitude: defaults.double(forKey: "StoredLatitude"),
            longitude: defaults.double(forKey: "StoredLongitude"),
            isCheckin: isCheckin,
            timestamp: Date()
        )
        onTransition?(request)
        // Sent now if possible; otherwise saved and retried, in order, until the server answers.
        CheckInQueue.shared.deliver(request)
    }

}
