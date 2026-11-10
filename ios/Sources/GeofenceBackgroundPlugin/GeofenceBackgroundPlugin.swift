import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(GeofenceBackgroundPlugin)
public class GeofenceBackgroundPlugin: CAPPlugin, CAPBridgedPlugin {
    
    // Capacitor 6 only exposes methods listed here to JavaScript.
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "startTrackUser", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopTrackUser", returnType: CAPPluginReturnPromise)
    ]

    public let identifier = "GeofenceBackgroundPlugin"
    public let jsName = "GeofenceBackground"
    // Created when the bridge loads its plugins, so the CLLocationManager delegate is in place
    // when iOS relaunches a killed app to deliver a region event. Never set to nil: the same
    // manager is reused if tracking is started again after a stop.
    private let locationContinues = ContinuesLocationManager.shared
    static var isTrackUser: Bool = false

    override public func load() {
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
}
