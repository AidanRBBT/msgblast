import XCTest
@testable import MsgBlastCore

final class PersonalAgentTests: XCTestCase {
    func testSnapshotIncludesEveryMemberAndBoundedRepliesButNoDraftsOrAddresses() throws {
        let chat = Chat(id: "chat", handle: "private@example.com", lastActivity: 0)
        var member = Member(agentID: UUID(), name: "Cedar", chat: chat)
        member.anchor = Anchor(rowID: 10, guid: "prompt")
        var comparison = Comparison(prompt: "Compare the options", members: [member, Member(agentID: UUID(), name: "Lumen", chat: chat)])
        comparison.allDraft = "UNSENT SECRET"
        var later = Comparison(prompt: "Unrelated", members: [member])
        later.members[0].anchor = Anchor(rowID: 20, guid: "later")
        let messages = [
            Message(id: 9, guid: "old", chatID: chat.id, text: "OLD SECRET", outgoing: false),
            Message(id: 10, guid: "prompt", chatID: chat.id, text: comparison.prompt, outgoing: true),
            Message(id: 11, guid: "reply", chatID: chat.id, text: "First answer", outgoing: false),
            Message(id: 21, guid: "other", chatID: chat.id, text: "UNRELATED SECRET", outgoing: false),
            Message(id: 22, guid: "thread", chatID: chat.id, text: "Explicit thread answer", outgoing: false, replyTo: "prompt")
        ]
        let snapshot = try ComparisonSummaryInput(comparison: comparison, comparisons: [comparison, later], messages: [chat.id: messages])
        XCTAssertEqual(snapshot.responseCount, 2)
        XCTAssertEqual(snapshot.respondingMemberCount, 1)
        XCTAssertTrue(snapshot.prompt.contains("Explicit thread answer"))
        XCTAssertTrue(snapshot.prompt.contains("Lumen"))
        for secret in ["OLD SECRET", "UNRELATED SECRET", "UNSENT SECRET", "private@example.com"] {
            XCTAssertFalse(snapshot.prompt.contains(secret))
        }
        let changed = try ComparisonSummaryInput(comparison: comparison, comparisons: [comparison, later], messages: [chat.id: messages + [Message(id: 23, guid: "new", chatID: chat.id, text: "New reply", outgoing: false, replyTo: "prompt")]])
        XCTAssertNotEqual(snapshot.fingerprint, changed.fingerprint)
    }

    func testExistingStateDecodesWithoutPersonalAgentFields() throws {
        var state = AppState()
        state.comparisons = [Comparison(prompt: "Existing", members: [])]
        let encoded = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(AppState.self, from: encoded)
        XCTAssertNil(restored.personalAgentProvider)
        XCTAssertNil(restored.comparisons[0].summary)
    }

    func testReactionsCountAsResponsesAndInvalidateSummaryWhenChangedOrRemoved() throws {
        let chat = Chat(id: "chat", handle: "private@example.com", lastActivity: 0)
        var member = Member(agentID: UUID(), name: "Cedar", chat: chat)
        member.anchor = Anchor(rowID: 10, guid: "question")
        let comparison = Comparison(prompt: "Choose an option", members: [member])
        var question = Message(id: 10, guid: "question", chatID: chat.id, text: comparison.prompt, outgoing: true)
        func snapshot() throws -> ComparisonSummaryInput {
            try ComparisonSummaryInput(comparison: comparison, comparisons: [comparison], messages: [chat.id: [question]])
        }
        let waiting = try snapshot()
        question.reactions = [MessageReaction(id: "private-reaction-sender", emoji: "👍", outgoing: false)]
        let reacted = try snapshot()
        XCTAssertEqual(reacted.responseCount, 1)
        XCTAssertEqual(reacted.respondingMemberCount, 1)
        XCTAssertTrue(reacted.prompt.contains("👍"))
        XCTAssertFalse(reacted.prompt.contains("private-reaction-sender"))
        XCTAssertNotEqual(waiting.fingerprint, reacted.fingerprint)
        question.reactions[0].emoji = "👎"
        XCTAssertNotEqual(reacted.fingerprint, try snapshot().fingerprint)
        question.reactions.removeAll()
        XCTAssertEqual(waiting.fingerprint, try snapshot().fingerprint)
        question.reactions = [MessageReaction(id: "user", emoji: "❤️", outgoing: true)]
        let userReaction = try snapshot()
        XCTAssertEqual(userReaction.responseCount, 0)
        XCTAssertEqual(userReaction.respondingMemberCount, 0)
        XCTAssertTrue(userReaction.prompt.contains("❤️"))
    }

