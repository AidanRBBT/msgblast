import Foundation

private let summaryAnswerFilename = "answer.txt"

public enum PersonalAgentProvider: String, CaseIterable, Identifiable, Sendable {
    case codex, claude, cursor, gemini, pi, grok, hermes
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude Code"
        case .cursor: "Cursor"
        case .gemini: "Gemini CLI"
        case .pi: "Pi"
        case .grok: "Grok"
        case .hermes: "Hermes"
        }
    }
    public var executable: String { self == .cursor ? "cursor-agent" : rawValue }
    public var setup: String {
        switch self {
        case .codex: "codex login"
        case .claude: "claude auth login"
        case .cursor: "cursor-agent login"
        case .gemini: "gemini"
        case .pi: "pi"
        case .grok: "grok login"
        case .hermes: "hermes login"
        }
    }

    // Keep the raw value for saved preferences and reports, but fail closed until
    // Each blocked adapter needs verified denial of every built-in and MCP tool.
    public var unavailabilityReason: String? {
        switch self {
        case .cursor:
            return "Cursor is unavailable for comparison reports because its CLI cannot disable all tools with a verified policy. Choose another installed personal agent; saved Cursor reports remain readable."
        case .grok:
            return "Grok is unavailable for comparison reports because its current adapter cannot enforce complete tool denial independently of inherited configuration. Choose another installed personal agent; saved Grok reports remain readable."
        default:
            return nil
        }
    }

    func arguments(in directory: URL) throws -> [String] {
        switch self {
        case .codex:
            return ["exec", "--skip-git-repo-check", "--ephemeral", "--ignore-user-config", "--sandbox", "read-only",
                    "-c", "approval_policy=\"never\"", "-c", "features.shell_tool=false", "--color", "never",
                    "--output-last-message", directory.appendingPathComponent(summaryAnswerFilename).path, "-"]
        case .claude:
            return ["--print", "--output-format", "json", "--tools", "", "--strict-mcp-config",
                    "--permission-mode", "dontAsk", "--no-session-persistence", "--disable-slash-commands",
                    "--setting-sources", "", "--settings", "{\"disableAllHooks\":true}"]
        case .cursor:
            throw PersonalAgentError.unsupportedProvider(self)
        case .gemini:
            return ["--prompt", "Summarize the comparison supplied on stdin.", "--output-format", "json", "--approval-mode", "plan", "--extensions", "none",
                    "--policy", directory.appendingPathComponent("no-tools.toml").path]
        case .pi:
            return ["--print", "--no-tools", "--no-extensions", "--no-skills", "--no-context-files", "--no-prompt-templates", "--no-session"]
        case .grok:
            throw PersonalAgentError.unsupportedProvider(self)
        case .hermes:
            return ["chat", "--query-file", "-", "--quiet", "--toolsets", "none", "--safe-mode", "--source", "tool", "--max-turns", "1"]
        }
    }

    func answer(stdout: String, directory: URL) throws -> String {
        let answer: String
        switch self {
        case .codex:
            answer = try AgentProcess.readOutput(directory.appendingPathComponent(summaryAnswerFilename))
        case .claude, .cursor, .gemini:
            guard let data = stdout.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["is_error"] as? Bool != true, object["error"] == nil,
                  let text = object[self == .gemini ? "response" : "result"] as? String else {
                throw PersonalAgentError.invalidResponse(name)
            }
            answer = text
        case .pi, .grok, .hermes: answer = stdout
        }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PersonalAgentError.invalidResponse(name) }
        return trimmed
    }
}

public struct InstalledPersonalAgent: Identifiable, Equatable, Sendable {
    public let provider: PersonalAgentProvider
    public let executableURL: URL
    public let path: String
    public var id: String { provider.id }
    public init(provider: PersonalAgentProvider, executableURL: URL, path: String) {
        self.provider = provider; self.executableURL = executableURL; self.path = path
    }
}

public enum PersonalAgentError: LocalizedError {
    case unavailable(String), unsupportedProvider(PersonalAgentProvider), failed(String, Int32), timedOut, tooLarge, invalidResponse(String)
    public var errorDescription: String? {
        switch self {
        case .unavailable(let name): "\(name) could not be launched. Refresh installed agents and check its CLI installation."
        case .unsupportedProvider(let provider): provider.unavailabilityReason ?? "\(provider.name) is unavailable for comparison reports."
        case .failed(let name, let code): "\(name) exited with status \(code). Open its CLI in Terminal to check sign-in, usage limits, and updates, then try again."
        case .timedOut: "The personal agent did not finish within three minutes. Try again when it is ready."
        case .tooLarge: "The comparison or agent output is too large to summarize in one request. No partial summary was saved."
        case .invalidResponse(let name): "\(name) did not return a completed comparison report. Check its sign-in and CLI version in Terminal, then try again."
        }
    }
}

public enum LocalPersonalAgent {
    public static func discover() async -> [InstalledPersonalAgent] {
        await Task.detached(priority: .utility) {
            let environment = ProcessInfo.processInfo.environment
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            // GUI apps usually inherit a minimal PATH. Ask the login shell for PATH only;
            // no user-provided text is interpolated into shell code, and no credentials are read.
            let shell = environment["SHELL"] ?? "/bin/zsh"
            let shellPath = try? AgentProcess.run(executable: URL(fileURLWithPath: shell), arguments: ["-lc", "/usr/bin/printenv PATH"],
                input: "", environment: environment, timeout: 5, cancellation: AgentCancellation()).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = [shellPath, environment["PATH"], "\(home)/.local/bin:\(home)/.grok/bin:\(home)/.bun/bin:\(home)/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"].compactMap { $0 }.joined(separator: ":")
            return discover(path: path)
        }.value
    }

