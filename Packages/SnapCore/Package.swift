// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SnapCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "SnapCore", targets: ["SnapCore"])],
    targets: [
        .target(name: "SnapCore"),
        .testTarget(name: "SnapCoreTests", dependencies: ["SnapCore"]),
    ]
)
