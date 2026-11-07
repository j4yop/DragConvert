// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DragConvert",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DragConvert", targets: ["DragConvertApp"])
    ],
    dependencies: [
        .package(path: "Packages/DragSense"),
        .package(path: "Packages/CapabilityGraph"),
        .package(path: "Packages/WheelUI"),
        .package(path: "Packages/JobCore"),
        .package(path: "Packages/EngineKit"),
        .package(path: "Packages/Engines/PDFEngine"),
        .package(path: "Packages/Engines/ImageEngine"),
        .package(path: "Packages/Engines/DocumentEngine"),
        .package(path: "Packages/Engines/MediaEngine")
    ],
    targets: [
        .executableTarget(
            name: "DragConvertApp",
            dependencies: [
                .product(name: "DragSense", package: "DragSense"),
                .product(name: "CapabilityGraph", package: "CapabilityGraph"),
                .product(name: "WheelUI", package: "WheelUI"),
                .product(name: "JobCore", package: "JobCore"),
                .product(name: "EngineKit", package: "EngineKit"),
                .product(name: "PDFEngine", package: "PDFEngine"),
                .product(name: "ImageEngine", package: "ImageEngine"),
                .product(name: "DocumentEngine", package: "DocumentEngine"),
                .product(name: "MediaEngine", package: "MediaEngine")
            ],
            path: "App"
        ),
        .testTarget(
            name: "DragConvertTests",
            dependencies: [
                .product(name: "CapabilityGraph", package: "CapabilityGraph"),
                .product(name: "JobCore", package: "JobCore"),
                .product(name: "ImageEngine", package: "ImageEngine"),
                .product(name: "PDFEngine", package: "PDFEngine"),
                .product(name: "DocumentEngine", package: "DocumentEngine"),
                .product(name: "MediaEngine", package: "MediaEngine")
            ],
            path: "Tests/DragConvertTests"
        )
    ]
)
