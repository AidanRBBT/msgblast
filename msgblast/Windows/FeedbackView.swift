import AppKit
import SwiftUI
import UniformTypeIdentifiers
import msgblastCore

@MainActor
final class FeedbackSession: ObservableObject {
    @Published var kind: DiagnosticReportKind = .feedback
    @Published var note = ""
    @Published var contact = ""
    @Published var includeDiagnostics = false
    @Published var message: String?
    let facts: DiagnosticFacts
    weak var window: NSWindow?
    private var temporaryDirectories: [URL] = []

    init(facts: DiagnosticFacts) { self.facts = facts }

    var canExport: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && contactIsAcceptable
    }

    var contactIsAcceptable: Bool {
        let trimmed = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || DiagnosticReport.isValidContact(trimmed)
    }

    var saveTitle: String { includeDiagnostics ? "Save Report with Diagnostics…" : "Save Report…" }
    var shareTitle: String { includeDiagnostics ? "Share Report with Diagnostics…" : "Share Report…" }
    var diagnosticsPreview: String { DiagnosticReport.diagnosticsJSON(facts) }

    func save() {
        guard let package = makePackage() else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = package.suggestedFilename
        panel.title = saveTitle
        panel.message = package.includeDiagnostics
            ? "The ZIP includes the note you wrote and the diagnostic report shown in this window."
            : "The ZIP includes the note you wrote. A diagnostic report is not included."
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        do {
            try DiagnosticArchive.write(package.archive, to: url)
            message = "Saved \(url.lastPathComponent). msgblast did not upload it."
        } catch {
            message = error.localizedDescription
        }
    }

    func share() {
        guard let package = makePackage(), let view = window?.contentView else { return }
        do {
            let url = try DiagnosticArchive.writeTemporary(package)
            temporaryDirectories.append(url.deletingLastPathComponent())
            let picker = NSSharingServicePicker(items: [url])
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            message = "Choose where to send \(url.lastPathComponent). msgblast does not upload it."
        } catch {
            message = error.localizedDescription
        }
    }

    func cleanup() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
    }

    private func makePackage() -> DiagnosticPackage? {
        do {
            let package = try DiagnosticReport.make(DiagnosticRequest(
                kind: kind, note: note, contact: contact, includeDiagnostics: includeDiagnostics, facts: facts))
            message = nil
            return package
        } catch {
            message = error.localizedDescription
            return nil
        }
    }
}

@MainActor
final class FeedbackWindowController: NSObject, NSWindowDelegate {
    static var current: FeedbackWindowController?
    let session: FeedbackSession
    private var hostedWindow: NSWindow?

    static func show(model: AppModel?, updater: AppUpdater) {
        if let current, let window = current.hostedWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = FeedbackWindowController(model: model, updater: updater)
        current = controller
        controller.hostedWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    init(model: AppModel?, updater: AppUpdater) {
        session = FeedbackSession(facts: FeedbackFacts.capture(model: model, updater: updater))
        super.init()
        let host = NSHostingController(rootView: FeedbackView(session: session))
        let window = NSWindow(contentViewController: host)
        window.title = "Send Feedback"
        window.setContentSize(NSSize(width: 560, height: 680))
        window.minSize = NSSize(width: 480, height: 520)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        session.window = window
        hostedWindow = window
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.session.cleanup()
            self.hostedWindow?.delegate = nil
            self.hostedWindow = nil
            if FeedbackWindowController.current === self { FeedbackWindowController.current = nil }
        }
    }
}

struct FeedbackView: View {
    @ObservedObject var session: FeedbackSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("msgblast does not upload this report.")
                .font(.headline)
            Text("Save or share it yourself. Write only what you want a person to read. Leave out message transcripts, phone numbers, and files.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker("Kind", selection: $session.kind) {
                ForEach(DiagnosticReportKind.allCases, id: \.rawValue) { kind in
                    Text(kind.label).tag(kind)
                }
            }.pickerStyle(.segmented)
            Text("Feedback note").font(.headline)
            TextEditor(text: $session.note)
                .font(.body)
                .frame(minHeight: 120)
                .accessibilityLabel("Feedback note")
            TextField("Reply email, optional", text: $session.contact)
                .accessibilityLabel("Reply email, optional")
            if !session.contactIsAcceptable {
                Text("Leave the reply address blank or enter an email address.")
                    .font(.caption).foregroundStyle(.orange)
            }
            Toggle("Include a diagnostic report", isOn: $session.includeDiagnostics)
            Text(DiagnosticReport.excludedTopics.map { "• \($0)" }.joined(separator: "\n"))
                .font(.caption).foregroundStyle(.secondary)
            if session.includeDiagnostics {
                Text("This is the entire diagnostic file.")
                    .font(.headline)
                ScrollView {
                    Text(session.diagnosticsPreview)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("Diagnostic preview")
                        .accessibilityLabel("Diagnostic preview")
                        .accessibilityValue(session.diagnosticsPreview)
                }
                .frame(minHeight: 140, maxHeight: 220)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text("A diagnostic report is not included.")
                    .font(.callout)
            }
            if let message = session.message {
                Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button(session.shareTitle) { session.share() }
                    .disabled(!session.canExport)
                Button(session.saveTitle) { session.save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!session.canExport)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
