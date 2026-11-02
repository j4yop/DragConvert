// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ImageEngine",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ImageEngine", targets: ["ImageEngine"])],
    dependencies: [
        .package(path: "../../JobCore"),
        .package(path: "../../EngineKit")
    ],
    targets: [
        .target(
            name: "ImageEngine",
            dependencies: [
                .product(name: "JobCore", package: "JobCore"),
                .product(name: "EngineKit", package: "EngineKit")
            ],
            path: "Sources/ImageEngine"
        )
    ]
)
