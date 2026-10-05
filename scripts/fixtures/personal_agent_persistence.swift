import Foundation
import MsgBlastCore

// Controlled storage and provider substitutes: no real app data, provider CLI or network.
@MainActor
final class AppModel {
    enum StorageFailure: LocalizedError {
        case finalSave
        var errorDescription: String? { "Fixture storage rejected the completed report." }
    }
    var state = AppState()
    var messages: [String: [Message]] = [:]
    var databaseAvailable = true
    var failFinalSave = false
    var saveAttempts: [ComparisonSummary?] = []
    func save() throws {
        saveAttempts.append(state.comparisons.first?.summary)
        if failFinalSave && saveAttempts.count == 2 { throw StorageFailure.finalSave }
    }
    func persist() {}
    func comparison(_ id: UUID) -> Comparison? { state.comparisons.first { $0.id == id } }
    func index(_ id: UUID) -> Int? { state.comparisons.firstIndex { $0.id == id } }
}

@MainActor
enum LocalPersonalAgent {
    static var response: CheckedContinuation<String, Never>?
    static var requests = 0
    static func discover() async -> [InstalledPersonalAgent] {
        [InstalledPersonalAgent(provider: .codex, executableURL: URL(fileURLWithPath: "/dev/null"), path: "")]
    }
    static func summarize(_ input: ComparisonSummaryInput, using agent: InstalledPersonalAgent) async throws -> String {
        requests += 1
        return await withCheckedContinuation { response = $0 }
    }
}

@main
struct PersistenceCheck {
    enum Failure: Error { case assertion(String), timedOut }
    @MainActor
    static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure.assertion(message) }
    }
    @MainActor
    static func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !predicate() {
            guard Date() < deadline else { throw Failure.timedOut }
            await Task.yield()
        }
    }
    @MainActor
    static func fixture(previousReport: Bool) throws -> AppModel {
        let model = AppModel()
        let chat = Chat(id: "fixture", handle: "fixture@example.com", lastActivity: 0)
        var member = Member(agentID: UUID(), name: "Fixture participant", chat: chat)
        member.anchor = Anchor(rowID: 1, guid: "fixture-prompt")
        let comparison = Comparison(prompt: "Synthetic comparison", members: [member])
        model.state.comparisons = [comparison]
        model.messages[chat.id] = [
            Message(id: 1, guid: "fixture-prompt", chatID: chat.id, text: comparison.prompt, outgoing: true),
            Message(id: 2, guid: "fixture-reply", chatID: chat.id, text: "Synthetic answer", outgoing: false)
        ]
        if previousReport {
            let input = try ComparisonSummaryInput(comparison: comparison, comparisons: model.state.comparisons, messages: model.messages)
            model.state.comparisons[0].summary = ComparisonSummary(provider: "Saved fixture analyst", report: ComparisonReport(
                bestNextAction: "Keep the previously saved action.", rationale: "Previous rationale.",
                comparison: "Previously saved comparison.", uncertainties: ["Previous uncertainty."]), input: input)
        }
        return model
    }
    @MainActor
    static func run(previousReport: Bool, failFinalSave: Bool) async throws {
        let model = try fixture(previousReport: previousReport)
        model.failFinalSave = failFinalSave
        let previous = model.state.comparisons[0].summary
        let id = model.state.comparisons[0].id
        let controller = PersonalAgentController(demo: false)
        let previousRequests = LocalPersonalAgent.requests
        await controller.requestReport(id, model: model)
        try await waitUntil { LocalPersonalAgent.response != nil }
        try check(model.saveAttempts.count == 1 && model.saveAttempts[0] == previous, "Preflight must save the previous report before provider completion")
        try check(controller.running.contains(id), "Report must be running while provider response is pending")
        try check(LocalPersonalAgent.requests == previousRequests + 1, "Provider must be called exactly once")
        let pending = LocalPersonalAgent.response
        LocalPersonalAgent.response = nil
        pending?.resume(returning: """
        {"bestNextAction":"Try the new fixture action.","rationale":"New fixture rationale.","comparison":"New fixture comparison.","uncertainties":[]}
        """)
        try await waitUntil { controller.running.isEmpty }
        try check(model.saveAttempts.count == 2, "Completed report must attempt its final save")
        try check(model.saveAttempts[1]?.report?.bestNextAction == "Try the new fixture action.", "Final save must receive the completed provider report")
        if failFinalSave {
            try check(model.state.comparisons[0].summary == previous, "Final-save failure must restore the entire previous summary")
            try check(controller.errors[id] == AppModel.StorageFailure.finalSave.localizedDescription, "Final-save failure must expose the storage error to the UI")
        } else {
            try check(model.state.comparisons[0].summary == model.saveAttempts[1], "Successful final save must retain the completed report")
            try check(controller.errors[id] == nil, "Successful final save must not report an error")
        }
        try check(!controller.running.contains(id), "Completed request must clear its running state")
        print("PASS: final save \(failFinalSave ? "failed" : "succeeded"), previous report \(previousReport ? "present" : "absent"); report, error and running state verified")
    }
    @MainActor
    static func main() async {
        do {
            try await run(previousReport: true, failFinalSave: true)
            try await run(previousReport: false, failFinalSave: true)
            try await run(previousReport: true, failFinalSave: false)
        } catch {
            print("FAIL: \(error)")
            exit(1)
        }
    }
}
