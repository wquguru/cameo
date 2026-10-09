// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cameo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Cameo", path: "Sources/Cameo"),
        .executableTarget(name: "CameoSample", path: "Sources/CameoSample"),
        .executableTarget(name: "CameoIcon", path: "Sources/CameoIcon"),
    ],
    swiftLanguageModes: [.v5]
)
