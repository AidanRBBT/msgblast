import Foundation

public enum WebProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case muse, chatgpt, claude, grok
    public var id: String { rawValue }
    public var name: String {
        switch self { case .muse: "Muse"; case .chatgpt: "ChatGPT"; case .claude: "Claude"; case .grok: "Grok" }
    }
    public var homeURL: URL {
        switch self {
        case .muse: URL(string: "https://muse.ai/")!
        case .chatgpt: URL(string: "https://chatgpt.com/")!
        case .claude: URL(string: "https://claude.ai/new")!
        case .grok: URL(string: "https://grok.com/")!
        }
    }
    public var newChatURL: URL { self == .muse ? URL(string: "https://muse.ai/thread/new")! : homeURL }
    public func isSavedMuseChat(_ url: URL) -> Bool {
        self == .muse && isChatURL(url) && url.path != "/thread/new"
    }
    // Keep Muse's original file and WebKit data-store identifier through the upgrade.
    public var storageFilename: String { self == .muse ? "web-services.json" : "web-\(rawValue).json" }
    public func isChatURL(_ url: URL) -> Bool {
        guard url.scheme == "https", url.host == homeURL.host, url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return false }
        let path = url.path
        switch self {
        case .muse:
            return url.query == nil && url.fragment == nil && (path == "/thread/new" ||
                path.range(of: #"^/thread/[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$"#, options: .regularExpression) != nil)
        case .chatgpt: return path.isEmpty || path == "/" || path.range(of: #"^/c/[a-zA-Z0-9-]+/?$"#, options: .regularExpression) != nil
        case .claude: return path == "/new" || path.range(of: #"^/chat/[a-zA-Z0-9-]+/?$"#, options: .regularExpression) != nil
        case .grok: return path.isEmpty || path == "/" || path.range(of: #"^/c/[a-zA-Z0-9-]+/?$"#, options: .regularExpression) != nil
        }
    }
    // A first send can assign a conversation URL using history.replaceState.
    // Existing conversations must stay on exactly the same URL.
    public func acceptsReceipt(from original: URL, at current: URL) -> Bool {
        guard isChatURL(original), isChatURL(current) else { return false }
        if self == .muse {
            return isSavedMuseChat(current) && (original == current || original == newChatURL)
        }
        if original == current { return true }
        return original.path == homeURL.path && current.path != homeURL.path
    }
}
