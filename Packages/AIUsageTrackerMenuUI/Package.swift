// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "AIUsageTrackerMenuUI",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "AIUsageTrackerMenuUI", targets: ["AIUsageTrackerMenuUI"])
  ],
  dependencies: [
    .package(path: "../AIUsageTrackerCore"),
    .package(path: "../AIUsageTrackerModel"),
    .package(path: "../AIUsageTrackerAppEnvironment"),
    .package(path: "../AIUsageTrackerAPI"),
    .package(path: "../AIUsageTrackerLoginUI"),
    .package(path: "../AIUsageTrackerSettingsUI"),
    .package(path: "../AIUsageTrackerShareUI"),
  ],
  targets: [
    .target(
      name: "AIUsageTrackerMenuUI",
      dependencies: [
        "AIUsageTrackerCore",
        "AIUsageTrackerModel",
        "AIUsageTrackerAppEnvironment",
        "AIUsageTrackerAPI",
        "AIUsageTrackerLoginUI",
        "AIUsageTrackerSettingsUI",
        "AIUsageTrackerShareUI"
      ],
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(name: "AIUsageTrackerMenuUITests", dependencies: ["AIUsageTrackerMenuUI"]),
  ]
)
