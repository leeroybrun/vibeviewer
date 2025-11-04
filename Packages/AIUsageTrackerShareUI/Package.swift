// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "AIUsageTrackerShareUI",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "AIUsageTrackerShareUI", targets: ["AIUsageTrackerShareUI"])
  ],
  dependencies: [
    .package(path: "../AIUsageTrackerModel")
  ],
  targets: [
    .target(
      name: "AIUsageTrackerShareUI",
      dependencies: ["AIUsageTrackerModel"],
      resources: [
        // 将自定义字体放入 Sources/AIUsageTrackerShareUI/Fonts/ 下
        // 例如：Satoshi-Regular.otf、Satoshi-Medium.otf、Satoshi-Bold.otf、Satoshi-Italic.otf
        .process("Fonts"),
        .process("Images"),
        .process("Shaders")
      ]
    ),
    .testTarget(name: "AIUsageTrackerShareUITests", dependencies: ["AIUsageTrackerShareUI"]),
  ]
)
