import SwiftUI
import WebKit
import msgblastCore

struct EmbeddedServicePage: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct AgentsWorkspaceView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var web: WebAgents
    @Binding var showingComparison: Bool
    private var busy: Bool { model.busy || model.webBroadcastBusy || web.sessions.contains { $0.isSending } }
    private var nativeRecipients: [Agent] { model.state.agents.filter { model.state.selection.contains($0.id) } }
    private var attachmentComparisonID: UUID? { showingComparison ? nativeComparison?.id : nil }
    private var attachments: [MessageAttachment] { model.attachmentDraft(comparisonID: attachmentComparisonID) }
    private var canSend: Bool {
        let text = model.state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !busy && (!web.selected.isEmpty || !nativeRecipients.isEmpty)
            && (web.selected.isEmpty || (!text.isEmpty && attachments.isEmpty))
            && web.selected.allSatisfy { $0.snapshot.ready && $0.snapshot.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.hasUnresolvedSend(text) }
            && (nativeRecipients.isEmpty || (model.databaseAvailable && nativeRecipients.allSatisfy { model.route($0) != nil }))
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingComparison {
                HStack {
                    Button { showingComparison = false; web.setComparison(nil) } label: { Label("New comparison", systemImage: "plus") }
                        .accessibilityLabel("New comparison").disabled(busy)
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
                        WebAgentPane(session: session, account: model.personalAgent, busy: busy, sendNative: { sendDirect($0, to: session) }).frame(width: width)
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
                        Button("Open \(session.provider.name)") {
                            session.connect(); showingComparison = true
                        }.disabled(busy)
                        Spacer()
                    }
                }
            }
            let unavailable = web.selected.filter { !$0.snapshot.ready && !$0.loading }.map { $0.provider.name }
            if !unavailable.isEmpty && !model.state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !busy {
                Text("Connect \(unavailable.formatted(.list(type: .and))) in their panes before sending.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !web.selected.isEmpty && !attachments.isEmpty {
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
                            .disabled(model.route(agent) == nil || (nativeComparison?.members.contains { $0.id == agent.id } == false))
                            .help("Messages · \(agent.name)")
                    }
                }
            }.scrollIndicators(.hidden) }
            if showingComparison, let comparison = nativeComparison {
                FollowUpStatus(model: model, comparison: comparison, universal: true).disabled(busy)
            }
            MessageInput(text: Binding(get: { model.state.draft }, set: { model.state.draft = $0; model.persist() }),
                         attachments: attachments, addAttachments: { await model.addAttachments($0, comparisonID: attachmentComparisonID) },
                         removeAttachment: { id in model.setAttachmentDraft(attachments.filter { $0.id != id }, comparisonID: attachmentComparisonID) },
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
        if web.selected.isEmpty && nativeComparison?.webProviders == nil {
            Task { await model.start() }
            return
        }
        let originalDraft = model.state.draft
        let recipients = Set(nativeRecipients.map(\.id))
        let model = model
        let sessions = web.selected
        let existingID = showingComparison ? nativeComparison?.id : nil
        model.webBroadcastBusy = true
        showingComparison = true
        Task { @MainActor in
            defer { model.webBroadcastBusy = false }
            let comparisonID: UUID
            if let existingID { comparisonID = existingID }
            else {
                guard let id = await model.prepareWebComparison(originalDraft.trimmingCharacters(in: .whitespacesAndNewlines), recipientIDs: recipients, providers: sessions.map(\.provider)) else { return }
                comparisonID = id
            }
            if let i = model.index(comparisonID) {
                let previous = model.state.comparisons[i].webProviders ?? []
                model.state.comparisons[i].webProviders = WebProvider.allCases.filter { previous.contains($0) || sessions.map(\.provider).contains($0) }
                do { try model.save() } catch { model.error = error.localizedDescription; return }
            }
            _ = await AgentBroadcast.send(draft: originalDraft, currentDraft: { model.state.draft }, clearDraft: {
                model.state.draft = ""; model.persist()
            }, web: { text in
                await WebAgents.send(text, to: sessions, comparisonID: comparisonID)
            }, messages: { text in
                guard !recipients.isEmpty else { return nil }
                if existingID != nil {
                    guard let i = model.index(comparisonID) else { return nil }
                    let previousCount = model.state.comparisons[i].followUps.count
                    model.state.comparisons[i].allDraft = text
                    await model.followUp(comparisonID, recipients: Array(recipients))
                    return model.comparison(comparisonID)?.followUps.count != previousCount ? comparisonID : nil
                }
                await model.submit(comparisonID, retry: false)
                return comparisonID
            })
            web.setComparison(comparisonID)
        }
    }

    private func sendDirect(_ text: String, to session: WebAgentSession) {
        guard !busy, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let existingID = nativeComparison?.id
        model.webBroadcastBusy = true
        Task { @MainActor in
            defer { model.webBroadcastBusy = false }
            let id: UUID
            if let existingID { id = existingID }
            else {
                guard let created = await model.prepareWebComparison(text, recipientIDs: [], providers: [session.provider]) else { return }
                id = created
            }
            guard let i = model.index(id) else { return }
            if model.state.comparisons[i].webProviders?.contains(session.provider) != true {
                model.state.comparisons[i].webProviders = (model.state.comparisons[i].webProviders ?? []) + [session.provider]
            }
            do { try model.save() } catch { model.error = error.localizedDescription; return }
            showingComparison = true
            _ = await session.send(text, comparisonID: id)
            web.setComparison(id)
        }
    }
}

