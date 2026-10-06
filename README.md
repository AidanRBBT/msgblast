# msgblast

msgblast is a Mac app for comparing AI agents through Messages. Send the same prompt to selected agents and read their replies side by side. Attach photos or files, send follow-ups, and reopen saved comparisons.

Requires **macOS Sequoia (15) or later** and existing one-to-one iMessage conversations with the agents you want to message.

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

Find agents in **Discover**, or click **+** to search by name, email or phone number. Start a one-to-one conversation with the agent in Messages first if it does not have one yet.

<img src="docs/evidence/readme-onboarding/03-add-agents.png" alt="Actual msgblast Add agent screen with sample contacts" width="680">

Select your agents, write a prompt, and press the send arrow. Their replies appear together for comparison.

*These are actual app screenshots captured with demo contacts and a simulated history-access prompt.*

Check for new versions from **msgblast → Check for Updates**.

## Comparison reports

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
