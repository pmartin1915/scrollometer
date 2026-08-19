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
        // 6.16 is the floor for Configuration.journalMode = .wal (used in ScrollStore).
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.16.0"),
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
            dependencies: [
                "ScrollStore",
                .product(name: "ScrollCore", package: "ScrollCore"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
    ]
)
