// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WheelUI",
    platforms: [.macOS(.v13)],
    products: [.library(name: "WheelUI", targets: ["WheelUI"])],
    dependencies: [
        .package(path: "../CapabilityGraph")
    ],
    targets: [
        .target(
            name: "WheelUI",
            dependencies: [.product(name: "CapabilityGraph", package: "CapabilityGraph")],
            path: "Sources/WheelUI",
            resources: [.process("Resources")]
        )
    ]
)
