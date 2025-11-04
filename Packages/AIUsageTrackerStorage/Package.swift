// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AIUsageTrackerStorage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AIUsageTrackerStorage", targets: ["AIUsageTrackerStorage"])
    ],
    dependencies: [
        .package(path: "../AIUsageTrackerModel"),
        .package(path: "../AIUsageTrackerAPI"),
        .package(path: "../AIUsageTrackerCore")
    ],
    targets: [
        .target(
            name: "AIUsageTrackerStorage",
            dependencies: [
                .product(name: "AIUsageTrackerModel", package: "AIUsageTrackerModel"),
                .product(name: "AIUsageTrackerAPI", package: "AIUsageTrackerAPI"),
                .product(name: "AIUsageTrackerCore", package: "AIUsageTrackerCore")
            ]
        ),
        .testTarget(
            name: "AIUsageTrackerStorageTests",
            dependencies: ["AIUsageTrackerStorage"]
        )
    ]
)


