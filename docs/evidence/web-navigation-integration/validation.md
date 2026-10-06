# Web navigation integration validation

Imported the five uncommitted files from `codex/web-navigation` at base `436832243bbd2ca87c8a224dfd0d492f3845e837` into `codex/webkit-services` after `f9b05275a501d170626879f71c0f14f52795689a`. The source worktree remained unchanged, verified by SHA-256 before and after integration. Import patch SHA-256: `01de09b2fb0f58dad589127e67ad0ff00a903ad032d2886451fabe14ed01c4cf`.

The final source hashes are in [source-fingerprints.json](source-fingerprints.json). They match the development build, the final fixture build inputs, and the reviewed changes. The newer New Blast toolbar and first-use sign-in flow remain present.

## Behavior

- Windows open centered at up to 1600 × 1100 points, capped to the actual window screen. Subsequent manual resizing is left alone during the session.
- Embedded browsers accept blank pages and data/blob child frames used by web login flows. Arbitrary protocols remain blocked; automatic child-frame blocking does not replace the parent page with a warning.
- Blank login popups stay in the embedded session. A successful load clears its transient navigation warning while preserving a persistent storage failure.
- Provider headers retain Reload and remove Home. Preview storage is separated by bundle ID, with the canonical preview's existing folder preserved.

## Tests and review

- Final app/core/UI test target build succeeded. The direct XCTest runner passed **111 tests, zero failures**; see [tests.log](tests.log). This is not a passing automated UI suite.
- Four added real-WKWebView regressions cover child document execution, silent blocking of automatic frames, recovery from navigation errors, and blank popup session continuity. Their HTML is synthetic; they do not authenticate to live providers.
- The storage-error regression failed before the fix (one test, two failures), then passed in the complete suite. See [regression-red.log](regression-red.log).
- Production AppModel/WindowCoordinator restoration, native attachment follow-ups and retry isolation, and quit/update deferral checks passed using controlled local inputs. See [controllers.log](controllers.log). One existing Sparkle fixture deprecation warning remains.
- The [frozen review](review.json) identified two P2 issues: use the actual restored window's screen and preserve storage errors through navigation recovery. Both were fixed; the [bounded recheck](recheck.json) has no remaining actionable findings.
- Physical multi-display restoration and real authenticated provider sign-in were not exercised. Preview-folder selection was inspected and compiled; no real preview data migration was performed.

## Native evidence

All screenshots show the final compiled native macOS fixture app using local synthetic web pages and simulated Messages. No live messages or private account data were used. Mobile screenshots do not apply to this native macOS application.

1. [Launch](01-launch.png): wider window with New Blast in the toolbar.
2. [Ready](02-ready.png): all four web agents selected and a synthetic request ready to send.
3. [Results](03-comparison-results.png): four dedicated fixture replies side by side, with Reload-only headers.
4. [New Blast](04-new-blast.png): request and selected agents retained.

[walkthrough.mp4](walkthrough.mp4) is a **12-second sampled walkthrough assembled from these four actual native captures with edited timing**. It is not continuous video, a latency measurement, or proof of live authentication. Navigation-policy cases are established by the tests; the video shows their surrounding native comparison workflow.

The blue-green development app was built and opened for the user. Its existing draft and selections remained intact. No live Send was pressed, no app in `/Applications` was replaced, no permissions were reset, and no release was published. The PR remains a draft pending live-provider verification.
