// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImpulsePlayer",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ImpulsePlayer",
            targets: ["ImpulsePlayer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SRGSSR/google-cast-sdk", exact: "4.8.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ImpulsePlayer",
            dependencies: [
                .product(name: "GoogleCast", package: "google-cast-sdk")
            ],
            resources: [
                .process("Resources")  // Include the Resources folder for images
            ]
        ),
    ]
)
