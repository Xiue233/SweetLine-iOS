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
            url: "https://github.com/Xiue233/SweetLine-iOS/releases/download/v1.3.0/SweetLineCoreIOS.xcframework.zip",
            checksum: "e75089a900167855dc58e978b1172b8e03e96f100aa490f40e2dd4134fac3993"
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
