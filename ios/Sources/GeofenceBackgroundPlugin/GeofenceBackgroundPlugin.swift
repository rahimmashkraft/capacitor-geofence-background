import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(GeofenceBackgroundPlugin)
public class GeofenceBackgroundPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "GeofenceBackgroundPlugin"
    public let jsName = "GeofenceBackground"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "echo", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = GeofenceBackground()

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.echo(value)
        ])
    }
    private var locationContinues:ContinuesLocationManager?
    static var isTrackUser:Bool = false

   func startTrackUser(lat: Double, long: Double, radius: Double = 5.0, apiEndPoint: String, userID: Int) {

       locationContinues = ContinuesLocationManager.shared
       locationContinues?.startTrackUser(lat: lat, long: long, radius: radius, apiEndPoint: apiEndPoint, userID: userID)

   }

   func stopTrackUser(){
       locationContinues?.stopTrackUser()
       locationContinues = nil
   }

}
