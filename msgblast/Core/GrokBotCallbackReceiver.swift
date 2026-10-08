import Foundation
import Network
import CryptoKit

/// The tunnel exposes only this authenticated reply route. The listener binds to loopback.
@MainActor
public final class GrokBotCallbackReceiver {
    static let rejectionBody = "{\"error\":\"callback_rejected\"}"
    private var listener: NWListener?
    private var startup: CheckedContinuation<URL, Error>?
    private var clients: [UUID: GrokBotHTTPConnection] = [:]
    private var tokenHashes: [UUID: Data] = [:]
    private var completed: [UUID: Data] = [:]
    var onDrained: (() -> Void)?
    var hasActiveConnections: Bool { !clients.isEmpty }
    private let onReply: (GrokBotReceipt) throws -> Void
    public init(onReply: @escaping (GrokBotReceipt) throws -> Void) { self.onReply = onReply }
    public func register(id: UUID, tokenHash: Data) { tokenHashes[id] = tokenHash }
    public func start() async throws -> URL {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        return try await withCheckedThrowingContinuation { continuation in
            startup = continuation
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                Task { @MainActor in
                    guard let self, let startup = self.startup else { return }
                    switch state {
                    case .ready:
                        self.startup = nil
                        if let port = listener?.port { startup.resume(returning: URL(string: "http://127.0.0.1:\(port.rawValue)")!) }
                        else { startup.resume(throwing: GrokBotServiceError.callbackUnavailable) }
                    case .failed, .cancelled:
                        self.startup = nil; startup.resume(throwing: GrokBotServiceError.callbackUnavailable)
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.start(queue: .main)
        }
    }
    public func stop() {
        onDrained = nil
        listener?.cancel(); listener = nil
        startup?.resume(throwing: GrokBotServiceError.callbackUnavailable); startup = nil
        let open = Array(clients.values); clients = [:]; open.forEach { $0.stop() }
    }
    private func accept(_ connection: NWConnection) {
        let id = UUID()
        let client = GrokBotHTTPConnection(connection: connection, handle: { [weak self] path, headers, data in
            self?.receive(path: path, headers: headers, body: data) ?? 503
        }, finished: { [weak self] in
            guard let self else { return }
            self.clients[id] = nil
            if self.clients.isEmpty { self.onDrained?() }
        })
        clients[id] = client
        client.start()
    }
    private func receive(path: String, headers: [String: String], body: Data) -> Int {
        let parts = path.split(separator: "/")
        guard parts.count == 2, parts[0] == "reply", let id = UUID(uuidString: String(parts[1])), let expected = tokenHashes[id] else { return 404 }
        guard let auth = headers["authorization"], auth.hasPrefix("Bearer "),
              Data(SHA256.hash(data: Data(auth.dropFirst(7).utf8))) == expected else { return 401 }
        do {
            let receipt = try GrokBotService.decodeReceipt(body, id: id)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let signature = Data(SHA256.hash(data: try encoder.encode(receipt)))
            if let previous = completed[id] { return previous == signature ? 200 : 409 }
            try onReply(receipt)
            completed[id] = signature
            return 200
        } catch GrokBotServiceError.invalidReply { return 400 }
        catch GrokBotServiceError.callbackUnavailable { return 410 }
        catch { return 503 }
    }
}

@MainActor
private final class GrokBotHTTPConnection {
    private let connection: NWConnection
    private let handle: (String, [String: String], Data) -> Int
    private let finished: () -> Void
    private var data = Data()
    private var ended = false
    private var timeout: Task<Void, Never>?
    private var parsed: (path: String, headers: [String: String], offset: Int, end: Int)?
    init(connection: NWConnection, handle: @escaping (String, [String: String], Data) -> Int, finished: @escaping () -> Void) {
        self.connection = connection; self.handle = handle; self.finished = finished
    }
    func start() {
        connection.start(queue: .main)
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            self?.respond(408)
        }
        read()
    }
    func stop() { guard !ended else { return }; ended = true; timeout?.cancel(); connection.cancel(); finished() }
    private func read() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] chunk, _, complete, error in
            Task { @MainActor in
                guard let self, !self.ended else { return }
                if let chunk { self.data.append(chunk) }
                guard self.data.count <= GrokBotService.maximumBytes + 8192 else { self.respond(413); return }
                if self.inspect() { return }
                if complete || error != nil { self.respond(400) }
                else { self.read() }
            }
        }
    }
    // Only bounded, non-chunked JSON POSTs are accepted. No files or other app routes are served.
    private func inspect() -> Bool {
        if let parsed {
            if data.count < parsed.end { return false }
            guard data.count == parsed.end else { respond(400); return true }
            respond(handle(parsed.path, parsed.headers, data[parsed.offset..<parsed.end]))
            return true
        }
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else {
            if data.count > 8192 { respond(431); return true }
            return false
        }
        guard separator.lowerBound <= 8192, let header = String(data: data[..<separator.lowerBound], encoding: .utf8) else { respond(400); return true }
        let lines = header.components(separatedBy: "\r\n")
        let request = lines[0].split(separator: " ")
        guard request.count == 3, request[0] == "POST", request[2] == "HTTP/1.1" || request[2] == "HTTP/1.0" else { respond(405); return true }
        var fields: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { respond(400); return true }
            let key = line[..<colon].lowercased(), value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, fields[key] == nil else { respond(400); return true }
            fields[key] = value
        }
        guard fields["transfer-encoding"] == nil, let rawLength = fields["content-length"], rawLength.allSatisfy({ $0.isNumber }), let length = Int(rawLength), length > 0 else { respond(400); return true }
        guard length <= GrokBotService.maximumBytes else { respond(413); return true }
        guard fields["content-type"]?.split(separator: ";").first?.trimmingCharacters(in: .whitespaces).lowercased() == "application/json" else { respond(415); return true }
        let end = separator.upperBound + length
        parsed = (String(request[1]), fields, separator.upperBound, end)
        return inspect()
    }
    private func respond(_ status: Int) {
        guard !ended else { return }
        ended = true; timeout?.cancel()
        let body = status == 200 ? "{\"status\":\"recorded\"}" : GrokBotCallbackReceiver.rejectionBody
        let response = "HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] _ in
            Task { @MainActor in self?.connection.cancel(); self?.finished() }
        })
    }
}
