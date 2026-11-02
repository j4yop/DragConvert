// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EngineKit",
    platforms: [.macOS(.v13)],
    products: [.library(name: "EngineKit", targets: ["EngineKit"])],
    dependencies: [
        .package(path: "../JobCore")
    ],
    targets: [
        .target(
            name: "EngineKit",
            dependencies: [.product(name: "JobCore", package: "JobCore")],
            path: "Sources/EngineKit"
        )
    ]
)
