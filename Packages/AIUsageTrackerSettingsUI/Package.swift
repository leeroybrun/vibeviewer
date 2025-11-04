// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "AIUsageTrackerSettingsUI",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "AIUsageTrackerSettingsUI", targets: ["AIUsageTrackerSettingsUI"])
  ],
  dependencies: [
    .package(path: "../AIUsageTrackerModel"),
    .package(path: "../AIUsageTrackerAppEnvironment"),
    .package(path: "../AIUsageTrackerShareUI"),
  ],
  targets: [
    .target(
      name: "AIUsageTrackerSettingsUI",
      dependencies: [
        "AIUsageTrackerModel",
        "AIUsageTrackerAppEnvironment",
        "AIUsageTrackerShareUI",
      ]
    ),
    .testTarget(name: "AIUsageTrackerSettingsUITests", dependencies: ["AIUsageTrackerSettingsUI"]),
  ]
)
