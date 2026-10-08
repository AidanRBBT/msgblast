import Foundation
import msgblastCore
struct LocalStore: Sendable {
    let url: URL
    init(demo: Bool, isolated: Bool = false, fixtureDirectory: URL? = nil, supportDirectoryName: String? = nil, webPreview: Bool = false) {
        let folder = SupportDirectory.folderName(demo: demo, override: supportDirectoryName, webPreview: webPreview, bundleIdentifier: Bundle.main.bundleIdentifier)
        let root = fixtureDirectory ?? (demo && isolated && !webPreview
            ? FileManager.default.temporaryDirectory.appendingPathComponent("msgblast-UIFixture-" + UUID().uuidString, isDirectory: true)
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(folder, isDirectory: true))
        url = root.appendingPathComponent("state.json")
    }
    func load() throws -> AppState {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppState() }
        let bytes = try Data(contentsOf: url)
        var state = try JSONDecoder().decode(AppState.self, from: bytes)
        let needsMigration = state.comparisons.contains { ($0.webProviderIdentityVersion ?? 1) < 2 }
        try WebProviderStateMigration.migrateComparisons(in: &state, directory: url.deletingLastPathComponent())
        if needsMigration { try WebProviderStateMigration.preserveOriginal(bytes, at: url) }
        return state.recoveringInFlight()
    }
    func save(_ state: AppState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    // Keep a stable copy for saved drafts and partial-send retries, rather than a temporary picker URL.
    func stage(_ source: URL) throws -> MessageAttachment {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey])
        guard values.isRegularFile == true else { throw AppFailure.blocked("Choose a file rather than a folder.") }
        let id = UUID().uuidString
        let directory = url.deletingLastPathComponent().appendingPathComponent("Attachments/" + id, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch { try? FileManager.default.removeItem(at: directory); throw error }
        return MessageAttachment(id: id, filename: source.lastPathComponent, path: destination.path, mimeType: values.contentType?.preferredMIMEType, byteCount: values.fileSize.map(Int64.init))
    }
    func stage(_ data: Data, filename: String) throws -> MessageAttachment {
        let id = UUID().uuidString
        let directory = url.deletingLastPathComponent().appendingPathComponent("Attachments/" + id, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let destination = directory.appendingPathComponent(filename)
        do {
            try data.write(to: destination, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch { try? FileManager.default.removeItem(at: directory); throw error }
        let mime = try destination.resourceValues(forKeys: [.contentTypeKey]).contentType?.preferredMIMEType
        return MessageAttachment(id: id, filename: filename, path: destination.path, mimeType: mime, byteCount: Int64(data.count))
    }
    func removeUnreferenced(_ file: MessageAttachment, in state: AppState) {
        var references = state.attachmentsDraft ?? []
        for comparison in state.comparisons {
            references += comparison.attachments ?? []
            references += comparison.sharedContext?.flatMap(\.attachments) ?? []
            references += comparison.allAttachmentsDraft ?? []
            references += comparison.privateAttachmentDrafts?.values.flatMap { $0 } ?? []
            references += comparison.members.compactMap(\.payload).flatMap(\.parts).compactMap(\.attachment)
            for followUp in comparison.followUps {
                references += followUp.payloads?.values.flatMap(\.parts).compactMap(\.attachment) ?? []
            }
        }
        guard !references.contains(where: { $0.id == file.id }) else { return }
        let owned = url.deletingLastPathComponent().appendingPathComponent("Attachments/" + file.id, isDirectory: true)
        guard file.url.deletingLastPathComponent().standardizedFileURL == owned.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: owned)
    }
}
