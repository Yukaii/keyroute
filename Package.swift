// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "keyroute",
    products: [
        .executable(name: "keyroute", targets: ["keyroute"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3")
    ],
    targets: [
        .executableTarget(
            name: "keyroute",
            dependencies: ["Yams"]
        ),
        .testTarget(
            name: "keyrouteTests",
            dependencies: ["keyroute"]
        )
    ]
)
