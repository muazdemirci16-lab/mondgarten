// swift-tools-version: 5.8

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Klickrausch",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "Klickrausch",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.klickrausch",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .lightningBolt),
            accentColor: .presetColor(.orange),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
