import Foundation
import msgblastCore

@MainActor
final class AppModel {
    var state = AppState()
    var messages: [String: [Message]] = [:]
    var databaseAvailable = true
    func save() throws {}
    func persist() {}
    func comparison(_ id: UUID) -> Comparison? { state.comparisons.first { $0.id == id } }
    func index(_ id: UUID) -> Int? { state.comparisons.firstIndex { $0.id == id } }
}

// Controlled local substitutes: no provider CLI or network request is launched.
@MainActor
enum LocalPersonalAgent {
    static var discovery: CheckedContinuation<[InstalledPersonalAgent], Never>?
    static var cleanup: CheckedContinuation<Void, Never>?
    static var requests = 0
    static func discover() async -> [InstalledPersonalAgent] {
        await withCheckedContinuation { discovery = $0 }
    }
    static func finishDiscovery() {
        let pending = discovery
        discovery = nil
        pending?.resume(returning: [InstalledPersonalAgent(provider: .codex, executableURL: URL(fileURLWithPath: "/dev/null"), path: "")])
    }
    static func summarize(_ input: ComparisonSummaryInput, using agent: InstalledPersonalAgent) async throws -> String {
        requests += 1
        let request = requests
        do { try await Task.sleep(for: .seconds(30)) }
        catch {
            if request == 1 { await withCheckedContinuation { cleanup = $0 } }
            throw error
        }
        return ""
    }
}

@main
struct LifecycleCheck {
    enum Failure: Error { case timedOut }
    @MainActor
    static func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !predicate() {
            guard Date() < deadline else { throw Failure.timedOut }
            await Task.yield()
        }
    }
    @MainActor
    static func main() async throws {
        let controller = PersonalAgentController(demo: false)
        let model = AppModel()
        for i in 0..<2 {
            let chat = Chat(id: "fixture-\(i)", handle: "fixture-\(i)@example.com", lastActivity: 0)
            var member = Member(agentID: UUID(), name: "Fixture \(i)", chat: chat)
            member.anchor = Anchor(rowID: 1, guid: "prompt-\(i)")
            let comparison = Comparison(prompt: "Synthetic comparison \(i)", members: [member])
            model.state.comparisons.append(comparison)
            model.messages[chat.id] = [Message(id: 1, guid: "prompt-\(i)", chatID: chat.id, text: comparison.prompt, outgoing: true), Message(id: 2, guid: "reply-\(i)", chatID: chat.id, text: "Synthetic answer", outgoing: false)]
        }
        let first = Task { await controller.requestReport(model.state.comparisons[0].id, model: model) }
        try await waitUntil { LocalPersonalAgent.discovery != nil }
        LocalPersonalAgent.finishDiscovery()
        await first.value
        try await waitUntil { LocalPersonalAgent.requests > 0 }
        let second = Task { await controller.requestReport(model.state.comparisons[1].id, model: model) }
        try await waitUntil { LocalPersonalAgent.discovery != nil }
        let shutdown = Task { await controller.cancelAndWait() }
        try await waitUntil { LocalPersonalAgent.cleanup != nil }
        LocalPersonalAgent.finishDiscovery()
        await second.value
        for _ in 0..<10 { await Task.yield() }
        let unexpected = LocalPersonalAgent.requests > 1
        let cleanup = LocalPersonalAgent.cleanup
        LocalPersonalAgent.cleanup = nil
        cleanup?.resume()
        await shutdown.value
        controller.summarize(model.state.comparisons[1].id, provider: .codex, model: model)
        let leftRunning = !controller.running.isEmpty
        controller.cancelAll()
        for _ in 0..<10 { await Task.yield() }
        print("Provider starts: \(LocalPersonalAgent.requests); reports active after shutdown: \(leftRunning ? 1 : 0)")
        if unexpected || leftRunning { print("FAIL: pending discovery escaped shutdown"); exit(1) }
        print("PASS: pending discovery cannot start a report during shutdown")
    }
}
