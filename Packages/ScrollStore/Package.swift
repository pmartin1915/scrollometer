// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ScrollStore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ScrollStore", targets: ["ScrollStore"]),
    ],
    dependencies: [
        .package(path: "../ScrollCore"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "ScrollStore",
            dependencies: [
                "ScrollCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "ScrollStoreTests",
            dependencies: ["ScrollStore"]
        ),
    ]
)
