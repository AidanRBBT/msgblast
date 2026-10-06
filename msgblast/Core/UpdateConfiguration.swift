import Foundation

public struct UpdateConfiguration {
    public let isEnabled: Bool
    public let isLocalFixture: Bool
    public let unavailableReason: String

    public init(bundleURL: URL, bundleIdentifier: String?, info: [String: Any], arguments: [String], allowLocalFixture: Bool = false, environment: [String: String] = [:]) {
        let storePath = (info["msgblastFixtureStore"] as? String).map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        let temporaryRoot = FileManager.default.temporaryDirectory.standardizedFileURL.path + "/"
        let fixture = allowLocalFixture && bundleIdentifier == "com.msgblast.update-fixture"
            && info["msgblastUpdateFixture"] as? Bool == true && info["msgblastDemo"] as? Bool == true
            && storePath?.hasPrefix(temporaryRoot) == true
        isLocalFixture = fixture
        guard environment["XCTestConfigurationFilePath"] == nil, environment["XCTestBundlePath"] == nil,
              bundleURL.pathExtension == "app",
              info["msgblastDisableUpdates"] as? Bool != true,
              fixture || (bundleIdentifier == "com.msgblast.mac" && info["msgblastDemo"] as? Bool != true && !arguments.contains("--demo")) else {
            isEnabled = false
            unavailableReason = "Updates are disabled in previews and test runs."
            return
        }
        guard let feed = info["SUFeedURL"] as? String, let url = URL(string: feed),
              url.user == nil, url.password == nil,
              let host = url.host, !host.isEmpty,
              (fixture ? (url.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(host)) : url.scheme == "https"),
              let key = info["SUPublicEDKey"] as? String, Data(base64Encoded: key)?.count == 32 else {
            isEnabled = false
            unavailableReason = "This development build has no configured update service."
            return
        }
        isEnabled = true
        unavailableReason = ""
    }
}
