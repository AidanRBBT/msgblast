# msgblast agent instructions

## App icons

- **Development/live app:** use the saved blue-green duplicate of exploration 32. Its source is `output/icon-gradients/32-WhiteToClearSoftFadeBlueGreen.icon`; the app resource is `msgblast/AppIcon.icon`.
- **Demo/fixture app:** use the saved blue duplicate of exploration 32. Its source is `output/icon-gradients/32-WhiteToClearSoftFadeBlue.icon`; the app resource is `msgblast/AppIconDemo.icon`.
- Standard builds select `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`. `scripts/build_demo.sh` selects `AppIconDemo`. The distinction is development versus demo, not Debug versus Release.
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

### Each release

1. Select the reviewed source revision and write user-facing `release-notes/VERSION.md`; include them on the default branch.
2. Push an annotated version tag, e.g. `git tag -a v0.1.1 -m 'Release 0.1.1'`, then `git push origin v0.1.1`. Or dispatch the release workflow from the default branch with numeric version `0.1.1`.
3. Let Actions run the Python release/publication tests, core/controller Xcode regressions and isolated real Sparkle fixtures, then prepare and publish. Inspect its result/summary; it records the source revision, build counter, download/feed URLs and retains successful private artifacts for 30 days.
4. For the first hosted release, verify an installed prior build can Check for Updates, install/relaunch and retain drafts, attachments, agents, comparisons, preferences and macOS permissions. Do not send real messages, write real Contacts, overwrite the user's live app or reset its permissions solely to validate a release. Keep fixture/demonstration limits labeled in PR evidence.

The publisher verifies the existing signed feed directly from authenticated R2, then atomically reserves the next counter in `release-counter.json`. Counters are independent of Git commit count; failed attempts consume numbers and reruns get fresh immutable archive names. Never reset the ledger or reuse a filename for different bytes. It uploads/verifies the ZIP first, retains an immutable manifest, and updates the signed feed **last** with an ETag condition. Signature, authentication or public download failures stop publication; a competing publisher cannot replace a newer feed. GitHub may replace an older pending concurrency run with a newer one: inspect canceled pending tags before deciding to rerun them.

Ad-hoc app signing is explicit and unnotarized, with disabled library validation for nested ad-hoc code and strict code-signature verification. Sparkle still authenticates both feed and ZIP with Ed25519. First-launch approval may be needed, and TCC permission retention must be verified on actual distributed updates. Do not claim Apple-verified publisher identity, Gatekeeper acceptance or notarization for this path. Developer ID remains the default for direct `scripts/release.py` calls; use `--signing-mode ad-hoc` for this credential-free path rather than silently falling back when Apple credentials are absent.

Rollback means releasing the intended reverted source again with a larger allocated counter. Lowering the feed counter will not downgrade installed clients. Signing-key/identity changes require a deliberate migration. Missing R2 hosting or Actions variables/secrets are activation prerequisites; committed workflow code alone does not prove live distribution is configured.

## Pull request evidence

- Every PR I create or update must include **Screenshots** and **Video** sections in its description showing the changes in that PR. A screenshot of whatever browser tab happens to be open does not count.
- Capture the actual changed feature or workflow from the reviewed revision. Include desktop and mobile screenshots for responsive UI changes, and a short video showing the relevant interaction and result. Show before/after states when they make the change clearer.
- Embed screenshots and embed or directly link a playable video in the PR description; local-only file paths are not sufficient for reviewers. Keep evidence within the repository's existing access boundary.
- For nonvisual changes, show the relevant terminal/API workflow when feasible. If meaningful visual evidence cannot be captured, explicitly explain why in those sections; never silently omit them or substitute unrelated visuals.
- Label local fixtures, simulated inputs, edited timing, and other demonstration limitations accurately. Refresh evidence after changes that affect what it demonstrates. Do not start paid jobs or live matches solely to capture evidence without existing authorization.
- When the user asks for screenshots of a PR, show the changed feature's evidence, not the currently open browser page.
