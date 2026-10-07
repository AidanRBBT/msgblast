# Joining an existing conversation

Captured from this change using an isolated macOS app with bundle ID `com.msgblast.join-fixture`, the blue demo icon, and `--demo --isolated-demo`. All accounts, prompts, replies, and Messages chats are local fixtures; no real messages or provider requests were sent. Version labels are local development defaults.

The UI test starts a blast with Muse and ChatGPT, sends a shared follow-up, deselects ChatGPT, and sends a private/subset follow-up. It then adds Grok and Cedar from Send to. Grok receives one message containing the original ask and shared follow-up. Cedar receives those two messages through the Messages payload flow. Neither receives the private/subset message.

- `01-before.png`: existing blast before adding an agent.
- `02-web-agent.png`: Grok joined the same blast with shared context.
- `03-messages-agent.png`: Cedar joined the same blast with both historical shared messages.
- `walkthrough.mp4`: these actual app captures sequenced with edited four-second holds. This is a sampled state walkthrough, not continuous interaction recording.

This is a native macOS change; mobile screenshots do not apply. The final UI test passed. The initial full native suite passed 168 tests; after fixes, 31 focused core/attachment tests and the UI workflow passed. Legacy blasts recover shared text from matching receipt occurrences because older versions did not save broadcast scope; new blasts retain explicit shared history.
