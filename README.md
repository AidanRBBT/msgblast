# msgblast

msgblast is a Mac app for comparing AI agents in Messages and embedded Muse, ChatGPT, Claude, and Grok chats. Send one prompt to selected agents, read replies side by side, send follow-ups, and reopen saved comparisons. Messages agents also support photos and files.

Requires **macOS Sequoia (15) or later**. Web agents use your existing service accounts. Messages agents require existing one-to-one iMessage conversations.

## Download and install

[Download msgblast for Mac](https://updates.msgblast.app/latest.zip)

Unzip the download, drag **msgblast.app** into **Applications**, and open it.

### If macOS blocks the first launch

After trying to open msgblast, open **System Settings → Privacy & Security**, scroll to the security section, and select **Open Anyway**. Confirm **Open** when macOS asks again, if you trust the download. [Apple's first-launch instructions](https://support.apple.com/en-us/102445#openanyway).

<img src="docs/evidence/readme-onboarding/02-open-anyway.png" alt="macOS Privacy & Security showing that msgblast was blocked, with the Open Anyway button highlighted" width="820">

## Get started

### 1. Allow access to Messages history

Click **Open Settings** in msgblast's Messages history banner.

<img src="docs/evidence/readme-onboarding/01-history-access.png" alt="Actual msgblast history-access screen with the Open Settings button" width="820">

In **System Settings → Privacy & Security → Full Disk Access**, click **+**, choose **msgblast.app** from **Applications**, and click **Open**. Enable its switch and authenticate if requested. You can also drag the app card into that list. [Apple's Full Disk Access instructions](https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/mac).

Quit and reopen msgblast, then click **Check again** if the history banner remains.


### 2. Allow Contacts and Messages Automation

Allow Contacts when msgblast asks, so it can find and save agent contacts. If you previously declined, open **System Settings → Privacy & Security → Contacts** and enable access for msgblast. [Apple's privacy settings guide](https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/mac).

On your first send, allow msgblast to control **Messages**. If you previously declined, open **System Settings → Privacy & Security → Automation**, expand msgblast, and enable **Messages**. [Apple's Automation instructions](https://support.apple.com/en-nz/guide/mac-help/mchl108e1718/mac).

### 3. Add agents and send a prompt

Find agents in **Discover**, or click **Add Agent** to search by name, email or phone number. Start a one-to-one conversation with the agent in Messages first if it does not have one yet.

<img src="docs/evidence/readme-onboarding/03-add-agents.png" alt="Actual msgblast Add agent screen with sample contacts" width="680">

Select your agents, write a prompt, and press the send arrow. Their replies appear together for comparison.

*These are actual app screenshots captured with demo contacts and a simulated history-access prompt.*

Check for new versions from **msgblast → Check for Updates**.

## Comparison reports

ChatGPT and Claude conversations use native panes backed by your local Codex and Claude Code accounts. Reopen a saved comparison to resume the same CLI sessions and restore its replies and drafts. Muse and Grok retain their browser panes. See [native conversations and account setup](docs/personal-agent-reports.md#native-chatgpt-and-claude-conversations).

Click **Summarize** in a comparison to open a report with a recommended next action, a comparison of the replies, and open questions. Reports use an installed personal-agent CLI and its existing account. See [personal agent reports](docs/personal-agent-reports.md) for setup, supported CLIs, privacy limits, and fixture validation.

## Build it yourself

Install **Xcode 16.4 or later**, then clone this repository and build the app:

```sh
git clone https://github.com/mgalpert/msgblast.git
cd msgblast
xcodebuild -project msgblast.xcodeproj -scheme msgblast \
  -derivedDataPath build/from-source -destination 'platform=macOS' build
open build/from-source/Build/Products/Debug/msgblast.app
```

You can also open **msgblast.xcodeproj** in Xcode, select the **msgblast** scheme, and click **Run**.

## AI agent conversations

Select **Muse, ChatGPT, Claude, or Grok** beside your Messages agents in **My agents**. All four providers start selected; your choices are saved. Press **Send & compare** with a request. If a selected provider needs setup, msgblast opens its pane and explains how to sign in. ChatGPT and Claude use your local Codex and Claude Code accounts, with official CLI sign-in in Terminal. Muse and Grok use embedded pages. Signing in never submits the saved request automatically; press **Send & compare** again when ready. Right-click an agent’s **Open chat** action or reopen a saved comparison to return to its conversation.

Each new comparison gets separate provider conversations. ChatGPT and Claude save transcripts, drafts, and CLI session IDs and resume the same sessions on follow-up. Muse and Grok save their conversation URLs while the website retains history. **New Blast** starts separate conversations. Existing website chats and unrelated CLI sessions are not imported. A missing provider session or unconfirmed send stays visible and is not retried automatically.

**Your local accounts** shows ChatGPT, Claude, OpenClaw, and Hermes together. OpenClaw and Hermes report installation status and offer Terminal setup. Installation does not prove authentication or connectivity. OpenClaw chat is not connected; Hermes retains its comparison-report adapter. msgblast does not import account tokens.

Muse and Grok have separate persistent WebKit data stores. Safari, Chrome, and desktop-app cookies are not imported. Existing Muse state migrates in place; ChatGPT and Claude’s previous browser stores are preserved. HTTPS sign-in popups stay in an app sheet with their URL visible.

Before a shared submission, all selected conversations must be ready. Missing login or an existing provider draft keeps the request in the composer without sending to any recipient. Once ready, the shared composer submits concurrently to selected AI providers and independently to Messages recipients. Web send confirmations are page observations, not server delivery acknowledgements. Native Messages retains its attachment and retry workflow; shared sends including AI providers are text-only. Progress and errors stay visible; completed sends do not leave a persistent success banner.

Muse uses the signed-in user’s displayed avatar when readable, with bundled artwork as fallback. ChatGPT and Claude use their iOS app icons; Grok uses bundled generated artwork.

### Verification status

Native ChatGPT and Claude authentication, session persistence, and resumption are tested with local executable fixtures; live CLI login, inference, and resume remain unverified. Prior authenticated Muse/Grok browser sends and saved-chat checks are recorded in the browser evidence. Current English layouts use DOM selectors; an unrecognized layout blocks shared submission and leaves the embedded page usable. Fixtures do not prove future website or CLI compatibility.

Run `zsh scripts/build_web_preview.sh` and open `build/msgblast Web Preview.app` for live sign-in checks. It has a separate bundle identifier, blue demo icon, and `~/Library/Application Support/MsgBlast-WebPreview` state. **All web services are live; Messages are synthetic.** This does not install over the development app.

Run `zsh scripts/build_web_preview.sh --fixture` and open `build/msgblast Muse Fixture.app` for an entirely local test of all four providers. The historical fixture app name is retained. Every launch uses temporary state and no destination sends externally. [Multi-agent verification and evidence](docs/evidence/multi-web-agents/validation.md) distinguishes fixture results from live checks.

Core tests exercise the real WebKit engine for concurrent sends, replies, textarea/contenteditable inputs, first-message URL transitions, repeated identical prompts, existing drafts, expired sessions, ambiguous controls, storage failures, session isolation, Muse migration, and avatar lifecycle. Direct native UI checks cover agent selection, the shared composer, restored conversations and the removal of redundant success banners. [Latest verification and limits](docs/evidence/quiet-success-banners/validation.md) and [Grok follow-up verification](docs/evidence/toolbar-and-grok-followups/validation.md) distinguish live checks from local fixtures. Run the isolated core suite without launching the user's development app:

```sh
xcodebuild -project msgblast.xcodeproj -scheme msgblast \
  -derivedDataPath build/webkit-validation -destination 'platform=macOS,arch=arm64' \
  'PRODUCT_BUNDLE_IDENTIFIER=com.msgblast.webkit-validation.$(PRODUCT_NAME:rfc1034identifier)' \
  -only-testing:msgblastTests test
```

After building, `bash scripts/test_web_comparisons.sh build/webkit-validation` checks production comparison reopening, native attachment follow-ups, retry isolation, and quit/update deferral with controlled local fixtures. [Saved-chat validation](docs/evidence/dedicated-web-chats/validation.md) records the current results and live-test boundary.

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
