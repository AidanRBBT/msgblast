import SwiftUI
import WebKit
import MsgBlastCore

struct EmbeddedServicePage: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct AgentsWorkspaceView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var web: WebAgents
    @Binding var showingComparison: Bool
    @State private var sending = false
    private var busy: Bool { sending || model.busy || web.sessions.contains { $0.isSending } }
    private var nativeRecipients: [Agent] { model.state.agents.filter { model.state.selection.contains($0.id) } }
    private var canSend: Bool {
        let text = model.state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !busy && (!web.selected.isEmpty || !nativeRecipients.isEmpty)
            && (web.selected.isEmpty || (!text.isEmpty && model.attachmentDraft().isEmpty))
            && web.selected.allSatisfy { $0.snapshot.ready && $0.snapshot.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.state.hasUnresolvedSend(text) }
            && (nativeRecipients.isEmpty || (model.databaseAvailable && nativeRecipients.allSatisfy { model.route($0) != nil }))
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingComparison {
                HStack {
                    Button { showingComparison = false } label: { Label("Agents", systemImage: "chevron.left") }
                        .accessibilityLabel("Back to agents")
                    Spacer()
                    Text(web.fixture ? "Local fixture · no real sends" : model.demo ? "Live web agents · simulated Messages" : "")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(10)
                comparisonPanes
            } else {
                agentPicker
            }
            Divider()
            composer
        }
        .background(Color(nsColor: .textBackgroundColor))
        .task { web.connectSelected() }
    }

    private var nativeComparison: Comparison? { web.comparisonID.flatMap { model.comparison($0) } }

    private var agentPicker: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 28) {
                    ForEach(web.sessions, id: \.provider) { session in
                        PinnedAgentTile(agent: webAgent(session), selected: session.state.selected, size: tileSize(geometry)) {
                            web.toggle(session)
                        }.disabled(busy).help("\(session.provider.name) · \(session.provider.homeURL.host!)")
                    }
                    ForEach(model.state.agents) { agent in
                        PinnedAgentTile(agent: agent, selected: model.state.selection.contains(agent.id), size: tileSize(geometry)) {
                            toggle(agent.id)
                        }.disabled(busy || model.route(agent) == nil)
                            .help(model.route(agent)?.handle ?? "No matching conversation")
                    }
                }.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 20)
            }
        }
    }

    private func tileSize(_ geometry: GeometryProxy) -> CGFloat { min(100, max(48, (geometry.size.width - 80) / 3)) }

    private var comparisonPanes: some View {
        GeometryReader { geometry in
            let columns = web.selected.count + (nativeComparison?.members.count ?? 0)
            let width = max(320, (geometry.size.width - CGFloat(max(0, columns - 1))) / CGFloat(max(1, columns)))
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(web.selected, id: \.provider) { session in
                        if session.provider != web.selected.first?.provider { Divider() }
                        WebAgentPane(session: session, busy: busy).frame(width: width)
                    }
                    if let comparison = nativeComparison {
                        ForEach(comparison.members) { member in
                            if !web.selected.isEmpty || member.id != comparison.members.first?.id { Divider() }
                            ConversationView(model: model, comparisonID: comparison.id, memberID: member.id, embedded: true)
                                .frame(width: width)
                        }
                    }
                }.frame(height: geometry.size.height)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !showingComparison {
                ForEach(web.selected, id: \.provider) { session in
                    HStack {
                        Text(session.snapshot.ready ? "\(session.provider.name) is ready" : "Sign in to \(session.provider.name) inside MsgBlast to include it.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(session.snapshot.ready ? "Open \(session.provider.name)" : "Sign in to \(session.provider.name)") {
                            session.connect(); showingComparison = true
                        }.disabled(busy)
                    }
                }
            }
            if !web.selected.isEmpty && !model.attachmentDraft().isEmpty {
                Text("Web agents support text here. Remove the attachments or deselect them to send.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if showingComparison { ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Text("Send to").font(.caption).foregroundStyle(.secondary)
                    ForEach(web.sessions, id: \.provider) { session in
                        recipient(session.provider.name, selected: session.state.selected) { web.toggle(session) }
                    }
                    ForEach(model.state.agents) { agent in
                        recipient(agent.name, selected: model.state.selection.contains(agent.id)) { toggle(agent.id) }
                            .disabled(model.route(agent) == nil)
                            .help("Messages · \(agent.name)")
                    }
                }
            }.scrollIndicators(.hidden) }
            MessageInput(text: Binding(get: { model.state.draft }, set: { model.state.draft = $0; model.persist() }),
                         attachments: model.attachmentDraft(), addAttachments: { await model.addAttachments($0) },
                         removeAttachment: { id in model.setAttachmentDraft(model.attachmentDraft().filter { $0.id != id }) },
                         placeholder: "Message", accessibilityName: "Shared prompt", sendLabel: "Send & compare",
                         disabled: !canSend, attachmentsEnabled: web.selected.isEmpty, send: send)
        }.padding(20)
    }

    private func recipient(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                Text(title)
            }.font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
        }.buttonStyle(.plain).background(selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule())
            .accessibilityLabel("Recipient \(title)").accessibilityValue(selected ? "Selected" : "Not selected").disabled(busy)
    }

    private func toggle(_ id: UUID) {
        if model.state.selection.contains(id) { model.state.selection.remove(id) }
        else { model.state.selection.insert(id) }
        model.persist()
    }

    private func send() {
        guard canSend else { return }
        if web.selected.isEmpty {
            Task { await model.start() }
            return
        }
        let originalDraft = model.state.draft
        let recipients = Set(nativeRecipients.map(\.id))
        let model = model
        let sessions = web.selected
        sending = true
        showingComparison = true
        Task { @MainActor in
            defer { sending = false }
            let result = await AgentBroadcast.send(draft: originalDraft, currentDraft: { model.state.draft }, clearDraft: {
                model.state.draft = ""; model.persist()
            }, web: { text in
                await WebAgents.send(text, to: sessions)
            }, messages: { text in
                guard !recipients.isEmpty else { return nil }
                return await model.startTextComparison(text, recipientIDs: recipients) { id in
                    web.setComparison(id)
                }
            })
            web.setComparison(result.comparisonID)
        }
    }
}

