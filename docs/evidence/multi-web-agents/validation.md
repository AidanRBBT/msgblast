# Embedded ChatGPT, Claude, and Grok — validation

User request: add the same embedded-agent functionality as Muse for ChatGPT, Claude, and Grok. Claude's web entry redirected to `claude.ai`; Grok here means `grok.com`, not Grok Bot.

## Test evidence

- Characterization before implementation: existing 55 core tests passed on October 5, 2026.
- Initial extension: 60 core tests passed; zero failures, zero skipped. Result: `build/webkit-validation/Logs/Test/Test-MsgBlast-2026.10.05_14-44-31--0700.xcresult`.
- Tests use actual WKWebView instances with nonpersistent, synthetic HTML. They exercise all four providers concurrently without attaching a window, first-send conversation URL assignment, repeated identical messages, outgoing observation, replies, independent draft/sign-out failures, ambiguous send controls, persistent per-provider identifiers, and legacy Muse selection/session migration. Existing storage, partial-broadcast, draft-edit, and personal-avatar tests remain covered.
- Direct native UI: selected ChatGPT, Claude, and Grok from My agents; sent one shared synthetic prompt; observed one outgoing message and one fixture reply in each pane. The shared draft cleared after submission.
- Existing XCTest UI-runner authorization limits are not represented as a passing UI suite. Native UI evidence was captured directly with the computer-use tool.

## Live verification boundary

The real signed-out ChatGPT page renders inside the isolated MsgBlast Web Preview. Read-only site inspection verified the current ChatGPT textarea label and Grok textarea/submit-control attributes. Claude requires authentication; Grok in the research browser presented a Terms update that was not accepted by the agent.

**Authenticated live selectors, real shared submissions, login retention after relaunch, and long-running background behavior are still unverified.** The user was asked to sign in inside the preview. New-provider account/menu and transcript selectors remain compatibility assumptions until that check completes. Local fixtures cannot establish live service compatibility. Unrecognized layouts leave shared sending disabled, with the actual website available in its pane.

No live prompts, private transcripts, credentials, or avatars were exported for this evidence. Icon validation used isolated builds before the user-requested development build was refreshed; no installed app in /Applications was replaced. Preview Messages are synthetic; live preview web services are real.

## Captures

Desktop native macOS UI only; mobile screenshots do not apply. All screenshots show the changed feature using local fixture pages, not the providers' actual signed-in interfaces. ChatGPT and Claude use bundled iOS App Store artwork. Grok uses the user-requested ImageGen adaptation for the circular avatar. Muse retains its website/personal-avatar behavior.

The video is a sampled walkthrough assembled from actual native screenshots with edited timing. It shows selection, a prepared shared prompt, observed messages and replies, and sign-out. The submission screenshot was captured after the fast fixture replies appeared. It is not a continuous screen recording, a timing benchmark, or proof of live service compatibility. Evidence remains within this private repository.

## Simplification

Applied: reuse Muse's inspect script; name selector tuple fields and the Muse workspace-state owner; avoid publishing identical sign-in snapshots or nil avatars on every poll. Deferred eager-session construction and transcript-scan changes because they alter lifecycle or snapshot behavior beyond a behavior-preserving cleanup.

## Final review and regression results

The completed full CE review covered nine lenses and returned two independently validated P2 findings. The [pre-fix receipt](../../reviews/2026-10-05-multiweb-pre-fix/review.json) records the original findings, not the fixed state. The external cross-model pass was unavailable; the adversarial lens ran locally.

- Hidden historical messages could be mistaken for new submissions. The baseline now includes hidden DOM messages and assigns stable per-node fallback identities, with transcript continuity required before accepting a new outgoing message.
- A same-document switch from a blank chat to an older conversation could confirm the wrong send. Trusted page interaction invalidates receipt collection; first-send URL transitions also reject conversation paths linked before submission.
- Four regressions failed before these fixes and pass afterward: revealing a hidden matching message, prepending history, editing during a send while switching chats, and selecting an existing sidebar conversation. An unconfirmed identical prompt remains blocked from automatic retry.
- Rendered paragraphs and line breaks are tested for all three new adapters. Receipt text normalizes block boundaries without including embedded action controls.

Final isolated core run: **65 passed, zero failed, zero skipped**, on macOS 27.2 (26B5091g), arm64. Result bundle: `build/webkit-validation/Logs/Test/Test-MsgBlast-2026.10.05_15-12-08--0700.xcresult`. The four targeted receipt regressions passed in the preceding nine-test provider run. Xcode emitted a QoS runtime warning; this is not a background-performance validation.

Both isolated fixture and live-preview packages rebuilt successfully after the fixes. The final native fixture repeated selection, a single shared send, three observed outgoing messages and three replies, then Claude sign-out with a retained new draft and disabled Send. [Build fingerprint](build.json) records the exact source bytes used for the captures; no source changes followed them.

- [Selected agents](01-agents.png)
- [Prepared shared prompt](02-ready.png)
- [Observed shared submission](03-submission.png)
- [Three replies](04-replies.png)
- [Sign-in needed and retained draft](05-signout.png)
- [Sampled fixture walkthrough, edited timing](multi-agent-walkthrough.mp4)

## Agent artwork refresh

October 5, 2026: bundled official iOS App Store ChatGPT/Claude images and an ImageGen Grok adaptation requested by the user after inspecting its App Store image. [Asset sources and generation prompts](../../../MsgBlast/Resources/WebAgentIcons.md). Isolated `build/icon-validation` and fixture builds passed. The built image bytes match the repository assets; native picker and 38-point headers render the final artwork. The existing Muse avatar path remains unchanged. No new unit tests were added for static artwork; the earlier 65-test core result above covers the unchanged core implementation.

All five captures and the sampled video were refreshed from the final icon revision. A local shared send produced all three outgoing messages and replies; Claude sign-out retained the shared draft and disabled Send. No real prompts were sent.
