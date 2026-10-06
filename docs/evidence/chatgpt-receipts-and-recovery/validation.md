# ChatGPT receipts and recovered readiness

ChatGPT's current search-message markup is now recognized alongside its older message markup. A search unit must name one distinct message ID and a user or assistant role. Repeated copies of the same ID are accepted; units containing different IDs cannot confirm a send. Transcript headings and action buttons are excluded from the message text. Existing navigation, baseline, draft and single-click protections remain in place.

The separate Open Muse/ChatGPT/Claude/Grok buttons are removed. Right-click Open chat and the saved comparison remain available. MsgBlast's sidebar stays open. ChatGPT's own explicitly expanded sidebar is closed once per document; later manual reopening is respected. Unknown or ambiguous controls are left alone.

The owner then reported sign-in/dialog warnings above visibly ready Muse and Claude chats. Read-only diagnostics established that both snapshots were ready while the native error retained an earlier setup warning. Temporary readiness errors now clear when the intended comparison URL becomes ready. Storage errors, draft protection and uncertain sends are not cleared by that recovery.

## Checks

- Base revision: `f5d34a29425279851bf5142ef9918025e3241f3d`; final source hashes are in `source-fingerprints.json`.
- `receipt-red.log` reproduces an unconfirmed ChatGPT send with the new markup on the old parser. `receipt-green.log` passes with the corrected parser.
- `readiness-red.log` reproduces the owner's two exact stale warnings. The final regression passes for both services, creates no send attempt during recovery and preserves an unrelated draft error.
- `full-tests.log`: **116 XCTest cases pass, zero failures**. The app and UI test target compile. Tests ran with Xcode's direct XCTest runner; this is not a passing automated UI test suite.
- Sidebar tests cover Toggle, Hide and narrow-dialog Close controls, collapsed controls, ambiguity, unrelated dialogs and manual reopening. The transcript regression covers multiline text and an identical follow-up with a distinct message ID.
- Focused correctness and independent local adversarial review found no substantive issues. The full delta and subsequent warning-recovery change received separate reads. External review was not performed.
- The final source merges cleanly with `origin/main` at `29eb2a95e9e4d58215cb632b2499721a3dfa3f95`; the primary checkout was not changed.

## Live verification

The owner's authorized ChatGPT-only breakfast request was submitted once from the shared composer after the Send-selector fix. ChatGPT returned a reply, but MsgBlast's old transcript parser left the receipt unconfirmed. The corrected parser subsequently read that existing conversation and identified exactly one matching outgoing message with a stable ID, plus its assistant reply. No additional live requests were sent.

That one existing uncertain receipt and its comparison URL were manually reconciled in the local state while the app was stopped, after saving a backup. This is a repair of the already-observed send, not evidence of a second live submission or a general automatic recovery feature. Fresh first sends and repeated follow-ups with the final parser were exercised only against local WebKit fixtures.

The clean final app reopens all four original live conversations with their replies. The final native walkthrough verifies that the stale warnings are gone, no standalone Open buttons appear in the post-send picker, ChatGPT's sidebar is collapsed, and MsgBlast's sidebar is open. Model and thinking settings were not changed.

The final development package uses the saved blue-green artwork. Its staging source differs from the reviewed production source only in `AppIcon.icon/icon.json`; the compiled icon was inspected and the signature verified. The repository retains its green production artwork. No app in `/Applications` was overwritten and no release was published.

## Screenshots and video

- `01-picker.png`: actual post-send picker, all four web agents selected, no Open buttons, MsgBlast sidebar open.
- `02-restored-comparison.png`: actual saved conversations after the fixes, without stale readiness warnings.
- `03-reopened.png`: those same conversations after returning from the picker, with saved URLs and no resends.

`walkthrough.mp4` is a **12-second sampled walkthrough made from three actual native captures with edited timing**. It shows picker → saved comparison → comparison reopened. It is not continuous recording, a latency benchmark or a fresh send. Screenshots show the owner's already-existing breakfast conversation. Evidence stays within this private repository. Mobile screenshots do not apply to the native macOS app.

Opening a separate fixture app for new UI recording was rejected by automatic approval review. The screenshots above come from the separately authorized final development app. No synthetic reply is presented as a live response. Older fixture evidence elsewhere in the PR remains labeled with its original revision.

Future provider markup changes, live follow-up sends with this final parser, and sustained background operation remain unverified.
