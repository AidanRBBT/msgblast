import XCTest
import msgblastCore

final class UpdateTests: XCTestCase {
    private let key = Data(repeating: 7, count: 32).base64EncodedString()
    private func configuration(_ feed: String = "https://updates.example.com/appcast.xml", id: String = "com.msgblast.mac", demo: Bool = false, args: [String] = [], fixture: Bool = false, allowFixture: Bool = false, app: Bool = true) -> UpdateConfiguration {
        UpdateConfiguration(bundleURL: URL(fileURLWithPath: app ? "/Applications/msgblast.app" : "/tmp/msgblast"), bundleIdentifier: id,
            info: ["SUFeedURL": feed, "SUPublicEDKey": key, "msgblastDemo": demo, "msgblastUpdateFixture": fixture, "msgblastFixtureStore": FileManager.default.temporaryDirectory.appendingPathComponent("update-fixture").path], arguments: args, allowLocalFixture: allowFixture)
    }
    func testOnlyConfiguredRealAppsQueryTheProductionFeed() {
        XCTAssertTrue(configuration().isEnabled)
        XCTAssertFalse(configuration("").isEnabled)
        XCTAssertFalse(configuration("http://updates.example.com/appcast.xml").isEnabled)
        XCTAssertFalse(configuration(id: "com.msgblast.discover-preview").isEnabled)
        XCTAssertFalse(configuration(demo: true).isEnabled)
        XCTAssertFalse(configuration(args: ["--demo"]).isEnabled)
        XCTAssertFalse(configuration(app: false).isEnabled)
        let invalidKey = UpdateConfiguration(bundleURL: URL(fileURLWithPath: "/Applications/msgblast.app"), bundleIdentifier: "com.msgblast.mac", info: ["SUFeedURL": "https://updates.example.com/appcast.xml", "SUPublicEDKey": "not a public key"], arguments: [])
        XCTAssertFalse(invalidKey.isEnabled)
    }
    func testLocalFixtureCannotEnableOrdinaryPreviewsOrReleaseBuilds() {
        XCTAssertTrue(configuration("http://127.0.0.1:8000/appcast.xml", id: "com.msgblast.update-fixture", demo: true, fixture: true, allowFixture: true).isEnabled)
        XCTAssertFalse(configuration("http://127.0.0.1:8000/appcast.xml", id: "com.msgblast.update-fixture", demo: true, fixture: true).isEnabled)
        XCTAssertFalse(configuration("http://remote.example.com/appcast.xml", id: "com.msgblast.update-fixture", fixture: true, allowFixture: true).isEnabled)
        XCTAssertFalse(configuration("http://127.0.0.1:8000/appcast.xml", id: "com.msgblast.discover-preview", fixture: true, allowFixture: true).isEnabled)
    }
    func testXCTestHostNeverQueriesTheProductionFeed() {
        let config = UpdateConfiguration(bundleURL: URL(fileURLWithPath: "/Applications/msgblast.app"), bundleIdentifier: "com.msgblast.mac",
            info: ["SUFeedURL": "https://updates.example.com/appcast.xml", "SUPublicEDKey": key], arguments: [], environment: ["XCTestBundlePath": "/tmp/msgblastTests.xctest"])
        XCTAssertFalse(config.isEnabled)
    }
    @MainActor
    func testQuitWaitsForActiveSubmissionThenSavesDraftAndAttachmentReferences() throws {
        let gate = UpdateTermination()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let draft = "Retain this prompt and /private/staged/photo.png"
        let save = { try Data(draft.utf8).write(to: file, options: .atomic) }
        XCTAssertEqual(gate.request(isBusy: true, persist: save), .deferred)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertNil(gate.resume(isBusy: true, persist: save))
        XCTAssertEqual(gate.resume(isBusy: false, persist: save), .allowed)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), draft)
        XCTAssertNil(gate.resume(isBusy: false, persist: save), "A pending quit must only complete once")
    }
    @MainActor
    func testFailedStateSaveCancelsQuitAndKeepsTheAppRunning() {
        let gate = UpdateTermination()
        let failure = { throw NSError(domain: "fixture.storage", code: 1) }
        XCTAssertEqual(gate.request(isBusy: false, persist: failure), .cancelled)
        XCTAssertNotNil(gate.error)
        XCTAssertEqual(gate.request(isBusy: true, persist: failure), .deferred)
        XCTAssertEqual(gate.resume(isBusy: false, persist: failure), .cancelled)
        XCTAssertEqual(gate.request(isBusy: false, persist: {}), .allowed)
        XCTAssertNil(gate.error)
    }
}
