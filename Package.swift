// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BoardSensei",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BoardSensei", targets: ["BoardSenseiApp"]),
        .executable(name: "BoardSenseiNarrationTool", targets: ["BoardSenseiNarrationTool"]),
        .library(name: "MusicCore", targets: ["MusicCore"]),
    ],
    targets: [
        .target(
            name: "CBoardSenseiBridge",
            path: "Sources/CBoardSenseiBridge",
            publicHeadersPath: "include"
        ),
        .target(name: "MusicCore"),
        .executableTarget(
            name: "BoardSenseiApp",
            dependencies: ["MusicCore", "CBoardSenseiBridge"],
            resources: [
                .copy("Resources/Narration"),
                .copy("Resources/Brand"),
                .copy("Resources/Instruments"),
            ]
        ),
        .executableTarget(name: "BoardSenseiNarrationTool", dependencies: ["MusicCore"]),
        .testTarget(
            name: "MusicCoreTests",
            dependencies: ["MusicCore", "CBoardSenseiBridge"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
