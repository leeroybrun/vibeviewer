// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AIUsageTrackerLoginUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AIUsageTrackerLoginUI", targets: ["AIUsageTrackerLoginUI"]),
    ],
    dependencies: [
        .package(path: "../AIUsageTrackerShareUI")
    ],
    targets: [
        .target(
            name: "AIUsageTrackerLoginUI",
            dependencies: [
                "AIUsageTrackerShareUI"
            ]
        ),
        .testTarget(name: "AIUsageTrackerLoginUITests", dependencies: ["AIUsageTrackerLoginUI"])
    ]
)


