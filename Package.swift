// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ivors",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Ivors",
            targets: ["Ivors"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Ivors",
            dependencies: [],
            path: "Sources/Ivors"
        )
    ]
)
