import Foundation

@objc public class GeofenceBackground: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
