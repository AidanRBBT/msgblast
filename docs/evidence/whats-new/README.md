# What’s New and Contacts copy evidence

Captured October 6, 2026 from the integrated 0.6.1 source, with the source hashes in `source-sha256.json`.

Actual native macOS UI from a blue-icon Debug demo, marketing version 0.6.1 and local development build number (not a production counter). The copied bundle has identifier `com.msgblast.release061-evidence`, isolated simulated agents, and no configured updater. Production app was not replaced, restarted, or used. No real messages, Contacts writes, permission changes, logins, or paid requests. Mobile screenshots do not apply.

Screenshots: unread sidebar → current 0.6.1 highlights and contributor credits → published 0.6.0 highlights → original full 0.6.0 notes → viewed sidebar → Connect Contacts copy above search. The last capture uses `--contacts-access-preview`, a simulated missing Contacts connection after Messages access. The viewed state also persisted after quitting and relaunching the fixture.

`whats-new-walkthrough.mp4` sequences these actual native captures with edited four-second holds (24 seconds). It is an app-state walkthrough, not continuous screen recording. This fixture does not prove Developer ID signing, Apple notarization, or real macOS permission retention; those are release verification tasks.

Native check: `xcodebuild -project msgblast.xcodeproj -scheme msgblast -configuration Debug -derivedDataPath /tmp/msgblast-061-review -destination 'platform=macOS,arch=arm64' ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo MARKETING_VERSION=0.6.1 -only-testing:msgblastTests test -quiet`.
