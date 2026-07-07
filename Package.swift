// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TorFramework",
    platforms: [.iOS(.v15), .macOS(.v11)],
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
            url: "https://github.com/iCepa/Tor.framework/releases/download/v409.11.1/tor.xcframework.zip",
            checksum: "80711b4f831a0de8128038c044da07afabca32ccc7ee7affaddbbd2e3e313196"
        ),
        .target(
            name: "CTor",
            dependencies: ["TorCore", "tor"],
            publicHeadersPath: "include",
            // Needed for tor.xcframework, but not allowed in `.binaryTarget`. Hrgrml. But works this way.
            linkerSettings: [.linkedLibrary("z")]),
        .binaryTarget(
            name: "tor-nolzma",
            url: "https://github.com/iCepa/Tor.framework/releases/download/v409.11.1/tor-nolzma.xcframework.zip",
            checksum: "8c2b0ae078e89e1aaab2d5310fe2d19eed7d6a249c6fd6bcf7e8caf9435e19f1"),
        .target(
            name: "CTorNoLzma",
            dependencies: ["TorCore", "tor-nolzma"],
            publicHeadersPath: "include",
            // Needed for tor.xcframework, but not allowed in `.binaryTarget`. Hrgrml. But works this way.
            linkerSettings: [.linkedLibrary("z")]),
    ],
    swiftLanguageModes: [.v6]
)
