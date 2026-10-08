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
                Text("1. Click Copy Bot setup instructions below and paste them into Grok Bot.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("2. In Grok Bot, click “msgblast” next to “Created routine” to open the routine panel.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("3. Copy “POST to” into Webhook URL and “key” into Webhook key, then choose Connect Grok Bot.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Webhook URL", text: $webhookURL).accessibilityLabel("Grok Bot webhook URL")
                    .disabled(session.configuringGrokBot)
                SecureField("Webhook key", text: $webhookKey).accessibilityLabel("Grok Bot webhook key")
                    .disabled(session.configuringGrokBot)
                Text("The Authorization header is added automatically. Paste only the key.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(session.grokBotConnectionActivity?.title ?? "Connect Grok Bot") {
                        Task {
                            saved = await session.configureGrokBot(webhookURL: webhookURL, webhookKey: webhookKey)
                            if saved { webhookKey = "" }
                        }
                    }.disabled(busy || session.configuringGrokBot || session.hasPendingGrokBotRequests || webhookKey.isEmpty)
                    if saved { Label("Ready to send", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                    else if session.grokBotIsConfigured { Text(session.grokBotRemembersConnection ? "Connection saved" : "Connected for this session").foregroundStyle(.secondary) }
                }
                if let activity = session.grokBotConnectionActivity {
                    Text(activity.detail).font(.caption).foregroundStyle(.secondary)
                }
                if session.grokBotNeedsKeychainRetry {
                    Button("Retry saved connection") {
                        Task {
                            if await session.retryGrokBotSavedConnection() {
                                webhookURL = session.grokBotWebhookURL; webhookKey = ""; saved = false
                            }
                        }
                    }.disabled(busy || session.configuringGrokBot)
                }
                Text(session.grokBotIsConfigured && !session.grokBotRemembersConnection
                     ? "This connection is available for the current session. You may need to enter the webhook key again after quitting. Keep this Mac awake for replies."
                     : "Secure storage is used when available, without a Mac login password prompt. Keep msgblast open and this Mac awake while waiting for replies.")
                    .font(.caption).foregroundStyle(.secondary)
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
        .onChange(of: session.grokBotWebhookURL) { previous, current in
            if !current.isEmpty, webhookURL.isEmpty || webhookURL == previous { webhookURL = current }
        }
    }
}
