#!/usr/bin/env python3
"""掲載画像（store/raw-69 → 6.9インチ枠、raw-65 → 6.5インチ枠）を入れ直す。何度流しても増えない"""
import subprocess
from pathlib import Path
from common import asc, app_id, editable_version, HERE
APP = app_id()
VER = editable_version(APP)["id"]
loc = asc("get", f"/v1/appStoreVersions/{VER}/appStoreVersionLocalizations")["data"][0]["id"]
for kind, d in [("APP_IPHONE_67", "raw-69"), ("APP_IPHONE_65", "raw-65")]:
    subprocess.run([str(HERE / "Tools" / "upload-screenshots.py"), loc, kind, str(HERE / "store" / d)], check=True)
