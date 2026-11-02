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
        .package(path: "Packages/Engines/ImageEngine")
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
                .product(name: "ImageEngine", package: "ImageEngine")
            ],
            path: "App"
        ),
        .testTarget(
            name: "DragConvertTests",
            dependencies: [
                .product(name: "CapabilityGraph", package: "CapabilityGraph"),
                .product(name: "JobCore", package: "JobCore"),
                .product(name: "ImageEngine", package: "ImageEngine"),
                .product(name: "PDFEngine", package: "PDFEngine")
            ],
            path: "Tests/DragConvertTests"
        )
    ]
)
