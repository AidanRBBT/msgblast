import Foundation
import Combine
import MsgBlastCore

@MainActor
final class PersonalAgentController: ObservableObject {
    @Published private(set) var installed: [InstalledPersonalAgent] = []
    @Published private(set) var discovering = false
    @Published private(set) var errors: [UUID: String] = [:]
    @Published private var tasks: [UUID: Task<Void, Never>] = [:]
    var running: Set<UUID> { Set(tasks.keys) }
    let demo: Bool

    init(demo: Bool) { self.demo = demo }

    func discover() async {
        guard !discovering else { return }
        discovering = true
        defer { discovering = false }
        if demo {
            installed = [InstalledPersonalAgent(provider: .codex, executableURL: URL(fileURLWithPath: "/dev/null"), path: "")]
        } else {
            installed = await LocalPersonalAgent.discover()
        }
    }

    func input(for id: UUID, model: AppModel) throws -> ComparisonSummaryInput {
        guard let comparison = model.comparison(id) else { throw AppFailure.blocked("This comparison is no longer available.") }
        return try ComparisonSummaryInput(comparison: comparison, comparisons: model.state.comparisons, messages: model.messages)
    }

    func summarize(_ id: UUID, provider: PersonalAgentProvider, model: AppModel) {
        guard !running.contains(id) else { return }
        errors[id] = nil
        do {
            guard model.databaseAvailable else { throw AppFailure.blocked("Refresh Messages history before summarizing this comparison.") }
            let snapshot = try input(for: id, model: model)
            guard snapshot.responseCount > 0 else { throw AppFailure.blocked("Waiting for the first response. You can summarize as soon as a participant replies.") }
            guard let agent = installed.first(where: { $0.provider == provider }) else { throw PersonalAgentError.unavailable(provider.name) }
            // Check storage before starting a provider request that may consume the user's plan.
            try model.save()
            tasks[id] = Task { [weak self, weak model] in
                guard let self, let model else { return }
                defer { self.tasks[id] = nil }
                do {
                    let text: String
                    if self.demo {
                        try await Task.sleep(for: .seconds(1))
                        let names = model.comparison(id)?.members.map(\.name).joined(separator: ", ") ?? "the participants"
                        text = """
                        Demo summary · simulated output

                        Across \(names), the shared recommendation is to use one concrete question and evaluate each approach against the same goal.

                        Agreement
                        Make assumptions visible and test the options on a small example before committing.

                        Differences
                        Cedar emphasizes clarity, cost, and reversibility. Lumen emphasizes a small trial and explicit assumptions. Orbit starts with the desired outcome and follows up on unclear reasoning.

                        Next step
                        Choose a representative example, define the success criteria, and compare the results side by side.

                        This fixture demonstrates the summary workflow. No installed agent was contacted.
                        """
                    } else {
                        text = try await LocalPersonalAgent.summarize(snapshot, using: agent)
                    }
                    try Task.checkCancellation()
                    guard let index = model.index(id) else { return }
                    let previous = model.state.comparisons[index].summary
                    model.state.comparisons[index].summary = ComparisonSummary(provider: self.demo ? "Demo analyst (simulated)" : provider.name, text: text, input: snapshot)
                    do { try model.save() }
                    catch { model.state.comparisons[index].summary = previous; throw error }
                } catch is CancellationError {
                    self.errors[id] = "Summary cancelled."
                } catch {
                    self.errors[id] = error.localizedDescription
                }
            }
        } catch { errors[id] = error.localizedDescription }
    }

    func cancel(_ id: UUID) { tasks[id]?.cancel() }
    func cancelAll() { for task in tasks.values { task.cancel() } }
    func cancelAndWait() async {
        let pending = Array(tasks.values)
        for task in pending { task.cancel() }
        for task in pending { await task.value }
    }
}