private struct WebAgentPane: View {
    @ObservedObject var session: WebAgentSession
    let busy: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AgentAvatar(agent: webAgent(session), name: session.provider.name, size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.provider.name).font(.headline)
                    Text(session.webView.url?.host ?? session.provider.homeURL.host!).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if session.loading { ProgressView().controlSize(.small) }
                Label(session.snapshot.ready ? "Chat ready" : session.connected ? "Needs attention" : "Not connected", systemImage: session.snapshot.ready ? "checkmark.circle.fill" : "circle")
                    .font(.caption).foregroundStyle(session.snapshot.ready ? Color.green : Color.secondary)
                    .accessibilityIdentifier("\(session.provider.name) connection status")
                Button { session.openMainChat() } label: { Image(systemName: "house") }.help("Main \(session.provider.name) chat").accessibilityLabel("Main \(session.provider.name) chat").disabled(busy)
                Button { session.reload() } label: { Image(systemName: "arrow.clockwise") }.help("Reload \(session.provider.name)").accessibilityLabel("Reload \(session.provider.name)").disabled(busy)
            }.padding(14).background(.bar)
            if let latest = session.state.attempts.first {
                VStack(alignment: .leading, spacing: 3) {
                    Label(latest.status.label(for: session.provider), systemImage: latest.status == .observed ? "checkmark.circle" : "info.circle")
                        .font(.caption.weight(.semibold))
                    Text(latest.text).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if latest.status != .observed, let detail = latest.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .contain)
            }
            if let error = session.error { Text(error).font(.caption).foregroundStyle(.orange).padding(10).frame(maxWidth: .infinity, alignment: .leading) }
            if session.connected {
                if !session.snapshot.ready && !session.loading {
                    Text(session.snapshot.reason).font(.caption).foregroundStyle(.secondary).padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                if !session.snapshot.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !session.isSending {
                    Text("\(session.provider.name) has a draft. Send or clear it in the page before using the shared composer.").font(.caption).foregroundStyle(.orange).padding(8)
                }
                EmbeddedServicePage(webView: session.webView)
            } else {
                VStack(spacing: 18) {
                    AgentAvatar(agent: webAgent(session), name: session.provider.name, size: 80)
                    Text("\(session.provider.name), inside MsgBlast").font(.title2.weight(.semibold))
                    Text("Sign in here once, then send from the shared composer. Your \(session.provider.name) conversation and replies stay in this window.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 380)
                    Button("Connect \(session.provider.name)") { session.connect() }.buttonStyle(.borderedProminent).controlSize(.large)
                    Text("Safari’s login is separate. MsgBlast remembers its own web session.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(28)
            }
        }
        .sheet(isPresented: Binding(get: { session.popup != nil }, set: { if !$0 { session.closePopup() } })) {
            VStack(spacing: 0) {
                HStack {
                    Text(session.popupURL).font(.caption).textSelection(.enabled).lineLimit(2)
                    Spacer()
                    Button("Done") { session.closePopup() }
                }.padding(12)
                Divider()
                if let popup = session.popup { EmbeddedServicePage(webView: popup) }
            }.frame(minWidth: 650, minHeight: 650)
        }
    }

}

private let museDefaultAvatar = Bundle.main.url(forResource: "MuseAvatar", withExtension: "jpg").flatMap { try? Data(contentsOf: $0) }
@MainActor
private func webAgent(_ session: WebAgentSession) -> Agent {
    Agent(name: session.provider.name, handles: [], avatar: session.provider == .muse ? session.avatar ?? museDefaultAvatar : nil,
          colorIndex: WebProvider.allCases.firstIndex(of: session.provider)! + 4)
}
