// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Tangelo",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TangeloCore"),
        .executableTarget(name: "Tangelo", dependencies: ["TangeloCore"]),
        .testTarget(name: "TangeloCoreTests", dependencies: ["TangeloCore"]),
    ],
    swiftLanguageModes: [.v5]
)
