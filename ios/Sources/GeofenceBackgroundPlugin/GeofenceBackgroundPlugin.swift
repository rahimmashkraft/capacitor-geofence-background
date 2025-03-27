import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(GeofenceBackgroundPlugin)
public class GeofenceBackgroundPlugin: CAPPlugin, CAPBridgedPlugin {
    
        public let pluginMethods: [CAPPluginMethod] = [
         CAPPluginMethod(name: "startTrackUser", returnType: CAPPluginReturnPromise)
     ]
    
    public let identifier = "GeofenceBackgroundPlugin"
    public let jsName = "GeofenceBackground"
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
    // func startTrackUser(lat: Double, long: Double, radius: Double = 5.0, apiEndPoint: String, userID: Int) {
 
    //     locationContinues = ContinuesLocationManager.shared
    //     locationContinues?.startTrackUser(lat: lat, long: long, radius: radius, apiEndPoint: apiEndPoint, userID: userID)

 
    // }

    @objc func startTrackUser(_ call: CAPPluginCall) {
        let body = call.options as? [String:Any] ?? [:]

        guard let latString = body["lat"] as? String,
              let longString = body["long"] as? String,
              let apiEndPoint = body["apiEndPoint"] as? String,
              let userIDString = body["userID"] as? String,

              let lat = Double(latString),
              let long = Double(longString),
              let userID = Int(userIDString) else {
            call.reject("Missing or invalid parameters")
            return
        }

        let radius = Double(body["radius"] as? String ?? "5.0") ?? 5.0  // Default radius if conversion fails
        let auth_token = body["auth_token"] as? String ?? ""
        
        locationContinues?.startTrackUser(lat: lat, long: long, radius: radius, apiEndPoint: apiEndPoint, userID: userID, auth_token: auth_token)
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
        locationContinues?.stopTrackUser()
        locationContinues = nil
        GeofenceBackgroundPlugin.isTrackUser = false
        call.resolve(["message": "User tracking stopped successfully"])
    }
}
