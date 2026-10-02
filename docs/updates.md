# MsgBlast updates

MsgBlast integrates Sparkle 2.10.0's native updater. A configured installed app checks daily, offers release notes and the standard installation choices, and stores update preferences through Sparkle. Settings → Updates shows the current version/build, automatic check and download preferences, and Check for Updates.

Ordinary development builds have no feed or signing key, so updates remain unavailable. Demos, permission previews, unbundled SwiftPM runs and XCTest do not query production feeds. Local update verification uses separate temporary fixtures, not the user's running app.

## Before the first production release

Production distribution is not configured yet. The repository is private, and no distribution host or Developer ID Application signing identity has been supplied. Apple Development identities are insufficient for this release pipeline. No production release or public hosting is created by these scripts.

The release operator needs:

- Python 3.11+ and the Xcode/macOS versions listed in the repository README.

- A Developer ID Application certificate and its private key in the release machine's Keychain, from the intended Apple Developer team. Keep the same bundle identifier (`com.msgblast.mac`) and signing team across releases.
- An existing `notarytool` Keychain profile with Apple's notarization credentials. Create this interactively with `xcrun notarytool store-credentials msgblast-notary`; do not put passwords or API private keys in this repository or command logs.
- The **Sparkle 2.10.0 distribution**, including its `bin` directory, from the [official release](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0). Use the same version as the app's pinned dependency.
- A dedicated Sparkle Ed25519 signing key, created once with `/path/to/Sparkle-2.10.0/bin/generate_keys --account msgblast`. Store the private key in Keychain; copy only the printed public key into release configuration. Preserve a secure backup outside the repo. `generate_keys --account msgblast -p` retrieves the existing public key without generating a replacement.
- A chosen static **HTTPS** feed URL and archive directory. These must be downloadable by the installed app without a GitHub login or expiring URL. The private `mgalpert/msgblast` repository's release assets and raw-file URLs are not anonymous update hosting. Keep the repo private; select distribution hosting separately.
- An explicit release counter. For the first release, use build `1` and previous build `0`. For later releases, read the highest counter already published and choose a larger value, even if the marketing version has not changed. Never derive the counter from Git commit count. The script validates the supplied previous counter; it does not contact a production feed or reserve counters for multiple operators.

Install the first updater-enabled, signed and notarized `MsgBlast.app` in `/Applications`. Users whose current app predates the updater need this one manual installation. Quit the existing copy before installing; keep developer and demo bundles in separate paths. Confirm Full Disk Access, Contacts and Messages Automation on the first installation. Stable signing is necessary for consistent app identity, but permission preservation must also be checked during the first real Developer ID update.

## Prepare locally

Run from the worktree/repo containing the release source. Write `release-notes/VERSION.md` first. The included `release-notes/0.1.0.md` is a draft for the first updater release, not a published release announcement.

This example uses deliberately fictitious identity/hosting values. Replace them with the selected real identity, team, host and public key; do not use the example URLs as production configuration.

```sh
python3 scripts/release.py \
  --version 0.1.0 \
  --build 1 \
  --previous-build 0 \
  --identity 'Developer ID Application: YOUR ORGANIZATION (TEAMIDHERE)' \
  --team-id TEAMIDHERE \
  --notary-profile msgblast-notary \
  --feed-url https://YOUR-HOST.example/msgblast/appcast.xml \
  --download-url-prefix https://YOUR-HOST.example/msgblast/downloads/ \
  --public-key 'YOUR_BASE64_PUBLIC_KEY' \
  --sparkle-bin /path/to/Sparkle-2.10.0/bin \
  --keychain-account msgblast \
  --dry-run
```

`--dry-run` validates the configuration and prints the commands/export options without reading Keychain, running commands, creating files, notarizing or uploading. It therefore cannot prove the certificate/profile/key exists. Replace the placeholder public key with a valid base64 32-byte public key even for a dry run.

Remove `--dry-run` to prepare production artifacts. The script:

