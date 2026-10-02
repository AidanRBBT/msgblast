import SwiftUI
import AppKit
@main
struct MsgBlastApp: App {
    @NSApplicationDelegateAdaptor(SummaryTerminationDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("MsgBlast") {
            MainView(model: model).onAppear {
                appDelegate.personalAgent = model.personalAgent
                if model.coordinator == nil { model.coordinator = WindowCoordinator(model: model) }
            }
        }.defaultSize(width: 920, height: 660).windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { checkForUpdates() }
            }
            CommandGroup(after: .newItem) { Button("Refresh Messages") { model.refresh() }.keyboardShortcut("r", modifiers: .command) }
            CommandMenu("Comparisons") {
                ForEach(model.state.comparisons) { comparison in Button(comparison.title) { model.coordinator?.open(comparison.id) } }
            }
        }
        Settings { AppSettingsView(model: model) }
    }

    private func checkForUpdates() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let alert = NSAlert()
        alert.messageText = "Updates aren’t configured"
        alert.informativeText = "This development build doesn’t have an update service yet.\n\nCurrent version: \(version) (\(build))."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

@MainActor
final class SummaryTerminationDelegate: NSObject, NSApplicationDelegate {
    var personalAgent: PersonalAgentController?
    private var terminating = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let personalAgent, !personalAgent.running.isEmpty else { return .terminateNow }
        if !terminating {
            terminating = true
            Task {
                await personalAgent.cancelAndWait()
                sender.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }
}
