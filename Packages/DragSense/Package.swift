// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DragSense",
    platforms: [.macOS(.v13)],
    products: [.library(name: "DragSense", targets: ["DragSense"])],
    targets: [.target(name: "DragSense", path: "Sources/DragSense")]
)
