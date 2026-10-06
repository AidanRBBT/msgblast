import XCTest
@testable import msgblastCore

final class LocalAgentDetectionTests: XCTestCase {
    func testFindsOpenClawAndHermesWithoutLaunchingThem() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LocalAgentDetection-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("executed")
        for runtime in LocalAgentRuntime.allCases {
            let executable = directory.appendingPathComponent(runtime.rawValue)
            try Data("#!/bin/sh\n/bin/touch '\(marker.path)'\n".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        }
        let detected = LocalAgentDetection.detect(path: directory.path)
        XCTAssertEqual(detected.map(\.runtime), [.openclaw, .hermes])
        XCTAssertEqual(detected.map(\.executableURL), LocalAgentRuntime.allCases.map { directory.appendingPathComponent($0.rawValue) })
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testRejectsRelativeDirectoriesNonExecutablesAndDirectoriesNamedLikeCLIs() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LocalAgentDetection-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(to: directory.appendingPathComponent("hermes"))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: directory.appendingPathComponent("hermes").path)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("openclaw"), withIntermediateDirectories: false)
        XCTAssertTrue(LocalAgentDetection.detect(path: ".:relative:\(directory.path)").isEmpty)
    }
}
