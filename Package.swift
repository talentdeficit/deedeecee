// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "deedeecee",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "deedeecee",
            dependencies: ["Yams"],
            path: "Sources/deedeecee",
            linkerSettings: [
                .unsafeFlags(["-framework", "CoreDisplay", "-F", "/System/Library/PrivateFrameworks"])
            ]
        )
    ]
)
