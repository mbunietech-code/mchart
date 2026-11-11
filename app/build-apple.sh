#!/usr/bin/env bash
# Builds the Apple apps against production (run on a Mac, from anywhere):
#   ./build-apple.sh            -> iOS .ipa (App Store) + macOS .app
#   ./build-apple.sh ios        -> iOS only
#   ./build-apple.sh macos      -> macOS only
#   MCHART_REALTIME=off ./build-apple.sh   -> polling instead of WebSockets
#
# Outputs:
#   build/ios/ipa/*.ipa                      (needs a signing team in Xcode)
#   build/macos/Build/Products/Release/MChart.app
#
# The production / realtime settings are read from run-prod.ps1, the same
# way build-release.ps1 does, so all platforms stay in sync.
set -euo pipefail
cd "$(dirname "$0")"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8   # CocoaPods needs UTF-8

defines=()
while IFS= read -r d; do defines+=("$d"); done \
  < <(grep -oE -- '--dart-define=[^ ]+' run-prod.ps1)
version=$(sed -nE 's/^version:[[:space:]]*([0-9.]+).*/\1/p' pubspec.yaml)
if [[ "${MCHART_REALTIME:-on}" == "off" ]]; then
  defines+=("--dart-define=MCHART_REALTIME=off")
fi

target="${1:-all}"

if [[ "$target" == "all" || "$target" == "ios" ]]; then
  flutter build ipa --release "${defines[@]}"
fi
if [[ "$target" == "all" || "$target" == "macos" ]]; then
  flutter build macos --release "${defines[@]}"
fi

echo "Built MChart $version ($target)"
