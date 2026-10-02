# Onboarding revision: match AskForPermission's demonstrated handoff

The user selected the flow in https://github.com/riko2chen/AskForPermission/raw/main/docs/assets/demo.gif as the reference. The animation was viewed in the in-app browser, including its initial permission rows, docked floating guide, and macOS approval stage. No remote media was downloaded or local privacy setting changed.

The revised generated contact sheet is `msgblast-onboarding-codex-flow.png`; the exact built-in ImageGen prompt is in `msgblast-onboarding-codex-flow.prompt.md`. The earlier concept is preserved. This revision is a design concept, not screenshots of implemented onboarding or evidence of a permission grant.

The adopted flow is:

1. A compact Messages history row starts the request and opens Full Disk Access Settings.
2. Its card animates from the source row to a floating guide beside/below Settings, with a soft spring on arrival. The source becomes a dashed Complete in System Settings placeholder.
3. The guide contains an upward arrow, short instruction, back action, and draggable MsgBlast icon/name row. It follows the Settings window. The drag payload is the actual running app bundle URL.
4. The user drops the app into the list, enables its switch, and completes any macOS authentication/restart request. Dropping does not prove access.
5. The original row becomes Done only after MsgBlast's actual read-only Messages history open/query succeeds. Cancellation returns the card to its source; unavailable Settings tracking retains the manual Settings fallback. Reduced Motion should skip flight animation without changing the workflow.

The source animation uses Accessibility and Screen Recording examples. MsgBlast's adopted design requests only its Messages history capability through this guide. Contacts remains framework consent during Add; Automation remains consent on the first actual send. The account can be saved to Contacts before an eligible chat exists. Consent dialogs and System Settings are OS-owned; the illustrative layout does not redefine their wording or behavior.

This contact sheet adds four permission-flow states before the existing Add, pinned selection, first-send, and connected comparison views. Generated UI is illustrative: the final runtime should retain all previously sent outgoing bubble colors when recipient pills change. No app source or dependency was modified for this revision.
