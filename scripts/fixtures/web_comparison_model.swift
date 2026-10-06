import AppKit
import msgblastCore

@main struct SideChatModelCheck {
    @MainActor static func waitUntil(_ check: () -> Bool) async throws {
        for _ in 0..<100 { if check() { return }; try await Task.sleep(for: .milliseconds(100)) }
        preconditionFailure("Model fixture did not reach expected state")
    }
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let model = AppModel()
        precondition(model.demo && model.local.url.path.contains("UIFixture"))
        model.coordinator = WindowCoordinator(model: model)
        let recipient = model.state.agents[0]
        let first = await model.prepareWebComparison("First comparison", recipientIDs: [recipient.id], providers: [.muse])!
        let muse = model.webAgents.sessions.first { $0.provider == .muse }!
        precondition(muse.fixture)
        muse.connect()
        try await waitUntil { muse.snapshot.ready }
        let a = await muse.send("First comparison", comparisonID: first)
        precondition(a?.status == .observed)
        await model.submit(first, retry: false)
        let second = await model.prepareWebComparison("Second comparison", recipientIDs: [], providers: [.muse])!
        let b = await muse.send("Second comparison", comparisonID: second)
        precondition(b?.status == .observed && a?.conversationURL != b?.conversationURL)
        model.coordinator?.open(first)
        try await waitUntil { muse.webView.url == a?.conversationURL }
        precondition(model.state.selection == [recipient.id])
        precondition(model.webAgents.selected.map(\.provider) == [.muse])
        precondition(model.webAgents.comparisonID == first)
        precondition(model.comparison(first)?.members.first?.submission == .submitted)
        let attachment = try model.local.stage(Data("fixture attachment".utf8), filename: "sidechat-followup.txt")
        for text in ["", "Text with attachment"] {
            model.setAttachmentDraft([attachment], comparisonID: first)
            model.state.comparisons[model.index(first)!].allDraft = text
            await model.followUp(first, recipients: [recipient.id])
            let followup = model.comparison(first)!.followUps.last!
            precondition(followup.states[recipient.id.uuidString] == .submitted)
            precondition(followup.payloads?[recipient.id.uuidString]?.parts.contains { $0.attachment?.id == attachment.id } == true)
            precondition(model.attachmentDraft(comparisonID: first).isEmpty)
        }
        let beforeRetry = muse.state.attempts.count
        let failed = FollowUp(text: "Controlled failed follow-up", memberIDs: [recipient.id])
        model.state.comparisons[model.index(first)!].followUps.append(failed)
        let k = model.state.comparisons[model.index(first)!].followUps.count - 1
        model.state.comparisons[model.index(first)!].followUps[k].states[recipient.id.uuidString] = .failed
        await model.followUp(first, retry: failed.id)
        precondition(model.comparison(first)?.followUps.last?.states[recipient.id.uuidString] == .submitted)
        precondition(muse.state.attempts.count == beforeRetry)
        print("PASS: attachment-only and text-plus-attachment native follow-ups submit their comparison drafts; native retry does not resend Muse. Controlled local fixture inputs.")
        print("PASS: actual AppModel + WindowCoordinator restore comparison ID, native recipient, Muse selection and original side-chat URL. All sends use local fixtures.")
    }
}
