import XCTest
import WebKit
@testable import msgblastCore

@MainActor
final class MultiWebAgentTests: XCTestCase {
    func testProviderDestinationsAndFirstConversationTransition() {
        for provider in WebProvider.allCases {
            XCTAssertTrue(provider.isChatURL(provider.newChatURL))
            for invalid in ["https://\(provider.homeURL.host!).evil.test/", "http://\(provider.homeURL.host!)/", "https://\(provider.homeURL.host!)/login", "https://\(provider.homeURL.host!)/settings", "https://\(provider.homeURL.host!):444/", "https://user@\(provider.homeURL.host!)/"] {
                XCTAssertFalse(provider.isChatURL(URL(string: invalid)!), invalid)
            }
        }
        for provider in [WebProvider.chatgpt, .claude, .grok] {
            let path = provider == .claude ? "/chat/abc-123" : "/c/abc-123"
            let conversation = URL(string: path, relativeTo: provider.homeURL)!.absoluteURL
            XCTAssertTrue(provider.acceptsReceipt(from: provider.homeURL, at: conversation))
            XCTAssertFalse(provider.acceptsReceipt(from: conversation, at: provider.homeURL))
            XCTAssertFalse(provider.acceptsReceipt(from: conversation, at: URL(string: path + "different", relativeTo: provider.homeURL)!.absoluteURL))
        }
    }

