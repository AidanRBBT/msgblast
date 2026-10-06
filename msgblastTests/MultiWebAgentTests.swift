import XCTest
import WebKit
@testable import msgblastCore

@MainActor
final class MultiWebAgentTests: XCTestCase {
    func testRecoveredReadinessClearsOnlyTransientComparisonSetupWarnings() async throws {
        for provider in [WebProvider.muse, .claude] {
            let session = WebAgentSession(provider: provider, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
            session.connect()
            try await waitFor { session.snapshot.ready }
            let blocking = provider == .muse
                ? "document.getElementById('hatch-chat-scroll').hidden=true"
                : "const dialog=document.createElement('div');dialog.id='loading-dialog';dialog.setAttribute('role','dialog');dialog.textContent='Loading';document.body.append(dialog)"
            _ = try await session.webView.callAsyncJavaScript(blocking, arguments: [:], in: nil, contentWorld: .page)
            let opened = await session.openComparison(UUID())
            XCTAssertFalse(opened)
            XCTAssertNotNil(session.error)
            let recovery = provider == .muse
                ? "document.getElementById('hatch-chat-scroll').hidden=false"
                : "document.getElementById('loading-dialog').remove()"
            _ = try await session.webView.callAsyncJavaScript(recovery, arguments: [:], in: nil, contentWorld: .page)
            await session.refresh()
            XCTAssertTrue(session.snapshot.ready)
            XCTAssertNil(session.error, "A recovered page must not retain its temporary setup warning")
            XCTAssertTrue(session.state.attempts.isEmpty, "Recovery never sends automatically")

            // An unrelated draft-protection error is not a transient readiness warning.
            _ = try await session.webView.callAsyncJavaScript("const input=document.querySelector('textarea,[contenteditable]');if(input.tagName==='TEXTAREA')input.value='Keep draft';else input.textContent='Keep draft'", arguments: [:], in: nil, contentWorld: .page)
            _ = await session.openComparison(UUID())
            let draftError = try XCTUnwrap(session.error)
            XCTAssertTrue(draftError.contains("has a draft"))
            _ = try await session.webView.callAsyncJavaScript("const input=document.querySelector('textarea,[contenteditable]');if(input.tagName==='TEXTAREA')input.value='';else input.textContent=''", arguments: [:], in: nil, contentWorld: .page)
            await session.refresh()
            XCTAssertTrue(session.snapshot.ready)
            XCTAssertEqual(session.error, draftError)
        }
    }

    // Control structures observed in the signed-in narrow panes on 2026-10-05.
    // No account data or provider network calls are used by these fixtures.
    func testSignedInNarrowLayoutsCanSendWithHiddenAccountControlsAndRichEditors() async throws {
        for provider in WebProvider.allCases {
            let session = WebAgentSession(provider: provider, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
            session.connect()
            try await waitFor { session.snapshot.ready }
            var html = WebPageScript(provider: provider).fixture
            func replace(_ source: String, with replacement: String) {
                XCTAssertTrue(html.contains(source), "\(provider.name) fixture changed; update the observed layout variant")
                html = html.replacingOccurrences(of: source, with: replacement)
            }
            switch provider {
            case .muse:
                replace(#"<div id="hatch-chat-scroll" aria-label="Chat messages">"#,
                    with: #"<div id="hatch-chat-scroll"><div aria-label="Chat messages" role="log"></div>"#)
            case .chatgpt:
                replace(#"<button data-testid="accounts-profile-button">"#,
                    with: #"<button aria-label="Open profile menu" style="display:none">"#)
                replace(#"<textarea aria-label="Chat with ChatGPT"></textarea>"#,
                    with: #"<div class="ProseMirror" contenteditable="true" role="textbox" aria-label="Ask ChatGPT"></div>"#)
                replace(#"aria-label="Send message""#, with: #"aria-label="Send""#)
            case .claude:
                replace(#"<button data-testid="user-menu-button">"#,
                    with: #"<button data-testid="user-menu-button" style="display:none">"#)
            case .grok:
                replace(#"<button data-testid="user-menu-button">Fixture account</button>"#,
                    with: #"<button aria-haspopup="menu"><img alt="pfp"></button>"#)
                replace(#"<textarea aria-label="Ask Grok anything"></textarea>"#,
                    with: #"<div class="tiptap ProseMirror" contenteditable="true" role="textbox" aria-label="Ask Grok anything"></div>"#)
            }
            session.webView.loadHTMLString(html, baseURL: provider.newChatURL)
            try await waitFor { !session.webView.isLoading }
            let result = try await session.webView.callAsyncJavaScript(WebPageScript(provider: provider).inspect, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String: Any]
            XCTAssertEqual(result?["ready"] as? Bool, true, "\(provider.name): \(result?["reason"] ?? "missing snapshot")")
            guard result?["ready"] as? Bool == true else { continue }
            let attempt = await session.send("Narrow layout comparison", comparisonID: UUID())
            XCTAssertEqual(attempt?.status, .observed, provider.name)
            XCTAssertTrue(provider.isSavedConversation(try XCTUnwrap(attempt?.conversationURL)))
            XCTAssertEqual(session.snapshot.messages.filter { $0.role == "user" }.map(\.text), ["Narrow layout comparison"])

            // Retained hidden account markup must not override a visible sign-in page.
            _ = try await session.webView.callAsyncJavaScript("const login=document.createElement('button');login.textContent='Log in';document.body.append(login)", arguments: [:], in: nil, contentWorld: .page)
            if provider != .muse {
                let signedOut = try await session.webView.callAsyncJavaScript(WebPageScript(provider: provider).inspect, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String: Any]
                XCTAssertEqual(signedOut?["ready"] as? Bool, false, provider.name)
            }
        }
    }

    func testChatGPTSearchMessageMarkupConfirmsSendsAndFollowups() async throws {
        let session = WebAgentSession(provider: .chatgpt, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
        session.connect()
        try await waitFor { session.snapshot.ready }
        var html = WebPageScript(provider: .chatgpt).fixture
        let oldAttributes = "a.dataset.messageAuthorRole=role;a.dataset.messageId=crypto.randomUUID();"
        XCTAssertTrue(html.contains(oldAttributes))
        html = html.replacingOccurrences(of: oldAttributes, with: "const id=crypto.randomUUID();a.dataset.chatgptSearchUnitKey='fallback-turn-0:0:'+role;a.dataset.chatgptSearchMessageIds=role==='assistant'?id+' '+id:id;")
        let oldContent = "a.textContent=text;document.getElementById('transcript').append(a);"
        XCTAssertTrue(html.contains(oldContent))
        html = html.replacingOccurrences(of: oldContent, with: """
        const content=document.createElement('div');content.dataset.contentSearchUnitKey=a.dataset.chatgptSearchUnitKey;content.textContent=text;a.append(content);
        if(role==='assistant'){const heading=document.createElement('h4');heading.dataset.conversationRole='assistant';heading.textContent='ChatGPT said:';a.prepend(heading);}
        const action=document.createElement('button');action.textContent='Copy';a.append(action);document.getElementById('transcript').append(a);
        """)
        session.webView.loadHTMLString(html, baseURL: WebProvider.chatgpt.newChatURL)
        try await waitFor { !session.webView.isLoading }
        let comparison = UUID(), prompt = "A message with\ntwo lines"
        let first = await session.send(prompt, comparisonID: comparison)
        XCTAssertEqual(first?.status, .observed)
        guard first?.status == .observed else { return }
        let url = try XCTUnwrap(first?.conversationURL)
        try await waitFor { session.snapshot.messages.contains { $0.role == "assistant" } }
        XCTAssertEqual(session.snapshot.messages.map(\.role), ["user", "assistant"])
        XCTAssertEqual(session.snapshot.messages.map(\.text), ["A message with two lines", "ChatGPT fixture reply: A message with two lines"])
        XCTAssertEqual(Set(session.snapshot.messages.map(\.id)).count, 2)
        // Repeating the same prompt must identify a new message, not reuse the old receipt.
        let second = await session.send(prompt, comparisonID: comparison)
        XCTAssertEqual(second?.status, .observed)
        XCTAssertEqual(second?.conversationURL, url)
        XCTAssertNotEqual(second?.messageID, first?.messageID)
        XCTAssertEqual(session.snapshot.messages.filter { $0.role == "user" }.count, 2)
        // Search units aggregating different messages cannot identify a unique user send.
        _ = try await session.webView.callAsyncJavaScript("""
        const unit=document.querySelector('[data-chatgpt-search-message-ids]');
        unit.setAttribute('data-chatgpt-search-message-ids','first-id second-id');
        """, arguments: [:], in: nil, contentWorld: .page)
        await session.refresh()
        XCTAssertEqual(session.snapshot.messages.first?.role, "unknown")
    }

    func testChatGPTInitialSidebarLayoutPreservesLaterUserChoice() async throws {
        for sidebar in [
            #"<button id="sidebar" aria-label="Toggle sidebar" aria-expanded="true">Sidebar</button>"#,
            #"<div role="dialog"><button id="sidebar" aria-label="Close sidebar" aria-expanded="true">Sidebar</button></div>"#,
            #"<button id="sidebar" aria-label="Hide sidebar" aria-expanded="true">Sidebar</button>"#
        ] {
            let session = WebAgentSession(provider: .chatgpt, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
            let html = WebPageScript(provider: .chatgpt).fixture.replacingOccurrences(of: "<main id=\"chat\">", with: """
            \(sidebar)<script>document.querySelector('#sidebar').onclick=function(){this.setAttribute('aria-expanded',this.getAttribute('aria-expanded')==='true'?'false':'true');window.sidebarClicks=(window.sidebarClicks||0)+1;};</script><main id="chat">
            """)
            session.webView.loadHTMLString(html, baseURL: WebProvider.chatgpt.homeURL)
            try await waitFor { !session.webView.isLoading }
            let script = WebPageScript(provider: .chatgpt).configureInitialLayout
            _ = try await session.webView.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .defaultClient)
            let closed = try await session.webView.callAsyncJavaScript("return document.querySelector('#sidebar').getAttribute('aria-expanded')", arguments: [:], in: nil, contentWorld: .page) as? String
            XCTAssertEqual(closed, "false")
            // Simulate the user choosing to reopen after the initial layout was applied.
            _ = try await session.webView.callAsyncJavaScript("document.querySelector('#sidebar').click()", arguments: [:], in: nil, contentWorld: .page)
            _ = try await session.webView.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .defaultClient)
            let clicks = try await session.webView.callAsyncJavaScript("return window.sidebarClicks", arguments: [:], in: nil, contentWorld: .page) as? Int
            XCTAssertEqual(clicks, 2)
        }
    }

    func testInitialSidebarLayoutDoesNotToggleCollapsedAmbiguousOrOtherProviderControls() async throws {
        for (provider, controls) in [
            (WebProvider.chatgpt, #"<button aria-label="Show sidebar">Sidebar</button>"#),
            (.chatgpt, #"<button aria-label="Toggle sidebar" aria-expanded="false">Sidebar</button>"#),
            (.chatgpt, #"<button aria-label="Toggle sidebar" aria-expanded="true">One</button><button aria-label="Toggle sidebar" aria-expanded="true">Two</button>"#),
            (.chatgpt, #"<button aria-label="Toggle sidebar" aria-expanded="true" disabled>Sidebar</button>"#),
            (.chatgpt, #"<button aria-label="Close sidebar" aria-expanded="true">Sidebar</button><div role="dialog">Unrelated dialog</div>"#),
            (.claude, #"<button aria-label="Toggle sidebar" aria-expanded="true">Sidebar</button>"#)
        ] {
            let session = WebAgentSession(provider: provider, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
            let html = WebPageScript(provider: provider).fixture.replacingOccurrences(of: "<main id=\"chat\">", with: controls + "<main id=\"chat\">")
            session.webView.loadHTMLString(html, baseURL: provider.newChatURL)
            try await waitFor { !session.webView.isLoading }
            _ = try await session.webView.callAsyncJavaScript("window.sidebarClicks=0;document.querySelectorAll('button[aria-label*=sidebar]').forEach(b=>b.onclick=()=>window.sidebarClicks++)", arguments: [:], in: nil, contentWorld: .page)
            _ = try await session.webView.callAsyncJavaScript(WebPageScript(provider: provider).configureInitialLayout, arguments: [:], in: nil, contentWorld: .defaultClient)
            let clicks = try await session.webView.callAsyncJavaScript("return window.sidebarClicks", arguments: [:], in: nil, contentWorld: .page) as? Int
            XCTAssertEqual(clicks, 0, "\(provider): \(controls)")
        }
    }

    func testLiveBrowserSupportsInternalFramesWithoutNavigationWarnings() async throws {
        for provider in [WebProvider.claude, .grok] {
            let session = WebAgentSession(provider: provider, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: false)
            session.webView.loadHTMLString("""
            <body data-test="navigation"><iframe id="blank" src="about:blank"></iframe>
            <script>
            window.frameReady = [];
            window.addEventListener('message', event => {
                if (['data-frame', 'blob-frame'].includes(event.data)) window.frameReady.push(event.data);
            });
            for (const kind of ['data', 'blob']) {
                const payload = '<script>parent.postMessage("' + kind + '-frame", "*")<' + '/script>';
                const frame = document.createElement('iframe');
                frame.src = kind === 'data' ? 'data:text/html,' + encodeURIComponent(payload)
                    : URL.createObjectURL(new Blob([payload], {type: 'text/html'}));
                document.body.append(frame);
            }
            </script></body>
            """, baseURL: provider.homeURL)
            try await waitFor { session.error != nil || (!session.webView.isLoading && session.webView.url != nil) }
            XCTAssertNil(session.error, provider.name)
            guard session.error == nil else { continue }
            let result = try await session.webView.callAsyncJavaScript("""
            for (let i = 0; i < 40 && window.frameReady.length < 2; i++)
                await new Promise(resolve => setTimeout(resolve, 50));
            return {blank: document.querySelector('#blank').contentDocument.URL, ready: window.frameReady.sort()};
            """, arguments: [:], in: nil, contentWorld: .page) as? [String: Any]
            XCTAssertEqual(result?["blank"] as? String, "about:blank")
            XCTAssertEqual(result?["ready"] as? [String], ["blob-frame", "data-frame"])
            XCTAssertNil(session.error)
        }
    }

    func testBlockedAutomaticFrameDoesNotInterruptTheParentPage() async throws {
        let session = WebAgentSession(provider: .grok, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: false)
        session.webView.loadHTMLString("<body>Parent stays usable<iframe src='msgblast-test-blocked://child'></iframe></body>", baseURL: WebProvider.grok.homeURL)
        try await waitFor { !session.webView.isLoading && session.webView.url != nil }
        XCTAssertNil(session.error)
        let text = try await session.webView.callAsyncJavaScript("return document.body.textContent", arguments: [:], in: nil, contentWorld: .page) as? String
        XCTAssertEqual(text, "Parent stays usable")
    }

    func testSuccessfulPageLoadClearsOnlyNavigationErrors() async throws {
        let session = WebAgentSession(provider: .claude, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: false)
        session.webView(session.webView, didFailProvisionalNavigation: nil, withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
        XCTAssertNotNil(session.error)
        session.webView.loadHTMLString("<body>Recovered</body>", baseURL: WebProvider.claude.homeURL)
        try await waitFor { !session.webView.isLoading && session.webView.url != nil }
        XCTAssertNil(session.error)
        let brokenStorage = temporaryDirectory()
        try FileManager.default.createDirectory(at: brokenStorage, withIntermediateDirectories: true)
        let blocked = WebAgentSession(provider: .claude, storageURL: brokenStorage, fixture: false)
        let storageError = blocked.error
        XCTAssertNotNil(storageError)
        blocked.webView(blocked.webView, didFailProvisionalNavigation: nil, withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
        XCTAssertEqual(blocked.error, storageError)
        blocked.webView.loadHTMLString("<body>Storage remains blocked</body>", baseURL: WebProvider.claude.homeURL)
        try await waitFor { !blocked.webView.isLoading && blocked.webView.url != nil }
        XCTAssertEqual(blocked.error, storageError)
    }

    func testLiveBrowserKeepsBlankLoginPopupInTheSameSession() async throws {
        let session = WebAgentSession(provider: .claude, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: false)
        session.webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        session.webView.loadHTMLString("<body>Local login popup test</body>", baseURL: WebProvider.claude.homeURL)
        try await waitFor { session.error != nil || (!session.webView.isLoading && session.webView.url != nil) }
        XCTAssertNil(session.error)
        guard session.error == nil else { return }
        _ = try await session.webView.callAsyncJavaScript("window.open('about:blank','login')", arguments: [:], in: nil, contentWorld: .page)
        try await waitFor { session.popup != nil }
        XCTAssertTrue(session.popup?.configuration.websiteDataStore === session.webView.configuration.websiteDataStore)
        XCTAssertNil(session.error)
        session.closePopup()
    }

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

    func testGrokFollowUpWaitsForSubmitToBecomeEnabledAndClicksOnce() async throws {
        let session = WebAgentSession(provider: .grok, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
        let html = WebPageScript(provider: .grok).fixture.replacingOccurrences(of: #"<textarea aria-label="Ask Grok anything"></textarea>"#,
            with: #"<div contenteditable="true" role="textbox" aria-label="Ask Grok anything"></div>"#)
        session.connect()
        try await waitFor { session.snapshot.ready }
        session.webView.loadHTMLString(html, baseURL: WebProvider.grok.newChatURL)
        try await waitFor { !session.webView.isLoading }
        let comparison = UUID()
        let first = await session.send("First question", comparisonID: comparison)
        XCTAssertEqual(first?.status, .observed)
        guard first?.status == .observed else { return }
        try await waitFor { session.snapshot.messages.contains { $0.role == "assistant" } }
        _ = try await session.webView.callAsyncJavaScript("""
        window.submitClicks=0;
        send.addEventListener('click',()=>window.submitClicks++);
        input.addEventListener('input',()=>{send.disabled=true;history.replaceState({},'',location.pathname+'?rid=11111111-2222-4333-8444-555555555555');setTimeout(()=>send.disabled=false,600)});
        """, arguments: [:], in: nil, contentWorld: .page)
        let followup = await session.send("Delayed follow-up", comparisonID: comparison)
        XCTAssertEqual(followup?.status, .observed)
        XCTAssertEqual(followup?.conversationURL, first?.conversationURL)
        let clicks = try await session.webView.callAsyncJavaScript("return window.submitClicks", arguments: [:], in: nil, contentWorld: .page) as? Int
        XCTAssertEqual(clicks, 1)
        XCTAssertEqual(session.snapshot.messages.filter { $0.role == "user" }.map(\.text), ["First question", "Delayed follow-up"])
    }

    func testUnavailableSubmitTimesOutWithoutClickingAndKeepsTheDraft() async throws {
        let session = WebAgentSession(provider: .grok, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
        session.connect()
        try await waitFor { session.snapshot.ready }
        try await bindExistingFixtureChat(session)
        _ = try await session.webView.callAsyncJavaScript("""
        window.submitClicks=0;
        send.addEventListener('click',()=>window.submitClicks++);
        input.addEventListener('input',()=>send.disabled=true);
        """, arguments: [:], in: nil, contentWorld: .page)
        let attempt = await session.send("Keep this unsent draft")
        XCTAssertEqual(attempt?.status, .notSent)
        XCTAssertTrue(attempt?.detail?.contains("Send control is unavailable") == true)
        XCTAssertEqual(session.snapshot.draft, "Keep this unsent draft")
        let clicks = try await session.webView.callAsyncJavaScript("return window.submitClicks", arguments: [:], in: nil, contentWorld: .page) as? Int
        XCTAssertEqual(clicks, 0)
        XCTAssertTrue(session.snapshot.messages.isEmpty)
    }

    func testWaitingForSubmitNeverSendsAfterDraftOrConversationChanges() async throws {
        for change in [
            "input.value='Keep my changed draft'",
            "history.replaceState({},'', '/c/different-conversation')",
            "send.after(send.cloneNode(true))",
            "input.focus();input.select();document.execCommand('insertText',false,'Edited then restored');input.value='Do not send after a change'"
        ] {
            let session = WebAgentSession(provider: .grok, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
            session.connect()
            try await waitFor { session.snapshot.ready }
            try await bindExistingFixtureChat(session)
            _ = try await session.webView.callAsyncJavaScript("""
            window.submitClicks=0;
            send.addEventListener('click',()=>window.submitClicks++);
            input.addEventListener('input',()=>{send.disabled=true;setTimeout(()=>{\(change);send.disabled=false},600)},{once:true});
            """, arguments: [:], in: nil, contentWorld: .page)
            let attempt = await session.send("Do not send after a change")
            XCTAssertEqual(attempt?.status, .notSent)
            let clicks = try await session.webView.callAsyncJavaScript("return window.submitClicks", arguments: [:], in: nil, contentWorld: .page) as? Int
            XCTAssertEqual(clicks, 0)
            XCTAssertTrue(session.snapshot.messages.isEmpty)
        }
    }

    func testNavigationWhileWaitingForSubmitStopsBeforeAttempting() async throws {
        let session = WebAgentSession(provider: .grok, storageURL: temporaryDirectory().appendingPathComponent("state.json"), fixture: true)
        session.connect()
        try await waitFor { session.snapshot.ready }
        try await bindExistingFixtureChat(session)
        _ = try await session.webView.callAsyncJavaScript("input.addEventListener('input',()=>send.disabled=true)", arguments: [:], in: nil, contentWorld: .page)
        let navigation = Task { @MainActor in
            try await Task.sleep(for: .milliseconds(300))
            session.webView.loadHTMLString("<body>Different page</body>", baseURL: WebProvider.grok.homeURL)
        }
        let attempt = await session.send("Do not follow a navigation")
        try await navigation.value
        XCTAssertEqual(attempt?.status, .notSent)
        XCTAssertTrue(attempt?.detail?.contains("navigated") == true)
        XCTAssertFalse(session.state.hasUnresolvedSend("Do not follow a navigation"))
        XCTAssertFalse(session.isSending)
    }

    func testGrokResponseSelectorPreservesOnlyTheSameConversationIdentity() throws {
        let base = try XCTUnwrap(URL(string: "https://grok.com/c/known-chat"))
        let response = try XCTUnwrap(URL(string: base.absoluteString + "?rid=11111111-2222-4333-8444-555555555555"))
        XCTAssertEqual(WebProvider.grok.canonicalConversationURL(response), base)
        XCTAssertTrue(WebProvider.grok.acceptsReceipt(from: base, at: response))
        XCTAssertTrue(WebProvider.grok.acceptsReceipt(from: response, at: base))
        XCTAssertFalse(WebProvider.grok.isSavedConversation(response), "Persist only the conversation URL")
        for suffix in ["?rid=not-an-id", "?rid=11111111-2222-4333-8444-555555555555%00ignored", "?rid=11111111-2222-4333-8444-555555555555&mode=other", "?other=1", "#other"] {
            XCTAssertNil(WebProvider.grok.canonicalConversationURL(try XCTUnwrap(URL(string: base.absoluteString + suffix))))
        }
        XCTAssertFalse(WebProvider.grok.acceptsReceipt(from: base, at: try XCTUnwrap(URL(string: "https://grok.com/c/another-chat"))))
        XCTAssertNil(WebProvider.chatgpt.canonicalConversationURL(try XCTUnwrap(URL(string: "https://chatgpt.com/c/chat?rid=11111111-2222-4333-8444-555555555555"))))
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

    func testComparisonSetupWaitsForAllLoginsAndDoesNotSubmitOnSignIn() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let web = WebAgents(directory: directory, fixture: true)
        web.connectSelected()
        try await waitFor { web.sessions.allSatisfy { $0.snapshot.ready } }
        let claude = web.sessions[2]
        _ = try await claude.webView.callAsyncJavaScript("chat.hidden=true;login.hidden=false", arguments: [:], in: nil, contentWorld: .page)
        let signedOut = await web.prepareComparison(nil, for: web.selected)
        XCTAssertFalse(signedOut)
        XCTAssertTrue(web.sessions.allSatisfy { $0.state.attempts.isEmpty && !$0.snapshot.messages.contains { $0.role == "user" } })
        _ = try await claude.webView.callAsyncJavaScript("chat.hidden=false;login.hidden=true", arguments: [:], in: nil, contentWorld: .page)
        await claude.refresh()
        // Muse can return to its main page after login; submission must open a side chat.
        _ = try await web.sessions[0].webView.callAsyncJavaScript("history.replaceState({},'', '/')", arguments: [:], in: nil, contentWorld: .page)
        let openedSideChat = await web.prepareComparison(nil, for: web.selected)
        XCTAssertFalse(openedSideChat, "Navigating from an unready main page must only prepare the comparison")
        XCTAssertEqual(web.sessions[0].webView.url, WebProvider.muse.newChatURL)
        let connected = await web.prepareComparison(nil, for: web.selected)
        XCTAssertTrue(connected)
        XCTAssertTrue(web.sessions.allSatisfy { $0.state.attempts.isEmpty && !$0.snapshot.messages.contains { $0.role == "user" } }, "Setup and sign-in must never send")
        let results = await WebAgents.send("Explicit submission after sign-in", to: web.selected)
        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results.values.allSatisfy { $0.status == .observed })
    }

    func testFailedNewComparisonSetupClearsDeselectedWorkspaceIdentity() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let web = WebAgents(directory: directory, fixture: true), previousID = UUID()
        web.connectSelected()
        try await waitFor { web.sessions.allSatisfy { $0.snapshot.ready } }
        let previous = await WebAgents.send("Previous comparison", to: web.selected, comparisonID: previousID)
        XCTAssertTrue(previous.values.allSatisfy { $0.status == .observed })
        web.setComparison(previousID)
        web.sessions[0].updateState { $0.selected = false }
        let claude = web.sessions[2]
        _ = try await claude.webView.callAsyncJavaScript("chat.hidden=true;login.hidden=false", arguments: [:], in: nil, contentWorld: .page)
        let prepared = await web.prepareComparison(nil, for: web.selected)
        XCTAssertFalse(prepared)
        XCTAssertNil(web.comparisonID, "Failed setup must not restore an old comparison on retry")
        XCTAssertTrue(web.sessions.allSatisfy { $0.state.comparisonID == nil })
        XCTAssertTrue(web.sessions.allSatisfy { $0.state.conversationURLs[previousID.uuidString] == previous[$0.provider]?.conversationURL })
    }

    func testLoginCompletingDuringSetupRequiresAnotherExplicitSubmission() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let web = WebAgents(directory: directory, fixture: true)
        web.connectSelected()
        try await waitFor { web.sessions.allSatisfy { $0.snapshot.ready } }
        let claude = web.sessions[2]
        _ = try await claude.webView.callAsyncJavaScript("chat.hidden=true;login.hidden=false;history.replaceState({},'', '/login')", arguments: [:], in: nil, contentWorld: .page)
        XCTAssertTrue(claude.snapshot.ready, "Exercise a stale snapshot before the next polling tick")
        let signIn = Task { @MainActor in
            try await Task.sleep(for: .milliseconds(500))
            _ = try await claude.webView.callAsyncJavaScript("chat.hidden=false;login.hidden=true", arguments: [:], in: nil, contentWorld: .page)
        }
        let maySubmit = await web.prepareComparison(nil, for: web.selected)
        try await signIn.value
        XCTAssertTrue(claude.snapshot.ready, "The fixture must finish signing in during preparation")
        XCTAssertFalse(maySubmit, "An unready click must never become a queued send after sign-in")
        XCTAssertTrue(web.sessions.allSatisfy { $0.state.attempts.isEmpty })
        let explicitRetry = await web.prepareComparison(nil, for: web.selected)
        XCTAssertTrue(explicitRetry)
    }

    func testComparisonSetupPreservesExistingPageDraft() async throws {
        let web = WebAgents(directory: temporaryDirectory(), fixture: true)
        web.connectSelected()
        try await waitFor { web.sessions.allSatisfy { $0.snapshot.ready } }
        let chatgpt = web.sessions[1]
        _ = try await chatgpt.webView.callAsyncJavaScript("document.querySelector('textarea').value='Keep my page draft'", arguments: [:], in: nil, contentWorld: .page)
        let ready = await web.prepareComparison(nil, for: web.selected)
        XCTAssertFalse(ready)
        XCTAssertEqual(chatgpt.snapshot.draft, "Keep my page draft")
        XCTAssertTrue(web.sessions.allSatisfy { $0.state.attempts.isEmpty })
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
