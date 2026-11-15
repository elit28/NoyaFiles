// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NoyaCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NoyaCore", targets: ["NoyaCore"]),
    ],
    targets: [
        .target(name: "NoyaCore"),
        .testTarget(name: "NoyaCoreTests", dependencies: ["NoyaCore"]),
    ]
)
