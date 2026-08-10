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
        .binaryTarget(
            name: "Sentry",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.25.0/Sentry.xcframework.zip",
            checksum: "766417fae6474bc83e6691164a0b5fa93f8879cc7c9721dba5f7f5bf2ef20174"
        ),
        .executableTarget(
            name: "EyeOh",
            dependencies: [
                "Sentry",
            ],
            path: "Sources/EyeOh"
        ),
        .testTarget(
            name: "EyeOhTests",
            dependencies: ["EyeOh"],
            path: "Tests/EyeOhTests"
        ),
    ]
)
