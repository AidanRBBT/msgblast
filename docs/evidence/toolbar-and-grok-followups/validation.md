# Toolbar and Grok follow-ups

## Change and diagnosis

New Blast uses `square.and.pencil`, with matching horizontal/vertical padding on its label and the newly visible Add Agent label. Both existing actions are unchanged.

Grok follow-ups failed for two observed reasons: its Submit button was still disabled at 177 ms and enabled at 435 ms after filling; it also appended a UUID `rid` query parameter while retaining the same conversation path. A fixed 150 ms pause and an exact-URL check therefore rejected an otherwise valid prepared draft.

The session now polls readiness without clicking for up to five seconds before persisting the attempting state. The final click remains synchronous and rechecks the draft, conversation, known unique Send control and user interruption. A valid single Grok `rid` UUID is removed from persistent conversation identity; other queries, fragments, malformed IDs and different conversations remain rejected. No automatic resend was added.

## Verification

Final source: **121 XCTest cases passed, zero failures** (`tests.log`). The exact branch was checked for a clean merge against `origin/main` at `f86cce472649d5468792d04a86dd05a7b763774a`; this check did not modify either checkout.

- `xcodebuild build-for-testing` succeeded for the app, core tests and UI test target. The direct XCTest runner is used because the earlier Xcode test daemon stalled; an automated UI-suite pass is not claimed.
- Five regression tests cover delayed Send activation, the Grok response parameter, disabled-control timeout with draft retention, real navigation before the click, and changes to draft/destination/control ambiguity/trusted input.
- Two original red runs reproduced the disabled-control and exact-URL failures. Review corrected a test that had used the intentionally blocked native Reload action during sending; the replacement loads a different document and verifies navigation stops before attempting.
- The owner explicitly authorized `i want something fancy` to Grok only. Native UI verification deselected Muse, ChatGPT and Claude, submitted once, observed **Appeared in Grok**, one matching user message and Grok's reply in the existing conversation. The other providers were not resent. All four were reselected afterward without sending.
- New Blast returned to the agent picker. Add Agent opened its existing setup sheet; Done closed it without changing contacts. The final development build was reopened with saved logins and comparisons intact.
- Strict nested code-signature verification passed. The compiled icon was inspected and matches the saved blue-green development artwork. Repository artwork still matches the saved green production icon. No production app was replaced and no release was published.

## Capture provenance

`source-sha256.json` identifies the final reviewed source and tests. The development staging source matches it except for the required blue-green AppIcon artwork.

- `01-before.png`: prior toolbar at base revision `17a6a5d2f6beec6df054eb19f349a8447b065da1`.
- `02-picker.png`, `03-add-agent.png`: actual final reviewed native build, all four agents selected and no standalone Open buttons.
- `04-grok-followup.png`: actual authorized live follow-up and reply. Captured after the functional fix, immediately before the final 36-byte UUID validation hardening; that additional check changes only malformed UUID handling. The request was not resent to recreate evidence.
- `development-icon.png`: rendered from the final compiled app's `AppIcon.icns`.
- `walkthrough.mp4`: 23-second sampled walkthrough built from the above actual captures with edited timing. Shows old toolbar, final picker, Add Agent setup, return to picker and the earlier successful Grok-only follow-up. It is not continuous recording or a send-latency benchmark.

Evidence remains in the private repository. Mobile screenshots do not apply to this native macOS change. Provider website changes and sustained background operation remain unverified.
