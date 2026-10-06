# Account settings evidence

Captured October 6, 2026 from isolated local macOS demo builds of msgblast. The before build is based on `7bb350983618facc82815c2f2db47d196c09df3e`; the after build contains this PR's Swift changes and bundled icons. Captures were made on macOS 27.2; this is not a Sequoia runtime check. This is a native macOS feature; mobile screenshots do not apply.

- `before-settings.png`: account panel on My agents, generic symbols, connected ChatGPT still offering Sign in.
- `after-my-agents.png`: My agents contains the agent picker, without the local accounts panel.
- `after-settings.png`: Settings contains all four official icons; the connected ChatGPT fixture offers Switch account; the signed-out Claude fixture still offers Sign in.
- `before-chat.png` / `after-chat.png`: connected chat fixtures before and after the label fix.
- `after-chat-ready.png`: empty connected ChatGPT/Claude panes, readiness copy, and retained shared draft.
- `after-refresh.png`: same connected state and draft after pressing Reload ChatGPT; nothing submitted by refresh.
- `account-settings-demo.mp4`: 24-second sequence of these actual CUA app captures, with edited four-second holds. It is a sampled walkthrough, not a continuous screen recording. Final frame follows Send & compare and shows simulated replies.

All identities, account statuses, prompts and replies in this evidence are local fixtures. Settings deliberately has one connected and one signed-out fixture; the independent native-chat fixtures are both connected. This is not evidence of a live authentication transition or a live provider request. Sign-in actions are disabled by demo mode. No real messages were sent, credentials read, or live user state changed.

Validation: app compiled and existing `PersonalAgentTests.testAccountStatusUsesProviderStatusCommandsWithoutInference` passed (1 test, 0 failures, 0 skips); manual CUA checks confirmed the move to Settings, icons, connected/signed-out actions, retained draft on refresh and simulated comparison result.
