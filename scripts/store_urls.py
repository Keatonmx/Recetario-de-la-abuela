"""Show, and optionally fix, the web links App Store Connect holds for the app.

Covers the privacy policy URL (App Information), the support and marketing URLs (each App
Store version), and the TestFlight privacy policy and marketing URLs (Test Information).
With --fix, any link on an old host is moved to the GitHub Pages site. The GitHub account
was renamed from Keatonmx to RedfernsOutpost, and Pages doesn't redirect.

    pip install pyjwt cryptography requests
    ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_P8=... python scripts/store_urls.py [--fix]

It prints only these URL fields, never contact details (the logs are public).
"""
import argparse
import base64
import os
import re
import sys
import time

import jwt
import requests

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.keatonmx.recetario"  # The bundle ID never changes, even after the rename.
OLD_HOST = "keatonmx.github.io"
NEW_HOST = "redfernsoutpost.github.io"


def private_key():
    p8 = os.environ.get("ASC_KEY_P8", "")
    if "BEGIN PRIVATE KEY" in p8:
        return p8.replace("\r", "")
    return base64.b64decode("".join(p8.split())).decode()


KEY_ID, ISSUER, P8 = os.environ.get("ASC_KEY_ID", "").strip(), os.environ.get("ASC_ISSUER_ID", "").strip(), private_key()


def call(method, path, **kw):
    now = int(time.time())
    token = jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
                       P8, algorithm="ES256", headers={"kid": KEY_ID})
    r = requests.request(method, API + path, headers={"Authorization": "Bearer " + token}, **kw)
    if r.status_code >= 400:
        sys.exit(f"::error::{method} {path} failed ({r.status_code}): {r.text[:500]}")
    return r.json() if r.text else {}


def fixed(url):
    """The url on the new host, or None when it isn't on the old one."""
    return re.sub(re.escape(OLD_HOST), NEW_HOST, url, flags=re.I) if url and OLD_HOST in url.lower() else None


def review(kind, label, rows, fields, fix):
    """Print each URL field; with fix, move old-host links to the new host."""
    stale = 0
    for row in rows:
        attrs = row["attributes"]
        changes = {}
        for field in fields:
            url = attrs.get(field)
            new = fixed(url)
            mark = "  OLD" if new else ""
            print(f"{label} [{attrs.get('locale', '')}] {field}: {url or '(empty)'}{mark}")
            if new:
                stale += 1
                changes[field] = new
        if fix and changes:
            call("PATCH", f"/{kind}/{row['id']}",
                 json={"data": {"type": kind, "id": row["id"], "attributes": changes}})
            for field, new in changes.items():
                print(f"  fixed {field}: {new}")
    return stale


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fix", action="store_true", help="move old-host links to the new host")
    fix = parser.parse_args().fix

    apps = call("GET", "/apps", params={"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        sys.exit(f"::error::No app with bundle ID {BUNDLE_ID}.")
    app = apps[0]["id"]
    stale = 0

    for info in call("GET", f"/apps/{app}/appInfos")["data"]:
        state = info["attributes"].get("state") or info["attributes"].get("appStoreState", "")
        rows = call("GET", f"/appInfos/{info['id']}/appInfoLocalizations")["data"]
        stale += review("appInfoLocalizations", f"App Information ({state})", rows,
                        ["privacyPolicyUrl", "privacyChoicesUrl"], fix)

    versions = call("GET", f"/apps/{app}/appStoreVersions", params={"filter[platform]": "IOS"})["data"]
    for version in versions:
        a = version["attributes"]
        rows = call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
        stale += review("appStoreVersionLocalizations", f"Version {a.get('versionString')} ({a.get('appStoreState')})",
                        rows, ["supportUrl", "marketingUrl"], fix)

    rows = call("GET", f"/apps/{app}/betaAppLocalizations")["data"]
    stale += review("betaAppLocalizations", "TestFlight", rows, ["privacyPolicyUrl", "marketingUrl"], fix)

    if stale and not fix:
        print(f"{stale} link(s) still on {OLD_HOST}. Run again with fix on to move them.")
    elif not stale:
        print(f"No links on {OLD_HOST}.")


if __name__ == "__main__":
    main()
