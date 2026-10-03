# Release automation validation

`validation.json` contains captured command output, exit statuses and source hashes from the automation revision, plus the manifest from a real local universal ad-hoc Release preparation. No Apple credentials or notarization were used. The local ZIP and appcast were verified with official Sparkle tools during preparation; no production upload occurred.

The Python publication tests use synthetic storage/network and mocked signing/CLI responses. They exercise counter reservation, immutable archive writes, archive-before-feed ordering, authentication failure, artifact tampering and concurrent publication. They do not prove a real R2 host works.

The app preparation preceded a command-construction simplification and strict-key-validator extraction that preserve preparation command contents and order. The new publisher guard rejects malformed keys before prior-feed verification. This capture reruns the current test suite and independently verifies the previously prepared app's nested code signatures and hardened runtime. Source hashes identify the current automation code. The ephemeral private test key was removed; the public key in the manifest is a fixture key, not the persistent production key.

Workflow lint passes with external ShellCheck disabled. The `xcode-27` label is explicitly allowlisted for the linter using GitHub's official hosted-runner image documentation; this does not configure a self-hosted runner.

## Screenshots

Release automation is a nonvisual CI/storage change. A meaningful screenshot of an actual hosted run cannot be captured yet: the workflow is not merged and no hosted app release has run. R2 bucket/domain, credentials, Actions configuration and cache bypass are now configured; authenticated conditional writes and anonymous diagnostic download/hash verification passed. Native Terminal is unavailable through the enabled computer-use surface. The actual command outputs are retained in `validation.json`; no unrelated browser screenshot is used. The original native updater screenshots in `../updates/` still demonstrate the unchanged app feature.

## Video

No hosted release video is claimed because no hosted release has run. The original native updater interaction video in `../updates/` demonstrates app installation with isolated fixtures, not this new Actions/R2 pipeline. First hosted publication and a real old-to-new distributed update remain activation checks.

## Review reconciliation

Full CE review completed (`20261002-132710-e4ec132a`). Confirmed P2 finding 1 was applied inline: reusable strict seed validation now precedes all publisher signing-tool calls. The orchestration regression failed before the fix and passes afterward, with no storage/tool invocation or key content in either output stream. All 32 Python tests pass. No actionable findings remain unresolved. A separate success-path orchestration test verifies counter/snapshot propagation, source revision and summary using synthetic preparation/publication.

Hosted publication and actual Release-artifact installation/relaunch with permission retention remain activation checks. The final public feed check can fail after publication; the operator guide explains how to inspect authenticated state before a rerun.

## PR 1 merge review

Fresh nine-lens review (`20261002-213628-1fe181ad`) confirmed one P2 fixture-icon mismatch. It is corrected: the isolated Debug source selects `AppIconDemo`, and the fixture script rejects an incorrect source icon before any key generation or temporary fixture creation. The rejection was exercised against the existing live-icon source, then the corrected fixture passed all four real Sparkle scenarios. Native screenshots/video were recaptured with the blue demo icon, successful relaunch, retained draft/attachment and preferences. Standard and Release defaults retain `AppIcon`. See `review-verification.json` for source hashes and limits.
