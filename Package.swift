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
            url: "https://github.com/Xiue233/SweetLine-iOS/releases/download/v1.3.1/SweetLineCoreIOS.xcframework.zip",
            checksum: "45bcf3f36e0b23d2c4757f8681aea7d22c2489510da51ec8dd7e090dde568cc8"
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
