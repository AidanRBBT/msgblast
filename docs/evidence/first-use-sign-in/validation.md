# First-use sign-in and saved request

The first Send & compare opens the selected agent pages and a Connect your accounts overlay. The shared request stays in the composer. Sign-in never submits by itself; the user must press Send & compare again once the chats are ready.

## Verified

- 107 core XCTest cases passed with zero failures on the final fresh-inspection logic.
- Two new regressions failed before fixing stale comparison identity and login completion during setup. A separate stale-polling-snapshot variant also failed before its fix. All pass afterward.
- Production AppModel/WindowCoordinator fixture checks passed for native draft/attachment follow-ups, native retry isolation, saved chat restoration, and quit/update deferral.
- Final native fixture walkthrough: all four selected, signed out, first Send opens overlay, request retained, sign-in produces no messages, explicit second Send produces one outgoing message and one fixture reply in each dedicated chat. The shared composer clears afterward.
- The app and UI test targets compile. The Xcode test daemon previously stalled before running UI cases; this document does not claim an automated UI suite pass.
- Focused correctness review and an independent local adversarial review found two issues, both fixed and rechecked. The final scoped review has no remaining findings. Cross-model egress had been rejected by automatic approval review, so this was a local review, not a cross-model pass.
- The comparison-chat shortcut remains unchanged. Core task callers explicitly discard the new readiness result where appropriate.

## Evidence

Screenshots are actual native macOS captures from the final fixture build, with synthetic pages and prompts. No live account messages were sent. Mobile does not apply to this native macOS UI.

The 18-second MP4 is a sampled walkthrough made from six actual screenshots with edited timing: saved request, first-use overlay, sign-in pages, signed-in/unsent state, then explicit-send results across all four agents. It is not continuous recording or a latency measurement.

Source fingerprints and review scope are in `review.json`; before/after regression logs are alongside it. The live development build uses the saved blue-green icon and the existing `com.msgblast.mac` identity. No release/tag, permission reset, or replacement of `/Applications` is part of this change.

## Limits

Real unsigned provider pages were inspected. Authenticated provider sending, follow-ups, login persistence and future DOM compatibility remain unverified; fixture success does not establish those behaviors. A login redirect that first needs to open a dedicated chat prepares it without sending and can require another explicit Send once ready.

## Reproduction

Build with `xcodebuild -project msgblast.xcodeproj -scheme msgblast -derivedDataPath build/first-use-final -destination 'platform=macOS,arch=arm64' build-for-testing`.

Run the compiled core XCTest bundle with Xcode's direct `xctest` runner and `DYLD_FRAMEWORK_PATH` set to `build/first-use-final/Build/Products/Debug`. Run `bash scripts/test_web_comparisons.sh build/first-use-final` for production-controller fixtures.
