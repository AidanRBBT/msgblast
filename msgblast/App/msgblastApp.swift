import SwiftUI
import AppKit
import Combine
import msgblastCore
struct msgblastApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle
    @StateObject private var startup = AppStartup()
    private var model: AppModel? { startup.model }
    @StateObject private var updater = AppUpdater()
    private let preferredWindowSize = NSSize(width: 1600, height: 1100)
    private var initialWindowSize: NSSize {
        let screen = NSScreen.main?.visibleFrame.size ?? preferredWindowSize
        return NSSize(width: min(preferredWindowSize.width, screen.width), height: min(preferredWindowSize.height, screen.height))
    }
    var body: some Scene {
        WindowGroup(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "msgblast") {
            Group {
                if startup.needsInstallation { InstallationView() }
                else if let model {
                    MainView(model: model).onAppear { lifecycle.configure(model: model); updater.configure(delegate: lifecycle); if model.coordinator == nil { model.coordinator = WindowCoordinator(model: model) } }
                }
            }.background(InitialWindowFrame(size: preferredWindowSize))
        }.defaultSize(width: initialWindowSize.width, height: initialWindowSize.height).windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(updater.configuration.isEnabled && !updater.canCheckForUpdates)
            }
            CommandGroup(after: .newItem) { Button("Refresh Messages") { model?.refresh() }.keyboardShortcut("r", modifiers: .command).disabled(model == nil) }
            CommandMenu("Comparisons") {
                ForEach(model?.state.comparisons ?? []) { comparison in Button(comparison.title) { model?.coordinator?.open(comparison.id) } }
            }
        }
        Settings {
            if let model { AppSettingsView(model: model, updater: updater) }
            else { InstallationView() }
        }
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

@MainActor
private final class AppStartup: ObservableObject {
    let needsInstallation: Bool
    let model: AppModel?
    private var observation: AnyCancellable?

    init() {
        #if DEBUG
        let development = true
        let preview = ProcessInfo.processInfo.arguments.contains("--installation-preview")
        #else
        let development = false
        let preview = false
        #endif
        needsInstallation = preview || InstallationLocation.needsInstallation(
            bundleURL: Bundle.main.bundleURL,
            homeURL: FileManager.default.homeDirectoryForCurrentUser, development: development)
        model = needsInstallation ? nil : AppModel()
        // Keep comparison menus in sync without constructing the model for an
        // uninstalled copy (its initializer starts Messages history polling).
        observation = model?.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
    }
}

// Apply the launch size once, after SwiftUI restores the window's previous frame.
// Subsequent user resizing is left alone.
private struct InitialWindowFrame: NSViewRepresentable {
    let size: NSSize
    func makeNSView(context: Context) -> InitialWindowSizingView {
        let view = InitialWindowSizingView()
        view.preferredSize = size
        return view
    }
    func updateNSView(_ nsView: InitialWindowSizingView, context: Context) {}
}

private final class InitialWindowSizingView: NSView {
    var preferredSize = NSSize(width: 1600, height: 1100)
    private var applied = false
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, !applied else { return }
        applied = true
        let size = preferredSize
        DispatchQueue.main.async { [weak window] in
            guard let window, let screen = window.screen ?? NSScreen.main else { return }
            let bounds = screen.visibleFrame
            let width = min(size.width, bounds.width), height = min(size.height, bounds.height)
            window.setFrame(NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                                   width: width, height: height), display: true)
        }
    }
}
