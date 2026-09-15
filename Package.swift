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
        .target(name: "DrumIcons"),
        .executableTarget(name: "icon-preview", dependencies: ["DrumIcons"]),
        .executableTarget(name: "TriggerSearch", dependencies: ["TriggerSearchKit", "DrumIcons"]),
        .testTarget(name: "TriggerSearchKitTests", dependencies: ["TriggerSearchKit"]),
    ]
)
