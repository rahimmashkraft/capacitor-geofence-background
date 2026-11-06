// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorGeofenceBackground",
    // iOS 13 is Capacitor 6's minimum. Apps on Capacitor 7 (iOS 14) and 8 (iOS 15) can still use it.
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "CapacitorGeofenceBackground",
            targets: ["GeofenceBackgroundPlugin"])
    ],
    dependencies: [
        // Any Capacitor from 6 on, like the ">=6.0.0" npm peer range. A version range, not a
        // branch, so it resolves alongside the exact Capacitor version an app pins.
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", "6.0.0"..<"100.0.0")
    ],
    targets: [
        .target(
            name: "GeofenceBackgroundPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/GeofenceBackgroundPlugin"),
        .testTarget(
            name: "GeofenceBackgroundPluginTests",
            dependencies: ["GeofenceBackgroundPlugin"],
            path: "ios/Tests/GeofenceBackgroundPluginTests")
    ]
)