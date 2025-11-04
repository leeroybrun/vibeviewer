// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AIUsageTrackerAppEnvironment",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "AIUsageTrackerAppEnvironment",
      targets: ["AIUsageTrackerAppEnvironment"]
    )
  ],
  dependencies: [
    .package(path: "../AIUsageTrackerAPI"),
    .package(path: "../AIUsageTrackerModel"),
    .package(path: "../AIUsageTrackerStorage"),
    .package(path: "../AIUsageTrackerCore"),
    
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "AIUsageTrackerAppEnvironment",
      dependencies: [
        "AIUsageTrackerAPI",
        "AIUsageTrackerModel",
        "AIUsageTrackerStorage",
        "AIUsageTrackerCore",
      ]
    ),
    .testTarget(
      name: "AIUsageTrackerAppEnvironmentTests",
      dependencies: ["AIUsageTrackerAppEnvironment"],
      path: "Tests/AIUsageTrackerAppEnvironmentTests"
    ),
  ]
)
