// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AITranslatorCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AITranslatorCore",
            targets: ["AITranslatorCore"]
        )
    ],
    targets: [
        .target(
            name: "AITranslatorCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AITranslatorCoreTests",
            dependencies: ["AITranslatorCore"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
