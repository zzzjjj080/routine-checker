#!/usr/bin/env python3
"""審査の連絡先とメモ（日英）。連絡先は黒川ごみの日と同じものを写す。
審査環境で挙動が変わる点（審査の人は家を出られない）を必ず書く（引き継ぎ書 6節）。"""
from common import asc, app_id, editable_version

APP = app_id()
VER = editable_version(APP)["id"]
other = asc("get", "/v1/apps/6829385443/appStoreVersions?limit=1")["data"][0]["id"]
c = asc("get", f"/v1/appStoreVersions/{other}/appStoreReviewDetail")["data"]["attributes"]
NOTES = """No account, login, or credentials are required. No in-app purchases, no ads, no user-generated content, and no network connections. All data stays on the device.

WHAT THE APP DOES
A simple checklist app (e.g. "Morning", "Back home"). Its main feature: if you leave home while a checklist is still unfinished, it immediately notifies you with the remaining items (e.g. "keys, medicine"), at most once a day. It also sends reminders at set times or, while you are at home, at set intervals, and shows the number of unfinished checklists on the app icon badge.

WHY "ALWAYS" LOCATION IS REQUESTED
To notice that the user has left (or entered) home while the app is closed, the app monitors one circular region around the home location the user sets (CLMonitor, radius 100/150/300 m). The home location is stored only on the device, used only to decide inside/outside home, never sent anywhere, and no location history is kept. Without "Always", the app still works as a checklist with time-based reminders.

IMPORTANT FOR REVIEW: the "left home" notification needs the device to physically leave the home area, which is not possible during review. Please use the preview button instead:
1. Tap the gear icon (top left) -> 家の場所 (Home location) -> 今いる場所を家にする (Use current location as home). Allow location ("Always" when asked).
2. Go back to the list. On the "朝" (Morning) row, tap the bell chip (いつ知らせるか / When to notify).
3. In 家を出たとき (When leaving home), the switch やり残したまま家を出たら知らせる is ON by default. Tap 試しに知らせを出してみる (Send a test notification), then go to the Home Screen. The same notification as the real one appears after 5 seconds.
4. Tap a checklist row to open it and tap items to check them. When all items are checked, a celebration appears and the icon badge decreases.

External services: none. Only Apple frameworks (CoreLocation, UserNotifications, MapKit to show the map when choosing the home location).
Regional differences: none. The UI is Japanese only and the app is offered in Japan only.

【日本語】
朝・帰りなどのチェックリストのアプリです。いちばんの機能は、リストがそろわないまま家の範囲を出たら、残っている項目を通知すること（1日1回まで）。審査環境では家を出られないため、上の手順3の「試しに知らせを出してみる」で同じ通知を5秒後に出せます。位置情報は家の範囲の中か外かの判定にだけ使い、端末の外に送らず、履歴も残しません。"""
print("メモの字数", len(NOTES))
attrs = {"contactFirstName": c["contactFirstName"], "contactLastName": c["contactLastName"],
         "contactEmail": c["contactEmail"], "contactPhone": c["contactPhone"],
         "demoAccountRequired": False, "notes": NOTES}
cur = asc("get", f"/v1/appStoreVersions/{VER}/appStoreReviewDetail", ok=True)
if cur and cur.get("data"):
    rid = cur["data"]["id"]
    asc("patch", f"/v1/appStoreReviewDetails/{rid}", {"data": {"type": "appStoreReviewDetails", "id": rid, "attributes": attrs}})
else:
    asc("post", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
        "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": VER}}}}})
