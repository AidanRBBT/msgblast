import Foundation
import msgblastCore

@main struct ConfiguredCLIConversations {
    static func main() async throws {
        let fixture = URL(fileURLWithPath: CommandLine.arguments[1])
        let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        print("DETERMINISTIC LOCAL FIXTURE — no provider, login, connector, or paid model request")
        for provider in [PersonalAgentProvider.codex, .claude] {
            let agent = InstalledPersonalAgent(provider: provider, executableURL: fixture, path: "/usr/bin:/bin")
            let working = directory.appendingPathComponent(provider.rawValue, isDirectory: true)
            let initial = "/configured-fixture-skill inspect"
            print("\n\(provider.name): input: \(initial)")
            let first = try await LocalPersonalAgent.reply(to: [WebPageMessage(role: "user", text: initial)], using: agent, workingDirectory: working)
            precondition(first.text.contains("fixture configuration loaded"))
            print("output: \(first.text)")
            let resumed = try await LocalPersonalAgent.reply(to: [WebPageMessage(role: "user", text: "Continue with the configured fixture tool")], using: agent, sessionID: first.sessionID, workingDirectory: working)
            precondition(resumed.sessionID == first.sessionID)
            print("follow-up: \(resumed.text) (same saved session and directory)")
            let denied = try await LocalPersonalAgent.reply(to: [WebPageMessage(role: "user", text: "DENIED_ACTION: write a fixture file")], using: agent, sessionID: first.sessionID, workingDirectory: working)
            precondition(denied.text.contains("denied"))
            print("permission result: \(denied.text)")
            let comparison = Comparison(prompt: "Compare fixture replies", members: [])
            let input = try ComparisonSummaryInput(comparison: comparison, comparisons: [comparison], messages: [:])
            let report = try await LocalPersonalAgent.summarize(input, using: agent)
            precondition(report == "Restricted report: configured fixture tool was not loaded.")
            print("comparison summary: \(report)")
            var legacy = WebWorkspaceState()
            let id = UUID()
            legacy.localSessionIDs[id.uuidString] = first.sessionID
            legacy.localConversations[id.uuidString] = [WebPageMessage(role: "user", text: "Earlier request"), WebPageMessage(role: "assistant", text: "Earlier answer")]
            legacy.localDrafts[id.uuidString] = "Saved draft"
            precondition(legacy.resumableLocalSessionID(for: id) == nil)
            let replacement = try await LocalPersonalAgent.reply(to: legacy.localConversations[id.uuidString]! + [WebPageMessage(role: "user", text: "Continue with configured tools")], using: agent, sessionID: legacy.resumableLocalSessionID(for: id), workingDirectory: working)
            legacy.recordLocalSession(replacement.sessionID, for: id)
            let restored = try JSONDecoder().decode(WebWorkspaceState.self, from: JSONEncoder().encode(legacy))
            precondition(restored.localPreviousSessionIDs[id.uuidString] == [first.sessionID])
            precondition(restored.localDrafts[id.uuidString] == "Saved draft")
            precondition(restored.resumableLocalSessionID(for: id) == replacement.sessionID)
            print("legacy session: rebuilt once from quoted saved transcript; old ID and draft retained")
        }
        print("\nPASS: configured new/resumed conversations, denied action, restricted summaries, and legacy session retention")
    }
}
