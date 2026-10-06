# msgblast agent instructions

## App icons

- **Live/production app (default for users):** use the green polished exploration 32 icon. Its source is `output/icon-gradients/32-WhiteToClearSoftFade-Polished.icon`. Ensure `msgblast/AppIcon.icon` contains this green artwork when preparing a live build or release.
- **Development app:** use the saved blue-green duplicate of exploration 32. Its source is `output/icon-gradients/32-WhiteToClearSoftFadeBlueGreen.icon`; the development app resource is `msgblast/AppIcon.icon`.
- **Demo/fixture app:** use the saved blue duplicate of exploration 32. Its source is `output/icon-gradients/32-WhiteToClearSoftFadeBlue.icon`; the app resource is `msgblast/AppIconDemo.icon`.
- Standard builds select `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`. `scripts/build_demo.sh` selects `AppIconDemo`. Verify the selected artwork matches the intended live, development, or demo build before building or publishing; choosing Release alone does not switch the development icon to green.
- The unsuffixed `output/icon-gradients/32-WhiteToClearSoftFade.icon` is an editable exploration and may have a different background. Use the verified green `32-WhiteToClearSoftFade-Polished.icon` for live builds.
- Preserve the user's saved artwork when copying these icons into the app resources. Keep both icon resources registered in `scripts/generate_project.py` and the generated Xcode project.
- Validate icon changes with an isolated derived data directory. The demo script uses `build/icon-demo` and packages `build/Build/Products/Debug/msgblast Demo.app`. Do not overwrite or restart the user's running development app merely to validate an icon change.

## Building and publishing app updates

The default distribution path is now **automated ad-hoc releases without Apple credentials**. `.github/workflows/release-adhoc.yml` runs for pushed `vVERSION` tags or manual dispatches from the default branch. Pushing ordinary source commits does not distribute a new app. The workflow tests, builds, ad-hoc signs, signs the Sparkle ZIP/feed, uploads to an existing public R2 host and verifies anonymous downloads. No coding agent needs to repeat build/sign/upload commands each release.

Read `docs/automated-releases.md` before activating or changing the pipeline; use `docs/updates.md` for the optional Developer ID/notarization path. The workflow must be on the default branch and release source must be reachable from it. The source repo remains private; installed apps need a separately configured public HTTPS archive/feed host.

### One-time activation

- Configure a dedicated Cloudflare R2 bucket and HTTPS custom domain. Set Actions variables `MSGBLAST_PUBLIC_BASE_URL` (ending in `/`), `MSGBLAST_R2_ACCOUNT_ID`, `MSGBLAST_R2_BUCKET` and `MSGBLAST_PUBLIC_KEY`.
- Set Actions secrets `MSGBLAST_SPARKLE_PRIVATE_KEY` (persistent base64 32-byte seed), `MSGBLAST_R2_ACCESS_KEY_ID` and `MSGBLAST_R2_SECRET_ACCESS_KEY`. Scope the R2 credential to the release bucket. Apple certificate/team/notarization credentials are not required.
- Generate the Sparkle key once, retain its Keychain copy and secure backup, and reuse it across releases. Never put private keys in YAML, command arguments, logs, PRs, source or assets. The workflow uses an owner-only temporary seed file outside artifacts and removes it with `always()` cleanup.
- Respect archive cache headers and bypass cache for `appcast.xml` and `release-counter.json`. Do not host the feed behind GitHub login, expiring tokens or a development `r2.dev` URL.
- Preserve bundle identifier `com.msgblast.mac`, update key and installed app location. Users whose current version lacks Sparkle need one manual installation into `/Applications`; ordinary development builds with no feed/key cannot receive updates.

The README download URL is fixed at `https://updates.msgblast.app/latest.zip`. The `download/` Worker verifies the published signed appcast and redirects to its highest build; releases do not require README edits or Worker redeployments. Keep the redirect uncached and archive names immutable. See `download/README.md` for maintaining the endpoint and the limits of request logs as download metrics.

### Version and build numbers

- Use `MAJOR.MINOR.PATCH` for the user-facing version. Increase PATCH for fixes, MINOR for new features, and MAJOR for incompatible changes after 1.0. During 0.x development, incompatible changes also advance MINOR. Reset lower components when advancing a higher component. Documentation-only commits do not need an app release.
- Read the current published `appcast.xml` and recent successful Actions runs before selecting a version. Examples below use `0.1.3`; they are examples, not a permanent next-version setting. Do not infer the published version from a local development app.
- `CFBundleShortVersionString` is the marketing version; `CFBundleVersion` is the automatically allocated build counter. About must show the distributed values, for example `Version 0.1.3 (5)` if Actions actually allocated build 5.
- The publisher allocates the counter from `release-counter.json` and the authenticated signed feed. Never choose, reset, or manually increment a production build counter. Failed reservations leave gaps; reruns use a new counter.
- The release workflow passes `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` to Xcode. Keep Info.plist's build-setting substitutions intact. Local project defaults in `scripts/generate_project.py` and the generated project are development defaults; changing those alone does not publish or prove a release version.
- Choose a new marketing version for new published source. A retry of an unsuccessful release can reuse its intended marketing version, with a fresh allocated build. Never replace previously published archive bytes or move a published tag.

