// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MediaEngine",
    platforms: [.macOS(.v13)],
    products: [.library(name: "MediaEngine", targets: ["MediaEngine"])],
    dependencies: [
        .package(path: "../../JobCore"),
        .package(path: "../../EngineKit")
    ],
    targets: [
        .target(
            name: "MediaEngine",
            dependencies: [
                .product(name: "JobCore", package: "JobCore"),
                .product(name: "EngineKit", package: "EngineKit")
            ],
            path: "Sources/MediaEngine"
        )
    ]
)
