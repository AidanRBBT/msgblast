import AppKit
import Combine
import WebKit

@MainActor
public final class MuseWebSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published public private(set) var state = WebWorkspaceState()
    @Published public private(set) var snapshot = MusePageSnapshot()
    @Published public private(set) var isSending = false
    @Published public private(set) var connected = false
    @Published public private(set) var loading = false
    @Published public private(set) var error: String?
    @Published public private(set) var popup: WKWebView?
    @Published public private(set) var popupURL = ""
    @Published public private(set) var avatar: Data?
    public let webView: WKWebView
    public let fixture: Bool
    private let storageURL: URL
    private var storageFailed = false
    private var poll: Task<Void, Never>?
    private var refreshing = false
    private var navigationGeneration = 0
    private var avatarKey: String?
    private static let mainChatURL = URL(string: "https://muse.ai/")!

    public init(storageURL: URL, fixture: Bool) {
        self.storageURL = storageURL
        self.fixture = fixture
        var loaded = WebWorkspaceState()
        var failure: String?
        do { loaded = try JSONDecoder().decode(WebWorkspaceState.self, from: Data(contentsOf: storageURL)).recoveringInFlight() }
        catch CocoaError.fileReadNoSuchFile { }
        catch { failure = "Web session state could not be read. The saved file has been preserved: \(error.localizedDescription)" }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = fixture ? .nonPersistent() : WKWebsiteDataStore(forIdentifier: loaded.sessionID)
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        super.init()
        state = loaded
        storageFailed = failure != nil
        error = failure
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        if failure == nil { persist() }
    }

    deinit { poll?.cancel() }

    public static func isChatURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "muse.ai" && (url.path.isEmpty || url.path == "/") && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
    }

    public func updateState(_ edit: (inout WebWorkspaceState) -> Void) {
        guard !storageFailed else { return }
        edit(&state)
        persist()
    }

    public func connect() {
        guard !connected else { return }
        connected = true
        loadMainChat()
        poll = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    public func reload() {
        guard !isSending else { return }
        if !connected { connect() }
        else if fixture { loadMainChat() }
        else { webView.reload() }
    }

    public func openMainChat() {
        guard !isSending else { return }
        if !connected { connect() }
        else { loadMainChat() }
    }

    private func loadMainChat() {
        if fixture { webView.loadHTMLString(MusePageScript.fixture, baseURL: Self.mainChatURL) }
        else { webView.load(URLRequest(url: Self.mainChatURL)) }
    }

    public func closePopup() { popup = nil; popupURL = ""; Task { await refresh() } }

    public func refresh() async {
        guard connected, !loading, !refreshing else { return }
        guard let url = webView.url, Self.isChatURL(url) else {
            var current = MusePageSnapshot()
            current.url = webView.url?.absoluteString ?? ""
            current.reason = "Sign in to Muse and open your main chat."
            snapshot = current
            clearAvatar()
            return
        }
        refreshing = true
        defer { refreshing = false }
        let generation = navigationGeneration
        do {
            let result = try await webView.callAsyncJavaScript(MusePageScript.inspect, arguments: [:], in: nil, contentWorld: .defaultClient)
            guard generation == navigationGeneration, let result else { return }
            let fresh = try JSONDecoder().decode(MusePageSnapshot.self, from: JSONSerialization.data(withJSONObject: result))
            if snapshot != fresh { snapshot = fresh }
            await refreshAvatar(generation: generation)
        } catch {
            guard generation == navigationGeneration else { return }
            var current = MusePageSnapshot()
            current.reason = "Muse’s page is not ready. Reload or use the page directly."
            snapshot = current
            clearAvatar()
        }
    }

    private func clearAvatar() { avatarKey = nil; avatar = nil }

    private func refreshAvatar(generation: Int) async {
        guard snapshot.ready else { clearAvatar(); return }
        do {
            let result = try await webView.callAsyncJavaScript(MusePageScript.avatar, arguments: ["previousKey": avatarKey ?? ""], in: nil, contentWorld: .defaultClient) as? [String: Any]
            guard generation == navigationGeneration else { return }
            guard let key = result?["key"] as? String else { clearAvatar(); return }
            if key == avatarKey { return }
            guard let png = result?["png"] as? String, png.hasPrefix("data:image/png;base64,"), png.count < 400_000,
                  let data = Data(base64Encoded: String(png.dropFirst(22))),
                  let image = NSBitmapImageRep(data: data), image.pixelsWide == 256, image.pixelsHigh == 256 else { clearAvatar(); return }
            avatarKey = key
            avatar = data
        } catch {
            if generation == navigationGeneration { clearAvatar() }
        }
    }

    @discardableResult
    public func send(_ text: String) async -> WebSendAttempt? {
        guard !isSending, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard !storageFailed else { error = "Repair web session storage before sending."; return nil }
        guard !state.hasUnresolvedSend(text) else { error = "An earlier send of this text is unconfirmed. Check Muse; MsgBlast will not resend it automatically."; return nil }
        isSending = true
        defer { isSending = false }
        var attempt = WebSendAttempt(text: text)
        var submissionWasPossible = false
        state.attempts.insert(attempt, at: 0)
        do {
            try save()
            await refresh()
            guard let url = webView.url, Self.isChatURL(url), snapshot.ready, !loading else {
                throw WebSessionFailure.notSent(snapshot.reason)
            }
            let generation = navigationGeneration
            let expectedURL = snapshot.url
            let preparation = try await webView.callAsyncJavaScript(MusePageScript.prepare, arguments: ["text": text], in: nil, contentWorld: .defaultClient) as? [String: Any]
            guard preparation?["ok"] as? Bool == true, let messageIDs = preparation?["messageIDs"] as? [String] else {
                throw WebSessionFailure.notSent(preparation?["reason"] as? String ?? "Could not prepare Muse’s message field.")
            }
            let before = Set(messageIDs)
            // Allow React's input handler to enable its own Send control.
            try await Task.sleep(for: .milliseconds(150))
            guard generation == navigationGeneration, !loading else { throw WebSessionFailure.notSent("Muse navigated before submission. Review its draft.") }
            attempt.status = .attempting
            try store(attempt) // The possible external side effect is durably recorded first.
            submissionWasPossible = true
            let result = try await webView.callAsyncJavaScript(MusePageScript.clickSend, arguments: ["text": text, "expectedURL": expectedURL], in: nil, contentWorld: .defaultClient) as? [String: Any]
            if result?["clicked"] as? Bool == false {
                submissionWasPossible = false
                throw WebSessionFailure.notSent(result?["reason"] as? String ?? "Muse’s Send control was not clicked.")
            }
            guard result?["clicked"] as? Bool == true else { throw WebSessionFailure.unconfirmed }
            let normalizedText = Self.normalized(text)
            for _ in 0..<20 {
                try await Task.sleep(for: .milliseconds(250))
                await refresh()
                guard generation == navigationGeneration, snapshot.url == expectedURL else { break }
                let matches = snapshot.messages.filter { !before.contains($0.id) && $0.role == "user" && Self.normalized($0.text) == normalizedText }
                if matches.count == 1 {
                    attempt.status = .observed
                    attempt.messageID = matches[0].id
                    attempt.detail = "The outgoing message appeared in Muse. This is a page observation, not a server delivery receipt."
                    try store(attempt)
                    return attempt
                }
                if matches.count > 1 { break }
            }
            attempt.status = .uncertain
            attempt.detail = "Send was clicked, but a unique outgoing message could not be confirmed. Check Muse; no automatic resend."
        } catch {
            if attempt.status == .observed {
                self.error = "The message appeared in Muse, but its receipt could not be saved. Repair storage before sending again."
            } else {
                attempt.status = submissionWasPossible ? .uncertain : .notSent
                attempt.detail = error.localizedDescription
            }
        }
        do { try store(attempt) } catch { self.error = "Could not save the send result. Check Muse before retrying." }
        return attempt
    }

    private static func normalized(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    private func store(_ attempt: WebSendAttempt) throws {
        if let index = state.attempts.firstIndex(where: { $0.id == attempt.id }) { state.attempts[index] = attempt }
        try save()
    }
    private func save() throws {
        guard !storageFailed else { throw WebSessionFailure.notSent("Web session storage is unavailable.") }
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(state).write(to: storageURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storageURL.path)
        } catch {
            storageFailed = true
            throw error
        }
    }
    private func persist() {
        do { try save() } catch { storageFailed = true; self.error = "Could not save the web session: \(error.localizedDescription)" }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if webView === self.webView {
            navigationGeneration += 1; loading = true; snapshot = MusePageSnapshot(); clearAvatar()
        }
    }
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === self.webView { loading = false; Task { await refresh() } }
        else { popupURL = webView.url?.absoluteString ?? "" }
    }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failedNavigation(webView, error: error) }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failedNavigation(webView, error: error) }
    private func failedNavigation(_ view: WKWebView, error: Error) {
        guard view === webView else { return }
        loading = false
        if (error as NSError).code != NSURLErrorCancelled { self.error = "Muse could not load: \(error.localizedDescription)" }
    }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webView === self.webView {
            navigationGeneration += 1; loading = false; snapshot = MusePageSnapshot(); clearAvatar()
            error = "Muse’s web process stopped. Reload its page. Pending submissions will not be resent."
        }
    }
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        let allowed = fixture ? (url.absoluteString == "about:blank" || Self.isChatURL(url)) : url.scheme == "https"
        if !allowed {
            error = "This link cannot open inside MsgBlast. Stay on Muse’s website to continue."
        }
        if webView === popup { popupURL = url.absoluteString }
        return allowed ? .allow : .cancel
    }
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard !fixture, navigationAction.targetFrame == nil, navigationAction.request.url?.scheme == "https", popup == nil else { return nil }
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self; view.uiDelegate = self
        popupURL = navigationAction.request.url?.absoluteString ?? ""
        popup = view
        return view
    }
    public func webViewDidClose(_ webView: WKWebView) { if webView === popup { closePopup() } }
}

private enum WebSessionFailure: LocalizedError {
    case notSent(String), unconfirmed
    var errorDescription: String? {
        switch self {
        case .notSent(let message): message
        case .unconfirmed: "Muse did not return a reliable result after Send. Check its page; no automatic resend."
        }
    }
}
