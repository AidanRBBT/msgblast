import XCTest
import WebKit
@testable import msgblastCore

@MainActor
final class MultiWebAgentTests: XCTestCase {
    func testNewProvidersAttachReceiptsToTheirComparison() async throws {
        for provider in [WebProvider.chatgpt, .claude, .grok] {
            let session = WebAgentSession(provider: provider, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
            session.connect()
            try await waitFor { session.snapshot.ready }
            let id = UUID()
            let attempt = await session.send("A dedicated conversation", comparisonID: id)
            XCTAssertEqual(attempt?.status, .observed, provider.name)
            XCTAssertEqual(attempt?.comparisonID, id, provider.name)
            XCTAssertEqual(session.state.comparisonID, id, provider.name)
        }
    }

    func testEachProviderKeepsSeparateSavedChatsAcrossComparisonsAndReopening() async throws {
        for provider in WebProvider.allCases {
            let directory = temporaryDirectory(), firstID = UUID(), secondID = UUID()
            let storage = directory.appendingPathComponent("state.json")
            let session = WebAgentSession(provider: provider, storageURL: storage, fixture: true)
            session.connect()
            try await waitFor { session.snapshot.ready }
            let first = await session.send("First question", comparisonID: firstID)
            XCTAssertEqual(first?.status, .observed, provider.name)
            let firstURL = try XCTUnwrap(first?.conversationURL)
            XCTAssertTrue(provider.isSavedConversation(firstURL))
            try await waitFor { session.snapshot.messages.contains { $0.role == "assistant" } }
            let second = await session.send("Second question", comparisonID: secondID)
            XCTAssertEqual(second?.status, .observed, provider.name)
            XCTAssertNotEqual(second?.conversationURL, firstURL, provider.name)
            XCTAssertEqual(session.snapshot.messages.filter { $0.role == "user" }.map(\.text), ["Second question"])
            try await waitFor { session.snapshot.messages.contains { $0.role == "assistant" } }
            await session.openComparison(firstID)
            XCTAssertEqual(session.webView.url, firstURL)
            XCTAssertEqual(session.latestComparisonAttempt?.id, first?.id)
            let followup = await session.send("Follow up", comparisonID: firstID)
            XCTAssertEqual(followup?.status, .observed)
            XCTAssertEqual(followup?.conversationURL, firstURL)
            XCTAssertEqual(session.snapshot.messages.filter { $0.role == "user" }.map(\.text), ["First question", "Follow up"])
            let restored = WebAgentSession(provider: provider, storageURL: storage, fixture: true)
            XCTAssertEqual(restored.state.sessionID, session.state.sessionID)
            XCTAssertEqual(restored.state.conversationURLs[firstID.uuidString], firstURL)
            XCTAssertEqual(restored.state.conversationURLs[secondID.uuidString], second?.conversationURL)
            restored.connect()
            try await waitFor { restored.snapshot.ready }
            XCTAssertEqual(restored.webView.url, firstURL, "The saved destination must survive a new session instance")
        }
    }

    func testContenteditableFollowUpRestoresTheEditingSelection() async throws {
        let session = WebAgentSession(provider: .claude, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
        let id = UUID()
        session.connect()
        try await waitFor { session.snapshot.ready }
        let first = await session.send("First question", comparisonID: id)
        XCTAssertEqual(first?.status, .observed)
        try await waitFor { session.snapshot.messages.contains { $0.role == "assistant" } }
        _ = try await session.webView.callAsyncJavaScript("document.querySelector('[contenteditable]').focus(); window.getSelection().removeAllRanges()", arguments: [:], in: nil, contentWorld: .page)
        let followup = await session.send("Follow-up after composing elsewhere", comparisonID: id)
        XCTAssertEqual(followup?.status, .observed)
        XCTAssertEqual(followup?.conversationURL, first?.conversationURL)
        XCTAssertEqual(session.snapshot.messages.filter { $0.role == "user" }.map(\.text), ["First question", "Follow-up after composing elsewhere"])
    }

    func testLegacyMuseSavedChatMigratesWithoutChangingTheLoginStore() throws {
        let sessionID = UUID(), comparisonID = UUID()
        let url = "https://muse.ai/thread/11111111-2222-3333-4444-555555555555"
        let json = """
        {"sessionID":"\(sessionID)","includeMuse":true,"comparisonID":"\(comparisonID)","museConversations":{"\(comparisonID.uuidString)":"\(url)"}}
        """
        let migrated = try JSONDecoder().decode(WebWorkspaceState.self, from: Data(json.utf8))
        XCTAssertEqual(migrated.sessionID, sessionID)
        XCTAssertTrue(migrated.selected)
        XCTAssertEqual(migrated.conversationURLs[comparisonID.uuidString]?.absoluteString, url)
        let roundTrip = try JSONDecoder().decode(WebWorkspaceState.self, from: JSONEncoder().encode(migrated))
        XCTAssertEqual(roundTrip.conversationURLs, migrated.conversationURLs)
    }

    func testEveryProviderRequiresSavedURLAndBlocksUnconfirmedFollowUps() async throws {
        for provider in [WebProvider.chatgpt, .claude, .grok] {
            let session = WebAgentSession(provider: provider, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
            session.connect()
            try await waitFor { session.snapshot.ready }
            _ = try await session.webView.callAsyncJavaScript("history.replaceState = () => {}", arguments: [:], in: nil, contentWorld: .page)
            let id = UUID()
            let first = await session.send("No saved conversation yet", comparisonID: id)
            XCTAssertEqual(first?.status, .uncertain, provider.name)
            XCTAssertNil(session.state.conversationURLs[id.uuidString])
            let followup = await session.send("Different follow-up", comparisonID: id)
            XCTAssertEqual(followup?.status, .notSent)
            XCTAssertEqual(session.snapshot.messages.filter { $0.role == "user" }.count, 1)
            XCTAssertFalse(provider.acceptsReceipt(from: provider.newChatURL, at: provider.newChatURL))
        }
    }

    func testComparisonSelectionSynchronizesEveryProviderIncludingDeselectedOnes() {
        let directory = temporaryDirectory()
        let web = WebAgents(directory: directory, fixture: true), id = UUID()
        web.setComparison(id)
        XCTAssertTrue(web.sessions.allSatisfy { $0.state.comparisonID == id })
        let restored = WebAgents(directory: directory, fixture: true)
        XCTAssertTrue(restored.sessions.allSatisfy { $0.state.comparisonID == id })
        restored.setComparison(nil)
        XCTAssertTrue(restored.sessions.allSatisfy { $0.state.comparisonID == nil && $0.latestComparisonAttempt == nil })
    }

    func testProviderDestinationsAndFirstConversationTransition() {
        for provider in WebProvider.allCases {
            XCTAssertTrue(provider.isChatURL(provider.newChatURL))
            XCTAssertFalse(provider.isSavedConversation(provider.newChatURL))
            XCTAssertFalse(provider.isSavedConversation(URL(string: "https://\(provider.homeURL.host!)")!))
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

    func testNewAgentsStartSelectedAndRememberDeselectionAfterRelaunch() {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let web = WebAgents(directory: directory, fixture: true)
        XCTAssertEqual(web.selected.map(\.provider), WebProvider.allCases)
        web.toggle(web.sessions[3])
        let restored = WebAgents(directory: directory, fixture: true)
        XCTAssertEqual(restored.selected.map(\.provider), [.muse, .chatgpt, .claude])
        XCTAssertEqual(restored.sessions.map { $0.state.sessionID }, web.sessions.map { $0.state.sessionID })
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
        XCTAssertEqual(web.selected.map(\.provider), WebProvider.allCases)
        XCTAssertEqual(web.sessions[0].state.sessionID, id)
        XCTAssertEqual(web.sessions[0].state.draft, "Legacy draft")
        XCTAssertEqual(web.comparisonID, comparison)
        XCTAssertEqual(Set(web.sessions.map { $0.state.sessionID }).count, 4)
        for session in web.sessions { XCTAssertEqual(session.webView.configuration.websiteDataStore.identifier, session.state.sessionID) }
        web.toggle(web.sessions[2])
        let reopened = WebAgents(directory: directory, fixture: false)
        XCTAssertEqual(reopened.selected.map(\.provider), [.muse, .chatgpt, .grok])
        XCTAssertEqual(reopened.sessions.map { $0.state.sessionID }, web.sessions.map { $0.state.sessionID })
    }

    func testAllProvidersBroadcastAndObserveRepliesWithoutAnAttachedWindow() async throws {
        let web = WebAgents(directory: temporaryDirectory(), fixture: true)
        web.connectSelected()
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
        try await bindExistingFixtureChat(session)
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
        try await bindExistingFixtureChat(session)
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

    private func bindExistingFixtureChat(_ session: WebAgentSession) async throws {
        let id = UUID(), path = session.provider == .claude ? "/chat/existing-fixture" : "/c/existing-fixture"
        let url = URL(string: path, relativeTo: session.provider.homeURL)!.absoluteURL
        _ = try await session.webView.callAsyncJavaScript("history.replaceState({},'',url)", arguments: ["url":url.absoluteString], in: nil, contentWorld: .page)
        session.updateState { $0.comparisonID = id; $0.conversationURLs[id.uuidString] = url }
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
