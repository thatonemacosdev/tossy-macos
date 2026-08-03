// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EasyConvert",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "EasyConvert",
            path: "Sources/EasyConvert"
        )
    ]
)
