// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "JobCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "JobCore", targets: ["JobCore"])],
    targets: [.target(name: "JobCore", path: "Sources/JobCore")]
)
