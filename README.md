# MsgBlast

A local native Mac app for comparing agents in existing, separate one-to-one Messages conversations. Uses SwiftUI, AppKit windows and toolbars, and native Liquid Glass on macOS 26 or later.

## Build and run

Requires Xcode 27 (tested with 27.0) and macOS 26+.

```sh
xcodebuild -project MsgBlast.xcodeproj -scheme MsgBlast -derivedDataPath build -destination 'platform=macOS,arch=arm64' build
open build/Build/Products/Debug/MsgBlast.app
```

Open `MsgBlast.xcodeproj` in Xcode to run, debug, and test. The project has a shared `MsgBlast` scheme, core unit tests, and a native UI test target. `python3 scripts/generate_project.py` regenerates the project after adding Swift files. No external dependencies are required.

A fixture app can be built with `scripts/build_demo.sh`. Open `build/Build/Products/Debug/MsgBlast Demo.app`. Standard development builds use the blue-green icon; the demo uses the blue icon and compiles in `build/icon-demo` before copying to its usual app path. This has synthetic contacts and delayed synthetic replies; it cannot submit real messages. “Simulate one failure” exercises a known failure before submission. “Reset sample data” clears only the demo's app-owned state. Demo and live state are stored in separate directories.

## Use

1. Give **MsgBlast** Full Disk Access in System Settings → Privacy & Security, then quit and reopen it. The app opens `~/Library/Messages/chat.db` with `SQLITE_OPEN_READONLY`.
2. Use the toolbar's **+** button to search by name, email, or phone number. You can enter an account absent from Contacts: **Add** creates its Contacts entry and saves the real contact ID in MsgBlast, even without an existing chat. Contacts permission is required to save that entry. Only existing one-to-one Messages chats are eligible for sending; an account with no matching conversation stays saved and unselected until a conversation is available.
3. All available saved agents start selected. Tap a pinned avatar or its check overlay to change selection, write your prompt in the bottom input, and press the send arrow. By default, one connected native window holds the conversation columns and the universal input across the bottom.
4. Joined conversations have one universal input. A row of named recipient pills starts with every agent highlighted. Tap a pill to exclude that agent; tap again to include it. Click a conversation or its avatar to send only to that conversation, then add or remove recipients with the same pills. Highlighting always matches the next message's recipients. Changing targets retains the draft. When the columns do not fit, scroll horizontally; selecting a conversation brings its column into view. **MsgBlast → Settings → Conversations → Separate windows** restores independently draggable conversations and the floating shared composer. Changing the preference immediately rearranges open comparisons and preserves drafts, receipts, and each layout's saved frames.
5. Reopen comparisons from the sidebar or Comparisons menu. Another prompt in the same chat bounds ordinary history in the earlier comparison; explicit thread replies remain included.

Web links render as native image-backed cards with website titles and domains. Click a card to open its URL. Standard and custom emoji reactions attach to the original message, including replacement and removal events. Preview metadata is fetched from the linked website and cached in memory; a website that cannot provide metadata still has a usable native link card.

The circular **+** beside each message field opens Photos or the native file picker. Attach multiple photos/files, paste images or copied Finder files, or drop them into the composer. Previews can be removed before sending and opened in native Quick Look. A message can contain attachments without a caption. Drafts retain staged files across relaunch; each caption/file has its own saved submission receipt, so partial retries skip accepted parts. Conversation history displays photo previews and file cards.

The first ordinary send asks macOS to allow Automation of Messages. A successful Apple Event means **submitted to Messages**, not delivered. Sends run in an isolated child process with a timeout so they do not block the app's main thread. Known Automation denial can be retried; an ambiguous send is quarantined instead of automatically resending. Refresh reconciles a unique outgoing record when available. Interrupted follow-ups expose separate actions for failed and never-attempted recipients.

## Current integration gates

This build is a development app, **not a verified v1 release**. Read [integration findings](docs/integration-findings.md) for observed results and remaining gates.

- Live MsgBlast submitted controlled text to the authorized Michael and Pal destinations, reconciled outgoing anchors, and preserved private/shared recipient scopes. Real Contacts records were saved/reused for Pal and the pending Outlook address. The October 2 09:28 build regained history access and sent a fresh synthetic PNG and text file to Michael's self-address: Messages shows received copies and Read, and MsgBlast displays their live cards and delivery receipt. This verifies the self-address transfer; the earlier failed attachments remain Not Delivered and were not retried. See [the scoped delivery receipt](docs/evidence/live-attachment-delivery-MB1002-0929.json).
- A genuine inline reply was observed through native Messages UI. App-driven exact-prompt inline targeting and its database linkage still need end-to-end verification. Native Messages reported msgisaway@outlook.com as unregistered; no message was sent to it. Contact creation is independent of messaging registration.
- An older comparison's follow-up is blocked for members who joined a newer comparison, because genuine inline targeting by this app is unproven. It does not silently substitute quoted text.
- An isolated full run passed 50 checks (41 core/controller and nine native workflows), including actual Quick Look image pixels and reopening. Subsequent photo aspect-ratio and first-send Contacts consent improvements compile; their new native run was interrupted when the Mac locked. This fixture coverage does not establish app-driven inline replies.

## Local data

