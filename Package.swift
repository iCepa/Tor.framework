// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TorFramework",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CTor",
            targets: ["CTor"]
        ),
        .library(
            name: "CTorNoLzma",
            targets: ["CTorNoLzma"]
        ),
        .library(
            name: "Arti",
            targets: ["Arti"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "TorCore",
            publicHeadersPath: "include",
        ),
        .binaryTarget(
            name: "tor",
//            path: "tor.xcframework"
            url: "https://github.com/iCepa/Tor.framework/releases/download/409.17.1/tor.xcframework.zip",
            checksum: "14e7875f5452cdbfd0fbc4efbaa1b4d16855a7fa94d42580adf4d73adeb241d1"
        ),
        .target(
            name: "CTor",
            dependencies: ["TorCore", "tor"],
            publicHeadersPath: "include",
            // Needed for tor.xcframework, but not allowed in `.binaryTarget`. Hrgrml. But works this way.
            linkerSettings: [.linkedLibrary("z")]),
        .binaryTarget(
            name: "tor-nolzma",
//            path: "tor-nolzma.xcframework"
            url: "https://github.com/iCepa/Tor.framework/releases/download/409.17.1/tor-nolzma.xcframework.zip",
            checksum: "39579058d205389ce6aaeda6b152b730bed18032ec987487218f9466e9cd6c49"
        ),
        .target(
            name: "CTorNoLzma",
            dependencies: ["TorCore", "tor-nolzma"],
            publicHeadersPath: "include",
            // Needed for tor.xcframework, but not allowed in `.binaryTarget`. Hrgrml. But works this way.
            linkerSettings: [.linkedLibrary("z")]),
        .binaryTarget(
            name: "arti",
//            path: "arti.xcframework"
            url: "https://github.com/iCepa/Tor.framework/releases/download/409.15.3/arti.xcframework.zip",
            checksum: "f2e22a1ff1d9dc92554764b3fbc7eee0b30d9481d59478e01c01a93cbe947d12"
        ),
        .target(
            name: "Arti",
            dependencies: ["TorCore", "arti"],
            publicHeadersPath: "include"),
    ],
    swiftLanguageModes: [.v6]
)
