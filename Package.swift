// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SampleSearch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SampleSearch", targets: ["SampleSearch"]),
    ],
    targets: [
        .target(name: "SampleSearchKit"),
        .target(name: "DrumIcons"),
        .executableTarget(name: "icon-preview", dependencies: ["DrumIcons"]),
        .executableTarget(name: "SampleSearch", dependencies: ["SampleSearchKit", "DrumIcons"]),
        .testTarget(name: "SampleSearchKitTests", dependencies: ["SampleSearchKit"]),
    ]
)
