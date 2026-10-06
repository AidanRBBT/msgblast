# Agent picker defaults and post-send controls

Captured 2026-10-05 from the five-file follow-up to `add1cfd`, identified by `source-sha256.json`. Native macOS app; mobile screenshots do not apply.

## Results

- All four web providers start selected. The new regression failed against the old defaults, then passed; explicitly deselecting Grok survives recreating WebAgents with the same storage directory and preserves session IDs.
- All 103 core XCTest cases passed using the direct XCTest runner. The production controller fixture script also passed native follow-ups, retry isolation, saved conversation restoration, and quit/update deferral.
- The updated UI test target compiled. Automated UI execution is not claimed; native accessibility controls exercised the picker workflow manually.
- Fresh My agents: Muse, ChatGPT, Claude and Grok selected, no Open buttons. Native demo contacts were manually deselected solely to keep this demonstration to four web providers.
- Right-click Muse → Open chat: the existing embedded website panes appear without changing recipients. These are local signed-in page fixtures, not a real login demonstration.
- Returned to the picker, sent one synthetic prompt, and observed all four outgoing messages/replies.
- Returned to My agents: all four Open buttons appear. Open Muse returns to the same saved conversations. New comparison hides those buttons again.
- Existing persisted deselections remain unchanged on upgrade. No live messages were sent and no user data or macOS permissions were changed.
- Lite code review completed with no findings; source fingerprints and receipt are included. Separate simplification reviewers found no reuse, quality, or efficiency findings.

## Screenshots and video

`01-default-selected.png` → `02-context-menu.png` → `03-embedded-chat.png` → `04-synthetic-send.png` → `05-open-after-send.png` → `06-new-comparison.png`.

`walkthrough.mp4` is an 18-second sampled walkthrough of those six actual native captures with edited timing. It is not a continuous recording, latency measurement, or live-provider compatibility test. All page content and account controls are local fixtures. Corresponding accessibility snapshots are included.

## Reproduction

Build the core test bundle with `xcodebuild -project msgblast.xcodeproj -scheme msgblast -derivedDataPath build/sidechat-validation -destination 'platform=macOS,arch=arm64' -only-testing:msgblastTests build-for-testing -quiet`; execute it with the Xcode XCTest runner and `DYLD_FRAMEWORK_PATH` set to its Debug products directory. Run `bash scripts/test_web_comparisons.sh build/sidechat-validation` for production controller checks.

Build the native fixture with `zsh scripts/build_web_preview.sh --fixture`, then open `build/msgblast Muse Fixture.app`. Its bundle identity and data are isolated from the live app; shared sends run against local HTML. Each isolated demo launch starts fresh.
