import Foundation

/// A quit request remains pending while a submission is active. Saving succeeds before the app exits.
@MainActor
public final class UpdateTermination {
    public enum Decision: Equatable { case allowed, deferred, cancelled }
    public private(set) var error: String?
    private var waiting = false
    public init() {}

    public func request(isBusy: Bool, persist: () throws -> Void) -> Decision {
        if isBusy { waiting = true; return .deferred }
        waiting = false
        do { try persist(); error = nil; return .allowed }
        catch { self.error = "Could not save your drafts before quitting: \(error.localizedDescription)"; return .cancelled }
    }
    public func resume(isBusy: Bool, persist: () throws -> Void) -> Decision? {
        guard waiting, !isBusy else { return nil }
        return request(isBusy: false, persist: persist)
    }
}

/// Preserve both disk state and new in-memory drafts when the normal store is blocked.
/// Recovery is deliberately separate: a failed decode must never replace saved history.
public enum QuitStateRecovery {
    @discardableResult
    public static func preserve(_ state: AppState, originalURL: URL) throws -> URL {
        let files = FileManager.default
        let root = originalURL.deletingLastPathComponent().appendingPathComponent("Recovery", isDirectory: true)
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try files.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        func write(_ data: Data, name: String) throws -> URL {
            let url = directory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return url
        }
        let snapshot = try write(JSONEncoder().encode(state), name: "drafts-state.json")
        let original: Data?
        do {
            original = try Data(contentsOf: originalURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            original = nil
        } catch {
            // The original remains untouched even when its bytes are inaccessible.
            _ = try write(Data(error.localizedDescription.utf8), name: "original-read-error.txt")
            original = nil
        }
        if let original { _ = try write(original, name: "original-state.json") }
        return snapshot
    }
}
