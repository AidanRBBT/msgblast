import Foundation
import CryptoKit
import Security
import LocalAuthentication
import Darwin

/// Stores encrypted credentials and an opaque, hardware-wrapped private key.
/// The Secure Enclave retains the actual private key; no plaintext key is written.
enum GrokBotCredentialVault {
    private struct Envelope: Codable {
        let version: Int
        let wrappedKey: Data
        let ephemeralPublicKey: Data
        let salt: Data
        let ciphertext: Data
    }
    private static let maximumBytes = 32 * 1024

    static func fileURL(for storageURL: URL) -> URL {
        let name = SHA256.hash(data: context(for: storageURL)).map { String(format: "%02x", $0) }.joined()
        return storageURL.deletingLastPathComponent()
            .appendingPathComponent(".grokbot-credentials", isDirectory: true)
            .appendingPathComponent(name + ".json")
    }
    private static func context(for storageURL: URL) -> Data {
        Data("msgblast.grokbot.credentials.v1\n\(Bundle.main.bundleIdentifier ?? "unknown")\n\(storageURL.standardizedFileURL.path)".utf8)
    }
    private static func authenticationContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }
    private static func encryptionKey(from shared: SharedSecret, salt: Data, identity: Data) -> SymmetricKey {
        shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt, sharedInfo: identity, outputByteCount: 32)
    }
    static func save(_ credentials: GrokBotCredentials, at storageURL: URL) throws {
        guard SecureEnclave.isAvailable,
              let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, .privateKeyUsage, nil) else {
            throw GrokBotServiceError.keychain
        }
        let plaintext = try JSONEncoder().encode(credentials)
        guard plaintext.count <= maximumBytes / 2 else { throw GrokBotServiceError.keychain }
        let hardwareKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: access, authenticationContext: authenticationContext())
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let salt = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let identity = context(for: storageURL)
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: hardwareKey.publicKey)
        let key = encryptionKey(from: shared, salt: salt, identity: identity)
        let sealed = try AES.GCM.seal(plaintext, using: key, authenticating: identity)
        guard let ciphertext = sealed.combined else { throw GrokBotServiceError.keychain }
        let envelope = Envelope(version: 1, wrappedKey: hardwareKey.dataRepresentation,
                                ephemeralPublicKey: ephemeral.publicKey.rawRepresentation, salt: salt, ciphertext: ciphertext)
        let data = try JSONEncoder().encode(envelope)
        guard data.count <= maximumBytes else { throw GrokBotServiceError.keychain }
        try writePrivately(data, to: fileURL(for: storageURL))
    }
    static func read(_ storageURL: URL) throws -> GrokBotCredentials? {
        guard let data = try readPrivately(fileURL(for: storageURL)) else { return nil }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.version == 1, envelope.salt.count == 32 else { throw GrokBotServiceError.keychain }
            let hardwareKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: envelope.wrappedKey, authenticationContext: authenticationContext())
            let ephemeral = try P256.KeyAgreement.PublicKey(rawRepresentation: envelope.ephemeralPublicKey)
            let identity = context(for: storageURL)
            let shared = try hardwareKey.sharedSecretFromKeyAgreement(with: ephemeral)
            let key = encryptionKey(from: shared, salt: envelope.salt, identity: identity)
            let box = try AES.GCM.SealedBox(combined: envelope.ciphertext)
            let plaintext = try AES.GCM.open(box, using: key, authenticating: identity)
            let value = try JSONDecoder().decode(GrokBotCredentials.self, from: plaintext)
            return try GrokBotCredentials(webhookURL: value.webhookURL.absoluteString, webhookKey: value.webhookKey)
        } catch { throw GrokBotServiceError.keychain }
    }
    private static func readPrivately(_ url: URL) throws -> Data? {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        if descriptor < 0, errno == ENOENT { return nil }
        guard descriptor >= 0 else { throw GrokBotServiceError.keychain }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? file.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_uid == getuid(),
              info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o077 == 0,
              info.st_size > 0, info.st_size <= maximumBytes,
              let data = try file.read(upToCount: maximumBytes + 1), data.count <= maximumBytes else {
            throw GrokBotServiceError.keychain
        }
        return data
    }
    private static func writePrivately(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let folder = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard folder >= 0 else { throw GrokBotServiceError.keychain }
        defer { close(folder) }
        var info = stat()
        guard fstat(folder, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o077 == 0 else {
            throw GrokBotServiceError.keychain
        }
        let temporaryName = ".\(UUID().uuidString).tmp"
        let descriptor = openat(folder, temporaryName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw GrokBotServiceError.keychain }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? file.close(); unlinkat(folder, temporaryName, 0) }
        try file.write(contentsOf: data)
        guard fsync(descriptor) == 0, renameat(folder, temporaryName, folder, url.lastPathComponent) == 0 else {
            throw GrokBotServiceError.keychain
        }
    }
}
