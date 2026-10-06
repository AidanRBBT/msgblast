import Foundation

public enum LocalAgentRuntime: String, CaseIterable, Identifiable, Sendable {
    case openclaw, hermes
    public var id: String { rawValue }
    public var name: String { self == .openclaw ? "OpenClaw" : "Hermes" }
    public var setup: String { self == .openclaw ? "openclaw gateway status" : "hermes setup" }
    public var documentation: URL {
        URL(string: self == .openclaw ? "https://docs.openclaw.ai/start/getting-started" : "https://hermes-agent.nousresearch.com/docs/")!
    }
}

public struct InstalledLocalAgent: Identifiable, Equatable, Sendable {
    public let runtime: LocalAgentRuntime
    public let executableURL: URL
    public var id: String { runtime.id }
    public init(runtime: LocalAgentRuntime, executableURL: URL) {
        self.runtime = runtime; self.executableURL = executableURL
    }
}

public enum LocalAgentDetection {
    public static func detect() async -> [InstalledLocalAgent] {
        detect(path: await LocalPersonalAgent.executableSearchPath())
    }

    // Detect presence without launching either CLI or reading account/config files.
    public static func detect(path: String) -> [InstalledLocalAgent] {
        return LocalAgentRuntime.allCases.compactMap { runtime in
            executable(named: runtime.rawValue, path: path).map { InstalledLocalAgent(runtime: runtime, executableURL: $0) }
        }
    }

    static func executable(named name: String, path: String) -> URL? {
        let directories = path.split(separator: ":").map(String.init).filter { $0.hasPrefix("/") && !$0.contains("\n") }
        for directory in directories {
            let executable = URL(fileURLWithPath: directory).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: executable.path, isDirectory: &isDirectory), !isDirectory.boolValue,
               FileManager.default.isExecutableFile(atPath: executable.path) {
                return executable
            }
        }
        return nil
    }
}
