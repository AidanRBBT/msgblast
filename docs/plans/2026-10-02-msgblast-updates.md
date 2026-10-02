# MsgBlast updates

## Goal Capsule
Use Sparkle 2.10.0 and its standard native UI to update installed MsgBlast bundles safely. Match the Flo State workflow: daily checks, automatic update preference, release notes, Install on Quit and Install and Relaunch. Preserve the live primary checkout and app.

## Product Contract
- Updates run only in configured application bundles. Ordinary demos, permission previews, unbundled SwiftPM runs and XCTest must never query or install production updates.
- Settings exposes automatic checks, automatic downloads/install-on-quit, current version/build and Check for Updates. Preferences belong to Sparkle, not a duplicate store.
- Production feeds/archives use HTTPS and archive Ed25519 verification. No invented production host/key; unconfigured development builds explain that updates are unavailable.
- Save app-owned drafts/attachment references before termination. Delay update-triggered termination while AppModel.busy, allowing existing submissions to finish without retrying them.
- Published releases require Developer ID Application signing, hardened runtime, notarization and stapling. Build numbers are explicitly increasing release counters, not Git counts.
- Release assets remain private until the user selects a distribution host. Private GitHub release URLs are not anonymously downloadable Sparkle feeds.

## Implementation Units
### U1. Native updater
Files: Package.swift, Package.resolved, scripts/generate_project.py, generated Xcode project/resolved packages, MsgBlast/Info.plist, MsgBlast/App/MsgBlastApp.swift, new updater/settings sources, MsgBlast/Core/UpdateConfiguration.swift, MsgBlastTests/UpdateTests.swift, narrowly scoped app termination support, existing menu UI regression.
Use SPUStandardUpdaterController with observed canCheckForUpdates and preference properties. Info.plist configuration uses SPARKLE_FEED_URL, SPARKLE_PUBLIC_ED_KEY, MARKETING_VERSION and CURRENT_PROJECT_VERSION build settings. Blank feed/key are the development default. Add a narrowly scoped DEBUG-only local updater fixture/probe for isolated real Sparkle installation tests. Verify policy and termination behavior through focused tests and actual runtime.

### U2. Release tooling
Files exclusively: scripts/release.py, scripts/tests/test_release.py, docs/updates.md, release-notes/0.1.0.md.
Build and export via xcodebuild archive/exportArchive using Developer ID, include explicit version/build/feed/key configuration, notarize/staple, package with ditto, run Sparkle sign_update/generate_appcast and verify artifacts. Prepare locally, without automatically deploying or making the private repo public. Have a dry-run and reject missing credentials/insecure URLs/nonincreasing counters. Document installing the first updater-enabled app in /Applications and credentials/static HTTPS hosting needed. Unit tests prove the actual command plan/configuration and failures. Do not build shared targets while U1 edits them.

### U3. Integration verification and evidence
Files: scripts/test_updates.py, focused native tests if needed, docs/evidence/updates/**, README.md.
Build in this worktree only. Exercise real signed old-to-new update, signature rejection, no-update and failed-download cases using temporary app bundles/data and a localhost feed. Preserve a draft and attachment through installation/relaunch. Verify the native settings and standard Sparkle prompt and capture actual screenshots/short video, labeling all local synthetic fixtures. macOS-only UI: mobile screenshot is not applicable. Run relevant core/controller and native regressions. Never send real messages, modify real Contacts, replace the primary app, or reset its permissions.

## Verification Contract
Policy tests reject ordinary previews/demo/invalid or absent production configuration; configured real apps accept HTTPS and valid public keys. Update lifecycle tests prove busy waits and failed save cancels termination. Release tests prove signing/notarization are required and explicit increasing build counters feed the bundled metadata. Real Sparkle local signed installation must advance the bundled build; invalid archive signatures must not install. Native controls reflect persisted preferences; actual standard update dialog and result have screenshot/video evidence.

## Definition of Done
U1/U2/U3 work complete and local checks/evidence recorded; simplify and independent code review applied; changes committed on codex/sparkle-updates and delivered via a private GitHub PR with Screenshots and Video sections. Production deployment is not authorized until signing credentials and distribution host are provided; clearly document that prerequisite rather than pretending a live update service exists.
