// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MsgBlast", platforms: [.macOS("26.0")], products: [.executable(name: "MsgBlast", targets: ["MsgBlast"])], targets: [.target(name: "MsgBlastCore", path: "MsgBlast/Core"), .executableTarget(name: "MsgBlast", dependencies: ["MsgBlastCore"], path: "MsgBlast", exclude: ["Core", "Info.plist", "MsgBlast.entitlements"], resources: [.copy("Resources/Discover")], linkerSettings: [.linkedLibrary("sqlite3")]), .testTarget(name: "MsgBlastTests", dependencies: ["MsgBlastCore"], path: "MsgBlastTests")])
