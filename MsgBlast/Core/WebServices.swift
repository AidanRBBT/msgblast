import Foundation

public enum WebSendStatus: String, Codable, Sendable {
    case preparing, attempting, observed, notSent, uncertain
    public var label: String {
        switch self {
        case .preparing: "Checking Muse…"
        case .attempting: "Submitting to Muse…"
        case .observed: "Appeared in Muse"
        case .notSent: "Not sent to Muse"
        case .uncertain: "Muse submission unconfirmed"
        }
    }
}

public struct WebSendAttempt: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var created = Date()
    public var text: String
    public var status: WebSendStatus
    public var detail: String?
    public var messageID: String?
    public init(text: String, status: WebSendStatus = .preparing) {
        self.text = text; self.status = status
    }
}

public struct WebWorkspaceState: Codable, Sendable {
    public var sessionID = UUID()
    public var draft = ""
    public var includeMuse = false
    public var messageRecipients: Set<UUID> = []
    public var comparisonID: UUID?
    public var attempts: [WebSendAttempt] = []
    public init() {}
    public func hasUnresolvedSend(_ text: String) -> Bool {
        attempts.contains { $0.text == text && [.attempting, .uncertain].contains($0.status) }
    }
    public func recoveringInFlight() -> Self {
        var result = self
        for i in result.attempts.indices {
            switch result.attempts[i].status {
            case .attempting:
                result.attempts[i].status = .uncertain
                result.attempts[i].detail = "MsgBlast stopped during submission. Check Muse before sending this text again."
            case .preparing:
                result.attempts[i].status = .notSent
                result.attempts[i].detail = "MsgBlast stopped before clicking Send. Any prepared text remains in Muse."
            default: break
            }
        }
        return result
    }
}

public struct WebPageMessage: Decodable, Equatable, Sendable {
    public var id: String
    public var role: String
    public var text: String
}

public struct MusePageSnapshot: Decodable, Equatable, Sendable {
    public var url = ""
    public var ready = false
    public var reason = "Connect Muse to open its sign-in page here."
    public var draft = ""
    public var messages: [WebPageMessage] = []
    public init() {}
}

public struct AgentBroadcastResult: Sendable {
    public let muse: WebSendAttempt?
    public let comparisonID: UUID?
}

@MainActor
public enum AgentBroadcast {
    public static func send(
        draft: String,
        currentDraft: @MainActor () -> String,
        clearDraft: @MainActor () -> Void,
        muse: @MainActor @Sendable (String) async -> WebSendAttempt?,
        messages: @MainActor @Sendable (String) async -> UUID?
    ) async -> AgentBroadcastResult {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        async let webAttempt = muse(text)
        async let comparisonID = messages(text)
        let result = await AgentBroadcastResult(muse: webAttempt, comparisonID: comparisonID)
        let mayHaveSent = result.comparisonID != nil || result.muse.map { [.observed, .uncertain].contains($0.status) } == true
        // Keep edits to the next message; a wholly rejected broadcast remains ready to correct.
        if mayHaveSent && currentDraft() == draft { clearDraft() }
        return result
    }
}
