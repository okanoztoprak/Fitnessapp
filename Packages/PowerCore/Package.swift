// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PowerCore",
    platforms: [.iOS(.v18), .macOS(.v14), .watchOS(.v11)],
    products: [.library(name: "PowerCore", targets: ["PowerCore"])],
    targets: [
        .target(name: "PowerCore"),
        .testTarget(name: "PowerCoreTests", dependencies: ["PowerCore"]),
    ]
)
