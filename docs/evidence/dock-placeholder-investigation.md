# Dock placeholder investigation — October 1, evening

The user's 8:26:54 PM screenshot shows a generic icon grid labelled msgblast in the Dock. This is actual failure evidence. A normal foreground application registration alone does not establish that the Dock rendered its icon.

Read-only checks found:

- Running msgblast is registered as a foreground application, not an accessory process.
- The built bundle contains `CFBundleIconFile=AppIcon`, `CFBundleIconName=AppIcon`, `AppIcon.icns`, and `Assets.car`; strict code-signature verification succeeded at inspection time.
- Extracting both small and large ICNS renditions shows the green chat-stack artwork.
- `NSRunningApplication.icon` and `NSWorkspace.icon(forFile:)` both resolved green chat-stack artwork, with different artwork revisions. The running icon export is retained under `onboarding/dock-resolved-running-icon.png`.
- The canonical Debug executable and icon resources were replaced at 8:25 PM after the current live process launched. Two other user-owned chats are working in the same checkout; the Discover chat invoked a test build against canonical `build`, while the icon chat continues changing the artwork source.
- The user expressly authorized coordination. Both chats received requests to use separate build folders and preserve the running canonical bundle.

Concurrent bundle replacement is confirmed. Its causal role in the Dock placeholder has not yet been visually validated by relaunching a stable bundle. The native Dock inspection tool timed out, and the Mac subsequently became locked. No Dock cache was deleted and no system process was forcibly restarted.

## Attachment observations during that overlap

Live shared synthetic-image and private synthetic-file sends have reconciled outgoing anchors, and their cards appear in the correct msgblast columns. Live Quick Look opened an empty panel for both file types. A frozen app with a separate bundle identifier and build directory successfully showed the same synthetic image in native Quick Look with three joined columns. The first isolated attempt failed at a test selector; the next reached a valid preview but failed an incorrect filename-as-window-title assertion. Neither result is a passing regression or a reproduction of the live empty panel.

Filtered system logs naming only the synthetic test file report `sandbox_extension_issue_file failed` and transcoder `Operation not permitted` errors at 8:26 and 8:29 PM. These came from Messages attachment-processing services, not from the isolated test's Quick Look view. They do not prove external delivery, or establish the cause of the live empty panel. Direct CLI access to the Messages database remained denied; no access restriction was bypassed.

A stable-build, current-permission check and native Messages inspection remain required. No preview implementation change has been made on an unconfirmed theory.

## Checks after the user unlocked the Mac

The canonical app was quit and relaunched from its complete path after the concurrent builds stopped. It now reports denied history access, so the old process's successful access does not establish approval for the current on-disk development signature. Dock rendering is still not independently observed.

Native Messages explicitly shows Delivered for Pal's shared MB1001-2016 text and Not Delivered for the synthetic PNG. Native Messages Quick Look nevertheless shows that failed PNG correctly. This proves downstream file-send failure and rules out a universally unpreviewable test file; it does not identify the transfer failure's cause. No failed attachment was resent.

The corrected isolated Quick Look check passed at 20:54:58 (one test, zero failures). A saved regression generates its own two-color PNG, sends only in an isolated Demo, and asserts the exact native Image Preview identifier after a joined transcript click. That regression passed at 20:58:32 (one test, zero failures); it captures only the Quick Look panel. These are fixture preview checks, not live transfer evidence.

The canonical app was rebuilt only after quitting it and after both other chats moved builds aside. The current build succeeded at 21:03:52 and strict signature verification passed. System Settings explicitly shows msgblast off under Full Disk Access. Its existing approval must be refreshed by the user before final live history/transfer checks. The relaunched process remains foreground with a resolved icon, but metadata is not visual proof of Dock rendering.

The saved Quick Look test's early screenshot caught an unrendered transition, so that image is excluded from feature evidence. Its accessibility assertion passed in the full 47-check run, while the subsequent stronger pixel-rendering assertion compiled but was interrupted by a Codex dialog. It remains to be executed without that interruption.

Further fixture diagnosis found unsupported color-space warnings in the generated preview image. Its blank screenshot is therefore not explained by timing alone. The regression now writes explicit opaque RGBA bytes; an ImageIO/CoreGraphics round trip verified the blue/green regions and alpha. Its native rerun was interrupted before preview and was stopped; a later Computer Use check reports the Mac locked. No passing pixel-rendering result, current Dock observation or current live access is inferred.
