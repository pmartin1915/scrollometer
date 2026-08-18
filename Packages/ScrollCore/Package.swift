// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ScrollCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ScrollCore", targets: ["ScrollCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "ScrollCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ScrollCoreTests",
            dependencies: ["ScrollCore"]
        ),
    ]
)
