import ProjectDescription

let workspaceName = "AIUsageTracker"

let project = Project(
    name: workspaceName,
    organizationName: "AIUsageTracker",
    options: .options(
        developmentRegion: "en",
        disableBundleAccessors: false,
        disableSynthesizedResourceAccessors: false
    ),
    packages: [
        .local(path: "Packages/AIUsageTrackerCore"),
        .local(path: "Packages/AIUsageTrackerModel"),
        .local(path: "Packages/AIUsageTrackerAPI"),
        .local(path: "Packages/AIUsageTrackerLoginUI"),
        .local(path: "Packages/AIUsageTrackerMenuUI"),
        .local(path: "Packages/AIUsageTrackerSettingsUI"),
        .local(path: "Packages/AIUsageTrackerAppEnvironment"),
        .local(path: "Packages/AIUsageTrackerStorage"),
        .local(path: "Packages/AIUsageTrackerShareUI"),
    ],
    settings: .settings(base: [
        "SWIFT_VERSION": "5.10",
        "MACOSX_DEPLOYMENT_TARGET": "14.0",
    ]),
    targets: [
        .target(
            name: workspaceName,
            destinations: .macOS,
            product: .app,
            bundleId: "com.magicgroot.aiusagetracker",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "LSUIElement": .boolean(true),
                "LSMinimumSystemVersion": .string("14.0"),
                "LSApplicationCategoryType": .string("public.app-category.productivity"),
                "UIAppFonts": .array([.string("Satoshi-Regular.ttf"), .string("Satoshi-Medium.ttf"), .string("Satoshi-Bold.ttf"), .string("Satoshi-Italic.ttf")]),
            ]),
            sources: ["AIUsageTracker/**"],
            resources: [
                "AIUsageTracker/Assets.xcassets",
                "AIUsageTracker/Preview Content/**",
            ],
            dependencies: [
                .package(product: "AIUsageTrackerAPI"),
                .package(product: "AIUsageTrackerModel"),
                .package(product: "AIUsageTrackerCore"),
                .package(product: "AIUsageTrackerLoginUI"),
                .package(product: "AIUsageTrackerMenuUI"),
                .package(product: "AIUsageTrackerSettingsUI"),
                .package(product: "AIUsageTrackerAppEnvironment"),
                .package(product: "AIUsageTrackerStorage"),
                .package(product: "AIUsageTrackerShareUI"),
            ]
        )
    ]
)
