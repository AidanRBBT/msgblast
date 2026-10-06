# Unified Discover evidence

Captured October 6, 2026 from the actual native macOS app built from the source revision and file hashes in source-sha256.json. The evidence-only commit does not change app behavior.

The blue-icon isolated demo uses synthetic contacts and temporary saved state. Messages denial and Contacts approval are simulated; the two permission states were captured from separate instances of the same build. No real OS permission was granted, no real Contacts entry was written, and no real message was sent. Mobile screenshots do not apply to this native macOS app.

- 00: Messages setup above search, with contacts hidden.
- 01: Contacts setup above search after simulated Messages access.
- 02: Fo, Szn, Instinct and directory agent Orchid appear without typing a search.
- 03: Adding Fo replaces Add with only a remove icon.
- 04: Typing Instinct filters the contacts without Enter.
- 05: New Blast returns to the composer with the draft preserved.
- 06: Saving directory agent Allora exposes only a remove icon in both its contact row and its directory card; removal restores Add.

The 24-second MP4 sequences these actual screenshots with edited timing. It is a sampled interaction walkthrough, not a continuous recording, live permission test, or latency benchmark. Screenshots and video stay within this private repository.

Validation: isolated demo build passed; native Xcode msgblastTests suite passed all 151 tests with zero failures. Full live Contacts, OS permission retention, and distributed-app installation are not covered by these fixtures. The final inactive sidebar appearance was not independently captured; text dimming follows the same native control-active state as the icons.