### Push source changes

1. Inspect the branch, index, and working tree before editing or committing. Use an isolated `codex/` branch/worktree when other work is present. Commit only the requested files; do not absorb unrelated changes or reset the user's checkout.
2. Complete the change and relevant checks. For an app release, add concise user-facing `release-notes/VERSION.md` to the same reviewed source. Verify the saved green production artwork matches `msgblast/AppIcon.icon`; `scripts/release.py` enforces this before building.
3. Push the source branch and get the intended changes reviewed and merged onto `main`. Honor the PR evidence requirements below. Fetch `origin/main` and identify the exact reviewed release revision. Do not force-push `main`.
4. A source push or PR merge does **not** publish an app. Trigger distribution when the user requests a release/update. Report source-only work as source-only until publication has been verified.

### Trigger a release

Prefer an annotated tag pinned to the reviewed revision. Run the commands separately, check each result, and stop on failure. First confirm the version is newer than the published version and the tag is unused. After the source and release notes are merged:

```sh
git fetch origin main --tags
release_version=0.1.3
release_revision=$(git rev-parse origin/main)
git cat-file -e "$release_revision:release-notes/$release_version.md"
git tag -a "v$release_version" "$release_revision" -m "Release $release_version"
git push origin "v$release_version"
```

Verify `release_revision` is the reviewed commit before tagging. The workflow requires tagged source to be reachable from the default branch. Never use an unreviewed local HEAD merely because the local branch is named `main`.

Alternatively, dispatch the workflow from `main` with a numeric version, without the `v` prefix:

```sh
gh workflow run release-adhoc.yml -R mgalpert/msgblast --ref main -f version=0.1.3
```

Dispatch builds `main` as resolved for that run. Verify the run's `headSha` matches the intended source; use a tag when the revision must be pinned. Choose **one** trigger per release. Do not push a tag and dispatch the same release as two separate jobs.

Actions handles testing, building, ad-hoc signing, Sparkle signing, counter allocation and R2 publication. Do not repeat those steps manually or add Apple credentials for this distribution path.

### Verify publication before calling it released

1. Identify the run belonging to the chosen tag/dispatch and check its source SHA. Wait for completion and inspect its conclusion and summary. A queued, canceled, failed, or unfinished run is not evidence of a successful release.

   ```sh
   gh run list -R mgalpert/msgblast --workflow release-adhoc.yml --limit 5
   gh run view RUN_ID -R mgalpert/msgblast --json status,conclusion,headSha,url
   gh run watch RUN_ID -R mgalpert/msgblast --exit-status --interval 20
   ```

2. Check the published signed feed and immutable `releases/VERSION-BUILD.json` manifest. Confirm version, allocated build and `source_revision`; use the actual allocated build from the run, not a predicted counter.
3. Check that `https://updates.msgblast.app/latest.zip` returns a no-store **302** to the manifest's immutable ZIP URL. Download through that fixed URL and compare its SHA-256 with the manifest. Use the known verifier User-Agent for CLI checks:

   ```sh
   curl -fsSI -A msgblast-release-verifier https://updates.msgblast.app/latest.zip
   ```

4. Inspect `msgblast.app/Contents/Info.plist` inside the downloaded ZIP: the version/build must match the feed and manifest, the app name must be `msgblast`, and the bundle ID must be `com.msgblast.mac`. Inspect the compiled icon in the downloaded artifact and verify the green production icon. Inspecting only source artwork does not prove the distributed icon is correct.
5. The README keeps `https://updates.msgblast.app/latest.zip` without a hardcoded version label. A successfully published feed advances the redirect automatically; do not rewrite the README for each build or point it back to an old immutable archive.
6. Report the verified version/build, release result and fixed download link. Publishing does not mean the user's installed app has updated. For the first hosted update, validate install/relaunch and retention of drafts, attachments, agents, comparisons, preferences and macOS permissions with the user's authorized setup. Do not send real messages, write real Contacts, overwrite the user's live app or reset permissions solely to validate a release. Keep fixture limits labeled in PR evidence.

### Failed releases and rollback

- Inspect the failed step, signed feed and immutable manifest before retrying. If failure occurs after the conditional feed upload, the release may already be live even though the final anonymous check failed.
- Fix the cause, then rerun the same intended release only when appropriate. Its build counter will advance; do not delete published objects, reset the ledger, reuse a ZIP filename, or force-move the tag. If fixing source changes the tagged revision, choose a new version/tag.
- GitHub can replace an older pending concurrency run with a newer pending run. Check canceled runs and decide whether their source should still ship; do not blindly rerun every canceled job.
- Rollback is a new release of the intended reverted source with a new marketing version and a larger automatically allocated build. Lowering the feed counter does not downgrade installed clients.

