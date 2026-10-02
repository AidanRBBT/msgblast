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
    @ObservedObject var session: MuseWebSession
    @Binding var showingComparison: Bool
    @State private var sending = false
    private static let muse = Agent(name: "Muse", handles: [], colorIndex: 4)
    private var busy: Bool { sending || model.busy || session.isSending }
    private var nativeRecipients: [Agent] { model.state.agents.filter { model.state.selection.contains($0.id) } }
    private var canSend: Bool {
        let text = model.state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !busy && (session.state.includeMuse || !nativeRecipients.isEmpty)
            && (!session.state.includeMuse || (!text.isEmpty && model.attachmentDraft().isEmpty))
            && (!session.state.includeMuse || (session.snapshot.ready && session.snapshot.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !session.state.hasUnresolvedSend(text)))
            && (nativeRecipients.isEmpty || (model.databaseAvailable && nativeRecipients.allSatisfy { model.route($0) != nil }))
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingComparison {
                HStack {
                    Button { showingComparison = false } label: { Label("Agents", systemImage: "chevron.left") }
                        .accessibilityLabel("Back to agents")
                    Spacer()
                    Text(session.fixture ? "Local fixture · no real sends" : model.demo ? "Live Muse · simulated Messages" : "")
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

    private var nativeComparison: Comparison? { session.state.comparisonID.flatMap { model.comparison($0) } }

    private var agentPicker: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 28) {
                    PinnedAgentTile(agent: Self.muse, selected: session.state.includeMuse, size: tileSize(geometry)) {
                        session.updateState { $0.includeMuse.toggle() }
                        if session.state.includeMuse { session.connect() }
                    }.disabled(busy).help("Muse · muse.ai")
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
            let columns = (session.state.includeMuse ? 1 : 0) + (nativeComparison?.members.count ?? 0)
            let width = max(320, (geometry.size.width - CGFloat(max(0, columns - 1))) / CGFloat(max(1, columns)))
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    if session.state.includeMuse { musePane.frame(width: width) }
                    if let comparison = nativeComparison {
                        ForEach(comparison.members) { member in
                            if session.state.includeMuse || member.id != comparison.members.first?.id { Divider() }
                            ConversationView(model: model, comparisonID: comparison.id, memberID: member.id, embedded: true)
                                .frame(width: width)
                        }
                    }
                }.frame(height: geometry.size.height)
            }
        }
    }

    private var musePane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "globe").font(.title2).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Muse").font(.headline)
                    Text(session.webView.url?.host ?? "muse.ai").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if session.loading { ProgressView().controlSize(.small) }
                Label(session.snapshot.ready ? "Chat ready" : session.connected ? "Needs attention" : "Not connected", systemImage: session.snapshot.ready ? "checkmark.circle.fill" : "circle")
                    .font(.caption).foregroundStyle(session.snapshot.ready ? Color.green : Color.secondary)
                    .accessibilityIdentifier("Muse connection status")
                Button { session.openMainChat() } label: { Image(systemName: "house") }.help("Main Muse chat").accessibilityLabel("Main Muse chat").disabled(busy)
                Button { session.reload() } label: { Image(systemName: "arrow.clockwise") }.help("Reload Muse").accessibilityLabel("Reload Muse").disabled(busy)
            }.padding(14).background(.bar)
            if let error = session.error { Text(error).font(.caption).foregroundStyle(.orange).padding(10).frame(maxWidth: .infinity, alignment: .leading) }
            if session.connected {
                if !session.snapshot.ready && !session.loading {
                    Text(session.snapshot.reason).font(.caption).foregroundStyle(.secondary).padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                if !session.snapshot.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !session.isSending {
                    Text("Muse has a draft. Send or clear it in the page before using the shared composer.").font(.caption).foregroundStyle(.orange).padding(8)
                }
                EmbeddedServicePage(webView: session.webView)
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "globe").font(.system(size: 46, weight: .light)).foregroundStyle(.teal)
                    Text("Muse, inside MsgBlast").font(.title2.weight(.semibold))
                    Text("Sign in here once, then send from the shared composer. Your Muse conversation and replies stay in this window.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 380)
                    Button("Connect Muse") { session.connect() }.buttonStyle(.borderedProminent).controlSize(.large)
                    Text("Safari’s login is separate. MsgBlast remembers its own web session.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(28)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if session.state.includeMuse && !showingComparison {
                HStack {
                    Text(session.snapshot.ready ? "Muse is ready" : "Sign in to Muse inside MsgBlast to include it.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(session.snapshot.ready ? "Open Muse" : "Sign in to Muse") {
                        session.connect(); showingComparison = true
                    }.disabled(busy)
                }
            }
            if session.state.includeMuse && !model.attachmentDraft().isEmpty {
                Text("Muse supports text here. Remove the attachments or deselect Muse to send.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if showingComparison, let latest = session.state.attempts.first {
                HStack(alignment: .top) {
                    Image(systemName: latest.status == .observed ? "checkmark.circle" : "info.circle")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(latest.status.label).font(.caption.weight(.semibold))
                        Text(latest.text).font(.caption).foregroundStyle(.secondary).lineLimit(1).textSelection(.enabled)
                        if let detail = latest.detail, latest.status != .observed { Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                    }
                    Spacer()
                }.accessibilityElement(children: .contain)
            }
            if showingComparison { ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Text("Send to").font(.caption).foregroundStyle(.secondary)
                    recipient("Muse", selected: session.state.includeMuse) {
                        session.updateState { $0.includeMuse.toggle() }
                        if session.state.includeMuse { session.connect() }
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
                         disabled: !canSend, attachmentsEnabled: !session.state.includeMuse, send: send)
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
        if !session.state.includeMuse {
            Task { await model.start() }
            return
        }
        let originalDraft = model.state.draft
        let recipients = Set(nativeRecipients.map(\.id))
        let model = model
        let session = session
        sending = true
        showingComparison = true
        Task { @MainActor in
            defer { sending = false }
            let result = await AgentBroadcast.send(draft: originalDraft, currentDraft: { model.state.draft }, clearDraft: {
                model.state.draft = ""; model.persist()
            }, muse: { text in
                await session.send(text)
            }, messages: { text in
                guard !recipients.isEmpty else { return nil }
                return await model.startTextComparison(text, recipientIDs: recipients) { id in
                    session.updateState { $0.comparisonID = id }
                }
            })
            session.updateState { $0.comparisonID = result.comparisonID }
        }
    }
}
