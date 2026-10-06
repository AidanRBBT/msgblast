# Web defaults and optional CLI agents

Captured from the changed app in an isolated local fixture build, version 0.5.0 (1), on macOS 27.2. No real accounts, messages, contacts, or paid requests were used. The blue icon identifies the fixture build; development uses blue-green and distribution uses green.

1. `01-web-defaults.png`: Muse, ChatGPT, Claude, and Grok are available by default; CLI agents are absent.
2. `02-cli-settings.png`: Settings enables Codex CLI and Claude Code independently, using official provider artwork.
3. `03-web-and-cli-selected.png`: the two websites and two CLIs selected together.
4. `04-separate-replies.png`: one shared request produces four distinct fixture replies and a saved, selected Blast.
5. `05-reopened-followup.png`: reopening the saved Blast retains both web conversations and both CLI histories; a follow-up reaches each.
6. `06-disabled-history.png`: disabling Codex CLI retains its archived history and disables its recipient control.

`walkthrough.mp4` is an edited, sampled walkthrough of those actual app states, with fixed holds between screenshots; it is not a continuous real-time recording. Responses and account states are simulated local fixtures. The full 140-test Xcode unit suite, three final migration regressions, and actual AppModel/WindowCoordinator fixture checks passed. The Xcode UI runner timed out enabling automation before executing its tests; direct computer-use interactions exercised the pictured workflow instead. Live provider behavior was not re-tested with real requests in this revision. This is a native macOS app, so mobile screenshots do not apply.
