# MsgBlast agent instructions

## App icons

- **Development/live app:** use the saved blue-green duplicate of exploration 32. Its source is `output/icon-gradients/32-WhiteToClearSoftFadeBlueGreen.icon`; the app resource is `MsgBlast/AppIcon.icon`.
- **Demo/fixture app:** use the saved blue duplicate of exploration 32. Its source is `output/icon-gradients/32-WhiteToClearSoftFadeBlue.icon`; the app resource is `MsgBlast/AppIconDemo.icon`.
- Standard builds select `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`. `scripts/build_demo.sh` selects `AppIconDemo`. The distinction is development versus demo, not Debug versus Release.
- Preserve the user's saved artwork when copying these icons into the app resources. Keep both icon resources registered in `scripts/generate_project.py` and the generated Xcode project.
- Validate icon changes with an isolated derived data directory. The demo script uses `build/icon-demo` and packages `build/Build/Products/Debug/MsgBlast Demo.app`. Do not overwrite or restart the user's running development app merely to validate an icon change.

## Pull request evidence

- Every PR I create or update must include **Screenshots** and **Video** sections in its description showing the changes in that PR. A screenshot of whatever browser tab happens to be open does not count.
- Capture the actual changed feature or workflow from the reviewed revision. Include desktop and mobile screenshots for responsive UI changes, and a short video showing the relevant interaction and result. Show before/after states when they make the change clearer.
- Embed screenshots and embed or directly link a playable video in the PR description; local-only file paths are not sufficient for reviewers. Keep evidence within the repository's existing access boundary.
- For nonvisual changes, show the relevant terminal/API workflow when feasible. If meaningful visual evidence cannot be captured, explicitly explain why in those sections; never silently omit them or substitute unrelated visuals.
- Label local fixtures, simulated inputs, edited timing, and other demonstration limitations accurately. Refresh evidence after changes that affect what it demonstrates. Do not start paid jobs or live matches solely to capture evidence without existing authorization.
- When the user asks for screenshots of a PR, show the changed feature's evidence, not the currently open browser page.
