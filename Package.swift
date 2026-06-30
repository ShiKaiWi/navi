// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Navi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Navi",
            path: "Sources/Navi"
        )
    ]
)
