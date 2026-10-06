#!/usr/bin/env bash
# Idempotent Linux preparation for Cloud Agents and the non-publishing CI job.
# Does not build, sign, or launch the Mac app, and does not start a service.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
if ! python3 -c 'import ensurepip' >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y python3-venv
fi
venv="${MSGBLAST_INSTALLER_VENV:-$HOME/.msgblast-installer}"
if [[ -d "$venv" && ! -x "$venv/bin/pip" ]]; then
  rm -rf "$venv"
fi
python3 -m venv "$venv"
"$venv/bin/python" -m pip install -r "$root/scripts/installer-requirements.txt"
npm ci --prefix "$root/download"
