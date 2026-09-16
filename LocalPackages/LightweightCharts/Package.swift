// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LightweightCharts",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "LightweightCharts",
            targets: ["LightweightCharts"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LightweightCharts",
            dependencies: [],
            exclude: [
                "Extensions/Bundle+Resources.swift",
            ],
            resources: [
                .process("Assets/content-setup.js"),
                .process("Assets/lightweight-charts.js"),
                .process("Assets/rounded-candlestick-series.js"),
                .process("Assets/rounded-histogram-series.js"),
                .process("Assets/price-level-markers.js"),
                .process("Assets/wrapper_functions.js"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
    ]
)
