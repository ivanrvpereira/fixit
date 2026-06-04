// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Fixit",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Fixit", targets: ["Fixit"]),
    ],
    targets: [
        .executableTarget(name: "Fixit"),
    ]
)
