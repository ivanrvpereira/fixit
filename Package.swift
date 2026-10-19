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
            // ../Frameworks: app bundle. @executable_path: source builds place Sparkle.framework beside the binary.
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                "-Xlinker", "-rpath", "-Xlinker", "@executable_path",
            ])]
        ),
        .testTarget(name: "FixitTests", dependencies: ["Fixit"]),
    ]
)
