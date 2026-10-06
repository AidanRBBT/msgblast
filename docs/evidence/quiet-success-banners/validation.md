# Quiet successful sends

Confirmed sends no longer show a persistent status row or repeat the shared prompt above the embedded chat. Preparing/submitting progress and not-sent/unconfirmed results still render their status and details. Independent session errors and draft warnings remain visible. Receipt storage, dedicated conversation identity and duplicate-send protection are unchanged.

Verification:
- App and existing UI tests compiled successfully using `xcodebuild build-for-testing`.
- Updated existing UI assertions wait for the provider reply instead of the removed banner; pre-login assertions also inspect reply absence.
- Native inspection of the final blue-green development build reopened all four saved chats and confirmed zero `Appeared in` accessibility labels with all four recipients selected. No live request was sent for this change.
- Reviewed the render condition for every existing send status; only `.observed` is hidden.
- Strict code-signature verification passed. The production source retains green artwork; the separate development build retains blue-green artwork.
- The core implementation did not change. The previous 121-case core run remains applicable; this UI-only change was checked through compilation and native inspection. The automated UI suite was not rerun after its earlier runner stall.
- Lite code review completed with no findings; see `review.json`. No matched plan or independent reviewer was required for this local presentation change.

Evidence:
- `before.png`: actual prior native build at `c4dd4f8`, cropped to provider headers and success labels.
- `after.png`: same region of the final changed native build, showing chat content directly below provider headers.
- `walkthrough.mp4`: sampled before/after comparison from those two captures, with edited timing. It is not continuous recording or a send test.
- Images are cropped only; private conversation content outside this header region is excluded. Mobile screenshots do not apply to the native macOS app. Evidence stays in the private repository.

The blue-green build remains open for the owner. Nothing was released or installed over the production app.
