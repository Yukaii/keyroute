// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "keyroute",
    products: [
        .library(name: "KeyrouteCore", targets: ["KeyrouteCore"]),
        .library(name: "KeyrouteTmux", targets: ["KeyrouteTmux"]),
        .library(name: "KeyrouteMacOS", targets: ["KeyrouteMacOS"]),
        .executable(name: "keyroute", targets: ["keyroute"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3")
    ],
    targets: [
        .target(
            name: "KeyrouteCore",
            dependencies: ["Yams"]
        ),
        .target(
            name: "KeyrouteTmux",
            dependencies: ["KeyrouteCore"]
        ),
        .target(
            name: "KeyrouteMacOS",
            dependencies: ["KeyrouteCore"]
        ),
        .executableTarget(
            name: "keyroute",
            dependencies: [
                "KeyrouteCore",
                "KeyrouteTmux",
                .target(name: "KeyrouteMacOS", condition: .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "keyrouteTests",
            dependencies: [
                "KeyrouteCore",
                "KeyrouteTmux"
            ]
        )
    ]
)
