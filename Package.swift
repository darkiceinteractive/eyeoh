// swift-tools-version: 6.2
import PackageDescription

let distributionChannel = Context.environment["EYEOH_DISTRIBUTION_CHANNEL"] ?? "source"
let includesDirectUpdater = distributionChannel == "direct"

var packageDependencies: [Package.Dependency] = []
var eyeOhDependencies: [Target.Dependency] = ["Sentry"]
var eyeOhLinkerSettings: [LinkerSetting] = []
var eyeOhSwiftSettings: [SwiftSetting] = []

if includesDirectUpdater {
    packageDependencies.append(
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.9.5")
    )
    eyeOhDependencies.append(.product(name: "Sparkle", package: "Sparkle"))
    eyeOhSwiftSettings.append(.define("EYEOH_DIRECT_UPDATER"))
    eyeOhLinkerSettings.append(
        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
    )
}

let package = Package(
    name: "EyeOh",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "EyeOh", targets: ["EyeOh"]),
    ],
    dependencies: packageDependencies,
    targets: [
        .binaryTarget(
            name: "Sentry",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.25.0/Sentry.xcframework.zip",
            checksum: "766417fae6474bc83e6691164a0b5fa93f8879cc7c9721dba5f7f5bf2ef20174"
        ),
        .executableTarget(
            name: "EyeOh",
            dependencies: eyeOhDependencies,
            path: "Sources/EyeOh",
            swiftSettings: eyeOhSwiftSettings,
            linkerSettings: eyeOhLinkerSettings
        ),
        .testTarget(
            name: "EyeOhTests",
            dependencies: ["EyeOh"],
            path: "Tests/EyeOhTests"
        ),
    ]
)
