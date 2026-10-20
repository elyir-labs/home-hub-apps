#!/usr/bin/env bash
# Copies the startup's numbers from the hub's repository (startup/sequence.json, written by startup/json.mjs) into
# both apps, so each draws J frame for frame as the wall does. Pass the hub checkout, or it fetches the published one.
set -euo pipefail
cd "$(dirname "$0")/.."
targets=(ios/Houses/startup.json android/app/src/main/assets/startup.json)
if [ $# -gt 0 ]; then cp "$1/startup/sequence.json" "${targets[0]}"
else curl -fsSL https://raw.githubusercontent.com/elyir-labs/home-hub/development/startup/sequence.json -o "${targets[0]}"; fi
cp "${targets[0]}" "${targets[1]}"
for t in "${targets[@]}"; do echo "$t: $(shasum -a 256 "$t" | cut -c1-12)"; done
