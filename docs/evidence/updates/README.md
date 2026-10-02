# Native updater evidence

Actual macOS updater interactions from this branch’s isolated Debug build on October 2, 2026. A temporary ad-hoc app named MsgBlast Update Fixture used synthetic Cedar data and a signed localhost appcast/archive. No real messages, Contacts writes, production hosting, Developer ID signing or notarization were exercised. Mobile screenshots are not applicable to this native macOS app.

The video assembles actual interaction screenshots with condensed pauses, rather than continuous screen recording. It shows Settings switches changing, Check for Updates, native Sparkle release notes and Install Update, Ready to Install, the retained draft/attachment after Install and Relaunch, and version 0.1.2 (2) with both preferences retained. The native up-to-date alert was also verified through accessibility; its screenshot API returned blank pixels, so it is excluded.

`runtime-results.json` records actual Sparkle installation/relaunch, deterministic postponement for a synthetic active send, no-update, invalid archive signature and HTTP download failure. Ad-hoc fixtures emit a sandbox-extension diagnostic despite passing all four cases; production signing/Gatekeeper remain unverified.
