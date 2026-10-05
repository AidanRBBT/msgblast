# Personal agent reports

Click **Summarize** in the top-right toolbar of a comparison window, a separate conversation window, or the floating shared composer. A separate, resizable **Comparison report** window opens and starts the personal agent selected last time (or the first detected CLI on first use). The report leads with **Best next action** and its reasoning, then compares the responses and lists open questions. Select a different personal agent in the report window and click **Update report** to use it.

The report includes every participant's available responses, reactions, confirmed follow-ups, and explicit thread replies within the same boundaries as the conversation columns. It is independent of the message-recipient selection. At least one reply or recipient reaction is required to generate a report; the response count includes both. The report is saved with the comparison, can be copied, and becomes visibly stale when the conversation changes. Clicking **Summarize** again focuses the existing report window and requests an update; clicking while a request is running only focuses the report. New replies never trigger automatic provider requests. Existing saved summaries remain readable until replaced by a report.

Supported CLIs: **Codex, Claude Code, Gemini CLI, Pi, Grok, and Hermes**. Detection checks the login shell's PATH and common installation directories; it does not install agents or inspect credential files. Install and sign in through the provider's own CLI, then use **Refresh agents**. Finding an executable does not establish that it is signed in. A desktop app alone may not include its CLI. CLI updates can change supported flags; launch, authentication, and output errors leave the previous summary intact.

Cursor (`cursor-agent`) is excluded from discovery and rejected before any report process can launch. Cursor's [Ask mode](https://cursor.com/docs/cli/overview) permits read-only exploration, and its [permission configuration](https://docs.cursor.com/cli/reference/permissions) does not establish a verified denial of every tool in MsgBlast's adapter. Participant replies are untrusted, so read-only mode is insufficient. Existing saved Cursor selections and reports still decode; the report window explains the restriction and offers the other installed agents. This restriction remains until complete tool denial can be enforced and verified.

This follows [bb's local CLI integration approach](https://github.com/get-bb/bb/tree/c8b9459ba911a5666fda4ed63291aed68b6a64be/plugins): its Claude adapter resolves the local executable for the Agent SDK, Codex uses a local app-server child, and Cursor/OpenCode/omp/Grok/Hermes use ACP bridges. MsgBlast uses one-shot CLI adapters for its single-summary workflow rather than embedding bb's TypeScript server or long-lived session protocol. OpenCode and omp are not included in this initial adapter set. No bb source code is copied.

The chosen CLI uses its existing account and provider billing/usage limits; MsgBlast does not add an API-key form or promise that every CLI configuration bills a subscription. The comparison text is sent to the selected provider only when you request a summary. Unsent drafts, contact addresses, unrelated conversations, and attachment contents/paths are excluded (attachment filenames remain as context). Codex and Hermes use their isolated configuration modes while retaining CLI-owned authentication; other adapters disable tools or request the CLI's read-only mode. These are provider controls, not an OS-level isolation guarantee for third-party executables. Each run uses a private temporary working directory, direct arguments and stdin, a three-minute timeout, cancellation, and bounded output. Cancellation, timeout, and normal app quit stop the request process group before removing temporary request/output files; force quitting or a system crash cannot run that cleanup. After a completed run those files are removed; the provider may maintain its own history under its own policy.

The demo always uses a clearly labeled simulated report and never invokes an installed agent. Adapter tests use local executable fixtures, so they prove transport/parsing and failure behavior, not live provider authentication or billing. Validate without replacing the live app with:

```sh
xcodebuild -project MsgBlast.xcodeproj -scheme MsgBlast \
  -derivedDataPath build/personal-agent-validation \
  -destination 'platform=macOS,arch=arm64' \
  MSGBLAST_APP_BUNDLE_IDENTIFIER=com.msgblast.personal-agent-validation \
  ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo \
  -only-testing:MsgBlastTests \
  -only-testing:MsgBlastUITests/WorkflowTests/testSeparateConversationWindowsShareOneComparisonReport \
  -only-testing:MsgBlastUITests/WorkflowTests/testPersonalAgentOpensComparisonReportWithBestNextAction test
```

After the isolated build, run `scripts/test_personal_agent_shutdown.sh build/personal-agent-validation` to verify that delayed discovery cannot start a report during shutdown. It compiles the actual controller with controlled in-memory model and provider substitutes; no UI, Messages access, or provider request is involved.
