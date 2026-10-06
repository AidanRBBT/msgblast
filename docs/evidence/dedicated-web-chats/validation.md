# Dedicated web conversations and Discover cleanup

Captured October 5, 2026 from the actual native macOS fixture build. The final changed source is fingerprinted in [source-sha256.json](source-sha256.json); the commit containing this document carries that source. Web-chat captures precede the unrelated Discover-footer deletion; both previews were rebuilt after that deletion, and Discover's after capture uses the rebuilt app.

## Results

- **102 tests passed, zero failures** in the compiled `msgblastTests.xctest` bundle using the direct XCTest runner. Xcode's test daemon had stalled before starting cases; this is not an automated UI-suite pass. [Full result](core-tests.txt).
- Each of Muse, ChatGPT, Claude, and Grok creates distinct saved URLs for two comparisons, preserves the original URL on follow-up, and restores the selected comparison. Newly constructed sessions retain saved mappings and their WebKit identifiers. Legacy Muse mappings decode and re-encode without losing URLs.
- Optimistic outgoing text on a new-chat URL remains unconfirmed; subsequent sends in that comparison are blocked instead of silently allocating another chat.
- Manual native UI use exposed a contenteditable follow-up failure after the shared composer took focus. A regression failed before the selection-restoration fix and passed afterward. The final native walkthrough successfully sends the follow-up to all four agents.
- Production AppModel/WindowCoordinator and AppLifecycle checks passed: restore all four saved URLs and selection, native attachment follow-ups, native retry without resending Muse, and quit/update deferral. [Results and the fixture-only Sparkle deprecation warning](controller-checks.txt).
- Both [local fixture](fixture-build.txt) and [live web preview](live-build.txt) build and sign successfully. The development app and `/Applications` were not replaced.
- The linked chat's exact Discover footer removal is included: no Agent directory link or Directory snapshot text; search, categories, and agent cards remain.
- Standard GPL-3.0-only text was downloaded unchanged from SPDX's license-list-data repository. README explicitly selects version 3 only and preserves third-party rights. No runtime behavior is changed by this license addition, so it has no separate UI recording.
- Focused review had no actionable findings. [Initial review](review.json), [adversarial follow-up](adversarial.json), and [final supplement](review-supplement.json) document scope and limitations.

## Screenshots and video

All web pages and replies shown are **local synthetic fixtures**. No live messages, private conversations, real Contacts writes, update downloads, or external agent actions occurred. The same production views, WKWebViews, composer, and controllers run the workflow. The fixture's in-memory transcript restoration does not prove server-side history retention.

1. [Four agents and first prompt](01-ready.png)
2. [First dedicated conversations and replies](02-first-result.png)
3. [Follow-up prompt](03-followup-ready.png)
4. [Follow-up in the same conversations](04-followup-result.png)
5. [New comparison](05-new-comparison.png)
6. [Second prompt](06-second-ready.png)
7. [Four distinct second conversations](07-second-result.png)
8. [Original comparison and conversations restored](08-reopened.png)
9. [Discover before](09-discover-before.png)
10. [Discover after](10-discover-after.png)

[Play the walkthrough](walkthrough.mp4). This is a **25-second sampled walkthrough assembled from ten actual native captures, with edited timing**. It is not continuous recording or a latency measurement. Desktop captures are 3840 × 1520; video is 1920 × 760. This is a native macOS app, so mobile screenshots do not apply. Screenshots/video remain in this private repository.

## Reproduce

```sh
xcodebuild -project msgblast.xcodeproj -scheme msgblast \
  -derivedDataPath build/sidechat-validation -destination 'platform=macOS,arch=arm64' \
  -only-testing:msgblastTests build-for-testing -quiet
DYLD_FRAMEWORK_PATH="$PWD/build/sidechat-validation/Build/Products/Debug" \
  /Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Xcode/Agents/xctest \
  build/sidechat-validation/Build/Products/Debug/msgblastTests.xctest
bash scripts/test_web_comparisons.sh build/sidechat-validation
zsh scripts/build_web_preview.sh --fixture
zsh scripts/build_web_preview.sh
```

## Live validation remaining

The real Muse preview is signed out. Authenticated creation/reopening/history for every provider, login persistence after relaunch, trusted-input interruption, anti-automation behavior, and long-running background operation are not established by these fixtures. Unknown layouts disable shared sends while keeping each website available. The PR remains a draft for this live-validation boundary; no release was published.
