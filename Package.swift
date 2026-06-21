// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SweetLine",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(name: "SweetLine", targets: ["SweetLine"]),
    ],
    targets: [
        .binaryTarget(
            name: "SweetLineCoreIOS",
            path: "Vendor/iOS/SweetLineCoreIOS.xcframework"
        ),
        .target(
            name: "SweetLine",
            dependencies: ["SweetLineCoreIOS"],
            linkerSettings: [
                .linkedLibrary("iconv"),
            ]
        ),
        .testTarget(
            name: "SweetLineTests",
            dependencies: ["SweetLine"]
        ),
    ]
)
