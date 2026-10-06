# Signed-in provider layouts and ChatGPT Send

The signed-in narrow panes exposed control structures that the adapters did not recognize. Muse renders separate nested transcript markers; ChatGPT and Claude hide account controls with the sidebar; ChatGPT and Grok use rich editors; Grok exposes its profile through a menu image. ChatGPT additionally labels its send button **Send**, instead of the previously supported **Send message** or **Send prompt**.

The adapters now recognize those observed variants. Known account markup can be hidden, but a visible login button still blocks readiness. The editor and Send control must remain unique and visible; disabled controls, existing drafts, navigation changes and ambiguous outcomes retain their protections.

## Revision and checks

- Base: `fe7d1b0f32b9a6cf17e6e648c530a1d212717e5e`, plus the three source changes fingerprinted in `source-fingerprints.json`.
- `readiness-red.log`: the observed-layout regression fails before the readiness fixes.
- `chatgpt-send-red.log`: after adding the actual Send label to the fixture, ChatGPT returns notSent, creates no saved URL, and emits no outgoing message.
- `chatgpt-send-green.log`: the corrected selector passes the same regression for all four providers.
- `full-tests.log`: **112 tests passed, zero failures**, using the compiled XCTest bundle with the direct Xcode runner. This is not a passing automated UI suite.
- `controllers.log`: production AppModel/WindowCoordinator restoration, native retry isolation and quit/update deferral pass. These controllers are unchanged by the final Send-selector adjustment.
- `review.json`: focused correctness and independent adversarial review; no remaining findings. Review does not claim unperformed live checks.
- Current main `29eb2a95e9e4d58215cb632b2499721a3dfa3f95` merges cleanly. This check did not modify the primary checkout.

## Native fixture walkthrough

The app uses its real shared composer, persistent comparison mapping and WebKit adapters. Its local fixture HTML was adjusted to the observed control shapes, including ChatGPT's **Send** label. `fixture-only-changes.patch` records the demonstration-only WebAgentSession change; production WebPageScript and MusePageScript are byte-identical to the reviewed source. These staging changes are not shipped.

1. `01-request.png`: only the four web agents are selected, with a synthetic request ready.
2. `02-results.png`: one submission per service, four dedicated URLs, observed receipts and fixture replies.
3. `03-follow-up.png`: the next shared prompt appears in those same four chats, with replies and observed receipts.

`walkthrough.mp4` is a **12-second sampled walkthrough of three actual native captures with edited timing**, not continuous video, a latency benchmark, or live provider evidence. All messages and responses shown are local fixtures. Mobile screenshots do not apply to this native macOS app. Evidence remains in this private repository.

## Live checks and limits

The owner submitted the breakfast request in the blue-green development build and reported success for Muse, Claude and Grok. Inspection confirmed the outgoing text, responses and dedicated conversation URLs. ChatGPT contained the correct unsent draft and an enabled **Send** button, matching the reproduced selector failure.

The owner authorized sending the same request to ChatGPT only. The request was preserved in MsgBlast's shared composer and the unsent page draft cleared for a fresh adapter test. Automatic approval review then blocked restarting the signed-in app to load the fix; permission to reopen is pending. No second prompt was submitted to the other three services. The post-fix live ChatGPT submission is therefore not yet claimed here.

The fixed blue-green development package is built and code-signature verified; no installed app was overwritten, no release was published, and no signing-in state was reset. Future provider DOM changes, sustained background operation and real-server history restoration still require live testing.

## Reproduction

Build with Xcode's `build-for-testing`, Debug, macOS arm64 and isolated derived data. Run the resulting XCTest bundle with Xcode's `Agents/xctest`, setting `DYLD_FRAMEWORK_PATH` to its Debug products directory. Focus the regression with `-XCTest msgblastTests.MultiWebAgentTests/testSignedInNarrowLayoutsCanSendWithHiddenAccountControlsAndRichEditors`; omit the filter for the full suite.
