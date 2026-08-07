// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EyeOh",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "EyeOh", targets: ["EyeOh"]),
    ],
    targets: [
        .executableTarget(
            name: "EyeOh",
            path: "Sources/EyeOh"
        ),
        .testTarget(
            name: "EyeOhTests",
            dependencies: ["EyeOh"],
            path: "Tests/EyeOhTests"
        ),
    ]
)
