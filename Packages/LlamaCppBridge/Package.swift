// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LlamaCppBridge",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "LlamaCppBridge",
            targets: ["LlamaCppBridge"]
        ),
    ],
    targets: [
        .target(
            name: "LlamaCppBridge",
            dependencies: ["llama"]
        ),
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b8833/llama-b8833-xcframework.zip",
            checksum: "cf79e433e21c62f0648b7dd7e5905c58e109cacd3fbfe3ceac1faf62cfdc49f9"
        ),
    ]
)