The publisher verifies the existing signed feed directly from authenticated R2, then atomically reserves the next counter in `release-counter.json`. Counters are independent of Git commit count; failed attempts consume numbers and reruns get fresh immutable archive names. Never reset the ledger or reuse a filename for different bytes. It uploads/verifies the ZIP first, retains an immutable manifest, and updates the signed feed **last** with an ETag condition. Signature, authentication or public download failures stop publication; a competing publisher cannot replace a newer feed. GitHub may replace an older pending concurrency run with a newer one: inspect canceled pending tags before deciding to rerun them.

Ad-hoc app signing is explicit and unnotarized, with disabled library validation for nested ad-hoc code and strict code-signature verification. Sparkle still authenticates both feed and ZIP with Ed25519. First-launch approval may be needed, and TCC permission retention must be verified on actual distributed updates. Do not claim Apple-verified publisher identity, Gatekeeper acceptance or notarization for this path. Developer ID remains the default for direct `scripts/release.py` calls; use `--signing-mode ad-hoc` for this credential-free path rather than silently falling back when Apple credentials are absent.

Signing-key/identity changes require a deliberate migration. Missing R2 hosting or Actions variables/secrets are activation prerequisites; committed workflow code alone does not prove live distribution is configured.

## Cursor Cloud specific instructions

Hosted Cloud Agents run on Ubuntu and cannot validate the native Mac app. Follow [docs/cloud-agent.md](docs/cloud-agent.md) for install, Linux checks, the non-publishing native workflow, GitHub access limits, and release verification. Linux tests are not a substitute for `.github/workflows/validate.yml` on the `xcode-27` runner.

- Install with `bash scripts/cloud-agent-install.sh`. It pins `scripts/installer-requirements.txt` in `${MSGBLAST_INSTALLER_VENV:-$HOME/.msgblast-installer}` and runs `npm ci --prefix download`. Do not commit `.cursor/environment.json`; that file overrides the saved environment.
- Linux checks: `python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v`, then `npm test --prefix download` and `npm run check --prefix download`. The Wrangler check is a dry-run and does not deploy.
- Native core checks belong to `validate.yml` (`msgblastTests` plus `scripts/test_updates.py` on `xcode-27`). Cursor PR branches (`cursor/*`) and manual `workflow_dispatch` also build two ad-hoc preview ZIPs in that workflow: blue-green `msgblast Dev.app` (`com.msgblast.development`) and blue fixture `msgblast Demo.app` (`com.msgblast.demo`, `msgblastDemo` true). Artifacts stay on the Actions run for 14 days. Do not dispatch `release-adhoc.yml` as a test.
- Pull request descriptions need `## Screenshots`, `## Video`, and `Evidence-SHA: <branch head>`. `.github/workflows/pr-evidence.yml` rejects missing, local-only, placeholder, or stale evidence, including an empty or local `<video>` tag. Cursor branch previews also need separate `msgblast Dev SHA-256:` and `msgblast Demo SHA-256:` lines. A human still checks that the pictures show the change. A written exception is for that person to review; the checker does not treat it as a pass. Native UI evidence needs an authorized isolated Mac; Ubuntu cannot capture it, and an `.xcresult` is not a video. Do not use the user's live Mac without setup authorization.
- Keep Sparkle and R2 secrets in Actions only. Recheck `gh auth status` and the live appcast before any release. The October 6, 2026 baseline is 0.2.2 build 7 at `f86cce472649d5468792d04a86dd05a7b763774a`.

## Pull request evidence

- Every PR I create or update must include **Screenshots** and **Video** sections in its description showing the changes in that PR. A screenshot of whatever browser tab happens to be open does not count. Include `Evidence-SHA: <40-character branch head>` so `.github/workflows/pr-evidence.yml` can reject stale evidence. Cursor branch previews also name `msgblast Dev`, the `msgblast Demo` fixture, the Actions run URL, and separate lines `msgblast Dev SHA-256:` and `msgblast Demo SHA-256:` with different hashes. The workflow checks structure only; a human still has to confirm the images and video show this change.
- Capture the actual changed feature or workflow from the reviewed revision. Include desktop and mobile screenshots for responsive UI changes, and a short video showing the relevant interaction and result. Show before/after states when they make the change clearer.
- Embed screenshots and embed or directly link a playable video in the PR description; local-only file paths are not sufficient for reviewers. Keep evidence within the repository's existing access boundary.
- For nonvisual changes, show the relevant terminal/API workflow when feasible. If meaningful visual evidence cannot be captured, write the reason for a person to review. `scripts/check_pr_evidence.py` does not accept that explanation, an empty `<video>`, a local file, an unrelated image, or an example hidden in a code fence, indented code block, HTML comment, pre or code element, inline code, or escape. This setup change can record the workflow, so its screenshots and playable video stay mandatory.
- Label local fixtures, simulated inputs, edited timing, and other demonstration limitations accurately. Refresh evidence after changes that affect what it demonstrates. Do not start paid jobs or live matches solely to capture evidence without existing authorization.
- When the user asks for screenshots of a PR, show the changed feature's evidence, not the currently open browser page.
