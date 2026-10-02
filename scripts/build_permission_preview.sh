#!/bin/zsh
# Isolated native guide fixture: no real history reads or message sends.
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project MsgBlast.xcodeproj -scheme MsgBlast -derivedDataPath build -destination 'platform=macOS,arch=arm64' build -quiet
python3 - <<'PY'
from pathlib import Path
import shutil, plistlib
root = Path('build/Build/Products/Debug')
source, target = root/'MsgBlast.app', root/'MsgBlast Permission Preview.app'
if target.exists(): shutil.rmtree(target)
shutil.copytree(source, target, symlinks=True)
info = target/'Contents/Info.plist'
with info.open('rb') as f: data = plistlib.load(f)
data.update(CFBundleIdentifier='com.msgblast.permission-preview', CFBundleName='MsgBlast Permission Preview', MsgBlastDemo=True, MsgBlastPermissionGuidePreview=True)
with info.open('wb') as f: plistlib.dump(data, f)
PY
codesign --force --deep --sign - 'build/Build/Products/Debug/MsgBlast Permission Preview.app'
