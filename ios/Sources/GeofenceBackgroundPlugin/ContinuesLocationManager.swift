import Foundation
import CoreLocation
import UIKit

class ContinuesLocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = ContinuesLocationManager()

    private let locationManager = CLLocationManager()
    var myLocation: CLLocation?
    var isTrackUser: Bool = false
    private var monitoredRegion: CLCircularRegion?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func startTrackUser(lat: Double, long: Double, radius: Double = 5.0, apiEndPoint: String, userID: Int, auth_token: String) {
        let defaults = UserDefaults.standard
        defaults.set(lat, forKey: "StoredLatitude")
        defaults.set(long, forKey: "StoredLongitude")
        defaults.set(radius, forKey: "StoredRadius")
        defaults.set(apiEndPoint, forKey: "StoredAPIEndpoint")
        defaults.set(userID, forKey: "StoredUserID")
        defaults.set(auth_token, forKey: "auth_token")
        defaults.synchronize()

        if isTrackUser { return }
        isTrackUser = true

        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.startUpdatingLocation()
        createRegion(lat: lat, long: long, radius: radius)
    }

    func stopTrackUser() {
        isTrackUser = false
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

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
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                if #available(iOS 14.0, *) {
                    manager.requestAlwaysAuthorization()
                } else {
                    // For iOS 13 and below, always request "Always" authorization
                    DispatchQueue.main.async {
                        manager.requestAlwaysAuthorization()
                    }
                }
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
            let region = CLCircularRegion(center: coordinate, radius: regionRadius, identifier: "dynamicRegion")
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
        print("User entered the region")
        checkInOrCheckOutUser(isCheckin: true)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("User exited the region")
        checkInOrCheckOutUser(isCheckin: false)
    }

    func checkInOrCheckOutUser(isCheckin: Bool) {
        let defaults = UserDefaults.standard
        let storedLat = defaults.double(forKey: "StoredLatitude")
        let storedLong = defaults.double(forKey: "StoredLongitude")
        let storedAPIEndpoint = defaults.string(forKey: "StoredAPIEndpoint") ?? ""
        let storedUserID = defaults.integer(forKey: "StoredUserID")
        let auth_token = defaults.string(forKey: "auth_token") ?? ""
        print(isCheckin)
        guard !storedAPIEndpoint.isEmpty, let url = URL(string: storedAPIEndpoint) else {
            print("Invalid API Endpoint")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = ""
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"latitude\"\r\n\r\n\(storedLat)\r\n"
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"longitude\"\r\n\r\n\(storedLong)\r\n"
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"aid\"\r\n\r\n\(storedUserID)\r\n"
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"auth_token\"\r\n\r\n\(auth_token)\r\n"
        body += "--\(boundary)\r\n"
        body += "Content-Disposition: form-data; name=\"checkin\"\r\n\r\n\(isCheckin)\r\n"
        body += "--\(boundary)--\r\n"
        
        request.httpBody = body.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response Status Code: \(httpResponse.statusCode)")
                }
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response Data: \(responseString)")
                }
            }
        }
        
        task.resume()
    }

}
