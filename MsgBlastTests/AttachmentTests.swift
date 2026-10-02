import XCTest
import AppKit
@testable import MsgBlastCore

final class AttachmentTests: XCTestCase {
    func testTransportCopiesRecipientsIntoSeparatePrivateDirectories() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("MsgBlast-transport-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        let source = temporary.appendingPathComponent("report with \"quotes\".txt")
        let bytes = Data("Controlled attachment bytes".utf8)
        try bytes.write(to: source)
        let root = temporary.appendingPathComponent("outgoing", isDirectory: true)
        let attachment = MessageAttachment(filename: "../../metadata-is-not-a-path.txt", path: source.path)
        let first = try MessagesAttachmentStaging.stage(attachment, in: root)
        let second = try MessagesAttachmentStaging.stage(attachment, in: root)
        XCTAssertNotEqual(first.deletingLastPathComponent(), second.deletingLastPathComponent())
        for copy in [first, second] {
            XCTAssertEqual(copy.lastPathComponent, source.lastPathComponent)
            XCTAssertEqual(copy.deletingLastPathComponent().deletingLastPathComponent(), root.resolvingSymlinksInPath())
            XCTAssertEqual(try Data(contentsOf: copy), bytes)
            XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: copy.path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
            XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: copy.deletingLastPathComponent().path)[.posixPermissions] as? NSNumber)?.intValue, 0o700)
        }
        XCTAssertEqual(try Data(contentsOf: source), bytes, "Handoff must preserve the saved draft")
    }
    func testTransportRejectsSymlinkRootAndSource() throws {
        let files = FileManager.default
        let temporary = files.temporaryDirectory.appendingPathComponent("MsgBlast-transport-links-" + UUID().uuidString)
        defer { try? files.removeItem(at: temporary) }
        let outside = temporary.appendingPathComponent("outside", isDirectory: true)
        try files.createDirectory(at: outside, withIntermediateDirectories: true)
        let source = temporary.appendingPathComponent("source.txt")
        try Data("Controlled fixture".utf8).write(to: source)
        let linkedRoot = temporary.appendingPathComponent("linked-root")
        try files.createSymbolicLink(at: linkedRoot, withDestinationURL: outside)
        XCTAssertThrowsError(try MessagesAttachmentStaging.stage(MessageAttachment(filename: "source.txt", path: source.path), in: linkedRoot))
        XCTAssertTrue(try files.contentsOfDirectory(atPath: outside.path).isEmpty)
        let linkedSource = temporary.appendingPathComponent("linked-source.txt")
        try files.createSymbolicLink(at: linkedSource, withDestinationURL: source)
        let root = temporary.appendingPathComponent("regular-root", isDirectory: true)
        XCTAssertThrowsError(try MessagesAttachmentStaging.stage(MessageAttachment(filename: "linked-source.txt", path: linkedSource.path), in: root))
        XCTAssertTrue(try files.contentsOfDirectory(atPath: root.path).isEmpty)
    }
    @MainActor func testNativeEditorAcceptsImagePasteAndKeepsPlainTextEditable() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let view = AttachmentTextView()
        XCTAssertTrue(view.readablePasteboardTypes.contains(.png))
        var importedImage = false
        view.importAttachment = { selection in
            if case .image = selection { importedImage = true }
        }
        pasteboard.setData(Data([1, 2, 3]), forType: .png)
        XCTAssertTrue(view.readSelection(from: pasteboard, type: .png))
        XCTAssertTrue(importedImage)
        XCTAssertEqual(view.string, "")
        pasteboard.clearContents(); pasteboard.setString("plain text", forType: .string)
        XCTAssertTrue(view.readSelection(from: pasteboard, type: .string))
        XCTAssertEqual(view.string, "plain text")
    }
    @MainActor func testNativePasteDistinguishesFilesAndImagesFromPlainText() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let url = URL(fileURLWithPath: "/tmp/sample.txt")
        pasteboard.writeObjects([url as NSURL])
        guard case .files(let urls) = AttachmentImport.read(from: pasteboard) else { return XCTFail("A copied file must become an attachment.") }
        XCTAssertEqual(urls, [url])
        pasteboard.clearContents(); pasteboard.setString("ordinary typing", forType: .string)
        XCTAssertNil(AttachmentImport.read(from: pasteboard))
        pasteboard.clearContents(); pasteboard.setData(Data([1, 2, 3]), forType: .png)
        guard case .image(let bytes, let filename) = AttachmentImport.read(from: pasteboard) else { return XCTFail("A pasted image must become an attachment.") }
        XCTAssertEqual(bytes, Data([1, 2, 3])); XCTAssertTrue(filename.hasSuffix(".png"))
    }
    func testSavedAttachmentDraftsAndInterruptedReceiptsRecoverTogether() throws {
        let file = MessageAttachment(filename: "photo.png", path: "/tmp/photo.png")
        var state = AppState()
        var member = Member(agentID: UUID(), name: "Agent", chat: Chat(id: "A", handle: "agent@example.com", lastActivity: 0))
        var payload = OutgoingPayload(text: "", attachments: [file])
        payload.parts[0].state = .sending
        member.apply(payload)
        var comparison = Comparison(prompt: "", members: [member])
        comparison.attachments = [file]
        comparison.privateAttachmentDrafts = [member.id.uuidString: [file]]
        state.comparisons = [comparison]; state.attachmentsDraft = [file]
        let restored = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state)).recoveringInFlight()
        XCTAssertEqual(restored.attachmentsDraft, [file])
        XCTAssertEqual(restored.comparisons[0].privateAttachmentDrafts?[member.id.uuidString], [file])
        XCTAssertEqual(restored.comparisons[0].title, "photo.png")
        XCTAssertEqual(restored.comparisons[0].members[0].submission, .uncertain)
        XCTAssertNotNil(restored.comparisons[0].members[0].error)
        XCTAssertTrue(restored.comparisons[0].members[0].payload!.pendingIndices.isEmpty)
    }
    func testPartialAttachmentSendSurvivesRestartWithoutRetryingAcceptedParts() throws {
        let file = MessageAttachment(id: "file", filename: "report.pdf", path: "/tmp/report.pdf", byteCount: 100)
        var payload = OutgoingPayload(text: "Read this", attachments: [file, file])
        payload.parts[0].state = .submitted
        payload.parts[1].state = .failed
        payload.parts[2].state = .sending
        let restored = try JSONDecoder().decode(OutgoingPayload.self, from: JSONEncoder().encode(payload)).recoveringInFlight()
        XCTAssertEqual(restored.pendingIndices, [1])
        XCTAssertEqual(restored.parts[2].state, .uncertain)
        XCTAssertEqual(restored.submission, .uncertain)
        XCTAssertEqual(restored.parts[0].state, .submitted)
    }
    func testAttachmentAnchorUsesMetadataAndRequiresUniqueOutgoingRecord() {
        let file = MessageAttachment(id: "staged", filename: "report.pdf", path: "/tmp/report.pdf", byteCount: 100)
        var part = OutgoingPart(attachment: file)
        part.baseline = 10; part.attemptedAt = Date()
        let incoming = Message(id: 11, guid: "incoming", chatID: "A", text: "", outgoing: false, attachments: [file])
        let sent = Message(id: 12, guid: "sent", chatID: "A", text: "", outgoing: true, attachments: [file])
        XCTAssertEqual(part.anchorCandidate(in: [incoming, sent])?.guid, "sent")
        var duplicate = sent; duplicate.id = 13; duplicate.guid = "duplicate"
        XCTAssertNil(part.anchorCandidate(in: [sent, duplicate]))
        XCTAssertNil(part.anchorCandidate(in: [sent], before: 12))
    }
}
