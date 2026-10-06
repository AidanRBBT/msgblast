# Sequoia compatibility evidence

Captured from the unchanged application source in PR #5 (`d0929eb`), also used by the follow-up package/README fixes. The app was built in an isolated derived-data directory with the blue demo icon and launched with `--demo --isolated-demo` under a separate bundle ID. Host: macOS 27.2, Xcode 27 SDK. These captures verify the replacement material controls on a newer OS, not execution on Sequoia. No real Messages sends, Contacts writes, permission changes or live-app replacement occurred.

1. `01-composer.png`: three recipients selected; material input and send arrow.
2. `02-comparison.png`: connected comparison after simulated replies.
3. `03-follow-up.png`: Lumen excluded; follow-up drafted with send arrow.
4. `04-sent.png`: follow-up appears only in Cedar and Orbit; input clears.

`workflow.mp4` is an edited sequence of these actual captured UI states, held three seconds per state. It does not contain continuous pointer motion; timing is edited and all responses are fixtures. This is a native macOS app; mobile screenshots are not applicable. The original contributor separately reported macOS 15.4.1 build and isolated demo launch; these captures do not re-prove that claim.
