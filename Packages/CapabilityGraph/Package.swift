// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CapabilityGraph",
    platforms: [.macOS(.v13)],
    products: [.library(name: "CapabilityGraph", targets: ["CapabilityGraph"])],
    targets: [
        .target(name: "CapabilityGraph", path: "Sources/CapabilityGraph")
    ]
)
