import Foundation
import msgblastCore

extension AppModel {
    func attachmentDraft(comparisonID: UUID? = nil, memberID: UUID? = nil) -> [MessageAttachment] {
        guard let comparisonID, let comparison = comparison(comparisonID) else { return state.attachmentsDraft ?? [] }
        return memberID.map { comparison.privateAttachmentDrafts?[$0.uuidString] ?? [] } ?? comparison.allAttachmentsDraft ?? []
    }
    func setAttachmentDraft(_ files: [MessageAttachment], comparisonID: UUID? = nil, memberID: UUID? = nil, saveNow: Bool = true) {
        let previous = attachmentDraft(comparisonID: comparisonID, memberID: memberID)
        if let comparisonID, let i = index(comparisonID) {
            if let memberID {
                if state.comparisons[i].privateAttachmentDrafts == nil { state.comparisons[i].privateAttachmentDrafts = [:] }
                state.comparisons[i].privateAttachmentDrafts?[memberID.uuidString] = files
            } else { state.comparisons[i].allAttachmentsDraft = files }
        } else { state.attachmentsDraft = files }
        if saveNow {
            do {
                try save()
                for file in previous where !files.contains(where: { $0.id == file.id }) { local.removeUnreferenced(file, in: state) }
            } catch { self.error = error.localizedDescription }
        }
    }
    func addAttachments(_ selection: AttachmentImport, comparisonID: UUID? = nil, memberID: UUID? = nil) async {
        let store = local
        let imports: [AttachmentImport]
        switch selection {
        case .files(let urls): imports = urls.map { .files([$0]) }
        case .image: imports = [selection]
        }
        for item in imports {
            do {
                let file = try await Task.detached(priority: .userInitiated) {
                    switch item {
                    case .files(let urls): return try store.stage(urls[0])
                    case .image(let data, let filename): return try store.stage(data, filename: filename)
                    }
                }.value
                var draft = attachmentDraft(comparisonID: comparisonID, memberID: memberID)
                draft.append(file)
                setAttachmentDraft(draft, comparisonID: comparisonID, memberID: memberID)
            } catch { self.error = "Could not attach the file: \(error.localizedDescription)" }
        }
    }
    func claimedAnchors(chatID: String, except payload: OutgoingPayload) -> Set<String> {
        let own = Set(payload.parts.map(\.id))
        var claimed = Set<String>()
        for comparison in state.comparisons {
            for member in comparison.members where member.chat.id == chatID {
                if member.payload == nil, let anchor = member.anchor { claimed.insert(anchor.guid) }
                let payloads = [member.payload].compactMap { $0 } + comparison.followUps.compactMap { $0.payloads?[member.id.uuidString] }
                for part in payloads.flatMap(\.parts) where !own.contains(part.id) {
                    if let anchor = part.anchor { claimed.insert(anchor.guid) }
                }
            }
        }
        return claimed
    }
    func deliver(_ original: OutgoingPayload, to chat: Chat, simulateFailure: Bool = false, update: (OutgoingPayload) throws -> Void) async -> OutgoingPayload {
        var payload = original
        do {
            payload.reconcile(in: try latest(chat), excluding: claimedAnchors(chatID: chat.id, except: payload))
            try update(payload)
        } catch { self.error = error.localizedDescription; return payload }
        guard payload.submission != .uncertain else { return payload }
        for p in payload.pendingIndices {
            // An accepted send is never repeated. Wait for its receipt before sending the next part.
            guard payload.parts[..<p].allSatisfy({ $0.state == .submitted && $0.anchor != nil }) else { break }
            var attempted = false
            do {
                try validate(chat)
                if simulateFailure && payload.parts[p].attachment != nil {
                    demoFailureOnce = false
                    throw SendFailure.notSubmitted("Simulated failure before submission. Only unsent parts will be retried.")
                }
                payload.parts[p].baseline = try latest(chat).map(\.id).max() ?? 0
                payload.parts[p].attemptedAt = Date()
                payload.parts[p].state = .sending; payload.parts[p].error = nil
                try update(payload)
                attempted = true
                let part = payload.parts[p]
                if demo {
                    appendDemo(part.text ?? "", chat: chat, outgoing: true, attachments: part.attachment.map { [$0] } ?? [])
                } else if let file = part.attachment { try await MessageSender().send(file, to: chat) }
                else if let text = part.text { try await MessageSender().send(text, to: chat) }
                payload.parts[p].state = .submitted
                payload.parts[p].error = "Submitted, awaiting a history receipt. Refresh to reconcile."
                try update(payload)
                for _ in 0..<6 {
                    let fresh = try latest(chat)
                    payload.reconcile(in: fresh, excluding: claimedAnchors(chatID: chat.id, except: payload))
                    messages[chat.id] = fresh
                    if payload.parts[p].anchor != nil { break }
                    try await Task.sleep(for: .milliseconds(500))
                }
                try update(payload)
                if payload.parts[p].anchor == nil { break }
            } catch {
                payload.parts[p].state = Submission.failure(afterAttempt: attempted, error: error)
                payload.parts[p].error = error.localizedDescription
                do { try update(payload) } catch { self.error = error.localizedDescription }
                break
            }
        }
        return payload
    }
}
