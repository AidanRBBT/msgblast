#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project msgblast.xcodeproj -scheme msgblast -configuration Debug -derivedDataPath build/icon-demo -destination 'platform=macOS,arch=arm64' ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo build -quiet
python3 - <<'PY'
from pathlib import Path
import shutil, plistlib
source = Path('build/icon-demo/Build/Products/Debug/msgblast.app')
root = Path('build/Build/Products/Debug')
root.mkdir(parents=True, exist_ok=True)
target = root/'msgblast Demo.app'
if target.exists(): shutil.rmtree(target)
shutil.copytree(source, target, symlinks=True)
info = target/'Contents/Info.plist'
with info.open('rb') as f: data = plistlib.load(f)
assert data['CFBundleIconName'] == 'AppIconDemo', 'Demo build must select the blue icon'
data.update(CFBundleIdentifier='com.msgblast.demo', CFBundleName='msgblast Demo', msgblastDemo=True)
with info.open('wb') as f: plistlib.dump(data,f)
PY
codesign --force --deep --sign - 'build/Build/Products/Debug/msgblast Demo.app'
