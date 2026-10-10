// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cameo",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CameoShow", path: "Sources/CameoShow"),
        .executableTarget(name: "Cameo", dependencies: ["CameoShow"], path: "Sources/Cameo"),
        .executableTarget(name: "CameoSample", path: "Sources/CameoSample"),
        .executableTarget(name: "CameoIcon", path: "Sources/CameoIcon"),
        .testTarget(name: "CameoShowTests", dependencies: ["CameoShow"], path: "Tests/CameoShowTests"),
    ],
    swiftLanguageModes: [.v5]
)
