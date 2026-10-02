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
