# New Blast toolbar validation

The comparison action is now **New Blast** in the leading window toolbar, on the same row as Add agent. Its former content row is removed. The existing demo controls carry the fixture label. Drafts and recipient choices are preserved; active submission still disables New Blast, and starting over dismisses the first-use overlay.

- `xcodebuild ... build-for-testing`: passed (app, core tests and UI test target compiled).
- Direct XCTest runner: **107 tests passed, zero failures**. See tests.log.
- Native fixture walkthrough: all four web replies appeared; New Blast was disabled during submission, enabled afterwards, and returned to the picker with `Keep this request ready.` and the same selected web agents. The prior comparison remains in the sidebar. No initial Open buttons appear.
- Dedicated automated UI execution was not run. Existing UI coverage was inspected; no new test was added for this small layout/label move. Manual native interaction verifies placement and retention. Lite ce-code-review completed with no findings; simplification was below its threshold.
- Before image is revision ec8cd1a. After images use the changed source fingerprint below. Screenshots are actual native macOS captures with synthetic pages. Video is a 12-second sequence of four captures with edited timing, not continuous recording. No live messages were sent. Mobile does not apply to this macOS app.
- All captures and the video stay in the existing private repository. No release is published.

## Source fingerprints

- `msgblast/Windows/Views.swift`: `b30a18ac7fd3be2fc8745757b74bfb81d7d5f6e5883e055dc09863d7ab54ee49`
- `msgblast/Windows/WebServicesView.swift`: `dff9c0fb7da9aa2c86b20ef7495fafaf284e9ee7d13fb62f4e4f9960ca776a08`
