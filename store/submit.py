#!/usr/bin/env python3
"""ビルドを版に紐づけて審査に出す（引き継ぎ書 4章の reviewSubmissionItems）。課金は無い。
    python3 store/submit.py <ビルド番号> [--check]"""
import sys
from common import asc, app_id, editable_version

APP = app_id()
BUILD = sys.argv[1]
v = editable_version(APP)
VER = v["id"]
print("出す版", v["attributes"]["versionString"], v["attributes"]["appStoreState"])
b = asc("get", f"/v1/builds?filter[app]={APP}&filter[version]={BUILD}&limit=5")["data"]
if not b or b[0]["attributes"]["processingState"] != "VALID":
    sys.exit(f"ビルド {BUILD} はまだ VALID ではない: {b[0]['attributes']['processingState'] if b else '届いていない'}")
asc("patch", f"/v1/appStoreVersions/{VER}/relationships/build", {"data": {"type": "builds", "id": b[0]["id"]}})
print("ビルドを紐づけた", BUILD)
if "--check" in sys.argv:
    sys.exit(0)
open_subs = asc("get", f"/v1/reviewSubmissions?filter[app]={APP}&filter[state]=READY_FOR_REVIEW")["data"]
sub = open_subs[0] if open_subs else asc("post", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
      "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]
asc("post", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VER}}}}}, ok=True)
asc("patch", f"/v1/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
print("提出した", sub["id"])
