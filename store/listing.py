#!/usr/bin/env python3
"""掲載情報・カテゴリ・年齢制限・価格（無料）・配信地域（日本のみ）を App Store Connect へ入れる。
黒川ごみの日の store/listing.py を写したもの。何度流してもよい。"""
from common import asc, app_id, editable_version, editable_info, SUPPORT

APP = app_id()
VER = editable_version(APP)
INFO = editable_info(APP)
ver_loc = asc("get", f"/v1/appStoreVersions/{VER['id']}/appStoreVersionLocalizations")["data"][0]
info_loc = asc("get", f"/v1/appInfos/{INFO['id']}/appInfoLocalizations")["data"][0]

SUBTITLE = "やり残したまま家を出たら知らせる"
PROMO = ("朝の支度や帰りの片づけを、1行ずつ書くだけのチェックリストに。全部そろわないまま家を出ると、"
         "残っている項目をすぐ通知します。鍵・財布・薬の忘れ物に。")
KEYWORDS = "忘れ物,チェックリスト,持ち物,朝の準備,出かける前,鍵,外出,帰宅,習慣,リマインダー,やること,確認,位置情報,ToDo,支度"
DESC = """朝の支度や、帰ってからやることを、チェックリストにしておくアプリです。
いちばんの特長は、やり残したまま家を出たら知らせること。

■ やり残したまま家を出たら知らせる
「朝」のリストが全部そろわないまま家の範囲を出ると、「朝が残ったまま、家を出ました／まだ：鍵、薬」のように、残っている項目を通知します。駅に着いてから気づく前に、引き返せるところで知らせます。
・知らせるのは、その日のぶんが始まってから（時刻で知らせるリストなら最初の時刻を過ぎてから）
・1日1回まで。何度出入りしても繰り返し鳴りません
・集中モード中でも届く即時通知です

■ 書くだけのチェックリスト
1行に1つずつ書けば、そのままリストになります。朝・帰り・休日・出張の前など、いくつでも作れます。1項目1行で大きく並ぶので、10個ほどなら1画面に収まり、押すだけでチェックできます。

■ いつ知らせるか
リストごとに選べます。
・時刻で：平日の7時、のように曜日と時刻で
・家にいる間：18時〜23時に家にいる間だけ、30分・1時間・2時間ごとに
・通知なし
全部そろったら、その日はもう鳴りません。「30分後にもう一度」も選べます。

■ ホーム画面でも分かる
アイコンに、まだそろっていないリストの数を出します。

■ 毎日まっさらに
チェックは毎日決まった時刻（はじめは午前3時）に空になります。夜ふかしで日付をまたいでも、帰りのリストは消えません。

・家の場所は iPhone の中にだけ保存し、家の範囲の中か外かの判定にだけ使います。位置を外へ送らず、移動の履歴も残しません
・家を出たことを知るには、位置情報を「常に」にする必要があります
・家の範囲を出てから iPhone が気づくまで、数分かかることがあります
・インターネットに接続しません。広告・アカウント・課金はありません"""

asc("patch", f"/v1/appInfoLocalizations/{info_loc['id']}", {"data": {"type": "appInfoLocalizations", "id": info_loc["id"], "attributes": {
    "subtitle": SUBTITLE, "privacyPolicyUrl": SUPPORT + "privacy.html"}}})
asc("patch", f"/v1/appStoreVersionLocalizations/{ver_loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": ver_loc["id"], "attributes": {
    "description": DESC, "keywords": KEYWORDS, "promotionalText": PROMO,
    "supportUrl": SUPPORT, "marketingUrl": SUPPORT}}})
asc("patch", f"/v1/appInfos/{INFO['id']}", {"data": {"type": "appInfos", "id": INFO["id"], "relationships": {
    "primaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}},
    "secondaryCategory": {"data": {"type": "appCategories", "id": "LIFESTYLE"}}}}})
asc("patch", f"/v1/appStoreVersions/{VER['id']}", {"data": {"type": "appStoreVersions", "id": VER["id"], "attributes": {
    "copyright": "2026 Jin Nakamura", "releaseType": "AFTER_APPROVAL"}}})
asc("patch", f"/v1/apps/{APP}", {"data": {"type": "apps", "id": APP, "attributes": {
    "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})

# 年齢制限（すべてなし）
none = {k: "NONE" for k in ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated",
        "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation",
        "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity",
        "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic",
        "gunsOrOtherWeapons"]}
attrs = dict(none, gambling=False, unrestrictedWebAccess=False, healthOrWellnessTopics=False,
             messagingAndChat=False, userGeneratedContent=False, advertising=False,
             parentalControls=False, ageAssurance=False, lootBox=False, socialMedia=False)
asc("patch", f"/v1/ageRatingDeclarations/{INFO['id']}", {"data": {"type": "ageRatingDeclarations", "id": INFO["id"], "attributes": attrs}})

# 価格：無料
pp = asc("get", f"/v1/apps/{APP}/appPricePoints?filter[territory]=JPN&limit=200")
free = next(p["id"] for p in pp["data"] if float(p["attributes"]["customerPrice"]) == 0)
asc("post", "/v1/appPriceSchedules", {
    "data": {"type": "appPriceSchedules", "relationships": {
        "app": {"data": {"type": "apps", "id": APP}},
        "baseTerritory": {"data": {"type": "territories", "id": "JPN"}},
        "manualPrices": {"data": [{"type": "appPrices", "id": "${p0}"}]}}},
    "included": [{"type": "appPrices", "id": "${p0}", "attributes": {"startDate": None},
                  "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free}}}}]}, ok=True)

# 配信地域：日本のみ（画面は日本語だけ）
terr = asc("get", "/v1/territories?limit=200")["data"]
inc = [{"type": "territoryAvailabilities", "id": f"${{t{i}}}",
        "attributes": {"available": t["id"] == "JPN", "releaseDate": None, "preOrderEnabled": False},
        "relationships": {"territory": {"data": {"type": "territories", "id": t["id"]}}}}
       for i, t in enumerate(terr)]
asc("post", "/v2/appAvailabilities", {
    "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": False},
             "relationships": {"app": {"data": {"type": "apps", "id": APP}},
                               "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": x["id"]} for x in inc]}}},
    "included": inc}, ok=True)
print("掲載文字数", len(DESC), "キーワード", len(KEYWORDS), "サブタイトル", len(SUBTITLE), "宣伝文", len(PROMO))
