import XCTest
import CryptoKit
@testable import msgblastCore

@MainActor
final class GrokBotTests: XCTestCase {
    func testGrokBotIsASeparateOptionalAgentWithIndependentStorage() throws {
        let provider = try XCTUnwrap(WebProvider(rawValue: "grokbot"))
        XCTAssertEqual(provider.name, "Grok Bot")
        XCTAssertNotEqual(provider, .grok)
        XCTAssertNotEqual(provider.storageFilename, WebProvider.grok.storageFilename)
        XCTAssertFalse(WebProvider.webDefaults.contains(provider))
        XCTAssertNil(provider.personalAgentProvider)
        XCTAssertFalse(provider.isChatURL(URL(string: "https://grok.com/c/example")!))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let agents = WebAgents(directory: directory, fixture: true)
        let session = try XCTUnwrap(agents.sessions.first { $0.provider == provider })
        XCTAssertFalse(session.isEnabled)
        XCTAssertFalse(session.state.selected)
        XCTAssertEqual(agents.selected.map(\.provider), WebProvider.webDefaults)
    }
    func testRequestCarriesComparisonHistoryAndCallbackWithoutWebhookKey() throws {
        let id = UUID(), comparison = UUID(), callback = URL(string: "https://fixture.trycloudflare.com/reply/\(id)")!
        let payload = try GrokBotService.encodeRequest(id: id, comparisonID: comparison, message: "Follow up", history: [WebPageMessage(role: "assistant", text: "Earlier answer")], callbackURL: callback, callbackToken: "per-request-fixture-token")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual(body["request_id"] as? String, id.uuidString.lowercased())
        XCTAssertEqual(body["comparison_id"] as? String, comparison.uuidString.lowercased())
        XCTAssertEqual(body["message"] as? String, "Follow up")
        XCTAssertEqual(body["history"] as? [[String: String]], [["role": "assistant", "text": "Earlier answer"]])
        XCTAssertEqual(body["callback_url"] as? String, callback.absoluteString)
        XCTAssertNil(body["webhook_key"])
        XCTAssertThrowsError(try GrokBotService.encodeRequest(id: id, comparisonID: comparison, message: String(repeating: "x", count: 140_000), history: [], callbackURL: callback, callbackToken: "fixture"))
    }
    func testConnectionAndReceiptsRejectUnsafeOrUnrelatedResults() throws {
        for address in ["http://webhook.example/trigger", "https://user:pass@webhook.example/trigger", "https://webhook.example/#fragment"] {
            XCTAssertThrowsError(try GrokBotCredentials(webhookURL: address, webhookKey: "fixture-webhook-key-000000000000000000000"))
        }
        let id = UUID()
        XCTAssertThrowsError(try GrokBotService.decodeReceipt(Data("{\"request_id\":\"\(UUID())\",\"status\":\"answered\",\"answer\":\"Wrong comparison\"}".utf8), id: id))
        XCTAssertThrowsError(try GrokBotService.decodeReceipt(Data("{\"request_id\":\"\(id)\",\"status\":\"answered\",\"answer\":\"\"}".utf8), id: id))
    }
    func testSubmissionPostsDirectlyToAuthenticatedGrokBotWebhook() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GrokBotFixtureProtocol.self]
        let transport = URLSession(configuration: configuration)
        defer { transport.invalidateAndCancel() }
        let credentials = try GrokBotCredentials(webhookURL: "https://webhook.example/trigger", webhookKey: "fixture-webhook-key-000000000000000000000")
        let id = UUID()
        let body = try GrokBotService.encodeRequest(id: id, comparisonID: UUID(), message: "Transport check", history: [], callbackURL: URL(string: "https://fixture.trycloudflare.com/reply/\(id)")!, callbackToken: "fixture-callback")
        try await GrokBotService.submit(credentials, body: body, session: transport)
    }
    func testRejectedResponsesAreDefiniteButLostResponsesStayUncertain() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GrokBotFixtureProtocol.self]
        let transport = URLSession(configuration: configuration)
        defer { transport.invalidateAndCancel() }
        for code in [401, 403, 404, 429, 500] {
            let credentials = try GrokBotCredentials(webhookURL: "https://webhook.example/status/\(code)", webhookKey: "fixture-webhook-key-000000000000000000000")
            do { try await GrokBotService.submit(credentials, body: Data("{}".utf8), session: transport); XCTFail("Expected rejection") }
            catch let error as GrokBotServiceError { XCTAssertTrue(error.definitelyNotSubmitted, "HTTP \(code) must not be treated as an unknown send") }
        }
        let credentials = try GrokBotCredentials(webhookURL: "https://webhook.example/timeout", webhookKey: "fixture-webhook-key-000000000000000000000")
        do { try await GrokBotService.submit(credentials, body: Data("{}".utf8), session: transport); XCTFail("Expected timeout") }
        catch let error as GrokBotServiceError { XCTAssertFalse(error.definitelyNotSubmitted) }
    }
    func testConnectionLossMarksAnAttemptingRequestUncertainAndKeepsItsDraft() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = WebAgentSession(provider: .grokbot, storageURL: directory.appendingPathComponent("state.json"), fixture: true)
        var attempt = WebSendAttempt(text: "In flight", status: .attempting)
        attempt.comparisonID = UUID()
        session.updateState { $0.attempts = [attempt]; $0.draft = "Keep this draft" }
        session.beginShutdown()
        XCTAssertEqual(session.state.attempts.first?.status, .uncertain)
        XCTAssertEqual(session.state.draft, "Keep this draft")
    }
    func testLocalCallbackRequiresItsRequestTokenAndRecordsDuplicatesOnce() async throws {
        var received: [GrokBotReceipt] = []
        let receiver = GrokBotCallbackReceiver { received.append($0) }
        let address = try await receiver.start()
        defer { receiver.stop() }
        let id = UUID(), token = "fixture-callback-token"
        receiver.register(id: id, tokenHash: Data(SHA256.hash(data: Data(token.utf8))))
        let payload = try JSONEncoder().encode(GrokBotReceipt(request_id: id, status: .answered, answer: "Received on this Mac"))
        func call(_ key: String, body: Data = payload) async throws -> Int {
            var request = URLRequest(url: address.appendingPathComponent("reply/\(id.uuidString.lowercased())"))
            request.httpMethod = "POST"; request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as! HTTPURLResponse).statusCode
        }
        let rejected = try await call("wrong")
        XCTAssertEqual(rejected, 401); XCTAssertTrue(received.isEmpty)
        let accepted = try await call(token)
        XCTAssertEqual(accepted, 200); XCTAssertEqual(received.first?.answer, "Received on this Mac")
        let duplicate = try await call(token)
        XCTAssertEqual(duplicate, 200); XCTAssertEqual(received.count, 1)
        let changed = try await call(token, body: JSONEncoder().encode(GrokBotReceipt(request_id: id, status: .answered, answer: "Changed")))
        XCTAssertEqual(changed, 409); XCTAssertEqual(received.count, 1)
        let oversized = try await call(token, body: Data(repeating: 65, count: 140_000))
        XCTAssertEqual(oversized, 413)
    }
    func testCallbacksStayInTheirComparisonAndRestartDoesNotResend() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let agents = WebAgents(directory: directory, fixture: true)
        agents.setEnabled(true, for: .grokbot)
        let session = try XCTUnwrap(agents.sessions.first { $0.provider == .grokbot })
        let first = UUID(), second = UUID()
        let ready = await session.openComparison(first); XCTAssertTrue(ready)
        let sent = await session.send("First comparison", comparisonID: first)
        XCTAssertEqual(sent?.status, .waiting)
        let duplicate = await session.send("Do not duplicate", comparisonID: first); XCTAssertNil(duplicate)
        session.updateState { $0.comparisonID = second }
        _ = await session.send("Second comparison", comparisonID: second)
        await session.refresh()
        XCTAssertEqual(session.state.localConversations[first.uuidString]?.last?.text, "Grok Bot fixture reply: First comparison")
        XCTAssertEqual(session.snapshot.messages.last?.text, "Grok Bot fixture reply: Second comparison")
        _ = await session.send("Pending at exit", comparisonID: second)
        let restored = WebAgentSession(provider: .grokbot, storageURL: directory.appendingPathComponent(WebProvider.grokbot.storageFilename), fixture: true)
        XCTAssertEqual(restored.state.attempts.first?.status, .uncertain)
        let blocked = await restored.send("No automatic restart resend", comparisonID: second)
        XCTAssertNil(blocked)
        XCTAssertEqual(restored.state.attempts.count, 3)
    }
    func testCallbackRetriesAfterStorageFailureAndDrainsBeforeShutdown() async throws {
        var tries = 0, recorded = 0
        let receiver = GrokBotCallbackReceiver { _ in
            tries += 1
            if tries == 1 { throw GrokBotServiceError.keychain }
            recorded += 1
        }
        receiver.onDrained = { if recorded == 1 { receiver.stop() } }
        let address = try await receiver.start()
        defer { receiver.stop() }
        let id = UUID(), token = "synthetic-retry-token"
        receiver.register(id: id, tokenHash: Data(SHA256.hash(data: Data(token.utf8))))
        var request = URLRequest(url: address.appendingPathComponent("reply/\(id)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(GrokBotReceipt(request_id: id, status: .answered, answer: "Saved on retry"))
        let (_, first) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((first as? HTTPURLResponse)?.statusCode, 503)
        XCTAssertEqual(recorded, 0)
        let (_, second) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((second as? HTTPURLResponse)?.statusCode, 200, "Closing a disabled provider must follow its acknowledgement write")
        XCTAssertEqual(recorded, 1)
    }
}
private final class GrokBotFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "webhook.example" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.host, "webhook.example")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-webhook-key-000000000000000000000")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        if request.url?.path == "/timeout" { client?.urlProtocol(self, didFailWithError: URLError(.timedOut)); return }
        let status = request.url?.path.hasPrefix("/status/") == true ? Int(request.url!.lastPathComponent)! : 200
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"status\":\"queued\"}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
