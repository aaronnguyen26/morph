// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "morph",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "morph", targets: ["morph"])
    ],
    targets: [
        .executableTarget(
            name: "morph",
            path: "Sources/morph"
        ),
        .testTarget(
            name: "MorphTests",
            dependencies: ["morph"],
            path: "Tests/MorphTests"
        )
    ]
)
