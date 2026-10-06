#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
case "${1:-}" in
  "") preview_mode=live ;;
  --fixture) preview_mode=fixture ;;
  *) print -u2 'Usage: build_web_preview.sh [--fixture]'; exit 2 ;;
esac
# Isolate bundle identity, app-owned state, and Messages sends from the user's live app.
xcodebuild -project msgblast.xcodeproj -scheme msgblast -configuration Debug \
  -derivedDataPath build/web-preview -destination 'platform=macOS,arch=arm64' \
  ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo \
  'PRODUCT_BUNDLE_IDENTIFIER=com.msgblast.web-preview.$(PRODUCT_NAME:rfc1034identifier)' build -quiet
python3 - "$preview_mode" <<'PY'
from pathlib import Path
import plistlib, shutil, sys
fixture = sys.argv[1] == 'fixture'
source = Path('build/web-preview/Build/Products/Debug/msgblast.app')
name = 'msgblast Muse Fixture' if fixture else 'msgblast Web Preview'
target = Path('build') / (name + '.app')
if target.exists(): shutil.rmtree(target)
shutil.copytree(source, target, symlinks=True)
info = target/'Contents/Info.plist'
with info.open('rb') as f: data = plistlib.load(f)
data.update(CFBundleIdentifier='com.msgblast.muse-fixture' if fixture else 'com.msgblast.web-preview', CFBundleName=name, msgblastDemo=True, msgblastLiveWebPreview=not fixture, msgblastIsolatedDemo=fixture)
with info.open('wb') as f: plistlib.dump(data,f)
PY
if [[ "$preview_mode" == fixture ]]; then
  codesign --force --deep --sign - 'build/msgblast Muse Fixture.app'
else
  codesign --force --deep --sign - 'build/msgblast Web Preview.app'
fi
