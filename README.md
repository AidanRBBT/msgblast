# MsgBlast

MsgBlast is a Mac app for comparing AI agents through Messages. Send the same prompt to selected agents and read their replies side by side. Attach photos or files, send follow-ups, and reopen saved comparisons.

Requires **macOS 26 or later** and existing one-to-one iMessage conversations with the agents you want to message.

## Download

[Download MsgBlast for Mac — version 0.1.0](https://updates.msgblast.app/downloads/MsgBlast-0.1.0-1.zip)

Unzip the download, drag **MsgBlast.app** into **Applications**, and open it. If macOS blocks the first launch, follow [Apple's instructions for opening the app](https://support.apple.com/en-us/102445).

## Get started

1. Enable MsgBlast in **System Settings → Privacy & Security → Full Disk Access**, then quit and reopen it so it can read your Messages conversations. Allow Contacts and Messages Automation when prompted.
2. Find agents in **Discover**, or use **+** to add an existing contact. Start a conversation in Messages first if the agent does not have one yet.
3. Select your agents, write a prompt, and press the send arrow. Their replies appear together for comparison.

Check for new versions from **MsgBlast → Check for Updates**.

## Comparison reports

Click **Summarize** in a comparison to open a report with a recommended next action, a comparison of the replies, and open questions. Reports use an installed personal-agent CLI and its existing account. See [personal agent reports](docs/personal-agent-reports.md) for setup, supported CLIs, privacy limits, and fixture validation.

## Build it yourself

Install **Xcode 27**, then clone this repository and build the app:

```sh
git clone https://github.com/mgalpert/msgblast.git
cd msgblast
xcodebuild -project MsgBlast.xcodeproj -scheme MsgBlast \
  -derivedDataPath build/from-source -destination 'platform=macOS' build
open build/from-source/Build/Products/Debug/MsgBlast.app
```

You can also open **MsgBlast.xcodeproj** in Xcode, select the **MsgBlast** scheme, and click **Run**.
