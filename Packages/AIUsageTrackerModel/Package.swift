// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AIUsageTrackerModel",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AIUsageTrackerModel", targets: ["AIUsageTrackerModel"]),
    ],
    dependencies: [
        .package(path: "../AIUsageTrackerCore")
    ],
    targets: [
        .target(name: "AIUsageTrackerModel", dependencies: ["AIUsageTrackerCore"]),
        .testTarget(name: "AIUsageTrackerModelTests", dependencies: ["AIUsageTrackerModel"])
    ]
)
