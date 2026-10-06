import Foundation

public enum WebSendStatus: String, Codable, Sendable {
    case preparing, attempting, observed, notSent, uncertain
    public func label(for provider: WebProvider) -> String {
        switch self {
        case .preparing: "Checking \(provider.name)…"
        case .attempting: "Submitting to \(provider.name)…"
        case .observed: "Appeared in \(provider.name)"
        case .notSent: "Not sent to \(provider.name)"
        case .uncertain: "\(provider.name) submission unconfirmed"
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
    public var comparisonID: UUID?
    public var conversationURL: URL?
    public init(text: String, status: WebSendStatus = .preparing) {
        self.text = text; self.status = status
    }
}

public struct WebWorkspaceState: Codable, Sendable {
    public var sessionID = UUID()
    public var draft = ""
    public var selected = true
    public var messageRecipients: Set<UUID> = []
    public var comparisonID: UUID?
    public var attempts: [WebSendAttempt] = []
    public var conversationURLs: [String: URL] = [:]
    public init() {}
    private enum CodingKeys: String, CodingKey { case sessionID, draft, selected, includeMuse, messageRecipients, comparisonID, attempts, conversationURLs, museConversations }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try c.decode(UUID.self, forKey: .sessionID)
        draft = try c.decodeIfPresent(String.self, forKey: .draft) ?? ""
        selected = try c.decodeIfPresent(Bool.self, forKey: .selected) ?? c.decodeIfPresent(Bool.self, forKey: .includeMuse) ?? true
        messageRecipients = try c.decodeIfPresent(Set<UUID>.self, forKey: .messageRecipients) ?? []
        comparisonID = try c.decodeIfPresent(UUID.self, forKey: .comparisonID)
        conversationURLs = try c.decodeIfPresent([String: URL].self, forKey: .conversationURLs)
            ?? c.decodeIfPresent([String: URL].self, forKey: .museConversations) ?? [:]
        attempts = try c.decodeIfPresent([WebSendAttempt].self, forKey: .attempts) ?? []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sessionID, forKey: .sessionID)
        try c.encode(draft, forKey: .draft)
        try c.encode(selected, forKey: .selected)
        try c.encode(messageRecipients, forKey: .messageRecipients)
        try c.encodeIfPresent(comparisonID, forKey: .comparisonID)
        try c.encode(attempts, forKey: .attempts)
        try c.encode(conversationURLs, forKey: .conversationURLs)
    }
    public func hasUnresolvedSend(_ text: String) -> Bool {
        attempts.contains { $0.text == text && [.attempting, .uncertain].contains($0.status) }
    }
    public func recoveringInFlight() -> Self {
        var result = self
        for i in result.attempts.indices {
            switch result.attempts[i].status {
            case .attempting:
                result.attempts[i].status = .uncertain
                result.attempts[i].detail = "MsgBlast stopped during submission. Check the embedded chat before sending this text again."
            case .preparing:
                result.attempts[i].status = .notSent
                result.attempts[i].detail = "MsgBlast stopped before clicking Send. Any prepared text remains in the embedded chat."
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

public struct WebPageSnapshot: Decodable, Equatable, Sendable {
    public var url = ""
    public var ready = false
    public var reason = "Open this agent to sign in here."
    public var draft = ""
    public var messages: [WebPageMessage] = []
    public var submissionInterrupted: Bool?
    public init() {}
}

public struct AgentBroadcastResult: Sendable {
    public let web: [WebProvider: WebSendAttempt]
    public let comparisonID: UUID?
}

@MainActor
public enum AgentBroadcast {
    public static func send(
        draft: String,
        currentDraft: @MainActor () -> String,
        clearDraft: @MainActor () -> Void,
        web: @MainActor @Sendable (String) async -> [WebProvider: WebSendAttempt],
        messages: @MainActor @Sendable (String) async -> UUID?
    ) async -> AgentBroadcastResult {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        async let webAttempts = web(text)
        async let comparisonID = messages(text)
        let result = await AgentBroadcastResult(web: webAttempts, comparisonID: comparisonID)
        let mayHaveSent = result.comparisonID != nil || result.web.values.contains { [.observed, .uncertain].contains($0.status) }
        // Keep edits to the next message; a wholly rejected broadcast remains ready to correct.
        if mayHaveSent && currentDraft() == draft { clearDraft() }
        return result
    }
}
