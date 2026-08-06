// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Fixit",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Fixit", targets: ["Fixit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Fixit",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "FixitTests", dependencies: ["Fixit"]),
    ]
)
