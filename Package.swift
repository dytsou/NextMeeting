// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NextMeeting",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NextMeeting", targets: ["NextMeeting"])
    ],
    targets: [
        .executableTarget(
            name: "NextMeeting",
            path: "NextMeeting",
            exclude: [
                "Info.plist",
                "NextMeeting.entitlements",
                "Assets.xcassets",
                "en.lproj",
                "zh-Hant.lproj"
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("EventKit")
            ]
        )
    ]
)
