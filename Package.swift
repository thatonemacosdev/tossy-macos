// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tossy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tossy",
            path: "Sources/EasyConvert"
        )
    ]
)
