// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TriggerSearch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TriggerSearch", targets: ["TriggerSearch"]),
    ],
    targets: [
        .target(name: "TriggerSearchKit"),
        .executableTarget(name: "TriggerSearch", dependencies: ["TriggerSearchKit"]),
        .testTarget(name: "TriggerSearchKitTests", dependencies: ["TriggerSearchKit"]),
    ]
)
