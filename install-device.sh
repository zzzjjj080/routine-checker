#!/bin/bash
# 接続中の iPhone に最新のビルドを入れる。
#   ./install-device.sh
# iPhone は USB でつなぐか、Mac と同じ Wi-Fi に（一度 Xcode でペアリング済みなら）。
set -euo pipefail
cd "$(dirname "$0")/RoutineChecker"

list() { xcrun devicectl list devices 2>/dev/null | grep '(iPhone' | grep -v 'no DDI'; }
uuid_of() { grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' <<<"$1"; }

LINE=$(list | grep ' connected ' | head -1 || true)
[ -z "$LINE" ] && LINE=$(list | grep 'available (paired)' | head -1 || true)
if [ -z "$LINE" ]; then
  echo "iPhoneが見つかりません。USBで接続するか、Macと同じネットワークに繋いでください。"
  xcrun devicectl list devices 2>/dev/null | grep '(iPhone' || true
  exit 1
fi
DEV=$(uuid_of "$LINE")
echo "対象: $DEV"

xcodebuild -project RoutineChecker.xcodeproj -scheme RoutineChecker -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/routinechecker-dev \
  -allowProvisioningUpdates build

APP=$(find /tmp/routinechecker-dev/Build/Products -maxdepth 3 -name "RoutineChecker.app" -path "*Release-iphoneos*" | head -1)
xcrun devicectl device install app --device "$DEV" "$APP"
echo "入れ終わりました。ホーム画面の「ルーティン」を開いてください。"
