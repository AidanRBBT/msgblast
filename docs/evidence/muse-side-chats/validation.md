# Muse side-chat validation — October 5, 2026

Integrated `origin/main` at `5142076` in merge `f838cb5`, retaining lowercase app/module names, installation guidance, Sparkle, reports, and the branch's embedded agents. A final fetch confirmed main remained an ancestor. The primary checkout's unrelated uncommitted work was not touched.

## Results

- **96 XCTest cases passed, zero failures**, using the built `msgblastTests.xctest` bundle and real WKWebViews with local pages. See [tests.log](tests.log). The Xcode build succeeded, but its test daemon timed out before running cases; the same bundle then passed through the direct XCTest runner. This is not an automated UI-suite pass.
- `bash scripts/test_web_comparisons.sh build/sidechat-validation` passed. It compiles actual AppModel/WindowCoordinator and AppLifecycle source with controlled fixtures: restores comparison URL and recipients, submits attachment-only and text-plus-attachment native follow-ups, retries native failures without resending Muse, defers quit and update during web sends, and releases a pending update exactly once. No real Messages, updater, download, or termination runs. The lifecycle fixture uses a deprecated Sparkle item initializer solely to construct local test data. See [controller-checks.log](controller-checks.log).
- The existing personal-agent shutdown/persistence controller check passed after integration.
- Both isolated preview packages rebuilt successfully. No `/Applications` app was replaced and no release was published.
- Manual native UI checks on the final fixture: Muse + Cedar initial prompt, shared follow-up in the same side chat, a new Muse-only comparison with a different side chat, and reopening the first comparison from its sidebar row. Its original URL, native recipient, transcript, and comparison-specific receipt returned.

Final runtime source/assets are identified by [source-sha256.txt](source-sha256.txt). The packaged app was built from that source before capture. Subsequent changes only add validation scripts, documentation, and evidence.

## Captured workflow

All images are actual native macOS captures of **local synthetic web pages and simulated Messages**. Prompts and replies are controlled test data. Mobile screenshots do not apply to this native macOS feature.

1. `01-selected.png`: Muse and Cedar selected; first prompt prepared.
2. `02-first-send.png`: submission creates `/thread/f047fb49-0846-45a9-8cc4-bebdcafa328b`.
3. `03-first-reply.png`: first observed prompt and replies.
4. `04-follow-up-send.png`, `05-follow-up-result.png`: follow-up retains the first UUID.
5. `06-second-send.png`, `07-second-result.png`: new Muse-only comparison creates `/thread/3e128313-883c-4c88-811e-2d9415096db0`.
6. `08-reopened.png`: sidebar restores the first UUID, Cedar, and the correct “Make it 20 minutes.” receipt.

[walkthrough.mp4](walkthrough.mp4) is a 20-second sampled walkthrough built from these eight captures, held for 2.5 seconds each. Timing is edited; this is not a continuous recording or a latency benchmark. The images are not composited mockups. Evidence stays in the private repository.

## Review follow-up

The [pre-fix review](../../reviews/2026-10-05-muse-side-chats/review.json) found four P2 issues. All were addressed:

- Attachment import/display/removal now use the same comparison draft that native followUp consumes. Controller checks cover both payload forms.
- Comparison changes invalidate pending reopen work; readiness polls cannot publish stale errors or restore an earlier selection. A regression overlaps opens and clears selection while an open is pending.
- Embedded comparisons now render the existing native FollowUpStatus/recovery controls, disabled during either kind of send. The controller fixture verifies native retry does not call Muse.
- The native header displays the actual current host; “Side chat” is appended only for an allowlisted Muse chat URL. The captured fixture shows `muse.ai · Side chat`; arbitrary live-host navigation was not exercised.

Additional checks cover per-comparison receipts, fresh page drafts during switching, invalid saved URLs, main-chat redirects, optimistic messages without an assigned thread, persistence, and ambiguous receipt attribution. An invalid saved URL is preserved and blocks sending.

## Live boundary

The Muse frontend bundled in the installed app uses `/thread/new` and assigns a UUID session on first send; this informed the route adapter. The live preview is signed out, so **authenticated Muse side-chat creation and follow-up remain unverified**. No live prompt was sent in this change. Safari cookies were not read or copied.

ChatGPT, Claude, and Grok's authenticated layouts, login persistence after relaunch, and long-running background operation remain pending as documented in earlier branch evidence. The Muse trusted-user interruption listener has no new trusted-input test here; synthetic URL/history regressions pass but do not establish that branch. These limitations keep the PR in draft. Unknown layouts and ambiguous sends stop shared automation rather than falling back to Muse's main chat.
