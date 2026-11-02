// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PDFEngine",
    platforms: [.macOS(.v13)],
    products: [.library(name: "PDFEngine", targets: ["PDFEngine"])],
    dependencies: [
        .package(path: "../../JobCore"),
        .package(path: "../../EngineKit")
    ],
    targets: [
        .target(
            name: "PDFEngine",
            dependencies: [
                .product(name: "JobCore", package: "JobCore"),
                .product(name: "EngineKit", package: "EngineKit")
            ],
            path: "Sources/PDFEngine"
        )
    ]
)
