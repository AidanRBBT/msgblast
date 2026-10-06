# Quieter web-agent status

October 5, 2026. Native macOS captures from the final isolated fixture build; pages and account states are synthetic. No real prompts were sent or account sessions changed. Mobile screenshots do not apply.

The pane headers no longer display Chat ready / Needs attention / Not connected. Generic sign-in/layout banners are removed. My agents uses Open buttons without assuming the user is signed out. A nonempty shared draft displays one note listing unavailable agents; clearing the draft removes it. The Send & compare readiness gate, errors, receipts, and existing-page-draft warnings remain unchanged.

Verified in the native fixture: both Muse and ChatGPT signed out, empty composer has no MsgBlast readiness warnings; typing a draft shows one note and keeps Send disabled; clearing the draft removes the note. These three actual captures form the sampled video with edited timing. This is not a continuous recording or live-provider compatibility proof.

Final fixture and development builds passed. The idle development app was reopened and its clean headers checked against the real signed-out pages. No new unit tests were added for this reversible presentation change; the earlier core test results are unchanged, not rerun. A scoped lite correctness review found no findings.

Source SHA-256 (`MsgBlast/Windows/WebServicesView.swift`): `930b974a6425573e59a0ac7717a60af259c1aaca0bcde0edc2d2edfaf4c88e5b`.

- [Empty composer](01-empty.png)
- [Draft with one shared-send note](02-draft.png)
- [Cleared draft](03-cleared.png)
- [Sampled native walkthrough, edited timing](walkthrough.mp4)
