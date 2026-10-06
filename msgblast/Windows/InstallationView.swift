import SwiftUI
import AppKit

struct InstallationView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "msgblast"
    }
    private var bundleFile: String { Bundle.main.bundleURL.lastPathComponent }

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable().frame(width: 64, height: 64)
            Text("Move \(appName) to Applications")
                .font(.system(size: 24, weight: .semibold))
            Text("You’re opening the downloaded copy. Install \(bundleFile) before setting up Messages access. Leave an existing msgblast.app where it is.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            VStack(alignment: .leading, spacing: 12) {
                Text("1. Quit this copy of \(appName).")
                Text("2. Drag **\(bundleFile)** to **Applications**.")
                Text("3. Open \(bundleFile) from Applications.")
            }.padding(.vertical, 8)
            HStack(spacing: 12) {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }
                Button("Quit \(appName)") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 500, minHeight: 420)
    }
}
