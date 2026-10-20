#!/usr/bin/env bash
# Copies the startup's numbers from the hub's repository (startup/sequence.json, written by startup/json.mjs), so
# the app draws J frame for frame as the wall does. Pass the hub checkout, or it fetches the published one.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ $# -gt 0 ]; then cp "$1/startup/sequence.json" ios/Houses/startup.json
else curl -fsSL https://raw.githubusercontent.com/elyir-labs/home-hub/development/startup/sequence.json -o ios/Houses/startup.json; fi
echo "ios/Houses/startup.json: $(shasum -a 256 ios/Houses/startup.json | cut -c1-12)"
