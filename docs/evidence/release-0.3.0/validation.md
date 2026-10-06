# 0.3.0 release preparation

Reviewed integration base: `f5ad53b9e5febe224e2bb5c62f5432393f2ed079`, merging `origin/main` at `f86cce472649d5468792d04a86dd05a7b763774a` into the web-services feature branch without conflicts.

## Retained Sequoia support

- PR #5 (`cdae7c6bff32aab640c28432f9e115893026df7d`) is an ancestor of both main and this branch.
- PR #6 (`f86cce472649d5468792d04a86dd05a7b763774a`) changes two Messages connection strings; it does not revert compatibility code.
- Package.swift, Info.plist, the generated Xcode project and its generator retain macOS 15.0. The Tahoe-only glass APIs removed by #5 remain absent.
- The newly added web-controller check now also compiles with a macOS 15.0 target.
- No actual macOS 15 machine was used locally; deployment-target compilation is not a Sequoia runtime test. The release archive still requires post-publication inspection.

## Checks on the integrated release source

- `xcodebuild build-for-testing` passed using isolated `build/release-030-validation`, compiling the app, core tests and UI tests.
- Direct XCTest execution passed **121 tests, zero failures**. Existing Xcode test-daemon instability was avoided with the direct runner; this does not claim a passing automated UI suite.
- `bash scripts/test_web_comparisons.sh build/release-030-validation` passed the native attachment/follow-up and retry-isolation checks, four-provider saved-comparison restoration, and shared-send quit/update lifecycle checks. All sends used local fixtures.
- Python release-tooling suite passed **35 tests**.
- Generated project changes match the generator: marketing version 0.3.0, existing build-setting substitutions and development counter unchanged.
- Production icon exactly matches the saved green `32-WhiteToClearSoftFade-Polished.icon`. Blue-green development and blue demo sources are preserved.
- Reviewed README, detailed release notes, generator/project and regression-script changes; no findings. `git diff --check` passed.

## Evidence limits

The final preparation changes release notes, documentation, the marketing-version default and a test compilation target. They do not introduce a new visual workflow. Existing feature screenshots/videos remain linked in PR #3 at their captured revisions; imported Sequoia and Messages wording changes have their own evidence in PRs #5 and #6. Earlier captures identify fixture inputs, edited timing and their source revisions. No new live messages, production installation, permission reset or updater replacement was performed for release evidence.

Publication is a separate step through the tag-triggered Actions workflow. Its signed feed, archive, version/build, source SHA, compiled icon and code signatures must be verified before declaring this version released.