    func testLegacyMuseSessionSelectionAndPendingReceiptSurviveUpgrade() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID(), comparison = UUID()
        let json = """
        {"sessionID":"\(id)","draft":"Legacy draft","includeMuse":true,"messageRecipients":[],"comparisonID":"\(comparison)","attempts":[]}
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent("web-services.json"))
        let web = WebAgents(directory: directory, fixture: false)
        XCTAssertEqual(web.selected.map(\.provider), [.muse])
        XCTAssertEqual(web.sessions[0].state.sessionID, id)
        XCTAssertEqual(web.sessions[0].state.draft, "Legacy draft")
        XCTAssertEqual(web.comparisonID, comparison)
        XCTAssertEqual(Set(web.sessions.map { $0.state.sessionID }).count, 4)
        for session in web.sessions { XCTAssertEqual(session.webView.configuration.websiteDataStore.identifier, session.state.sessionID) }
        web.toggle(web.sessions[2])
        let reopened = WebAgents(directory: directory, fixture: false)
        XCTAssertEqual(reopened.selected.map(\.provider), [.muse, .claude])
        XCTAssertEqual(reopened.sessions.map { $0.state.sessionID }, web.sessions.map { $0.state.sessionID })
    }

    func testAllProvidersBroadcastAndObserveRepliesWithoutAnAttachedWindow() async throws {
        let web = WebAgents(directory: temporaryDirectory(), fixture: true)
        for session in web.sessions { web.toggle(session) }
        try await waitFor { web.sessions.allSatisfy { $0.snapshot.ready } }
        let results = await WebAgents.send("Compare a morning walk with an afternoon walk.", to: web.selected)
        XCTAssertEqual(results.count, 4)
        for provider in WebProvider.allCases { XCTAssertEqual(results[provider]?.status, .observed, provider.name) }
        try await waitFor { web.sessions.allSatisfy { $0.snapshot.messages.contains { $0.role == "assistant" && $0.text.contains("afternoon walk") } } }
        for session in web.sessions {
            XCTAssertEqual(session.snapshot.messages.filter { $0.role == "user" }.count, 1)
            XCTAssertEqual(session.snapshot.draft, "")
            XCTAssertNil(session.webView.window, "Submission must not depend on window focus")
        }
        let again = await WebAgents.send("Compare a morning walk with an afternoon walk.", to: web.selected)
        for provider in WebProvider.allCases {
            XCTAssertEqual(again[provider]?.status, .observed, provider.name)
            XCTAssertNotEqual(again[provider]?.messageID, results[provider]?.messageID)
        }
    }

    func testDraftOrSignedOutAgentDoesNotBlockIndependentSubmissions() async throws {
        let web = WebAgents(directory: temporaryDirectory(), fixture: true)
        web.sessions.forEach { $0.connect() }
        try await waitFor { web.sessions.allSatisfy { $0.snapshot.ready } }
        let chatgpt = web.sessions[1], claude = web.sessions[2]
        _ = try await chatgpt.webView.callAsyncJavaScript("document.querySelector('textarea').value='Keep this draft'", arguments: [:], in: nil, contentWorld: .page)
        _ = try await claude.webView.callAsyncJavaScript("chat.hidden=true;login.hidden=false", arguments: [:], in: nil, contentWorld: .page)
        let results = await WebAgents.send("New question", to: web.sessions)
        XCTAssertEqual(results[.muse]?.status, .observed)
        XCTAssertEqual(results[.grok]?.status, .observed)
        XCTAssertEqual(results[.chatgpt]?.status, .notSent)
        XCTAssertEqual(results[.claude]?.status, .notSent)
        XCTAssertEqual(chatgpt.snapshot.draft, "Keep this draft")
        XCTAssertFalse(claude.snapshot.ready)
    }

    func testSignedOutEditorsAndAmbiguousSendControlsAreNotSubmitted() async throws {
        for provider in [WebProvider.chatgpt, .claude, .grok] {
            let session = WebAgentSession(provider: provider, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
            session.connect()
            try await waitFor { session.snapshot.ready }
            _ = try await session.webView.callAsyncJavaScript("document.querySelector('button[data-testid]').remove()", arguments: [:], in: nil, contentWorld: .page)
            let signedOut = await session.send("Do not send signed out")
            XCTAssertEqual(signedOut?.status, .notSent, provider.name)
            session.reload()
            try await waitFor { session.snapshot.ready }
            _ = try await session.webView.callAsyncJavaScript("const s=document.querySelector('button[aria-label]');s.after(s.cloneNode(true))", arguments: [:], in: nil, contentWorld: .page)
            let ambiguous = await session.send("One intended recipient")
            XCTAssertEqual(ambiguous?.status, .notSent, provider.name)
            XCTAssertFalse(session.snapshot.messages.contains { $0.role == "user" })
        }
    }

    func testRevealingAnOlderMatchingMessageIsNotANewSendReceipt() async throws {
        let session = WebAgentSession(provider: .chatgpt, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
        session.connect()
        try await waitFor { session.snapshot.ready }
        _ = try await session.webView.callAsyncJavaScript("""
        const old=document.createElement('article');old.hidden=true;old.dataset.messageAuthorRole='user';old.dataset.messageId='earlier-message';old.textContent='Repeated question';document.getElementById('transcript').append(old);
        document.querySelector('button[aria-label]').addEventListener('click',e=>{e.stopImmediatePropagation();old.hidden=false;document.querySelector('textarea').value='';},true);
        """, arguments: [:], in: nil, contentWorld: .page)
        let attempt = await session.send("Repeated question")
        XCTAssertEqual(attempt?.status, .uncertain, "An earlier matching message becoming visible does not confirm a new submission")
        let retry = await session.send("Repeated question")
        XCTAssertNil(retry)
    }

    func testPrependingHistoryDoesNotChangeAnOlderMessageIntoAReceipt() async throws {
        let session = WebAgentSession(provider: .claude, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
        session.connect()
        try await waitFor { session.snapshot.ready }
        _ = try await session.webView.callAsyncJavaScript("""
        const old=document.createElement('article');old.dataset.testid='user-message';old.textContent='Repeated question';document.getElementById('transcript').append(old);
        document.querySelector('button[aria-label]').addEventListener('click',e=>{e.stopImmediatePropagation();const history=document.createElement('article');history.dataset.testid='assistant-message';history.textContent='Earlier history loaded';old.before(history);document.querySelector('[contenteditable]').textContent='';},true);
        """, arguments: [:], in: nil, contentWorld: .page)
        let attempt = await session.send("Repeated question")
        XCTAssertEqual(attempt?.status, .uncertain, "History insertion must not make an old role/index identity look new")
    }

    func testEditingThePageDuringSubmissionCannotConfirmAnotherConversation() async throws {
        let session = WebAgentSession(provider: .claude, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
        session.connect()
        try await waitFor { session.snapshot.ready }
        _ = try await session.webView.callAsyncJavaScript("""
        document.querySelector('button[aria-label]').addEventListener('click',e=>{e.stopImmediatePropagation();
        const input=document.querySelector('[contenteditable]');input.focus();document.execCommand('insertText',false,' Changed draft');
        history.replaceState(null,'','/chat/older-conversation');
        const old=document.createElement('article');old.dataset.testid='user-message';old.textContent='Repeated question';document.getElementById('transcript').append(old);},true);
        """, arguments: [:], in: nil, contentWorld: .page)
        let attempt = await session.send("Repeated question")
        XCTAssertEqual(attempt?.status, .uncertain, "A browser edit during submission invalidates receipt attribution across conversations")
        XCTAssertTrue(session.snapshot.draft.contains("Changed draft"))
    }

    func testAnExistingSidebarConversationCannotConfirmANewChatSend() async throws {
        let session = WebAgentSession(provider: .chatgpt, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
        session.connect()
        try await waitFor { session.snapshot.ready }
        _ = try await session.webView.callAsyncJavaScript("""
        const link=document.createElement('a');link.href='/c/older-conversation';link.textContent='Earlier conversation';document.body.append(link);
        document.querySelector('button[aria-label]').addEventListener('click',e=>{e.stopImmediatePropagation();
        history.replaceState(null,'',link.href);document.querySelector('textarea').value='';
        const old=document.createElement('article');old.dataset.messageAuthorRole='user';old.dataset.messageId='older-message';old.textContent='Repeated question';document.getElementById('transcript').append(old);},true);
        """, arguments: [:], in: nil, contentWorld: .page)
        let attempt = await session.send("Repeated question")
        XCTAssertEqual(attempt?.status, .uncertain, "A known pre-existing conversation cannot be the new-chat receipt")
    }

    func testMultilinePromptMatchesRenderedParagraphs() async throws {
        for provider in [WebProvider.chatgpt, .claude, .grok] {
            let session = WebAgentSession(provider: provider, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
            session.connect()
            try await waitFor { session.snapshot.ready }
            // Model a site's rendered paragraph markup after its normal Send handler.
            _ = try await session.webView.callAsyncJavaScript("""
            document.querySelector('button[aria-label]').addEventListener('click',()=>{
                document.querySelector('#transcript article').innerHTML='<p>First line</p><p>Second line<br>Third line</p>';
            });
            """, arguments: [:], in: nil, contentWorld: .page)
            let attempt = await session.send("First line\nSecond line\nThird line")
            XCTAssertEqual(attempt?.status, .observed, provider.name)
        }
    }

    private func temporaryDirectory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("MsgBlast-MultiWeb-\(UUID())") }
    private func waitFor(_ predicate: () -> Bool) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("WebKit did not reach expected state")
        throw NSError(domain: "WebAgentTests", code: 1)
    }
}
