// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DocumentEngine",
    platforms: [.macOS(.v13)],
    products: [.library(name: "DocumentEngine", targets: ["DocumentEngine"])],
    dependencies: [
        .package(path: "../../JobCore"),
        .package(path: "../../EngineKit"),
        .package(path: "../PDFEngine")
    ],
    targets: [
        .target(
            name: "DocumentEngine",
            dependencies: [
                .product(name: "JobCore", package: "JobCore"),
                .product(name: "EngineKit", package: "EngineKit"),
                .product(name: "PDFEngine", package: "PDFEngine")
            ],
            path: "Sources/DocumentEngine"
        )
    ]
)
