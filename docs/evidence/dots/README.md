# Dots option and saved avatar evidence

## Default ring fallback update

Captured from runtime `d3adbb46b845ae14f5d3e323f307826660fee2b5`, the latest update adds the user-requested Dots ring when there is no saved avatar. `ring-fallback-manifest.json` pins the reviewed runtime, bundled vector asset, screenshots, and recording. The personal avatar still takes priority.

- `08-default-ring-picker.png`: ring in the native picker before an avatar has been saved.
- `09-personal-avatar-priority.png`: a synthetic personal avatar replaces the ring in the native header.
- `10-saved-personal-avatar.png`: changed personal artwork remains in the picker.
- `11-ring-after-signout.png`: simulated sign-out clears the saved avatar and restores the ring in the header.
- `12-personal-avatar-relaunch.png`: saved personal artwork survives quitting and reopening the fixture.
- `dots-ring-workflow.mp4`: 29-second continuous native window recording, trimmed at normal speed. It shows the ring in the signed-out pane and picker, simulated sign-in, personalized artwork, and the saved picker avatar. Recording padding is retained. Relaunch was captured separately.

The Mac fixture uses synthetic account state, artwork, and replies. No live sign-out or provider requests were performed for this capture. Both isolated Dev and fixture builds compiled successfully and contain the exact reviewed PDF. `NSImage(data:)` loads its 256 × 256 vector representation. Functional Dev was reopened with the existing authorized account; its real saved puppy still appeared in the picker. Personal evidence stays local. This view-only asset change adds no unit test; native visual checks cover fallback rendering, personal-avatar priority, cache clearing, and relaunch. The unchanged 201-test core suite was rerun; its result is in the fallback manifest.

Version 0.6.5 and @altryne credit remain unchanged. No app release was triggered.

## Earlier Dots workflow evidence

Captured from runtime source `a6996f9bc8b01edcec1d2f3a4930d1d126c676b7` in the changed native Mac app. `manifest.json` pins runtime sources and captures by SHA-256. The synthetic fixture has its own identity and persistent support directory and uses the saved blue exploration 32 icon. The functional Dev app uses the saved blue-green icon. Neither replaces the user's installed app.

1. `01-optional-picker.png`: Dots is unselected beside the four default websites.
2. `02-dots-selected.png`: Dots is selected independently, with ChatGPT deselected.
3. `03-dots-reply.png`: shared prompt and synthetic Dots reply with the initial green avatar.
4. `04-updated-avatar.png`: changed purple avatar in the embedded pane and native header.
5. `05-saved-avatar-picker.png`: changed avatar retained in the picker.
6. `06-relaunch-avatar.png`: saved avatar restored after quitting and reopening the fixture.
7. `07-dots-contributor-credit.png`: @altryne credited in planned 0.6.5 patch notes.

`dots-workflow.mp4` is a continuous 24-second native window recording trimmed at normal speed. It shows optional selection, shared submission, a synthetic reply, avatar changes, the saved picker avatar, and contributor notes. The comparison narrows the window; recording padding is retained. Relaunch was captured separately. Website responses and artwork are synthetic. Mobile screenshots do not apply to this native Mac feature.

The final runtime fixes select the currently open dot before a fresh send, recognize the live `/dots/home` route, and reject avatar captures when viewport or artwork geometry changes before persistence. The guard accommodates fractional native pane sizes without weakening the later stability check. New tests exercise stale routing, home-route restoration, fractional bounds, resize during capture, and movement after capture.

The full 201-test native core suite passed with the final runtime and fixed-PNG test fixtures, including four focused avatar checks. A controlled image-decode regression fails on the old code and passes after waiting for changed sprite and nested image resources to decode before capturing. Cached artwork skips the decode wait. The strict original sprite-color assertion remains unchanged. The fixtures now supply a known native PNG sheet to CSS sprite rendering, avoiding WebKit canvas export, and the original avatar test awaits explicit refreshes so polling cannot race its baseline. The test revision is pinned separately in the manifest; these test-only changes do not alter the recorded runtime. The earlier 74 Python tooling tests and AppModel/WindowCoordinator and updater-lifecycle fixtures passed; their code is unchanged. Final-head hosted CI is recorded in the PR validation section. Xcode compiled the Swift targets; no independent lint command is configured.

The final isolated functional Dev app reused the user's authorized existing live ChatGPT session, returned `DOTS_DECODE_OK` on `/dots/home`, and freshly saved the real puppy avatar after clearing only this test app’s backed-up cached PNG. Quit/relaunch restored the picker avatar and reopened the saved comparison with its reply. Reconnecting can save a new still frame of an animated avatar; byte identity after reconnection is not claimed. Personal live footage remains in the ignored local build directory. Actual live logout was not exercised; fixture tests cover clearing a populated avatar cache on sign-out.

The incremental review closed all three retained findings in the routing/geometry fix delta. A further review of sprite-readiness changes found no actionable issue. Hosted CI on the earlier source head `0ed7508` passed all 201 native tests, Linux checks, evidence validation, and all five Sparkle updater fixtures. The earlier exact anchored-layout crop regression still lacks an automated reproducer; the fixed-header fixture is not claimed to reproduce it. Actual Dev red/green testing verified that behavior. The earlier Xcode UI runner timed out initializing automation mode before executing any UI test. Native computer use independently verified the final Dev workflow without changing macOS permissions.

Version 0.6.4 has already been published. This PR retains 0.6.5 as the planned patch update and thanks [@altryne](https://x.com/altryne). No release was triggered.
