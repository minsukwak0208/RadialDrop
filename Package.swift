// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadialDrop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "RadialDrop", targets: ["RadialDrop"]),
        .executable(name: "TestRunner", targets: ["TestRunner"]),
        .library(name: "RadialDropCore", targets: ["RadialDropCore"])
    ],
    targets: [
        .target(
            name: "RadialDropCore",
            dependencies: [],
            path: "Sources/RadialDropCore"
        ),
        .executableTarget(
            name: "RadialDrop",
            dependencies: ["RadialDropCore"],
            path: "Sources/RadialDrop"
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: ["RadialDropCore"],
            path: "Sources/TestRunner"
        )
    ]
)