private struct WebAgentPane: View {
    @ObservedObject var session: WebAgentSession
    @ObservedObject var account: PersonalAgentController
    let busy: Bool
    let sendNative: (String) -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AgentAvatar(agent: webAgent(session), name: session.provider.name, size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.provider.name).font(.headline)
                    Text(session.locationLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if session.loading { ProgressView().controlSize(.small) }
                if session.provider.personalAgentProvider == nil {
                    Button { session.openComparisonChat() } label: { Image(systemName: "house") }.help("\(session.provider.name) comparison chat").accessibilityLabel("\(session.provider.name) comparison chat").disabled(busy)
                }
                Button { session.reload() } label: { Image(systemName: "arrow.clockwise") }.help("Reload \(session.provider.name)").accessibilityLabel("Reload \(session.provider.name)").disabled(busy)
            }.padding(14).background(.bar)
            if let latest = session.latestComparisonAttempt {
                VStack(alignment: .leading, spacing: 3) {
                    Label(latest.status.label(for: session.provider), systemImage: latest.status == .observed ? "checkmark.circle" : "info.circle")
                        .font(.caption.weight(.semibold))
                    Text(latest.text).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if latest.status != .observed, let detail = latest.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .contain)
            }
            if let error = session.error { Text(error).font(.caption).foregroundStyle(.orange).padding(10).frame(maxWidth: .infinity, alignment: .leading) }
            if let provider = session.provider.personalAgentProvider {
                nativeConversation(provider)
            } else if session.connected {
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
        .task { if session.provider.personalAgentProvider != nil { await account.discover() } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if session.provider.personalAgentProvider != nil { session.reload() }
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

    private func nativeConversation(_ provider: PersonalAgentProvider) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(session.fixture ? "Simulated local account · no provider requests" : session.accountStatus.label)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if account.installed.contains(where: { $0.provider == provider }) {
                    Button(session.provider == .chatgpt ? "Sign in with ChatGPT" : "Sign in with Claude") { account.signIn(provider) }
                        .disabled(session.fixture || busy)
                } else {
                    Link("Install \(provider.name)", destination: URL(string: provider == .codex
                         ? "https://developers.openai.com/codex/cli" : "https://code.claude.com/docs/en/setup")!)
                }
            }
            if let error = account.accountError { Text(error).font(.caption).foregroundStyle(.orange) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if session.snapshot.messages.isEmpty {
                            Text("Start a conversation with \(session.provider.name). Your local CLI account is used, and this comparison’s replies are saved in msgblast.")
                                .foregroundStyle(.secondary).padding(.vertical, 20)
                        }
                        ForEach(session.snapshot.messages) { message in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(message.role == "user" ? "You" : session.provider.name).font(.caption.bold()).foregroundStyle(.secondary)
                                Text((try? AttributedString(markdown: message.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(message.text))
                                    .textSelection(.enabled)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(message.role == "user" ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                                .id(message.id)
                        }
                        if session.isSending { ProgressView("\(session.provider.name) is replying…").id("replying") }
                    }
                }.onChange(of: session.snapshot.messages.last?.id) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            if session.isSending { Button("Cancel \(session.provider.name) reply") { session.cancelNativeRequest() } }
            if session.latestComparisonAttempt?.status == .uncertain {
                Text("The last request was incomplete. Continuing may consume provider usage again.").font(.caption).foregroundStyle(.orange)
                Button("Acknowledge incomplete request") { session.acknowledgeIncompleteRequest() }.disabled(busy)
            }
            MessageInput(text: Binding(get: { session.state.draft }, set: { text in session.updateState { $0.draft = text } }),
                attachments: [], addAttachments: { _ in }, removeAttachment: { _ in }, placeholder: "Message \(session.provider.name)",
                accessibilityName: "Message \(session.provider.name)", sendLabel: "Send to \(session.provider.name)",
                disabled: busy || !session.snapshot.ready, attachmentsEnabled: false) {
                    sendNative(session.state.draft)
                }
        }.padding(14)
    }

}

private let museDefaultAvatar = Bundle.main.url(forResource: "MuseAvatar", withExtension: "jpg").flatMap { try? Data(contentsOf: $0) }
private let webDefaultAvatars: [WebProvider: Data] = Dictionary(uniqueKeysWithValues:
    [WebProvider.chatgpt, .claude, .grok].compactMap { provider in
        guard let url = Bundle.main.url(forResource: provider.rawValue, withExtension: provider == .grok ? "png" : "jpg", subdirectory: "WebAgentIcons"),
              let data = try? Data(contentsOf: url) else { return nil }
        return (provider, data)
    }
)
@MainActor
private func webAgent(_ session: WebAgentSession) -> Agent {
    Agent(name: session.provider.name, handles: [], avatar: session.provider == .muse ? session.avatar ?? museDefaultAvatar : webDefaultAvatars[session.provider],
          colorIndex: WebProvider.allCases.firstIndex(of: session.provider)! + 4)
}
