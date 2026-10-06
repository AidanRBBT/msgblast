import Foundation

/// The same Markdown files used by the release publisher, bundled for offline reading.
public struct ReleaseHistory: Sendable {
    public struct Entry: Identifiable, Sendable {
        public let version: String
        public let notes: String
        public let highlights: [String]
        public let contributors: String
        public var id: String { version }
    }

    public let entries: [Entry]
    public let installedVersion: String
    public var current: Entry? { entries.first { $0.version == installedVersion } }

    public init(directory: URL?, installedVersion: String) {
        self.installedVersion = installedVersion
        guard let directory, let installed = Self.components(installedVersion),
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            entries = []
            return
        }
        let summaries = (try? Data(contentsOf: directory.appendingPathComponent("highlights.json")))
            .flatMap { try? JSONDecoder().decode([String: [String]].self, from: $0) } ?? [:]
        let unpublished = (try? Data(contentsOf: directory.appendingPathComponent("unpublished.json")))
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        entries = files.compactMap { file -> Entry? in
            let version = file.deletingPathExtension().lastPathComponent
            guard file.pathExtension == "md", !unpublished.contains(version), let parts = Self.components(version),
                  !installed.lexicographicallyPrecedes(parts),
                  let notes = try? String(contentsOf: file, encoding: .utf8),
                  !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let sections = notes.components(separatedBy: "## Contributors\n")
            let bullets = sections[0].components(separatedBy: "\n").filter { $0.hasPrefix("- ") }.map { String($0.dropFirst(2)) }
            let credits = sections.dropFirst().first?.components(separatedBy: "\n## ").first ?? ""
            return Entry(version: version, notes: notes,
                highlights: Array((summaries[version] ?? bullets).prefix(3)),
                contributors: credits.trimmingCharacters(in: .whitespacesAndNewlines))
        }.sorted { $1.version.compare($0.version, options: .numeric) == .orderedAscending }
    }

    private static func components(_ version: String) -> [Int]? {
        let fields = version.split(separator: ".", omittingEmptySubsequences: false)
        guard fields.count == 3, fields.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        let numbers = fields.compactMap { Int($0) }
        return numbers.count == 3 ? numbers : nil
    }
}
