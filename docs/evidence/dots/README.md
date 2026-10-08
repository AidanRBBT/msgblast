# Dots option and saved avatar evidence

Captured from the changed native macOS app in an isolated fixture build. `manifest.json` pins the runtime source files by SHA-256. The fixture uses its own bundle identity and support directory and the saved blue exploration 32 icon. The production app and its data/permissions were left intact.

1. `01-optional-picker.png`: Dots starts unselected alongside the four default websites.
2. `02-dots-selected.png`: Dots selected independently; ChatGPT is deselected.
3. `03-dots-reply.png`: shared request and synthetic Dots reply in the embedded pane.
4. `04-updated-avatar.png`: changed synthetic avatar displayed in the pane and header.
5. `05-saved-avatar-picker.png`: earlier pre-integration capture retained for reference; excluded from the current video.
6. `06-relaunch-avatar.png`: earlier pre-integration relaunch capture retained for reference; excluded from the current video.
7. `07-dots-contributor-credit.png`: @altryne credited in the planned 0.6.5 notes, verified in functional Dev. This is a local development build, not a published release.

`dots-workflow.mp4` assembles the current selection, reply, avatar-change and contributor-note screenshots with edited timing. It is a sampled state demonstration, not continuous interaction footage. Website replies and avatar artwork are synthetic. This does not demonstrate live delivery, server-side history persistence, or a real account logout. The live website was inspected read-only to establish the adapter selectors. Mobile screenshots do not apply to this native Mac feature.

Checks: 195 native core tests, 74 Python tooling tests, and the real AppModel/WindowCoordinator plus updater-lifecycle fixture checks passed. Dots tests cover opt-in selection, landing redirects, ongoing-thread reuse, avatar changes/persistence, sprite frame pixel capture, navigation cache retention, dot-identity separation, and sign-out UI clearing. No independent lint command is configured; Xcode compiled all Swift targets.

The Mac locked during the final picker/relaunch refresh. Current video evidence uses only the refreshed states; persistence is covered by the passing core tests. The earlier picker/relaunch images are archived reference captures from the initial feature revision.
