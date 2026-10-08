# Joining an existing conversation

Captured from the reviewed privacy/order fixes using an isolated macOS app with bundle ID `com.msgblast.join-fixture`, the blue demo icon, and `--demo --isolated-demo`. All accounts, prompts, replies, and Messages chats are local fixtures. No real messages, CLI requests, or paid provider requests were sent. Version labels are development defaults.

The general join UI test starts with Muse and ChatGPT, sends a shared follow-up, excludes ChatGPT, and sends a subset follow-up. It then adds Grok and Cedar from Send to; each receives the original ask and shared follow-up, excluding the subset message.

The fresh CLI test creates a conversation through the Codex CLI pane, sends a private pane reply, and then sends an explicit shared follow-up. Grok, Claude Code, and Cedar join that same blast with Original + Shared; the private CLI detail remains only in Codex. An unsent shared draft stays intact.

- `01-before.png`: existing blast before adding an agent.
- `02-web-agent.png`: Grok joined with shared context.
- `03-messages-agent.png`: Cedar joined with both shared messages.
- `04-private-cli-before.png`: fresh sole-CLI conversation, including its private reply, before joins.
- `05-private-cli-after.png`: web, CLI, and Messages joins exclude the private CLI detail.
- `walkthrough.mp4`: five actual app captures sequenced with edited four-second holds (20 seconds). A sampled state walkthrough, not continuous interaction recording.

Native macOS UI has no mobile layout. Both UI workflows passed, as did 35 core/attachment regressions. Three privacy tests first failed against the reviewed old head before the fixes. The AppModel fixture also tests PR #27's exact private-Messages entry point and verifies controlled partial-failure receipts -> B sent -> A retried -> a new agent receives Original,A,B once. That chronology case is verified by model assertions rather than these UI captures; the failed receipt is injected and labeled, while B, retry, and joining use actual AppModel code with simulated Messages.

Unknown legacy follow-up scope is excluded from joining context, including unmarked cached context. Only explicitly shared messages are forwarded. PR #27's view changes were not merged here; its private `followUp(..., only:)` call was exercised directly. No app update was published.
