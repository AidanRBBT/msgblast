# Update recovery evidence

Captured from the reviewed 0.5.2 implementation with an isolated Debug demo-icon build on macOS. This is a nonvisual persistence/lifecycle change. Browser images show a read-only replay of the actual signed localhost Sparkle fixture's input, logs and persisted output; they are not production app UI screenshots. There is no mobile app UI change.

`recovery-walkthrough.mp4` is a three-frame replay with edited five-second holds, not continuous execution footage. It shows incompatible saved input, the actual install/quit log, and the preserved bytes/new draft plus verified relaunched fixture build. Builds 1 and 2 both contain the reviewed code; an unknown `future-provider` simulates a schema an older reader rejects. This does not claim old 0.4.3 binaries gained the new quit behavior, or that recovery drafts automatically appear in the main composer.

- `synthetic-original.json`: complete synthetic original with unknown provider and staged attachment reference.
- `sparkle-recovery.json`: actual recovery case output; incidental macOS sandbox stderr omitted from this focused record.
- `recovery-result.json`: actual preserved hashes, separately persisted in-memory state and relaunch marker.
- `replay.html`: read-only viewer used for captures.

Reproduce with:

```sh
xcodebuild -project msgblast.xcodeproj -scheme msgblast -derivedDataPath build/recovery-validation -destination 'platform=macOS,arch=arm64' ONLY_ACTIVE_ARCH=YES ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo -only-testing:msgblastTests test
python3 scripts/test_updates.py --derived-data build/recovery-validation --keep
```

The native suite passed 147 tests before the final three edge-case tests were added. The final targeted UpdateTests run passed all 10 checks. All five real Sparkle fixture cases passed on the final build. Fixtures generate temporary signing keys, delete those keys after the run, and never modify the installed production app or live data. The evidence remains in the private source repository.
