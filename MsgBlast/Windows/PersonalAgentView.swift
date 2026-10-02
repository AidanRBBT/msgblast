import SwiftUI
import MsgBlastCore

struct PersonalAgentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var agent: PersonalAgentController
    let comparisonID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: ComparisonSummaryInput?

    private var selected: PersonalAgentProvider? {
        if let saved = model.state.personalAgentProvider { return PersonalAgentProvider(rawValue: saved) }
        return agent.installed.first?.provider
    }
    private func refreshSnapshot() { snapshot = try? agent.input(for: comparisonID, model: model) }

    var body: some View {
        let summary = model.comparison(comparisonID)?.summary
        let input = snapshot
        let running = agent.running.contains(comparisonID)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: "sparkles").font(.title2).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal agent").font(.title2.bold())
                    Text("One summary of every response in this comparison.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if agent.discovering {
                ProgressView("Finding installed agents…").controlSize(.small)
            } else if agent.installed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No supported agent CLI found").font(.headline)
                    Text("Install and sign in to Codex, Claude Code, Cursor, Gemini CLI, Pi, Grok, or Hermes in Terminal, then refresh. A desktop app alone may not include its CLI.")
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Picker("Summarize with", selection: Binding(get: { selected?.rawValue ?? "" }, set: {
                        model.state.personalAgentProvider = $0; model.persist()
                    })) {
                        if let selected, !agent.installed.contains(where: { $0.provider == selected }) {
                            Text("\(selected.name) · not found").tag(selected.rawValue)
                        }
                        ForEach(agent.installed) { installed in
                            Text(agent.demo ? "Demo analyst (simulated)" : installed.provider.name).tag(installed.id)
                        }
                    }.disabled(running).frame(maxWidth: 340)
                    Spacer()
                    if running {
                        ProgressView().controlSize(.small)
                        Button("Cancel summary") { agent.cancel(comparisonID) }
                    } else {
                        Button(summary == nil ? "Summarize responses" : "Update summary") {
                            if let selected { agent.summarize(comparisonID, provider: selected, model: model) }
                        }.buttonStyle(.borderedProminent)
                            .disabled((input?.responseCount ?? 0) == 0 || !model.databaseAvailable || !agent.installed.contains(where: { $0.provider == selected }))
                    }
                }
            }
            HStack(alignment: .top) {
                Text(agent.demo ? "Demo uses synthetic replies and a simulated summary. No provider request is made." : "Uses your CLI’s existing sign-in and provider plan. The comparison text is sent to that provider when you click Summarize. Attachment contents are not included.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button("Refresh agents") { Task { await agent.discover() } }.disabled(agent.discovering || running)
            }
            if let selected, !agent.demo {
                Text("Sign in or troubleshoot in Terminal: \(selected.setup)")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Divider()
            if let error = agent.errors[comparisonID] {
                Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if let summary {
                HStack {
                    Text("\(summary.provider) · \(summary.respondingMemberCount) of \(summary.memberCount) participants · \(summary.responseCount) responses")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy summary") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(summary.text, forType: .string) }
                }
                if let input, input.fingerprint != summary.fingerprint {
                    Label("Conversation changed · update the summary to include the latest replies.", systemImage: "arrow.clockwise")
                        .font(.callout).foregroundStyle(.orange)
                }
                ScrollView {
                    Text(summary.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16).accessibilityIdentifier("Comparison summary text")
                }.background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                Text("Saved \(summary.created.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(running ? "Reading the responses…" : "See the full picture", systemImage: "text.alignleft",
                    description: Text((input?.responseCount ?? 0) == 0 ? "Waiting for the first response." : "\(input?.respondingMemberCount ?? 0) of \(input?.memberCount ?? 0) participants have replied. Your agent will summarize agreements, differences, and next steps."))
            }
        }
        .padding(24).frame(width: 650, height: 570)
        .task { refreshSnapshot(); await agent.discover() }
        .onChange(of: model.comparison(comparisonID)?.members.map { model.messages[$0.chat.id] ?? [] }) { refreshSnapshot() }
        .onChange(of: model.state.comparisons.flatMap(\.members)) { refreshSnapshot() }
    }
}

struct PersonalAgentButton: View {
    @ObservedObject var model: AppModel
    @ObservedObject var agent: PersonalAgentController
    let comparisonID: UUID
    @State private var presented = false
    var body: some View {
        Button { presented = true } label: {
            Label(agent.running.contains(comparisonID) ? "Summarizing…" : "Personal agent", systemImage: "sparkles")
        }
        .help("Summarize all responses using an agent installed on this Mac")
        .sheet(isPresented: $presented) { PersonalAgentView(model: model, agent: agent, comparisonID: comparisonID) }
    }
}
