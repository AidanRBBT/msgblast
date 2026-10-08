import SwiftUI
import msgblastCore

struct UpdateSidebar: View {
    @ObservedObject var updater: AppUpdater

    var body: some View {
        if let update = updater.pendingUpdate {
            Button { updater.checkForUpdates() } label: {
                HStack(spacing: 10) {
                    Image(systemName: update.isReady ? "arrow.triangle.2.circlepath" : "arrow.down.circle")
                        .font(.title3).foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(update.isReady ? "Ready to relaunch" : "Update available").font(.headline)
                        Text("Version \(update.version)").font(.caption).foregroundStyle(.secondary)
                        Text(update.isReady ? "Relaunch to update…" : "View update…")
                            .font(.caption).foregroundStyle(Color.accentColor)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!updater.canCheckForUpdates && !update.isReady)
            .accessibilityLabel(update.isReady ? "Relaunch to update" : "Update available")
            .accessibilityValue("Version \(update.version)")
        }
    }
}

struct WhatsNewSidebar: View {
    @AppStorage("lastViewedReleaseVersion") private var lastViewedVersion = ""
    @State private var showingHistory = false
    private static let bundledHistory = ReleaseHistory(
        directory: Bundle.main.resourceURL?.appendingPathComponent("release-notes"),
        installedVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
    private var history: ReleaseHistory { Self.bundledHistory }

    private var unread: Bool { history.current != nil && lastViewedVersion != history.installedVersion }

    var body: some View {
        Button {
            showingHistory = true
            if history.current != nil { lastViewedVersion = history.installedVersion }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").font(.title3).foregroundStyle(unread ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("What’s New").font(.headline)
                    Text("Version \(history.installedVersion) · \(unread ? "New changes" : "Release history")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if unread { Circle().fill(Color.accentColor).frame(width: 7, height: 7).accessibilityHidden(true) }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(unread ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("What’s New")
        .accessibilityValue(unread ? "New changes in version \(history.installedVersion)" : "Release history viewed")
        .sheet(isPresented: $showingHistory) { ReleaseHistoryView(history: history) }
    }
}

private struct ReleaseHistoryView: View {
    let history: ReleaseHistory
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVersion: String?
    @State private var showingFullNotes = false

    private var selected: ReleaseHistory.Entry? {
        history.entries.first { $0.version == selectedVersion } ?? history.current ?? history.entries.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What’s New in \(selected?.version ?? history.installedVersion)").font(.title2.bold())
                    Text("Installed version \(history.installedVersion)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(20)
            Divider()
            if history.entries.isEmpty {
                ContentUnavailableView("Release notes unavailable", systemImage: "doc.text", description: Text("This build doesn’t include a release history."))
            } else {
                HStack(spacing: 0) {
                    List(history.entries, selection: $selectedVersion) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.version).fontWeight(.semibold)
                            if entry.version == history.installedVersion {
                                Text("Installed").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4).tag(entry.version)
                    }.frame(width: 145)
                    Divider()
                    ScrollView {
                        if let selected {
                            VStack(alignment: .leading, spacing: 20) {
                                ReleaseNotesText(notes: showingFullNotes || selected.highlights.isEmpty ? selected.notes : compactNotes(selected))
                                if !selected.highlights.isEmpty {
                                    Button(showingFullNotes ? "Show highlights" : "Full release notes") { showingFullNotes.toggle() }
                                        .buttonStyle(.link)
                                }
                            }
                                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.id(selected?.version)
                }
            }
        }
        .frame(width: 740, height: 540)
        .onAppear { selectedVersion = selected?.version }
        .onChange(of: selectedVersion) { _, _ in showingFullNotes = false }
    }
    private func compactNotes(_ entry: ReleaseHistory.Entry) -> String {
        let highlights = entry.highlights.map { "- \($0)" }.joined(separator: "\n")
        let credits = entry.contributors.isEmpty ? "" : "\n\n## Contributors\n\(entry.contributors)"
        return "# msgblast \(entry.version)\n\n\(highlights)\(credits)"
    }
}

private struct ReleaseNotesText: View {
    let notes: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(notes.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("#") {
                    Text(String(line.drop(while: { $0 == "#" || $0 == " " })))
                        .font(line.hasPrefix("# ") ? .title2.bold() : .headline)
                        .padding(.top, line.hasPrefix("# ") ? 0 : 8)
                } else if line.hasPrefix("- ") {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").accessibilityHidden(true)
                        markdown(String(line.dropFirst(2)))
                    }
                } else if !line.isEmpty {
                    markdown(line)
                }
            }
        }.textSelection(.enabled)
    }
    private func markdown(_ text: String) -> Text {
        Text((try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
    }
}
