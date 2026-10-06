# Release 0.4.3 preparation

Base: `d97121478b561e6a278ca7bfb7b7f6c6d8105ff0` on main, including the Sequoia change, PRs #3 and #7, and the final Muse CPU-readback fix in PR #13. This preparation changes release notes, user documentation, and the development marketing-version default. Actions still supplies the production version and allocates the build counter.

## Checks

- Signed public feed authenticated with the configured persistent public key: **0.2.2 (7)** before publication. All 0.3.0–0.4.2 release runs failed before publication. No release job was queued or running when this preparation began.
- Python release/publication tooling: **35 tests passed**.
- Full Xcode `msgblastTests` run on the prepared source: **128 passed, 0 failed, 0 skipped**. Local macOS 27.2 / Apple Silicon; this is not a Sequoia runtime test.
- `scripts/test_web_comparisons.sh build/release-043-validation`: passed. The actual AppModel and WindowCoordinator restored saved Muse/Grok URLs, native ChatGPT/Claude sessions, recipients, and provider selection. Controlled Messages retries did not resend Muse. Attachment follow-ups and safe quit/update deferral also passed. These use isolated local fixtures, with no real messages, provider requests, production updates, or Contacts writes.
- Built Debug bundle contains version `0.4.3`, development build `1`, bundle ID `com.msgblast.mac`, and minimum macOS `15.0`. About and Updates read these bundle values. Production build numbering remains allocated by Actions; **1 is not a proposed production counter**.
- Production `AppIcon.icon` matches the saved green polished exploration 32 byte for byte. Local tests selected `AppIconDemo` in isolated derived data.
- Project regeneration only changes the intended marketing version. Diff whitespace checks pass. The scoped review found no changes to signing keys, app identity, update configuration, deployment target, or test acceptance criteria.

## Publication boundary

These checks establish preparation, not a published release. Publication requires the pinned Actions run to succeed, followed by independent signed-feed/archive verification and inspection of the downloaded bundle's version, counter, minimum OS, and compiled icon. Existing installed apps are not replaced by these checks.

## Screenshots

This PR changes documentation and version defaults, without a new interface interaction. A local About screenshot would show development counter 1, not the future Actions-allocated release counter. The bundle metadata above records that distinction; public artifact verification will establish the distributed values. Existing feature screenshots belong to PRs #3 and #7 and are not presented as new evidence for this preparation.

## Video

There is no changed interactive workflow to demonstrate in this preparation PR. The actual terminal test results are recorded above; no unrelated screen recording or production-account interaction is substituted. The prior runner failure and passing CPU-readback diagnostic are linked in [the avatar fix evidence](../muse-avatar-cpu/validation.md).
