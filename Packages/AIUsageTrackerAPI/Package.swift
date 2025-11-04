// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "AIUsageTrackerAPI",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "AIUsageTrackerAPI", targets: ["AIUsageTrackerAPI"])
  ],
  dependencies: [
    .package(path: "../AIUsageTrackerCore"),
    .package(path: "../AIUsageTrackerModel"),
    .package(url: "https://github.com/Moya/Moya.git", .upToNextMajor(from: "15.0.0")),
    .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.8.0")),
    
  ],
  targets: [
    .target(
      name: "AIUsageTrackerAPI",
      dependencies: [
        "AIUsageTrackerCore",
        "AIUsageTrackerModel",
        .product(name: "Moya", package: "Moya"),
        .product(name: "Alamofire", package: "Alamofire"),
      ]
    ),
    .testTarget(
      name: "AIUsageTrackerAPITests",
      dependencies: ["AIUsageTrackerAPI"]
    ),
  ]
)
