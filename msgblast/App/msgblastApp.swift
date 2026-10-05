import SwiftUI
import AppKit
struct msgblastApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle
    @StateObject private var model = AppModel()
    @StateObject private var updater = AppUpdater()
    var body: some Scene {
        WindowGroup("msgblast") {
            MainView(model: model).onAppear { lifecycle.configure(model: model); updater.configure(delegate: lifecycle); if model.coordinator == nil { model.coordinator = WindowCoordinator(model: model) } }
        }.defaultSize(width: 920, height: 660).windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(updater.configuration.isEnabled && !updater.canCheckForUpdates)
            }
            CommandGroup(after: .newItem) { Button("Refresh Messages") { model.refresh() }.keyboardShortcut("r", modifiers: .command) }
            CommandMenu("Comparisons") {
                ForEach(model.state.comparisons) { comparison in Button(comparison.title) { model.coordinator?.open(comparison.id) } }
            }
        }
        Settings { AppSettingsView(model: model, updater: updater) }
    }

}

@main
enum msgblastMain {
    @MainActor static func main() {
        #if DEBUG
        if UpdateProbe.isLocalFixture {
            if ProcessInfo.processInfo.arguments.contains("--update-probe") { UpdateProbe.run() }
            if Bundle.main.object(forInfoDictionaryKey: "msgblastUpdateProbeRelaunch") as? Bool == true { UpdateProbe.verifyRelaunch() }
        }
        #endif
        msgblastApp.main()
    }
}
