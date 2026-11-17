#!/bin/bash
# アーカイブを作って App Store Connect へ上げる（自動署名・API キー）。黒川ごみの日の upload.sh を写したもの。
#   ./upload.sh               … アーカイブして上げる
#   ./upload.sh --archive-only
# 版の印（RC_BUILD_STAMP）は入れない＝配布版の設定画面には「1.0 (1)」だけが出る。
set -eo pipefail
cd "$(dirname "$0")/RoutineChecker"
KEY=(-authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_CH8R5RJGXQ.p8
     -authenticationKeyID CH8R5RJGXQ -authenticationKeyIssuerID cfeb84ca-47e6-45b2-8c5f-192212240b6c)
DIR=~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)
mkdir -p "$DIR"; rm -rf "$DIR/RoutineChecker.xcarchive" "$DIR/RoutineChecker-export"
# アーカイブは Xcode のアカウントで署名する。API キー（App Manager）ではプロファイルを作れず、
# 即時通知の権利が入らない（引き継ぎ書 4-28）。書き出しとアップロードは API キーで
echo "→ アーカイブ"
xcodebuild -project RoutineChecker.xcodeproj -scheme RoutineChecker -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$DIR/RoutineChecker.xcarchive" \
  -allowProvisioningUpdates archive 2>&1 | grep -E "error:|ARCHIVE SUCCEEDED|ARCHIVE FAILED"
A="$DIR/RoutineChecker.xcarchive/Products/Applications/RoutineChecker.app"
echo "→ 上げる前の点検"
echo "   版 $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$A/Info.plist") ($(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$A/Info.plist"))"
printf "   開発用の入口（0 であること）: "; strings "$A/RoutineChecker" 2>/dev/null | grep -cE "RC_SHOT|demoData" || true
printf "   課金の試験用ファイル（0 であること）: "; find "$A" -name "*.storekit" | wc -l | tr -d ' '
printf "   即時通知の権利（1 であること）: "; codesign -d --entitlements - "$A" 2>/dev/null | grep -c time-sensitive || true
if [ "${1:-}" = "--archive-only" ]; then echo "✅ アーカイブまで"; exit 0; fi
echo "→ 書き出してアップロード"
xcodebuild -exportArchive -archivePath "$DIR/RoutineChecker.xcarchive" -exportOptionsPlist ExportOptions.plist \
  -exportPath "$DIR/RoutineChecker-export" -allowProvisioningUpdates "${KEY[@]}" 2>&1 | grep -E "error:|EXPORT SUCCEEDED|EXPORT FAILED|Upload"
echo "✅ 上げた。処理が終わるまで10分ほど"
