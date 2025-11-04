// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AIUsageTrackerCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AIUsageTrackerCore", targets: ["AIUsageTrackerCore"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "AIUsageTrackerCore", dependencies: []),
        .testTarget(name: "AIUsageTrackerCoreTests", dependencies: ["AIUsageTrackerCore"])
    ]
)
