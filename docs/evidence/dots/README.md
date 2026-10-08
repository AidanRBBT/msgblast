# Dots option and saved avatar evidence

Captured from the changed native macOS app in an isolated fixture build. `manifest.json` pins the runtime source files by SHA-256. The fixture uses its own bundle identity and support directory and the saved blue exploration 32 icon. The production app and its data/permissions were left intact.

1. `01-optional-picker.png`: Dots starts unselected alongside the four default websites.
2. `02-dots-selected.png`: Dots selected independently; ChatGPT is deselected.
3. `03-dots-reply.png`: shared request and synthetic Dots reply in the embedded pane.
4. `04-updated-avatar.png`: changed synthetic avatar displayed in the pane and header.
5. `05-saved-avatar-picker.png`: changed avatar retained in the picker.
6. `06-relaunch-avatar.png`: saved avatar restored after quitting and reopening the current fixture build.
7. `07-dots-contributor-credit.png`: @altryne credited in the planned 0.6.5 notes. This is a local development build, not a published release.

`dots-workflow.mp4` is a continuous native window recording, trimmed to 60 seconds at normal speed. It shows selection, shared submission, a synthetic reply, avatar changes, the saved picker avatar and contributor notes. Website replies and avatar artwork are synthetic. The relaunch screenshot was captured separately. Mobile screenshots do not apply to this native Mac feature.

Checks: 196 native core tests, 74 Python tooling tests, and the real AppModel/WindowCoordinator plus updater-lifecycle fixture checks passed. Dots tests cover opt-in selection, landing redirects, ongoing-thread reuse, avatar changes/persistence, sprite frame pixel capture, navigation cache retention, dot-identity separation, and sign-out UI clearing. No independent lint command is configured; Xcode compiled all Swift targets.

Actual Dots was also tested in the isolated functional Dev app with the user's authorized existing live ChatGPT sign-in. Two echo prompts returned the expected replies, the real puppy avatar was visually checked, its saved bytes survived quit/relaunch unchanged, and the saved comparison reopened the same dot thread. That test found and fixed narrow-layout account recognition and WebKit's incorrect crop of the anchored pet. Personal live recordings stay in the ignored local build directory and are excluded from this repository. Actual live logout was not exercised; populated-cache clearing is covered by the fixture test.

The broader Xcode test command returned 65 after all 196 core tests passed because the separate UI runner timed out while initializing macOS automation mode. No Xcode UI test executed. The actual Dev workflow was checked independently through native computer use; macOS permissions were not changed to work around the runner.
