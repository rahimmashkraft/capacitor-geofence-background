import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(GeofenceBackgroundPlugin)
public class GeofenceBackgroundPlugin: CAPPlugin {
    private var locationContinues: ContinuesLocationManager?
    static var isTrackUser: Bool = false

    override public func load() {
        locationContinues = ContinuesLocationManager.shared
    }

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": value
        ])
    }

    @objc func startTrackUser(_ call: CAPPluginCall) {
        guard let lat = call.getDouble("lat"),
              let long = call.getDouble("long"),
              let apiEndPoint = call.getString("apiEndPoint"),
              let userID = call.getInt("userID") else {
            call.reject("Missing or invalid parameters")
            return
        }

        let radius = call.getDouble("radius") ?? 5.0

        locationContinues?.startTrackUser(lat: lat, long: long, radius: radius, apiEndPoint: apiEndPoint, userID: userID)
        GeofenceBackgroundPlugin.isTrackUser = true

        call.resolve([
            "message": "User tracking started successfully",
            "latitude": lat,
            "longitude": long,
            "radius": radius,
            "apiEndPoint": apiEndPoint,
            "userID": userID
        ])
    }

    @objc func stopTrackUser(_ call: CAPPluginCall) {
        locationContinues?.stopTrackUser()
        locationContinues = nil
        GeofenceBackgroundPlugin.isTrackUser = false
        call.resolve(["message": "User tracking stopped successfully"])
    }
}
