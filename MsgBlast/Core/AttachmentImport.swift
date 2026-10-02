import AppKit

public enum AttachmentImport: Sendable {
    case files([URL])
    case image(Data, filename: String)

    @MainActor public static func read(from pasteboard: NSPasteboard) -> Self? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty { return .files(urls) }
        for (type, ext) in [(NSPasteboard.PasteboardType.png, "png"), (.tiff, "tiff")] {
            if let data = pasteboard.data(forType: type) { return .image(data, filename: "Image-\(UUID().uuidString).\(ext)") }
        }
        return nil
    }
}
