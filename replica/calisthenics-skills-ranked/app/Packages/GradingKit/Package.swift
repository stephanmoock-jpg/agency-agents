// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GradingKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "GradingKit", targets: ["GradingKit"])],
    targets: [
        .target(name: "GradingKit"),
        .testTarget(name: "GradingKitTests", dependencies: ["GradingKit"],
                    resources: [.copy("Resources/vectors.json"), .copy("Resources/catalog.json")]),
    ]
)
