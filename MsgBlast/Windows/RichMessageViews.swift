import SwiftUI
import AppKit
@preconcurrency import LinkPresentation
import MsgBlastCore

enum MessageAppearance {
    static let incomingBubbleColor = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(srgbRed: 59 / 255, green: 59 / 255, blue: 61 / 255, alpha: 1)
        }
        return NSColor(srgbRed: 233 / 255, green: 233 / 255, blue: 235 / 255, alpha: 1)
    })
}

@MainActor
final class LinkPreviewStore: ObservableObject {
    @Published private(set) var metadata: [URL: LPLinkMetadata] = [:]
    private var requested: Set<URL> = []

    func load(_ url: URL) async {
        guard requested.insert(url).inserted else { return }
        let provider = LPMetadataProvider()
        provider.timeout = 15
        do { metadata[url] = try await provider.startFetchingMetadata(for: url) }
        catch {
            // A link remains usable when the website cannot provide a preview.
            let fallback = LPLinkMetadata()
            fallback.originalURL = url; fallback.url = url; fallback.title = url.host
            metadata[url] = fallback
        }
    }
}

struct NativeLinkPreview: NSViewRepresentable {
    let url: URL
    let metadata: LPLinkMetadata?
    func makeNSView(context: Context) -> LPLinkView { LPLinkView(url: url) }
    func updateNSView(_ view: LPLinkView, context: Context) {
        if let metadata, view.metadata != metadata { view.metadata = metadata }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: LPLinkView, context: Context) -> CGSize? {
        let width = min(proposal.width ?? 320, 320)
        let size = view.intrinsicContentSize
        let height = size.width > 0 && size.height > 0 ? size.height * min(1, width / size.width) : 80
        return CGSize(width: width, height: max(60, height))
    }
}

struct RichLinkView: View {
    @ObservedObject var store: LinkPreviewStore
    let url: URL
    var body: some View {
        NativeLinkPreview(url: url, metadata: store.metadata[url])
            .fixedSize(horizontal: false, vertical: true)
            .task(id: url) { await store.load(url) }
    }
}

struct ReactionBadge: View {
    let reactions: [MessageReaction]
    var body: some View {
        HStack(spacing: -4) {
            ForEach(reactions) { reaction in
                Text(reaction.emoji).font(.system(size: 18))
                    .frame(width: 32, height: 32)
                    .background(MessageAppearance.incomingBubbleColor, in: Circle())
                    .overlay(Circle().stroke(Color(nsColor: .textBackgroundColor), lineWidth: 2))
                    .accessibilityLabel("\(reaction.outgoing ? "You" : "Recipient") reacted \(reaction.emoji)")
            }
        }
        .background(alignment: .bottomLeading) {
            Circle().fill(MessageAppearance.incomingBubbleColor).frame(width: 8, height: 8).offset(x: 0, y: 5)
            Circle().fill(MessageAppearance.incomingBubbleColor).frame(width: 4, height: 4).offset(x: -4, y: 11)
        }
    }
}
