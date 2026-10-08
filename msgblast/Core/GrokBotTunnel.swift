import Foundation
import Darwin

/// Starts the existing open-source cloudflared helper only for the app's loopback receiver.
@MainActor
public final class GrokBotTunnel {
    public private(set) var address: URL?
    public var onDisconnect: (() -> Void)?
    private var process: Process?
    private var output: Pipe?
    private var configurationDirectory: URL?
    private var startup: CheckedContinuation<URL, Error>?
    private var timer: Task<Void, Never>?
    private var readiness: Task<Void, Never>?
    private var logBuffer = ""
    private var candidate: URL?
    public init() {}
    public func start(localURL: URL) async throws -> URL {
        guard process == nil else { throw GrokBotServiceError.callbackUnavailable }
        guard localURL.scheme == "http", localURL.host == "127.0.0.1", localURL.port != nil else { throw GrokBotServiceError.callbackUnavailable }
        let paths = [Bundle.main.url(forResource: "cloudflared", withExtension: nil)?.path, "/opt/homebrew/bin/cloudflared", "/usr/local/bin/cloudflared"].compactMap { $0 }
        guard let executable = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { throw GrokBotServiceError.tunnelHelperMissing }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("msgblast-tunnel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let config = directory.appendingPathComponent("config.yml")
        try Data("{}\n".utf8).write(to: config)
        configurationDirectory = directory
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["tunnel", "--config", config.path, "--url", localURL.absoluteString, "--no-autoupdate", "--loglevel", "info", "--transport-loglevel", "error"]
        process.environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("TUNNEL_") && $0.key != "NO_AUTOUPDATE" }
        process.standardOutput = output; process.standardError = output
        self.process = process; self.output = output
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in self?.read(data) }
        }
        process.terminationHandler = { [weak self] ended in
            Task { @MainActor in
                guard let self, self.process === ended else { return }
                let disconnected = self.address != nil
                self.startup?.resume(throwing: GrokBotServiceError.callbackUnavailable); self.startup = nil
                let notify = self.onDisconnect
                self.stop()
                if disconnected { notify?() }
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            startup = continuation
            do { try process.run() }
            catch { startup = nil; stop(); continuation.resume(throwing: GrokBotServiceError.callbackUnavailable); return }
            timer = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(90)) } catch { return }
                guard let self, let startup = self.startup else { return }
                self.startup = nil; startup.resume(throwing: GrokBotServiceError.callbackUnavailable); self.stop()
            }
        }
    }
    private func read(_ data: Data) {
        logBuffer += String(decoding: data, as: UTF8.self)
        if let range = logBuffer.range(of: #"https://[a-z0-9-]+\.trycloudflare\.com"#, options: .regularExpression) {
            candidate = URL(string: String(logBuffer[range]))
        }
        if logBuffer.contains("Registered tunnel connection"), let candidate, startup != nil, readiness == nil {
            readiness = Task { [weak self] in
                // Registration can precede DNS propagation. Probe the receiver before sending Bot work.
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 3; configuration.timeoutIntervalForResource = 3
                configuration.httpShouldSetCookies = false; configuration.urlCache = nil
                let session = URLSession(configuration: configuration)
                defer { session.invalidateAndCancel() }
                for _ in 0..<40 {
                    guard !Task.isCancelled else { return }
                    if let (body, response) = try? await session.data(from: candidate),
                       (response as? HTTPURLResponse)?.statusCode == 405,
                       body == Data(GrokBotCallbackReceiver.rejectionBody.utf8), let self, let startup = self.startup {
                        self.startup = nil; self.address = candidate; self.timer?.cancel()
                        startup.resume(returning: candidate)
                        return
                    }
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                }
            }
        }
        // Helper logs are kept only in bounded memory; request headers and bodies are never logged.
        if logBuffer.utf8.count > 64 * 1024 { logBuffer = String(logBuffer.suffix(16 * 1024)) }
    }
    public func stop() {
        timer?.cancel(); timer = nil
        readiness?.cancel(); readiness = nil
        startup?.resume(throwing: GrokBotServiceError.callbackUnavailable); startup = nil
        output?.fileHandleForReading.readabilityHandler = nil
        if let process, process.isRunning {
            // This helper has no persistent state. Cleanup must finish even when the app exits now.
            kill(process.processIdentifier, SIGKILL)
        }
        process = nil; output = nil; address = nil; candidate = nil; logBuffer = ""
        if let configurationDirectory { try? FileManager.default.removeItem(at: configurationDirectory) }
        configurationDirectory = nil
    }
}
