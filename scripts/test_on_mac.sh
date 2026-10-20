#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo 'Full Xcode on macOS is required. Linux cannot run iOS builds.' >&2; exit 1; }
mkdir -p TestResults
UDID="${SIMULATOR_ID:-$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); ids=[v["udid"] for k,vs in d["devices"].items() if "iOS" in k for v in vs if v.get("isAvailable") and "iPhone" in v["name"]]; assert ids, "No iPhone simulator installed"; print(ids[0])')}"
xcodebuild -version
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
RESULT="TestResults/Zuneviu-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild test -project Zuneviu.xcodeproj -scheme Zuneviu -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath DerivedData -resultBundlePath "$RESULT" CODE_SIGNING_ALLOWED=NO | tee "${RESULT%.xcresult}.log"
echo "Test result: $RESULT"
echo 'Simulator tests do not certify physical-device playback or full Android parity.'
