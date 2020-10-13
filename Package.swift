// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "swift-msgpack",
    products: [
        .library(
            name: "MessagePack",
            targets: ["MessagePack"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MessagePack",
            dependencies: []),
        .testTarget(
            name: "MessagePackTests",
            dependencies: ["MessagePack"]),
    ]
)
