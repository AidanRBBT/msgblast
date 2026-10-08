import XCTest

final class WebServiceWorkflowTests: XCTestCase {
    @MainActor
    func testSevenChatsResizeWindowAndRemainReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--isolated-demo"]
        app.launch()
        app.activate()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Maple"].waitForExistence(timeout: 5))
        for name in ["Maple", "Echo", "Flint"] { app.buttons[name].click() }
        app.buttons["Send & compare"].click()
        XCTAssertTrue(app.staticTexts["Chats (7)"].waitForExistence(timeout: 15))
        let wideWidth = app.windows.firstMatch.frame.width
        for name in ["Muse", "ChatGPT", "Claude", "Grok", "Cedar", "Lumen", "Orbit"] {
            let tab = app.buttons["Show \(name) chat"]
            XCTAssertTrue(tab.exists)
            tab.click()
        }
        for name in ["Muse", "ChatGPT", "Claude", "Grok"] { app.buttons["Recipient \(name)"].click() }
        XCTAssertTrue(app.staticTexts["Chats (3)"].waitForExistence(timeout: 5))
        let narrowed = NSPredicate { _, _ in app.windows.firstMatch.frame.width <= min(wideWidth, 1500) }
        expectation(for: narrowed, evaluatedWith: app.windows.firstMatch)
        waitForExpectations(timeout: 5)
        for name in ["Muse", "ChatGPT", "Claude", "Grok"] { app.buttons["Recipient \(name)"].click() }
        XCTAssertTrue(app.staticTexts["Chats (7)"].waitForExistence(timeout: 5))
        let expanded = NSPredicate { _, _ in app.windows.firstMatch.frame.width >= wideWidth - 1 }
        expectation(for: expanded, evaluatedWith: app.windows.firstMatch)
        waitForExpectations(timeout: 5)
        capture(app, name: "Seven reachable chats — isolated fixture")
    }

    @MainActor
    func testWebDefaultsAndOptionalCLIConversationsStaySeparate() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--isolated-demo"]
        app.launch()
        defer { app.terminate() }
        for name in ["Muse", "ChatGPT", "Claude", "Grok"] {
            XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons[name].value as? String, "Selected")
        }
        XCTAssertFalse(app.buttons["Codex CLI"].exists)
        XCTAssertFalse(app.buttons["Claude Code"].exists)
        XCTAssertFalse(app.staticTexts["Your local accounts (simulated)"].exists)
        capture(app, name: "Four website agents by default — isolated fixture")
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows.matching(identifier: "com_apple_SwiftUI_Settings_window").firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        for name in ["Codex CLI", "Claude Code"] {
            let toggle = settings.switches["Enable \(name)"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.click()
        }
        capture(app, name: "Optional CLI toggles in Settings — simulated accounts")
        settings.buttons[XCUIIdentifierCloseWindow].click()
        for name in ["Cedar", "Lumen", "Orbit", "Maple", "Echo", "Flint", "Muse", "Grok"] { app.buttons[name].click() }
        XCTAssertEqual(app.buttons["Codex CLI"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["Claude Code"].value as? String, "Selected")
        let editor = app.textViews["Shared prompt"]
        editor.click(); editor.typeKey("a", modifierFlags: .command); editor.typeText("Web and CLI comparison fixture")
        app.buttons["Send & compare"].click()
        for name in ["ChatGPT", "Claude", "Codex CLI", "Claude Code"] {
            XCTAssertTrue(reply(app, containing: "\(name) fixture reply: Web and CLI comparison fixture").waitForExistence(timeout: 15))
        }
        XCTAssertEqual(app.webViews.count, 2, "Website chats coexist with two separate native CLI panes")
        XCTAssertFalse(app.buttons["Switch account"].exists)
        capture(app, name: "Website and CLI replies in the same blast — synthetic replies")
        app.buttons["New Blast"].click()
        let comparison = app.outlines.cells.containing(NSPredicate(format: "label CONTAINS %@", "Web and CLI comparison fixture")).firstMatch
        XCTAssertTrue(comparison.waitForExistence(timeout: 5))
        comparison.click()
        XCTAssertTrue(reply(app, containing: "Codex CLI fixture reply: Web and CLI comparison fixture").waitForExistence(timeout: 10))
        editor.click(); editor.typeText("Continue each saved conversation")
        app.buttons["Send & compare"].click()
        for name in ["ChatGPT", "Claude", "Codex CLI", "Claude Code"] {
            XCTAssertTrue(reply(app, containing: "\(name) fixture reply: Continue each saved conversation").waitForExistence(timeout: 15))
        }
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.switches["Enable Codex CLI"].click()
        settings.buttons[XCUIIdentifierCloseWindow].click()
        app.buttons["New Blast"].click()
        XCTAssertFalse(app.buttons["Codex CLI"].exists)
        comparison.click()
        XCTAssertTrue(reply(app, containing: "Codex CLI fixture reply: Web and CLI comparison fixture").waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Recipient Codex CLI"].isEnabled)
    }

    @MainActor
    private func reply(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
    }

    @MainActor
    func testSignedInWebsitesSkipConnectionIntro() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--isolated-demo"]
        app.launch()
        app.activate()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Cedar"].waitForExistence(timeout: 5))
        for name in ["Cedar", "Lumen", "Orbit", "Maple", "Echo", "Flint"] { app.buttons[name].click() }
        let editor = app.textViews["Shared prompt"]
        editor.click(); editor.typeKey("a", modifierFlags: .command); editor.typeText("Already signed in fixture")
        app.buttons["Send & compare"].click()
        for name in ["ChatGPT", "Claude", "Grok"] {
            XCTAssertTrue(reply(app, containing: "\(name) fixture reply: Already signed in fixture").waitForExistence(timeout: 15))
        }
        XCTAssertTrue(reply(app, containing: "Fixture reply: Already signed in fixture").exists)
        XCTAssertFalse(app.staticTexts["Connect your accounts"].exists)
        capture(app, name: "Signed-in websites submit without a login reminder — isolated fixture")
    }

    @MainActor
    func testSignedOutAgentOpensSetupAndKeepsPromptUntilUserSubmitsAgain() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--isolated-demo"]
        app.launch()
        app.activate()
        defer { app.terminate() }
        for name in ["Cedar", "Lumen", "Orbit", "Maple", "Echo", "Flint", "ChatGPT", "Claude", "Grok"] { app.buttons[name].click() }
        app.buttons["Muse"].rightClick()
        app.menuItems["Open chat"].click()
        let signOut = app.buttons["Sign out of fixture"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 10))
        signOut.click()
        XCTAssertTrue(app.buttons["Sign in to fixture"].waitForExistence(timeout: 10))
        app.buttons["New Blast"].click()
        let editor = app.textViews["Shared prompt"]
        editor.click(); editor.typeKey("a", modifierFlags: .command); editor.typeText("Keep this comparison request")
        let send = app.buttons["Send & compare"]
        XCTAssertTrue(send.isEnabled, "A signed-out agent must lead to setup, not a disabled send button")
        XCTAssertTrue(app.staticTexts["Website sign-in status"].waitForExistence(timeout: 5))
        app.activate(); send.click()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Connect your accounts", "Connect your accounts")).firstMatch.waitForExistence(timeout: 10))
        capture(app, name: "Only signed-out Muse requires login; prompt preserved — isolated fixture")
        app.activate(); app.buttons["Start signing in"].click()
        XCTAssertEqual(editor.value as? String, "Keep this comparison request")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Fixture reply: Keep this comparison request", "Fixture reply: Keep this comparison request")).firstMatch.exists)
        app.activate(); app.buttons["Sign in to fixture"].click()
        XCTAssertTrue(app.buttons["Sign out of fixture"].waitForExistence(timeout: 10))
        XCTAssertEqual(editor.value as? String, "Keep this comparison request")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Fixture reply: Keep this comparison request", "Fixture reply: Keep this comparison request")).firstMatch.exists, "Signing in must not submit automatically")
        app.activate(); send.click()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Fixture reply: Keep this comparison request", "Fixture reply: Keep this comparison request")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Appeared in Muse"].exists)
    }

    @MainActor
    func testFailedMessagesRecipientCanRetryWithoutResendingToMuse() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--isolated-demo"]
        app.launch()
        defer { app.terminate() }
        for name in ["Lumen", "Orbit", "Maple", "Echo", "Flint"] { app.buttons[name].click() }
        app.checkBoxes["Simulate one failure"].click()
        for name in ["ChatGPT", "Claude", "Grok"] { app.buttons[name].click() }
        let editor = app.textViews["Shared prompt"]
        editor.click(); editor.typeKey("a", modifierFlags: .command); editor.typeText("Mixed failure fixture")
        app.buttons["Send & compare"].click()
        XCTAssertTrue(reply(app, containing: "Fixture reply:").waitForExistence(timeout: 10))
        let retry = app.buttons["Retry only failed recipients"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        retry.click()
        XCTAssertTrue(app.textViews.matching(NSPredicate(format: "value == %@", "Mixed failure fixture")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(retry.exists)
        let museReplies = app.staticTexts.containing(NSPredicate(format: "value CONTAINS %@", "Fixture reply: Mixed failure fixture"))
        XCTAssertEqual(museReplies.count, 1)
    }

    @MainActor
    func testEmbeddedMuseAndMessagesReceiveOneSharedPrompt() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--isolated-demo"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["Muse"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Muse"].value as? String, "Selected")
        XCTAssertFalse(app.staticTexts["Web services"].exists)
        XCTAssertFalse(app.staticTexts["Grok Bot · unavailable"].exists)
        for name in ["Lumen", "Orbit", "Maple", "Echo", "Flint"] { app.buttons[name].click() }
        for name in ["ChatGPT", "Claude", "Grok"] { app.buttons[name].click() }
        XCTAssertEqual(app.buttons["Muse"].value as? String, "Selected")
        capture(app, name: "Muse selected beside Messages agents — local fixture")
        app.buttons["Muse"].rightClick()
        app.menuItems["Open chat"].click()
        XCTAssertTrue(app.buttons["Sign out of fixture"].waitForExistence(timeout: 10))
        capture(app, name: "Muse connected — local fixture")
        XCTAssertEqual(app.buttons["Recipient Cedar"].value as? String, "Selected")
        let editor = app.textViews["Shared prompt"]
        editor.click()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeText("Compare a morning walk with an afternoon walk.")
        capture(app, name: "Shared prompt ready — synthetic content")
        app.buttons["Send & compare"].click()
        XCTAssertTrue(reply(app, containing: "Fixture reply:").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "value CONTAINS %@", "Fixture reply: Compare a morning walk")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Cedar (Demo)"].firstMatch.waitForExistence(timeout: 10))
        capture(app, name: "Embedded Muse and Messages replies — synthetic content")
        editor.click(); editor.typeText("Keep this shared draft")
        let privateReply = app.textViews["Private reply to Cedar"]
        XCTAssertTrue(privateReply.exists)
        privateReply.click(); privateReply.typeText("Cedar direct reply from its pane")
        privateReply.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.textViews.matching(NSPredicate(format: "value == %@", "Cedar direct reply from its pane")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(privateReply.value as? String, "")
        XCTAssertEqual(editor.value as? String, "Keep this shared draft")
        XCTAssertFalse(reply(app, containing: "Fixture reply: Cedar direct reply from its pane").exists, "Private Messages replies must not be sent to Muse")
        capture(app, name: "Direct Messages pane reply — simulated Messages, shared draft retained")
        app.buttons["New Blast"].click()
        XCTAssertEqual(app.buttons["Muse"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["Cedar"].value as? String, "Selected")
        XCTAssertEqual(app.textViews["Shared prompt"].value as? String, "Keep this shared draft")
        app.buttons["Muse"].rightClick()
        app.menuItems["Open chat"].click()
        XCTAssertFalse(app.staticTexts["Appeared in Muse"].exists)
        XCTAssertFalse(app.buttons["Connect Muse"].exists)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