    func testDiscoveryIgnoresGenericAgentAndRelativePaths() throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try executable("agent", script: "exit 0", in: directory)
        XCTAssertTrue(LocalPersonalAgent.discover(path: directory.path + ":.").isEmpty)
        try executable("cursor-agent", script: "exit 0", in: directory)
        XCTAssertEqual(LocalPersonalAgent.discover(path: directory.path).map(\.provider), [.cursor])
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("codex"), withIntermediateDirectories: false)
        XCTAssertEqual(LocalPersonalAgent.discover(path: directory.path).count, 1)
    }

    @MainActor
    func testAllProviderAdaptersUseStdinAndReturnOnlyCompletedOutput() async throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let comparison = Comparison(prompt: "Quotes ' \" and $(touch SHOULD_NOT_EXIST) are data", members: [])
        let input = try ComparisonSummaryInput(comparison: comparison, comparisons: [comparison], messages: [:])
        for provider in PersonalAgentProvider.allCases {
            // This executable fixture exercises the actual process/adapter boundary without contacting a provider.
            let output: String
            switch provider {
            case .codex: output = "printf 'Completed summary' > answer.txt"
            case .claude, .cursor: output = "printf '%s' '{\"result\":\"Completed summary\",\"is_error\":false}'"
            case .gemini: output = "printf '%s' '{\"response\":\"Completed summary\"}'"
            default: output = "printf 'Completed summary'"
            }
            try executable(provider.executable, script: "/bin/cat > received.txt\n/usr/bin/cmp -s input.txt received.txt || exit 9\ntest ! -e SHOULD_NOT_EXIST || exit 8\n" + output, in: directory)
            let installed = InstalledPersonalAgent(provider: provider, executableURL: directory.appendingPathComponent(provider.executable), path: "/usr/bin:/bin")
            let answer = try await LocalPersonalAgent.summarize(input, using: installed)
            XCTAssertEqual(answer, "Completed summary", provider.name)
        }
    }

    func testProviderJSONErrorsAndEmptyOutputAreNotSummaries() throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for provider in [PersonalAgentProvider.claude, .cursor, .gemini] {
            XCTAssertThrowsError(try provider.answer(stdout: "{\"result\":\"Sign in\",\"is_error\":true}", directory: directory))
            XCTAssertThrowsError(try provider.answer(stdout: "{}", directory: directory))
        }
        XCTAssertThrowsError(try PersonalAgentProvider.pi.answer(stdout: " \n", directory: directory))
    }

    func testProviderArgumentsRetainNoninteractiveAndToolRestrictions() throws {
        let directory = URL(fileURLWithPath: "/tmp/summary with spaces")
        let required: [PersonalAgentProvider: [(String, String?)]] = [
            .codex: [("--ephemeral", nil), ("--ignore-user-config", nil), ("--sandbox", "read-only"), ("--output-last-message", directory.appendingPathComponent("answer.txt").path)],
            .claude: [("--tools", ""), ("--permission-mode", "dontAsk"), ("--strict-mcp-config", nil), ("--setting-sources", ""), ("--no-session-persistence", nil)],
            .cursor: [("--mode", "ask"), ("--workspace", directory.path)],
            .gemini: [("--approval-mode", "plan"), ("--extensions", "none"), ("--policy", directory.appendingPathComponent("no-tools.toml").path)],
            .pi: [("--no-tools", nil), ("--no-extensions", nil), ("--no-skills", nil), ("--no-session", nil)],
            .grok: [("--tools", ""), ("--no-subagents", nil), ("--disable-web-search", nil), ("--permission-mode", "dontAsk")],
            .hermes: [("--toolsets", "none"), ("--safe-mode", nil), ("--query-file", "-"), ("--quiet", nil)]
        ]
        for provider in PersonalAgentProvider.allCases {
            let arguments = provider.arguments(in: directory)
            for (flag, value) in try XCTUnwrap(required[provider]) {
                let index = try XCTUnwrap(arguments.firstIndex(of: flag), "\(provider): \(flag)")
                if let value {
                    XCTAssertLessThan(index + 1, arguments.count)
                    XCTAssertEqual(arguments.dropFirst(index + 1).first, value, "\(provider): \(flag)")
                }
            }
        }
    }

    func testTimeoutAndSuccessCleanUpWrapperChildrenAndTemporaryInput() throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let pidFile = directory.appendingPathComponent("child.pid")
        let workingFile = directory.appendingPathComponent("working.txt")
        let environment = ["PATH": "/usr/bin:/bin", "PID_FILE": pidFile.path, "WORKING_FILE": workingFile.path]
        for shouldWait in [true, false] {
            let script = """
            (trap '' TERM; exec /bin/sleep 30) &
            echo $! > "$PID_FILE"
            pwd > "$WORKING_FILE"
            \(shouldWait ? "wait" : "sleep 0.1; exit 0")
            """
            if shouldWait {
                XCTAssertThrowsError(try AgentProcess.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], input: "private fixture", environment: environment, timeout: 0.3, cancellation: AgentCancellation()))
            } else {
                XCTAssertEqual(try AgentProcess.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script], input: "private fixture", environment: environment, timeout: 3, cancellation: AgentCancellation()).status, 0)
            }
            let pid = try XCTUnwrap(Int32(String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
            defer { if kill(pid, 0) == 0 { kill(pid, SIGKILL) } }
            let deadline = Date().addingTimeInterval(2)
            while kill(pid, 0) == 0 && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
            XCTAssertEqual(kill(pid, 0), -1, "The wrapper's child must not outlive the request")
            let working = try String(contentsOf: workingFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(FileManager.default.fileExists(atPath: working), "Temporary transcript must be removed")
        }
    }

    func testProcessHandlesLargeOutputTimeoutCancellationAndExitStatus() throws {
        let environment = ["PATH": "/usr/bin:/bin"]
        let large = try AgentProcess.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "head -c 100000 /dev/zero"], input: String(repeating: "x", count: 100_000), environment: environment, timeout: 3, cancellation: AgentCancellation())
        XCTAssertEqual(large.stdout.utf8.count, 100_000)
        let failure = try AgentProcess.run(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "exit 7"], input: "", environment: environment, timeout: 3, cancellation: AgentCancellation())
        XCTAssertEqual(failure.status, 7)
        XCTAssertThrowsError(try AgentProcess.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], input: "", environment: environment, timeout: 0.1, cancellation: AgentCancellation())) { error in
            guard case PersonalAgentError.timedOut = error else { return XCTFail("Expected timeout: \(error)") }
        }
        let cancellation = AgentCancellation()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { cancellation.cancel() }
        XCTAssertThrowsError(try AgentProcess.run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], input: "", environment: environment, timeout: 5, cancellation: cancellation)) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testSavedSummaryRoundTripsAndDraftChangesDoNotInvalidateIt() throws {
        var comparison = Comparison(prompt: "Question", members: [])
        let input = try ComparisonSummaryInput(comparison: comparison, comparisons: [comparison], messages: [:])
        comparison.summary = ComparisonSummary(provider: "Codex", text: "Saved answer", input: input)
        comparison.allDraft = "Unsent edit"
        let updated = try ComparisonSummaryInput(comparison: comparison, comparisons: [comparison], messages: [:])
        XCTAssertEqual(input.fingerprint, updated.fingerprint)
        let decoded = try JSONDecoder().decode(Comparison.self, from: JSONEncoder().encode(comparison))
        XCTAssertEqual(decoded.summary, comparison.summary)
    }

    private func fixtureDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MsgBlast-AgentTest-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }
    private func executable(_ name: String, script: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name)
        try Data(("#!/bin/sh\n" + script + "\n").utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }
}
