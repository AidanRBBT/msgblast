# Cloud Agent and release capability

Hosted Cursor Cloud Agents run on Ubuntu. This runbook is the durable source for what they can verify, how native macOS checks run, and how a requested release is shipped. Recheck the live feed, Actions, and `gh` access before every release. The figures below are a baseline from October 6, 2026, not the next version.

Do not commit `.cursor/environment.json` to switch this repo onto a repository-managed environment. A committed environment file overrides the saved Cloud Agent environment. Keep the saved install equivalent to `scripts/cloud-agent-install.sh`, and change it only after that command has been run successfully.

## What Ubuntu can and cannot do

Ubuntu agents can install the pinned disk-image libraries, test the release scripts, and test the download worker. They cannot build or run the native app, exercise Contacts, Messages, or Full Disk Access, generate real DMG Finder aliases (`mac_alias.Alias.for_file` is unimplemented), inspect a compiled icon, or capture native UI.

Linux results are not native validation. Native checks use GitHub Actions on the `xcode-27` runner. Native UI evidence uses an authorized isolated Mac with Xcode. Cursor My Machines can run that Mac. Do not register the user's live Mac, overwrite the installed app, or change its permissions unless the user has authorized that setup.

## Install

`scripts/cloud-agent-install.sh` is idempotent and exits. It does not start a service.

```sh
bash scripts/cloud-agent-install.sh
```

The script creates `${MSGBLAST_INSTALLER_VENV:-$HOME/.msgblast-installer}` and installs the exact pins in `scripts/installer-requirements.txt` (`ds_store==1.3.1`, `mac_alias==2.2.3`). Use that interpreter for `scripts/build_installer.py`. System `python3` remains the interpreter for `scripts/tests`. The script also runs `npm ci --prefix download` from `download/package-lock.json`.

Cursor's Ubuntu image does not include `python3-venv`. The script installs that package only when `ensurepip` is missing, then removes a half-created virtualenv. The saved Cloud Agent install must inline this script, because a Build checks out `main` and cannot depend on the file until it is merged.

## Linux checks

```sh
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
npm test --prefix download
npm run check --prefix download
```

`npm run check` is `wrangler deploy --dry-run`. It does not deploy the worker. On October 6, 2026 it completed without a Cloudflare token.

Egress for this environment was unrestricted (`allow all`). If a user, team, or environment allowlist is turned on later, allow `github.com`, `registry.npmjs.org`, `pypi.org`, `files.pythonhosted.org`, and `updates.msgblast.app`. Wrangler telemetry may also contact Cloudflare; the dry-run itself does not need a secret.

## Native checks

`.github/workflows/validate.yml` runs on pull requests, pushes to `main`, and manual dispatch. It does not run on tags and does not call `scripts/automate_release.py`. It has read-only contents permission.

The native job matches the release runner:

- `runs-on: xcode-27`
- `DEVELOPER_DIR=/Applications/Xcode_27.0.app/Contents/Developer`
- `xcodebuild -project msgblast.xcodeproj -scheme msgblast -derivedDataPath build/updater-validation -destination 'platform=macOS,arch=arm64' ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo -only-testing:msgblastTests test -quiet`
- `python3 scripts/test_updates.py --derived-data build/updater-validation`

Checkout uses the same pinned `actions/checkout` commit as `.github/workflows/release-adhoc.yml`. The demo icon is intentional for this fixture build. Production release builds keep `AppIcon` and `scripts/release.py` rejects development artwork.

UI regressions live in `msgblastUITests/WorkflowTests.swift`. Select the fixture tests that cover a UI change and capture the interaction on an authorized Mac. The personal-agent fixture command is in [personal-agent-reports.md](personal-agent-reports.md). This validation workflow does not run UI tests, because screenshot evidence has to come from that Mac rather than from an unattended assertion alone.

Watch the run for the proposed revision before merge:

```sh
gh run list -R mgalpert/msgblast --workflow validate.yml --limit 5
gh run view RUN_ID -R mgalpert/msgblast --json status,conclusion,headSha,url,event
```