1. Requires the selected Developer ID Application identity in Keychain, checks the Sparkle Keychain public key matches the configured key, and checks the notarization profile before building.
2. Runs `xcodebuild archive` in an isolated derived data directory and exports with `method=developer-id`. Xcode signs nested frameworks and Sparkle helpers; the script does not recursively re-sign them or substitute ad-hoc signing. The release uses the saved development/live icon (`AppIcon`), not the demo icon.
3. Supplies `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `SPARKLE_FEED_URL`, and `SPARKLE_PUBLIC_ED_KEY`. Verifies exported metadata, archive signature policy, `MsgBlastCore.framework`, `Sparkle.framework`, Developer ID identity, hardened runtime and the Messages Automation entitlement.
4. Packages with `ditto`, submits to Apple notarization and requires an Accepted result. Staples and validates the ticket, checks Gatekeeper and the code signature again, then makes the final ZIP **after** stapling.
5. Signs and verifies that ZIP using Sparkle. Generates a one-release appcast with embedded Markdown notes and no delta artifacts, checks the enclosure's URL/signature/size and version/build, then signs and verifies the appcast itself.
6. Writes a local manifest containing the release configuration, notarization result, archive signature and artifact SHA-256 hashes. Never uploads, publishes a GitHub release, changes repository visibility, replaces `/Applications/MsgBlast.app`, or restarts the running app.

Artifacts default to `build/releases/VERSION-BUILD/`. A directory must be fresh; failures leave diagnostic/build artifacts and cannot overwrite earlier output. After fixing a failure, choose a fresh `--output` path. Do not publish a directory without `publish/release.json`, which is written only after all checks succeed.

```text
build/releases/0.1.0-1/
  MsgBlast.xcarchive/
  ExportOptions.plist
  export/MsgBlast.app             signed, notarized, stapled app
  publish/
    MsgBlast-0.1.0-1.zip          final signed update archive
    MsgBlast-0.1.0-1.md           source notes, embedded into appcast
    appcast.xml                 archive signature plus feed signature
    release.json                successful preparation manifest
```

## Publish after the distribution host is selected

Publishing is a separate operator step. The ZIP and appcast are intended for distribution to installed app users; repo privacy alone cannot make an authenticated private GitHub URL work with Sparkle. If distribution itself must be authenticated, design its authentication before choosing URLs; no authentication adapter is implemented here.

1. Review the built app and notes. Test the actual old production-signed app → new production-signed app with both installation choices. Verify saved agents, comparisons, drafts, attachment references and permissions survive. Do not send real messages just to test an update.
2. Upload the final ZIP under its immutable version/build filename at `--download-url-prefix`. Download it anonymously and compare its SHA-256 to the local manifest. Keep earlier ZIPs available; never reuse an old filename for different bytes.
3. Upload the unchanged signed appcast **last** to the exact `--feed-url` URL. Its embedded notes need no separately hosted notes page. This tool emits a one-release feed; publish it as the stable feed for the new release, while retaining earlier artifacts and manifests separately.
4. Download the published feed without a logged-in browser session and verify it with Sparkle's `sign_update --account msgblast --verify /path/to/downloaded-appcast.xml`. Check every enclosure is anonymously downloadable and resolves to the verified archive. Confirm a manually initiated update from an installed prior build works before relying on automatic checks.
5. Retain the source revision, explicit release counter, manifest and signing/notarization records. The next release must use a larger counter. A rollback is another forward release with a larger counter and the intended reverted code; lowering the feed counter will not downgrade installed clients.

Never edit the ZIP or signed feed after preparation. If release notes or the feed change, regenerate and sign the artifacts again. Never place the Sparkle private key, Apple private key or notarization secret in the feed, source tree, issue, PR or release asset.

## Verification and current limits

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p test_release.py -v
```

These focused tests use temporary synthetic app/ZIP/feed artifacts and simulated command outputs. They prove command configuration, required signing/notarization/HTTPS inputs, key matching, ordering, failure handling, metadata/signature checks, fresh output handling and dry-run behavior. They do **not** constitute a Developer ID release or successful Apple notarization.

Isolated updater integration evidence is recorded under `docs/evidence/updates/`. Local fixtures cannot prove production signing, hosting or permission preservation. A real production prepare/update remains contingent on Developer ID credentials, notarization credentials, the persistent Sparkle signing key and a selected distribution host.

This initial pipeline prepares one stable release locally. It does not add CI credential storage, paid services, beta channels, phased rollout, delta updates, authenticated hosting or automatic publishing.

References: [Sparkle publishing guidance](https://sparkle-project.org/documentation/publishing/), [Sparkle 2.10.0 generate_appcast command contract](https://github.com/sparkle-project/Sparkle/blob/2.10.0/generate_appcast/main.swift), [Sparkle signing tools](https://github.com/sparkle-project/Sparkle/blob/2.10.0/sign_update/main.swift), [Apple Developer ID distribution](https://developer.apple.com/developer-id/), [Apple notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Open source and ad-hoc distribution

Publishing source does not require an Apple Developer ID. Ad-hoc apps can use cryptographically signed Sparkle updates; the isolated local fixtures exercise that path. Developer ID signing and notarization provide Apple-verified publisher identity and a smoother first install. Stable signing also helps macOS recognize the app across versions for privacy permissions.

For a personal app or technical beta, ad-hoc distribution is possible with manual first-launch approval and persistent Sparkle signing keys. This repository's production preparation script deliberately requires Developer ID/notarization; it does not silently fall back to ad-hoc when credentials are missing. The localhost fixtures are temporary tests, not a public beta release or a long-lived feed.
