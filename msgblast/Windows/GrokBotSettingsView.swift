import SwiftUI
import AppKit
import msgblastCore

struct GrokBotSettingsView: View {
    @ObservedObject var session: WebAgentSession
    let busy: Bool
    @State private var webhookURL = ""
    @State private var webhookKey = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable Grok Bot", isOn: Binding(get: { session.isEnabled }, set: { session.setEnabled($0); if $0 { session.connect() } }))
                .toggleStyle(.switch).disabled(busy || session.configuringGrokBot)
            Text("Send directly to your Bot's webhook. Replies return to this Mac through an app-managed temporary tunnel.")
                .font(.caption).foregroundStyle(.secondary)
            if session.fixture {
                Label("Demo connection · webhook and replies are simulated", systemImage: "testtube.2")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                TextField("Webhook URL", text: $webhookURL).accessibilityLabel("Grok Bot webhook URL")
                SecureField("Webhook key", text: $webhookKey).accessibilityLabel("Grok Bot webhook key")
                HStack {
                    Button(session.configuringGrokBot ? "Connecting…" : "Connect Grok Bot") {
                        Task {
                            saved = await session.configureGrokBot(webhookURL: webhookURL, webhookKey: webhookKey)
                            if saved { webhookKey = "" }
                        }
                    }.disabled(busy || session.configuringGrokBot || session.hasPendingGrokBotRequests || webhookKey.isEmpty)
                    if saved { Label("Ready to send", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                    else if session.grokBotIsConfigured { Text("Connection saved").foregroundStyle(.secondary) }
                }
                Text("The webhook key is stored in macOS Keychain. Keep msgblast open and this Mac awake while waiting for replies.").font(.caption).foregroundStyle(.secondary)
                if session.hasPendingGrokBotRequests {
                    Text("Wait for pending replies before changing this connection.").font(.caption).foregroundStyle(.secondary)
                }
                if let error = session.error { Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
            }
            Button("Copy Bot setup instructions") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(GrokBotService.routineInstructions, forType: .string)
            }.disabled(session.fixture)
        }
        .onAppear { webhookURL = session.grokBotWebhookURL }
    }
}