Live state: `~/Library/Application Support/MsgBlast/state.json`. Fixture state: `~/Library/Application Support/MsgBlast-Demo/state.json`. Stores agent metadata, app-authored prompts/drafts, anchor GUIDs and row IDs, per-recipient/per-part attempt states, and outer window frames. Files the user attaches are staged under the corresponding `Attachments` directory with owner-only permissions. Sending creates a separate private transport copy per recipient under `~/Library/Messages/Attachments/MsgBlast-Outgoing`, retained for asynchronous native transfer. Removing an unsent preview deletes its draft copy after a successful state save, provided no other saved draft or send references it. Messages history attachments are read from their original locations and are not copied into app storage. An unreadable or corrupt state file is preserved rather than overwritten.

## Test

```sh
xcodebuild -project MsgBlast.xcodeproj -scheme MsgBlast -derivedDataPath build/validation -destination 'platform=macOS,arch=arm64' -only-testing:MsgBlastTests test
```

Remove `-only-testing:MsgBlastTests` to include UI tests after authorizing their runner. Those tests launch with `--demo --isolated-demo`, using a new temporary store for each launch so their reset cannot overwrite the normal Demo app's comparisons. The core SQLite fixture tests verify that reads leave database bytes unchanged, exclude groups/SMS/empty chats, retain thread relationships, and bind query parameters.

The isolated run at October 2, 09:15:53 passed 41 core/controller tests and nine native workflows, with zero failures/skips. A targeted extension also passed same-image close/reopen. Core regressions cover optional delivery columns, read-only history, recipient scopes and private transport copies, including rejected symlinks. Native workflows cover onboarding return, pending-contact eligibility, joined selection, partial retries, rendered previews and repeated private sends. The later photo-layout/Contacts-consent revision passed 41 core checks; its UI run was stopped after two activation failures with the screen locked. AppIntents metadata, synthetic file-URL sandbox and internal XCTest QoS warnings remain. See the current [completion audit](docs/completion-audit.md) for precise results and remaining live gates. Keep validation builds separate from the live app bundle to avoid replacing its executable/signature during permission checks.

The private repository is [mgalpert/msgblast](https://github.com/mgalpert/msgblast). Any future PR must include actual-feature **Screenshots** and **Video** sections, with repository-accessible evidence from the reviewed build; local screenshots alone do not satisfy that requirement.

## Embedded Muse

Select **Muse** alongside your other agents in **My agents**, then use **Sign in to Muse**. A real `WKWebView` opens `https://muse.ai/` inside MsgBlast. Sign in there and open the main chat. The same shared composer becomes available when the page exposes the expected chat and editable message field. Safari and the Muse desktop app have separate sessions; MsgBlast does not import their cookies or credentials. WebKit retains its own session using the persistent data-store identifier saved in `web-services.json` alongside MsgBlast's state.

Muse starts unselected; its avatar uses the same selection control as Messages agents. A shared prompt goes independently to each selected destination. Messages retains its existing selection, Contacts, history-access, routing, and submission checks. Each prompt including Muse creates a Messages comparison whose native columns appear beside Muse; Muse continues its main conversation. **Agents** returns to the same picker and draft, and **Open Muse** reopens the retained page. Messages-only sends keep their existing workflow and attachment support; with Muse selected, the shared send is text-only and existing attachments must be removed or Muse deselected. Actual Muse replies, links, and approval controls render in its page, rather than being attributed to a prompt by a quiet-time heuristic.

This initial adapter supports text and the main Muse chat in its English interface. It preserves any existing site draft and declines to send when the page is signed out, on another route, read-only, or has ambiguous controls. It records intent before clicking Send and checks for one new outgoing message ID with matching text. **Appeared in Muse** describes that page observation, not a server delivery acknowledgement. Unconfirmed or interrupted submissions are never retried automatically, and repeated shared sends of the same unconfirmed text are blocked; inspect the embedded conversation before taking further action. Per-recipient results stay independent when a broadcast partially fails.

Grok Bot is not exposed in the app; a working web login and chat have not been verified. Background updates and login persistence on the live Muse service must be verified separately from local fixtures. HTTPS sign-in popups stay inside an app sheet with their URL visible; MsgBlast does not bypass embedded-login restrictions or TLS validation. Navigating away from the main Muse page disables the shared adapter.

For an isolated live-browser check, run `zsh scripts/build_web_preview.sh` and open `build/MsgBlast Web Preview.app`. It uses a separate bundle identifier, blue demo icon, and `~/Library/Application Support/MsgBlast-WebPreview` state. **Muse is live; Messages are synthetic.** This preview never installs over or restarts the development app. Ordinary demo builds use a local HTML fixture and make no live web-service sends.

For a fully synthetic, independently launchable app, run `zsh scripts/build_web_preview.sh --fixture` and open `build/MsgBlast Muse Fixture.app`. Every launch gets a new temporary state directory; neither destination sends externally. [Validation and captured workflow](docs/evidence/muse-webkit/validation.md) distinguish this fixture from live use.

The WebKit tests use the real page engine and DOM adapter against explicitly synthetic HTML. They cover outgoing observation, replies, existing drafts, expired sessions, ambiguous sends, storage failure after observation, and retaining the session identifier. The production broadcast coordinator is tested for all success/failure combinations and edits to the next draft. The native workflow tests compare synthetic replies and retry only a failed Messages recipient. To avoid launching the user's development app during UI testing, use a separate bundle identity:

```sh
xcodebuild -project MsgBlast.xcodeproj -scheme MsgBlast \
  -derivedDataPath build/webkit-validation -destination 'platform=macOS,arch=arm64' \
  'PRODUCT_BUNDLE_IDENTIFIER=com.msgblast.webkit-validation.$(PRODUCT_NAME:rfc1034identifier)' \
  -only-testing:MsgBlastTests -only-testing:MsgBlastUITests/WebServiceWorkflowTests test
```
