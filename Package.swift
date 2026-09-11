// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DawnSend",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DawnSend", targets: ["DawnSend"])
    ],
    targets: [
        .target(
            name: "DawnSendCore"
        ),
        .executableTarget(
            name: "DawnSend",
            dependencies: ["DawnSendCore"]
        ),
        .testTarget(
            name: "DawnSendTests",
            dependencies: ["DawnSendCore"]
        )
    ]
)
