# Dots and Grok Bot integration evidence

Runtime source: `ba324c9a0af71f3a9b24735e6ad3210afae72479`. Captured with native computer use on macOS 27. Evidence is stored in the private repository. The following commit adds evidence only; it does not change the reviewed app source.

## Functional Dev preflight

The blue-green development app uses `com.msgblast.development`, its own `msgblast-Dev-Integration-065` support directory, hardened ad-hoc signing and disabled updates. `msgblastDemo` is false. Actual clicks verify Dots selection, Grok Bot opt-in, the connection settings and retention of an unsent composer draft when Settings closes. No demo flags are used. Webhook credentials remain blank; no tunnel or paid provider run is started. Messages is unavailable without Full Disk Access; no permissions were changed and no Messages or Contacts operations were performed.

`dev-agents.jpg`, `dev-settings.jpg` and `dev-preflight.mp4` show these checks. The displayed 0.4.3 (1) is the development project default, not the upcoming distributed marketing version.

## Demo workflow

The blue fixture app uses `com.msgblast.demo`, separate `msgblast-Demo-Integration-065` support data and disabled updates. All accounts, input, web pages, webhook callbacks and replies shown are simulated. No Bot or real recipient was contacted.

1. `01-demo-settings.jpg`: Grok Bot before opt-in.
2. `02-agents-before-send.jpg`: Dots and Grok Bot selected with a synthetic prompt.
3. `03-demo-replies.jpg`: both simulated replies, the Dots saved avatar and Grok Bot settings button.
4. `04-header-settings.jpg`: the header button opens Grok Bot settings.
5. `05-avatar-changed.jpg`: changing the fixture avatar updates the native Dots header.
6. `06-avatar-after-relaunch.jpg`: the saved purple avatar and comparison remain after quitting and reopening the fixture app. Fixture web page conversation contents themselves are recreated on relaunch; the native Grok Bot transcript remains.

`demo-workflow.mp4` shows another synthetic shared prompt, its simulated replies, an avatar change and opening settings from the Grok Bot header. Both videos are assembled from native screenshot samples collected around the actual clicks. Playback timing is edited to three captured samples per second, with repeated display frames; gaps between interaction segments are omitted. They are not continuous real-time screen recordings.

## Storage retry regression

The real XCTest uses a WebAgentSession and loopback HTTP receiver, obstructs its state file, checks HTTP 503 twice and no in-memory assistant reply, checks that new sends stay blocked, restores storage, retries to HTTP 200 and verifies one durable reply and duplicate suppression. `native-test-result.txt` is an excerpt of the actual successful test output, not a simulated result.

The callback disk failure is nonvisual and is not demonstrated by the UI videos. Native Terminal capture is unavailable through the computer-use tool, so its evidence is the actual test result and the regression assertions in source. The strengthened test does not exercise the production disabled-provider/tunnel shutdown path or negative recovery ownership cases; those are review coverage limits, not claims made by this evidence. Live paid Dots/Grok Bot replies were not retested in this integration preflight.

## Checks

225 native tests, 79 Python tests, 12 feedback Worker tests and 7 download Worker tests passed. Download Wrangler dry-run, combined comparison controller tests and five isolated Sparkle update scenarios passed. The integration review has no unresolved actionable findings.
