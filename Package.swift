// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Navi",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Pinned to 1.0.5: later releases adopt the @Entry / #Preview SwiftUI
        // macros, whose compiler plugins ship only with full Xcode (not the
        // Command Line Tools), so 1.0.6+ fails to build in a CLT-only setup.
        .package(url: "https://github.com/appstefan/HighlightSwift", exact: "1.0.5")
    ],
    targets: [
        .executableTarget(
            name: "Navi",
            dependencies: [
                .product(name: "HighlightSwift", package: "HighlightSwift")
            ],
            path: "Sources/Navi",
            resources: [.process("Assets.xcassets")]
        ),
        .testTarget(
            name: "NaviTests",
            dependencies: ["Navi"]
        )
    ]
)
