// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "MsgBlast", platforms: [.macOS("26.0")],
    products: [.executable(name: "MsgBlast", targets: ["MsgBlast"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "MsgBlastCore", path: "MsgBlast/Core"),
        .executableTarget(name: "MsgBlast", dependencies: ["MsgBlastCore", .product(name: "Sparkle", package: "Sparkle")], path: "MsgBlast",
            exclude: ["Core", "Info.plist", "MsgBlast.entitlements", "MsgBlastDebug.entitlements", "AppIcon.icon", "AppIconDemo.icon", "AppIconColor.icon", "AppIconNested.icon"],
            resources: [.copy("Resources/Discover"), .copy("ThirdPartyNotices.txt")], linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "MsgBlastTests", dependencies: ["MsgBlastCore"], path: "MsgBlastTests")
    ])
