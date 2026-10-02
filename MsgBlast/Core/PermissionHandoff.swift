import AppKit

public struct HistoryAccessHandoff: Equatable, Sendable {
    public enum Stage: Sendable { case idle, openingSettings, guiding, waitingForAccess, verified }
    public private(set) var stage: Stage = .idle
    public init() {}
    public var isActive: Bool { [.openingSettings, .guiding, .waitingForAccess].contains(stage) }
    public mutating func begin() { stage = .openingSettings }
    public mutating func showGuide() { if stage == .openingSettings { stage = .guiding } }
    public mutating func finishDrag(dropped: Bool) { if stage == .guiding, dropped { stage = .waitingForAccess } }
    public mutating func observeHistory(available: Bool) {
        if available { stage = .verified }
        else if stage == .verified { stage = .idle }
    }
    public mutating func cancel() { stage = .idle }
}

public enum PermissionGuideGeometry {
    public static func appKitFrame(_ frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }
    public static func dockedFrame(settings: CGRect, visibleFrame: CGRect) -> CGRect {
        let size = CGSize(width: min(360, visibleFrame.width - 24), height: 112)
        return CGRect(x: min(max(settings.maxX - size.width - 12, visibleFrame.minX + 12), visibleFrame.maxX - size.width - 12),
                      y: min(max(settings.minY + 12, visibleFrame.minY + 12), visibleFrame.maxY - size.height - 12),
                      width: size.width, height: size.height)
    }
}

public enum AppBundleDragPayload {
    public static func writer(for url: URL) -> NSURL? {
        var directory: ObjCBool = false
        guard url.isFileURL, url.pathExtension.lowercased() == "app",
              FileManager.default.fileExists(atPath: url.path, isDirectory: &directory), directory.boolValue else { return nil }
        return url as NSURL
    }
}
