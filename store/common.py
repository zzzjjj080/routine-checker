"""store/*.py の共通部分。ID は毎回 API から引く（版を作り直しても書き換えなくてよい）"""
import json, subprocess, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent.parent
BUNDLE = "com.zzzjjj080.RoutineChecker"
SUPPORT = "https://zzzjjj080.github.io/routine-support/"

def asc(method, path, body=None, ok=False):
    args = [str(HERE / "Tools" / "asc.py"), method, path] + ([json.dumps(body, ensure_ascii=False)] if body else [])
    r = subprocess.run(args, capture_output=True, text=True)
    head = r.stdout.split("\n", 1)[0]
    print(method, path.split("?")[0], head)
    if not head.startswith("HTTP 2"):
        print(r.stdout[:2000])
        if not ok: sys.exit(1)
        return None
    return json.loads(r.stdout.split("\n", 1)[1] or "{}")

def app_id():
    d = asc("get", f"/v1/apps?filter[bundleId]={BUNDLE}")["data"]
    if not d: sys.exit("App Store Connect にアプリがまだ登録されていない（本人の作業）")
    return d[0]["id"]

def editable_version(app):
    """準備中の版（無ければ止める）"""
    vers = [v for v in asc("get", f"/v1/apps/{app}/appStoreVersions")["data"]
            if v["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
    if not vers: sys.exit("出せる版がない（すべて審査中か公開済み）")
    return vers[0]

def editable_info(app):
    infos = asc("get", f"/v1/apps/{app}/appInfos")["data"]
    return next(i for i in infos if i["attributes"].get("appStoreState") != "READY_FOR_SALE")
