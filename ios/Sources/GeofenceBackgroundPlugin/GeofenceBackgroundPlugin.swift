import Foundation
import Capacitor
import CoreLocation
import UIKit

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(GeofenceBackgroundPlugin)
public class GeofenceBackgroundPlugin: CAPPlugin, CAPBridgedPlugin {
    
    // Capacitor 6 only exposes methods listed here to JavaScript.
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "startTrackUser", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopTrackUser", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getCurrentLocation", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkPermissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestPermissions", returnType: CAPPluginReturnPromise)
    ]

    public let identifier = "GeofenceBackgroundPlugin"
    public let jsName = "GeofenceBackground"
    // Created when the bridge loads its plugins, so the CLLocationManager delegate is in place
    // when iOS relaunches a killed app to deliver a region event. Never set to nil: the same
    // manager is reused if tracking is started again after a stop.
    private let locationContinues = ContinuesLocationManager.shared
    static var isTrackUser: Bool = false

    /// requestPermissions calls waiting for the user's answer. Only touched on the main thread.
    private var permissionCalls: [CAPPluginCall] = []
    private var isWaitingForWhenInUse = false
    private var isWaitingForAlways = false
    private var appStateObservers: [NSObjectProtocol] = []
    /// Increases each time a permission request finishes, so a timer from an earlier one does nothing.
    private var permissionRound = 0

    override public func load() {
        locationContinues.onTransition = { [weak self] request in
            self?.notifyListeners("geofenceEvent", data: request.eventData, retainUntilConsumed: true)
        }
        locationContinues.onAuthorizationChange = { [weak self] status in
            self?.authorizationChanged(status)
        }
        CheckInQueue.shared.setStatusHandler { [weak self] request, status in
            var data = request.eventData
            data["status"] = status.rawValue
            self?.notifyListeners("requestResult", data: data, retainUntilConsumed: true)
        }
        // Send check-ins saved while there was no network, and retry when the network comes back.
        CheckInQueue.shared.start()
    }

    /// Reads a numeric option that JavaScript may send as a number (`24.86`) or a string (`"24.86"`).
    private func doubleOption(_ call: CAPPluginCall, _ key: String) -> Double? {
        if let value = call.getDouble(key) { return value }
        if let text = call.getString(key) { return Double(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    /// Reads an integer option that JavaScript may send as a number (`42`) or a string (`"42"`).
    private func intOption(_ call: CAPPluginCall, _ key: String) -> Int? {
        if let value = call.getInt(key) { return value }
        if let text = call.getString(key) { return Int(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": value
        ])
    }   
    // func startTrackUser(lat: Double, long: Double, radius: Double = 5.0, apiEndPoint: String, userID: Int) {
 
    //     locationContinues = ContinuesLocationManager.shared
    //     locationContinues?.startTrackUser(lat: lat, long: long, radius: radius, apiEndPoint: apiEndPoint, userID: userID)

 
    // }

    @objc func startTrackUser(_ call: CAPPluginCall) {
        guard let lat = doubleOption(call, "lat"),
              let long = doubleOption(call, "long"),
              let userID = intOption(call, "userID"),
              let apiEndPoint = call.getString("apiEndPoint"), !apiEndPoint.isEmpty else {
            call.reject("Missing or invalid parameters: lat, long, userID and apiEndPoint are required")
            return
        }

        let radius = doubleOption(call, "radius") ?? 5.0  // Default radius if missing or invalid
        let auth_token = call.getString("auth_token") ?? ""

        locationContinues.startTrackUser(lat: lat, long: long, radius: radius, apiEndPoint: apiEndPoint, userID: userID, auth_token: auth_token)
        GeofenceBackgroundPlugin.isTrackUser = true

        call.resolve([
            "message": "User tracking started successfully",
            "latitude": lat,
            "longitude": long,
            "radius": radius,
            "apiEndPoint": apiEndPoint,
            "userID": userID,
            "auth_token": auth_token
        ])
    }

    @objc func stopTrackUser(_ call: CAPPluginCall) {
        locationContinues.stopTrackUser()
        GeofenceBackgroundPlugin.isTrackUser = false
        call.resolve(["message": "User tracking stopped successfully"])
    }

    @objc func getStatus(_ call: CAPPluginCall) {
        var result: [String: Any] = [
            "isTracking": false,
            "pendingRequests": CheckInQueue.shared.pendingRequests.count
        ]
        if let area = locationContinues.savedArea() {
            result["isTracking"] = true
            result["latitude"] = area.latitude
            result["longitude"] = area.longitude
            result["radius"] = area.radius
            result["apiEndPoint"] = area.apiEndPoint
            result["userID"] = area.userID
        }
        call.resolve(result)
    }

    @objc func getCurrentLocation(_ call: CAPPluginCall) {
        let timeout = max(1, call.getDouble("timeout") ?? 10_000) / 1000
        let maximumAge = max(0, call.getDouble("maximumAge") ?? 0) / 1000
        let highAccuracy = call.getBool("enableHighAccuracy") ?? true
        DispatchQueue.main.async {
            LocationFetcher.fetch(highAccuracy: highAccuracy, timeout: timeout, maximumAge: maximumAge) { [weak self] result in
                switch result {
                case .success(let location):
                    call.resolve(self?.locationResult(location) ?? [:])
                case .failure(let error):
                    call.reject(error.message, error.failure.rawValue)
                }
            }
        }
    }

    /// Same fields as on Android. Values iOS doesn't know (negative) are left out.
    private func locationResult(_ location: CLLocation) -> [String: Any] {
        var result: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": CheckInSender.formatTimestamp(location.timestamp)
        ]
        if location.verticalAccuracy >= 0 {
            result["altitude"] = location.altitude
            result["altitudeAccuracy"] = location.verticalAccuracy
        }
        if location.speed >= 0 {
            result["speed"] = location.speed
        }
        if location.course >= 0 {
            result["heading"] = location.course
        }
        // While tracking, also say how far the device is from the area and whether it is inside.
        if let area = locationContinues.savedArea() {
            let distance = location.distance(from: CLLocation(latitude: area.latitude, longitude: area.longitude))
            result["distanceFromCenter"] = distance
            result["isInsideArea"] = distance <= area.radius
        }
        return result
    }

    @objc override public func checkPermissions(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(self.permissionStatus())
        }
    }

    /// Asks for "While Using", then "Always", and resolves once the user has answered both.
    @objc override public func requestPermissions(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let isRunning = !self.permissionCalls.isEmpty
            self.permissionCalls.append(call)
            if !isRunning {
                self.locationContinues.suppressAutoAlwaysRequest = true
                self.continuePermissionRequest()
            }
        }
    }

    private func continuePermissionRequest() {
        let status = locationContinues.authorizationStatus
        if status == .notDetermined {
            isWaitingForWhenInUse = true
            locationContinues.requestWhenInUse()
            return
        }
        guard status == .authorizedWhenInUse, !locationContinues.hasRequestedAlways else {
            finishPermissionRequest()
            return
        }
        // Right after the "While Using" prompt the app may not be active yet. Wait, so the
        // app becoming active below really means the "Always" prompt has closed.
        guard UIApplication.shared.applicationState == .active else {
            observeOnce(UIApplication.didBecomeActiveNotification) { [weak self] in
                self?.continuePermissionRequest()
            }
            return
        }
        isWaitingForAlways = true
        // Keeping "While Using" changes nothing, so iOS reports no change: finish when the
        // prompt closes instead.
        var didShowPrompt = false
        observeOnce(UIApplication.willResignActiveNotification) { didShowPrompt = true }
        let round = permissionRound
        observeOnce(UIApplication.didBecomeActiveNotification) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.finishPermissionRequest(round: round) }
        }
        // iOS shows the prompt only once per app. If it doesn't appear, don't wait forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if !didShowPrompt { self?.finishPermissionRequest(round: round) }
        }
        locationContinues.requestAlways()
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        if isWaitingForWhenInUse && status != .notDetermined {
            isWaitingForWhenInUse = false
            continuePermissionRequest()
        } else if isWaitingForAlways && status != .authorizedWhenInUse {
            finishPermissionRequest()
        }
    }

    private func observeOnce(_ name: Notification.Name, _ handler: @escaping () -> Void) {
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                self?.appStateObservers.removeAll { $0 === observer }
            }
            handler()
        }
        if let observer = observer {
            appStateObservers.append(observer)
        }
    }

    private func finishPermissionRequest(round: Int? = nil) {
        guard !permissionCalls.isEmpty, round == nil || round == permissionRound else { return }
        permissionRound += 1
        isWaitingForWhenInUse = false
        isWaitingForAlways = false
        locationContinues.suppressAutoAlwaysRequest = false
        appStateObservers.forEach { NotificationCenter.default.removeObserver($0) }
        appStateObservers = []
        let status = permissionStatus()
        let calls = permissionCalls
        permissionCalls = []
        calls.forEach { $0.resolve(status) }
    }

    private func permissionStatus() -> [String: Any] {
        let location: String
        let background: String
        switch locationContinues.authorizationStatus {
        case .notDetermined:
            location = "prompt"
            background = "prompt"
        case .restricted, .denied:
            location = "denied"
            background = "denied"
        case .authorizedAlways:
            location = "granted"
            background = "granted"
        case .authorizedWhenInUse:
            location = "granted"
            background = locationContinues.hasRequestedAlways ? "denied" : "prompt"
        @unknown default:
            location = "prompt"
            background = "prompt"
        }
        return ["location": location, "backgroundLocation": background]
    }
}

extension CheckInRequest {
    /// The fields shared by the geofenceEvent and requestResult events. Same as on Android.
    var eventData: [String: Any] {
        [
            "eventId": eventID,
            "transition": isCheckin ? "enter" : "exit",
            "timestamp": CheckInSender.formatTimestamp(timestamp),
            "latitude": latitude,
            "longitude": longitude
        ]
    }
}