Confirm `headSha` is the revision under review. Do not dispatch `release-adhoc.yml` as a test.

## GitHub access observed October 6, 2026

`gh auth status` authenticated as the Cursor integration (`cursor`). Recheck it before relying on this list. Do not print tokens.

| Call | Result | Accepted permission |
| --- | --- | --- |
| List workflows and runs | 200 | `actions=read` |
| List pull requests, read a file, read tag `v0.2.2` | 200 | metadata / contents read |
| Push this setup branch | succeeded | branch push works; this does not prove tag push |
| `GET /user` | 403 | integration cannot read the user |
| List Actions variables | 403 | `actions_variables=read` is not granted |
| List Actions secrets | 403 | `secrets=read` is not granted |
| Repository Actions permissions | 403 | not granted |

Tag push and `workflow_dispatch` of `release-adhoc.yml` were not attempted. Either one can publish. A future release needs permission to push an annotated tag, or to dispatch that workflow, in addition to the read access above. Do not create a broad token or change repository security settings to obtain it. If dispatch is required, the integration needs the repository Actions dispatch permission and nothing broader.

The user stated that these Actions variables and secrets already exist: `MSGBLAST_PUBLIC_BASE_URL`, `MSGBLAST_R2_ACCOUNT_ID`, `MSGBLAST_R2_BUCKET`, `MSGBLAST_PUBLIC_KEY`, `MSGBLAST_SPARKLE_PRIVATE_KEY`, `MSGBLAST_R2_ACCESS_KEY_ID`, and `MSGBLAST_R2_SECRET_ACCESS_KEY`. This agent could not list them. Keep signing and R2 secrets only in Actions. No Apple credentials are required for the ad-hoc path.

Repository metadata from this integration reported `"visibility": "public"`. The release docs still say the source repository stays private. This setup did not change visibility.

## Release baseline and procedure

Published baseline checked October 6, 2026:

- Version 0.2.2, build 7, source `f86cce472649d5468792d04a86dd05a7b763774a`
- Actions run `37424723747` (`https://github.com/mgalpert/msgblast/actions/runs/37424723747`), conclusion success
- Manifest `https://updates.msgblast.app/releases/0.2.2-7.json`
- `https://updates.msgblast.app/latest.zip` returned a no-store 302 to `https://updates.msgblast.app/downloads/msgblast-0.2.2-7.zip`

Recheck the feed, manifest, and recent successful runs before choosing another version. Documentation-only preparation does not get a marketing release.

Follow [AGENTS.md](../AGENTS.md) and [automated-releases.md](automated-releases.md). Short form, after review and merge to `main`:

1. Fetch `origin/main` and tags. Confirm the reviewed SHA and an unused, newer `MAJOR.MINOR.PATCH`.
2. Use one trigger. Prefer an annotated `vVERSION` tag pinned to that SHA. Alternatively dispatch `release-adhoc.yml` from `main` with the numeric version. Do not do both.
3. Actions tests, builds, ad-hoc signs, Sparkle-signs, allocates the build counter, and publishes immutable R2 objects. Do not choose or reset the counter, replace an archive, or move a published tag.
4. Verify the run SHA and success, then the feed and `releases/VERSION-BUILD.json`. With User-Agent `msgblast-release-verifier`, confirm `latest.zip` is a no-store 302 to the manifest ZIP. Download through that URL, compare SHA-256, and inspect `Info.plist` (`msgblast`, `com.msgblast.mac`, the allocated version and build) and the compiled green icon.
5. Do not edit the README or redeploy the worker for an app release. Ad-hoc signing is unnotarized. A failed final public check can happen after the feed upload; inspect the feed and manifest before any retry. Rollback is a new higher version and build.

Production artwork is `output/icon-gradients/32-WhiteToClearSoftFade-Polished.icon`, copied to `msgblast/AppIcon.icon`. Development artwork is the blue-green duplicate. Demo and updater fixtures use `AppIconDemo`.
