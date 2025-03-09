// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorGeofenceBackground",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "CapacitorGeofenceBackground",
            targets: ["GeofenceBackgroundPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", branch: "main")
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