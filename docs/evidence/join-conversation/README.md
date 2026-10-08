# Joining an existing conversation

Captured from the reviewed privacy/order fixes using an isolated macOS app with bundle ID `com.msgblast.join-fixture`, the blue demo icon, and `--demo --isolated-demo`. All accounts, prompts, replies, and Messages chats are local fixtures. No real messages, CLI requests, or paid provider requests were sent. Version labels are development defaults.

The general join UI test starts with Muse and ChatGPT, sends a shared follow-up, excludes ChatGPT, and sends a subset follow-up. It then adds Grok and Cedar from Send to; each receives the original ask and shared follow-up, excluding the subset message.

The fresh CLI test creates a conversation through the Codex CLI pane, sends a private pane reply, and then sends an explicit shared follow-up. Grok, Claude Code, and Cedar join that same blast with Original + Shared; the private CLI detail remains only in Codex. An unsent shared draft stays intact.

- `01-before.png`: existing blast before adding an agent.
- `02-web-agent.png`: Grok joined with shared context.
- `03-messages-agent.png`: Cedar joined with both shared messages.
- `04-private-cli-before.png`: fresh sole-CLI conversation, including its private reply, before joins.
- `05-private-cli-after.png`: web, CLI, and Messages joins exclude the private CLI detail.
- `06-private-pane-blocked.png`: actual private pane after the Messages side finishes while the controlled web completion is pending; the draft is retained and Send is disabled. Captured by the native model fixture from this branch.
- `walkthrough.mp4`: six actual app captures sequenced with edited four-second holds (24 seconds). A sampled state walkthrough, not continuous interaction recording.

Native macOS UI has no mobile layout. Both UI workflows passed, as did 36 core/attachment regressions. Three privacy tests first failed against the reviewed old head before the fixes. The AppModel fixture also tests PR #27's exact private-Messages entry point and verifies controlled partial-failure receipts -> B sent -> A retried -> a new agent receives Original,A,B once. That chronology case is verified by model assertions rather than these UI captures; the failed receipt is injected and labeled, while B, retry, and joining use actual AppModel code with simulated Messages.

Unknown legacy follow-up scope is excluded from joining context, including unmarked cached context. Only explicitly shared messages are forwarded. PR #27's view changes were not merged here. A separate scratch copy layered its view changes with these fixes and passed the same native pane callback and model assertions. The reviewed combined worktree and main were not modified. No app update was published.

Broadcast-race verification uses a deterministic gate: the actual AgentBroadcast Messages closure sends through AppModel with a reserved UUID; the web closure waits for it to finish, attempts the real private pane Send callback and model API, then injects a labeled private ledger record before returning a simulated observed receipt. Completion marks only the reserved UUID. After the pending private draft is sent following completion, a new agent receives only Original + Shared. The legacy injected ledger has no transport send; it tests identity independently of the guard. The old model allowed the private call while webBroadcastBusy and failed this regression before the fix.
