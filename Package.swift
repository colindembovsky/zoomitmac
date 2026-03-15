// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ZoomItMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ZoomItMac", targets: ["ZoomItMac"])
    ],
    targets: [
        .executableTarget(
            name: "ZoomItMac"
        )
    ]
)