    public static func discover(path: String) -> [InstalledPersonalAgent] {
        let directories = path.split(separator: ":").map(String.init).filter { $0.hasPrefix("/") && !$0.contains("\n") }
        return PersonalAgentProvider.allCases.compactMap { provider in
            guard provider.unavailabilityReason == nil else { return nil }
            for directory in directories {
                let url = URL(fileURLWithPath: directory).appendingPathComponent(provider.executable)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue,
                   FileManager.default.isExecutableFile(atPath: url.path) {
                    return InstalledPersonalAgent(provider: provider, executableURL: url, path: path)
                }
            }
            return nil
        }
    }

    public static func summarize(_ input: ComparisonSummaryInput, using agent: InstalledPersonalAgent) async throws -> String {
        guard agent.provider.unavailabilityReason == nil else { throw PersonalAgentError.unsupportedProvider(agent.provider) }
        let cancellation = AgentCancellation()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await Task.detached(priority: .userInitiated) {
                guard input.prompt.utf8.count <= 2_000_000 else { throw PersonalAgentError.tooLarge }
                var environment = ProcessInfo.processInfo.environment
                environment["PATH"] = agent.path
                environment["NO_COLOR"] = "1"
                // Avoid inherited session markers when launched from another agent's terminal.
                environment.removeValue(forKey: "CLAUDECODE")
                let result = try AgentProcess.run(executable: agent.executableURL, input: input.prompt, environment: environment,
                    timeout: 180, cancellation: cancellation, provider: agent.provider)
                guard result.status == 0 else { throw PersonalAgentError.failed(agent.provider.name, result.status) }
                return result.stdout
            }.value
        } onCancel: { cancellation.cancel() }
    }
}

final class AgentCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.withLock { cancelled = true } }
    var isCancelled: Bool { lock.withLock { cancelled } }
}

enum AgentProcess {
    struct Result { let status: Int32; let stdout: String }
    static func readOutput(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: 4_000_001) ?? Data()
        guard data.count <= 4_000_000 else { throw PersonalAgentError.tooLarge }
        return String(decoding: data, as: UTF8.self)
    }
    static func run(executable: URL, arguments: [String] = [], input: String, environment: [String: String],
                    timeout: TimeInterval, cancellation: AgentCancellation, provider: PersonalAgentProvider? = nil) throws -> Result {
        // Reject blocked adapters before writing the transcript or launching any process.
        if let provider, provider.unavailabilityReason != nil { throw PersonalAgentError.unsupportedProvider(provider) }
        let files = FileManager.default
        let directory = files.temporaryDirectory.appendingPathComponent("msgblast-Summary-\(UUID())", isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? files.removeItem(at: directory) }
        let inputURL = directory.appendingPathComponent("input.txt")
        try Data(input.utf8).write(to: inputURL)
        if provider == .gemini {
            try Data("[[rule]]\ntoolName = \"*\"\ndecision = \"deny\"\npriority = 999\n".utf8)
                .write(to: directory.appendingPathComponent("no-tools.toml"))
        }
        let stdoutURL = directory.appendingPathComponent("stdout.txt"), stderrURL = directory.appendingPathComponent("stderr.txt")
        files.createFile(atPath: stdoutURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        files.createFile(atPath: stderrURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let stdin = try FileHandle(forReadingFrom: inputURL)
        let stdout = try FileHandle(forWritingTo: stdoutURL), stderr = try FileHandle(forWritingTo: stderrURL)
        defer { try? stdin.close(); try? stdout.close(); try? stderr.close() }
        let process = Process()
        process.executableURL = executable; process.arguments = try provider?.arguments(in: directory) ?? arguments
        process.currentDirectoryURL = directory; process.environment = environment
        process.standardInput = stdin; process.standardOutput = stdout; process.standardError = stderr
        if cancellation.isCancelled { throw CancellationError() }
        do { try process.run() } catch { throw PersonalAgentError.unavailable(provider?.name ?? executable.lastPathComponent) }
        // File-backed I/O avoids pipe deadlocks for long prompts and verbose CLIs.
        // These owner-only temporary files are removed on success, failure, timeout and cancellation.
        // Foundation launches each Process in its own process group. Validate the
        // group before using it, and clean up wrapper children even after the leader exits.
        let pid = process.processIdentifier
        let group = pid != getpgrp() && (getpgid(pid) == pid || kill(-pid, 0) == 0) ? pid : nil
        defer {
            if let group {
                kill(-group, SIGTERM)
                let deadline = Date().addingTimeInterval(1)
                while kill(-group, 0) == 0 && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
                if kill(-group, 0) == 0 { kill(-group, SIGKILL) }
            } else if process.isRunning {
                process.terminate()
                let deadline = Date().addingTimeInterval(1)
                while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
                if process.isRunning { kill(pid, SIGKILL) }
            }
            if process.isRunning {
                process.waitUntilExit()
            }
        }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if cancellation.isCancelled { throw CancellationError() }
            if Date() >= deadline { throw PersonalAgentError.timedOut }
            for url in [stdoutURL, stderrURL, directory.appendingPathComponent(summaryAnswerFilename)] {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 4_000_000 { throw PersonalAgentError.tooLarge }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        if cancellation.isCancelled { throw CancellationError() }
        let output = try readOutput(stdoutURL)
        if let provider, process.terminationStatus == 0 {
            return Result(status: 0, stdout: try provider.answer(stdout: output, directory: directory))
        }
        return Result(status: process.terminationStatus, stdout: output)
    }
}
