<p align="center">
  <img src="docs/images/readme/msgblast-icon.png" alt="msgblast" width="96">
</p>

<h1 align="center">msgblast</h1>
<p align="center"><strong>Ask once. Compare the answers.</strong></p>
<p align="center">Send one question to several AI assistants. Read their replies side by side on your Mac.</p>
<p align="center"><a href="https://updates.msgblast.app/latest.zip"><strong>Download for Mac</strong></a> · macOS Sequoia 15 or later</p>

<img src="docs/images/readme/compare-answers.jpg" alt="One question sent to Instinct, Fo, and Szn, with three different answers side by side and a shared follow-up message" width="1100">

Planning a weekend, researching a purchase, or testing an idea? Write your question once, choose your assistants, and compare their suggestions in one window. Send a follow-up to everyone or just one assistant. Your comparisons stay saved so you can return to them later.

*Actual app screenshot with an example conversation. The replies are illustrative sample text.*

## Use the assistants you already text

msgblast works with AI assistants in **Messages**, including [Instinct](https://instinct.com/), [Fo](https://wajo.ai/), and [Szn](https://theszn.ai/). Start an iMessage conversation with each assistant you want to use, then add it to msgblast. Each assistant’s own account and access requirements apply.

You can also send photos and files to your Messages assistants.

## Get started

1. [Download msgblast](https://updates.msgblast.app/latest.zip), unzip the file, and drag **msgblast.app** into **Applications**. Open the app.
2. For Messages assistants, click **Open Settings** in msgblast and allow it to read Messages history. Quit and reopen the app afterward. Then click **Add Agent**, find your assistant by name, email, or phone number, and allow Contacts when asked. The permission steps are below.
3. Muse, ChatGPT, Claude, and Grok start selected in **Agents**. Sign in to their websites inside msgblast when needed. **Agent** means an AI assistant in msgblast.
4. Type a question and press the send arrow. If account setup opens, finish signing in, then send again; your question stays ready. Allow msgblast to control **Messages** when sending there. Replies appear together for comparison.

<details>
<summary>Help opening the app and allowing Messages access</summary>

**If macOS blocks the first launch:** after trying to open msgblast, go to **System Settings → Privacy & Security**, scroll to the security section, and choose **Open Anyway**. Confirm **Open** if you trust the download. [Apple’s first-launch instructions](https://support.apple.com/en-us/102445#openanyway).

**Messages history:** click **Open Settings** in msgblast. In **Privacy & Security → Full Disk Access**, click **+**, choose **msgblast.app** from **Applications**, and click **Open**. Enable its switch and authenticate if asked. Quit and reopen msgblast, then click **Check again** if the history banner remains. This lets msgblast read replies from your existing Messages conversations.

**Contacts:** allow access when msgblast asks so it can find your assistants. If you previously declined, enable msgblast in **Privacy & Security → Contacts**.

**Sending through Messages:** on the first send, allow msgblast to control **Messages**. If you previously declined, enable **Messages** under **Privacy & Security → Automation → msgblast**.

</details>

Check for updates from **msgblast → Check for Updates**.

## Muse, ChatGPT, Claude, and Grok

Select these agents alongside your Messages assistants. Each Blast gets its own conversations, and follow-ups continue in the saved chats.

All four use their websites inside msgblast, with persistent sign-in sessions. Muse uses a side chat. Existing Safari, Chrome, desktop-app and CLI sessions do not automatically sign you in to these embedded pages.

**Codex CLI** and **Claude Code** are separate optional agents. Add them in **msgblast → Settings** to compare their replies alongside the web accounts. Their sign-ins, conversations and settings are separate from the websites; enabling a CLI does not replace its web agent. Manage local account sign-in and switching in Settings.

Shared requests involving these four agents are text-only. Messages-only requests can include attachments. Model and thinking settings are not controlled by a shared selector.

<img src="docs/images/readme/choose-agents.jpg" alt="Agent selection showing Muse, ChatGPT, Claude, Grok, Instinct, Fo, and Szn with their icons" width="1100">

*Captured from the app source with sample Messages profiles. No messages were sent.*

For developers: [build from source](docs/build-from-source.md).

## License

Copyright (C) 2026 Michael Galpert and contributors.

Except where separately licensed or attributed, msgblast is licensed under the
[GNU General Public License, version 3 only](LICENSE) (`GPL-3.0-only`). You may
use, modify, and redistribute it, including commercially, under those terms.
Distributed modified versions must remain under GPLv3 and include the
corresponding source as required by the license. The software comes without
any warranty.

Third-party dependencies, service icons, logos, and other attributed assets
retain their respective licenses and rights; this license does not relicense
third-party material or grant trademark rights.
