# Contacts entitlement and keyboard shortcuts evidence

Actual native macOS Debug blue-icon fixture captures from this change on October 6, 2026, marketing version 0.6.2 and local development build (not a production counter). Copied bundle identifier `com.msgblast.release062-evidence`, simulated agents/Contacts, isolated state, updater disabled. Production app was inspected read-only for entitlements; it was not replaced or restarted. No real messages, Contacts grants/reads/writes, account logins, or paid requests. Mobile screenshots do not apply.

Native interaction order: draft → ⌘2 Discover → ⌘F and type Fo → ⌘N with retained draft/selected agents and typed “preserved” → ⌘W then ⌘N and typed “reopened”. ⌘1/⌘2 return navigation was also verified. Each screenshot is an actual native app state. Video sequences these captures and the diagnostic transcript with edited four-second holds; it is not continuous screen recording.

`06-entitlement-check.png` is a rendered transcript of actual codesign and test results recorded in `checks.json`, not a terminal screen capture. The installed signed 0.6.1 binary omits Address Book entitlement; the real rebuilt Debug signature includes it. Release guard tests simulate missing exported entitlement in both signing modes and reject packaging/notarization; Apple calls in those tests are mocked. Actual Contacts permission and fetch still require verification in the corrected installed app.

155 native core tests passed before final window/focus edits. The final focused Command-Return unit test passed. Final isolated build passed. The targeted UI test runner timed out enabling macOS automation before any assertions; manual native checks above supply interaction evidence, and native CI remains required.

Source hashes in `source-sha256.json`. Review includes full permission-focused review with independent Claude, plus combined correctness/Claude review and bounded manual followups; agent capacity prevented the full combined reviewer roster. No actionable findings remain. Reopening New Blast and initial composer focus were corrected and verified before these captures.
