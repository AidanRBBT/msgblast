# Account settings and navigation evidence

Captured October 6, 2026 from isolated local macOS demo builds of msgblast. The before build is based on `7bb350983618facc82815c2f2db47d196c09df3e`; after captures contain this change's Swift views and bundled icons. Captures were made on macOS 27.2, not Sequoia. This is a native macOS feature; mobile screenshots do not apply. Preview version labels use local development defaults, not a published release build.

- `before-settings.png`: account panel on My agents, generic symbols, connected ChatGPT still offering Sign in.
- `before-chat.png`: previous connected chat columns with persistent sign-in actions.
- `after-my-agents.png`: the renamed Agents page contains the agent picker without the local accounts panel.
- `after-settings.png`: Settings contains all four official icons; connected ChatGPT offers Switch account; signed-out Claude still offers Sign in.
- `after-sidebar.png`: simulated blast results, active comparison highlighted, Agents unselected, and no connected-account strip in ChatGPT or Claude columns.
- `after-new-blast.png`: pressing New Blast returns to Agents and removes the previous comparison highlight.
- `account-settings-demo.mp4`: 20-second sequence of actual CUA app captures with edited four-second holds. This is a sampled walkthrough, not a continuous recording. It shows the old account panel, the new Agents page, Settings, simulated comparison results, then New Blast.

All identities, account statuses, prompts and replies in this evidence are local fixtures. Settings deliberately has connected ChatGPT and signed-out Claude; native-chat fixtures are independently connected. This does not demonstrate a live authentication transition or provider request. Sign-in actions are disabled by demo mode. No real messages were sent for these checks.

Validation: development and demo apps compiled; existing `PersonalAgentTests.testAccountStatusUsesProviderStatusCommandsWithoutInference` passed (1 test, 0 failures, 0 skips). Manual CUA checks confirmed Settings-only placement, icons, connected/signed-out actions, draft retained on refresh, simulated results, comparison selection, New Blast, and reopening a saved comparison.
