import XCTest
import AppKit
@testable import MsgBlastCore

final class PermissionHandoffTests: XCTestCase {
    func testDropDoesNotClaimHistoryAccessAndCancellationCanRetry() {
        var flow = HistoryAccessHandoff()
        flow.begin(); flow.showGuide(); flow.finishDrag(dropped: true)
        XCTAssertEqual(flow.stage, .waitingForAccess)
        flow.observeHistory(available: false)
        XCTAssertEqual(flow.stage, .waitingForAccess)
        flow.cancel()
        XCTAssertEqual(flow.stage, .idle)
        flow.begin(); flow.showGuide(); flow.finishDrag(dropped: false)
        XCTAssertEqual(flow.stage, .guiding)
        flow.observeHistory(available: true)
        XCTAssertEqual(flow.stage, .verified)
        XCTAssertFalse(flow.isActive)
        flow.observeHistory(available: false)
        XCTAssertEqual(flow.stage, .idle)
    }
    func testGuideStaysVisibleAsSettingsMovesAcrossDisplays() {
        let screen = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        for settings in [CGRect(x: -1050, y: 100, width: 700, height: 650), CGRect(x: -250, y: -40, width: 700, height: 650)] {
            let guide = PermissionGuideGeometry.dockedFrame(settings: settings, visibleFrame: screen)
            XCTAssertTrue(screen.contains(guide))
            XCTAssertGreaterThanOrEqual(guide.width, 300)
        }
        XCTAssertEqual(PermissionGuideGeometry.appKitFrame(CGRect(x: -800, y: 150, width: 700, height: 650), primaryHeight: 1000), CGRect(x: -800, y: 200, width: 700, height: 650))
    }
    @MainActor
    func testDragTransfersTheRealAppURLAndRejectsImagesAndExecutables() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let app = root.appendingPathComponent("MsgBlast.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let writer = try XCTUnwrap(AppBundleDragPayload.writer(for: app))
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(pasteboard.writeObjects([writer]))
        XCTAssertEqual(NSURL(from: pasteboard)?.absoluteURL, app)
        XCTAssertNil(AppBundleDragPayload.writer(for: root.appendingPathComponent("icon.png")))
        XCTAssertNil(AppBundleDragPayload.writer(for: URL(string: "https://example.com/MsgBlast.app")!))
        XCTAssertNil(AppBundleDragPayload.writer(for: root.appendingPathComponent("Missing.app")))
    }
}
