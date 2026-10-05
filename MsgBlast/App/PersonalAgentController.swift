import Foundation
import Combine
import MsgBlastCore

@MainActor
final class PersonalAgentController: ObservableObject {
    @Published private(set) var installed: [InstalledPersonalAgent] = []
    @Published private(set) var discovering = false
    @Published private(set) var errors: [UUID: String] = [:]
    @Published private var tasks: [UUID: Task<Void, Never>] = [:]
    private var discoveryTask: Task<[InstalledPersonalAgent], Never>?
    private var shuttingDown = false
    var running: Set<UUID> { Set(tasks.keys) }
    let demo: Bool

    init(demo: Bool) { self.demo = demo }

    func discover() async {
        if let discoveryTask { installed = await discoveryTask.value; return }
        discovering = true
        let task = Task { [demo] in
            if demo {
                return [InstalledPersonalAgent(provider: .codex, executableURL: URL(fileURLWithPath: "/dev/null"), path: "")]
            }
            return await LocalPersonalAgent.discover()
        }
        discoveryTask = task
        installed = await task.value
        discoveryTask = nil; discovering = false
    }

    func selectedProvider(model: AppModel) -> PersonalAgentProvider? {
        if let saved = model.state.personalAgentProvider { return PersonalAgentProvider(rawValue: saved) }
        return installed.first?.provider
    }

    func requestReport(_ id: UUID, model: AppModel) async {
        guard !shuttingDown, !running.contains(id) else { return }
        await discover()
        if let provider = selectedProvider(model: model) { summarize(id, provider: provider, model: model) }
    }

    func input(for id: UUID, model: AppModel) throws -> ComparisonSummaryInput {
        guard let comparison = model.comparison(id) else { throw AppFailure.blocked("This comparison is no longer available.") }
        return try ComparisonSummaryInput(comparison: comparison, comparisons: model.state.comparisons, messages: model.messages)
    }

    func summarize(_ id: UUID, provider: PersonalAgentProvider, model: AppModel) {
        guard !shuttingDown, !running.contains(id) else { return }
        errors[id] = nil
        do {
            guard model.databaseAvailable else { throw AppFailure.blocked("Refresh Messages history before summarizing this comparison.") }
            let snapshot = try input(for: id, model: model)
            guard snapshot.responseCount > 0 else { throw AppFailure.blocked("Waiting for the first response. You can summarize as soon as a participant replies.") }
            guard provider.unavailabilityReason == nil else { throw PersonalAgentError.unsupportedProvider(provider) }
            guard let agent = installed.first(where: { $0.provider == provider }) else { throw PersonalAgentError.unavailable(provider.name) }
            // Check storage before starting a provider request that may consume the user's plan.
            try model.save()
            tasks[id] = Task { [weak self, weak model] in
                guard let self, let model else { return }
                defer { self.tasks[id] = nil }
                do {
                    let report: ComparisonReport
                    if self.demo {
                        try await Task.sleep(for: .seconds(1))
                        let names = model.comparison(id)?.members.map(\.name).joined(separator: ", ") ?? "the participants"
                        report = ComparisonReport(
                            bestNextAction: "Choose one representative example and test each approach against the same success criteria.",
                            rationale: "A small trial turns the different recommendations into evidence you can compare before committing.",
                            comparison: "Across \(names), the shared recommendation is to make assumptions visible and compare options against one concrete goal.\n\n**Agreement**\nStart small and evaluate each answer against consistent criteria.\n\n**Differences**\nCedar emphasizes clarity, cost, and reversibility. Lumen emphasizes a small trial and explicit assumptions. Orbit starts with the desired outcome and follows up on unclear reasoning.",
                            uncertainties: ["Which outcome matters most to you: clarity, cost, or reversibility?", "Simulated demo report. No installed agent was contacted."])
                    } else {
                        let response = try await LocalPersonalAgent.summarize(snapshot, using: agent)
                        guard let parsed = ComparisonReport(response: response) else { throw PersonalAgentError.invalidResponse(provider.name) }
                        report = parsed
                    }
                    try Task.checkCancellation()
                    guard let index = model.index(id) else { return }
                    let previous = model.state.comparisons[index].summary
                    model.state.comparisons[index].summary = ComparisonSummary(provider: self.demo ? "Demo analyst (simulated)" : provider.name, report: report, input: snapshot)
                    do { try model.save() }
                    catch { model.state.comparisons[index].summary = previous; throw error }
                } catch is CancellationError {
                    self.errors[id] = "Report cancelled."
                } catch {
                    self.errors[id] = error.localizedDescription
                }
            }
        } catch { errors[id] = error.localizedDescription }
    }

    func cancel(_ id: UUID) { tasks[id]?.cancel() }
    func cancelAll() { for task in tasks.values { task.cancel() } }
    func beginShutdown() { shuttingDown = true }
    func cancelAndWait() async {
        beginShutdown()
        let pending = Array(tasks.values)
        for task in pending { task.cancel() }
        for task in pending { await task.value }
    }
}
