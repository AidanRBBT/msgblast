#!/bin/bash
# Actual app/controller code with local web + Messages fixtures; no real sends or updates.
set -euo pipefail
web_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
web_build="${1:-$web_root/build/sidechat-validation}"
web_build="$(cd -- "$web_build" && pwd)"
web_frameworks="$web_build/Build/Products/Debug"
web_sparkle="$web_build/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
web_tmp="$(mktemp -d "${TMPDIR:-/tmp}/msgblast-web-checks.XXXXXX")"
trap 'rm -rf "$web_tmp"' EXIT
web_flags=(-swift-version 6 -D DEBUG -parse-as-library -module-cache-path "$web_tmp/modules"
    -target "$(uname -m)-apple-macos15.0" -F "$web_frameworks" -F "$web_sparkle"
    -framework msgblastCore -framework Sparkle
    -Xlinker -rpath -Xlinker "$web_frameworks" -Xlinker -rpath -Xlinker "$web_sparkle")
web_sources=()
while IFS= read -r source; do web_sources+=("$source"); done < <(rg --files "$web_root/msgblast" -g '*.swift' | rg -v '/Core/|/msgblastApp.swift$')
# The standalone harness excludes the @main app, but its views use these shared command bindings.
python3 - "$web_root/msgblast/App/msgblastApp.swift" "$web_tmp/window-actions.swift" <<'PY_ACTIONS'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
start = source.index("struct MainWindowActions {")
end = source.index("private struct BlastCommands:", start)
Path(sys.argv[2]).write_text("import SwiftUI\n" + source[start:end])
PY_ACTIONS
xcrun swiftc "${web_flags[@]}" "$web_tmp/window-actions.swift" "${web_sources[@]}" "$web_root/scripts/fixtures/web_comparison_model.swift" -o "$web_tmp/model"
"$web_tmp/model" --demo --isolated-demo
xcrun swiftc "${web_flags[@]}" "$web_root/msgblast/App/AppUpdater.swift" "$web_root/scripts/fixtures/web_broadcast_lifecycle.swift" -o "$web_tmp/lifecycle"
"$web_tmp/lifecycle"
