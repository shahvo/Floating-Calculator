// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FloatingCalculator",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FloatingCalculator"
        )
    ]
)
