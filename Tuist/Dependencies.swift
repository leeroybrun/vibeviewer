import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: .init(
        packages: [
            // This project keeps a single source of truth: declare local packages only in Project.swift.
        ],
        baseSettings: .settings(
            base: [:],
            configurations: [
                .debug(
                    name: "Debug",
                    settings: [
                        "SWIFT_OPTIMIZATION_LEVEL": "-Onone"
                    ]
                ),
                .release(
                    name: "Release",
                    settings: [
                        "SWIFT_OPTIMIZATION_LEVEL": "-Owholemodule"
                    ]
                ),
            ]
        )
    ),
    platforms: [.macOS]
)
