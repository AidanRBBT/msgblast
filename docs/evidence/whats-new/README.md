# What’s New sidebar evidence

Captured October 6, 2026 from this change's native macOS app, using an isolated blue-icon demo build with marketing version 0.6.0 and local build 1. Version 0.6.0 is a prepared release, not a claim of public distribution.

The demo has its own bundle identifier (`com.msgblast.whats-new-evidence-v2`), temporary fixture data, simulated agents, and disabled updater configuration. No real messages, Contacts writes, account sign-ins, or paid requests were used. The production app was not replaced or launched. Mobile screenshots do not apply to this native macOS UI.

## Screenshots

- `sidebar-unread.png`: unread card with the installed version.
- `history-current.png`: three highlights, version heading, contributor shout-outs, and full-notes control.
- `history-previous.png`: prior version's compact highlights and contributor credits.
- `history-full.png`: the same prior version expanded to its full notes.
- `sidebar-viewed.png`: cleared unread highlight with the version still visible.

## Video

`whats-new-walkthrough.mp4` sequences those actual app captures in interaction order, with edited four-second holds. It shows unread → current notes → prior notes → full notes → viewed. This is an app-state walkthrough, not continuous screen recording. The original screenshots are retained above; the video is scaled and padded to fit a consistent frame.

## Verification

- Native Xcode unit suite: 147 tests passed before the shorter format and credits were added.
- Final UpdateTests: 8 tests passed, covering version ordering, future/unpublished exclusion, missing notes, concise highlights, and retained contributor credits/full notes, along with existing updater safety checks.
- Short-format tests first failed because highlight/credit fields did not exist, then passed after implementation.
- Manual native checks: open current notes, select a prior version, expand full notes, close the sheet, quit/relaunch, and verify the viewed state persists. Latest-version selection, shortened copy, contributor links, and version heading were checked in the actual UI.
- Contributor handles were verified against GitHub commit ranges: 0.2.0→0.2.1 includes `anishthite` and `mgalpert`; 0.5.0→0.5.1 includes `mgalpert` and `cursoragent`. The 0.6.0 acknowledgment names Sequoia support as an earlier contribution.
- Three simplification lenses ran; immutable history caching was applied. Final scoped correctness review found no actionable issues.

Build and test with:

```sh
xcodebuild -project msgblast.xcodeproj -scheme msgblast -configuration Debug \
  -derivedDataPath build/whats-new -destination 'platform=macOS,arch=arm64' \
  ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo MARKETING_VERSION=0.6.0 \
  -only-testing:msgblastTests/UpdateTests test
```

The initial SwiftPM attempt encountered existing `MessagesAccessGuide` test compilation errors; the native Xcode target above is the authoritative passing check. Packaging the demo changes only its copied bundle metadata and ad-hoc signature, as described above.
