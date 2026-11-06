"""Make the App Store provisioning profile that testflight.yml signs with.

Run it on Windows with the same App Store Connect API key Packmule uses:

    pip install pyjwt cryptography requests
    python scripts/mint_profile.py --key-id ABC123DEFG --issuer-id 1234-... --key C:/path/AuthKey_ABC123DEFG.p8

It registers the bundle id if needed, creates an IOS_APP_STORE profile that trusts every
Apple Distribution certificate on the team (so the DIST_P12_B64 already used by Packmule
matches), and writes the profile, base64 encoded, to a file outside the repo. Then:

    gh secret set PROFILE_APP_B64 -R Keatonmx/Recetario-de-la-abuela --body (Get-Content $HOME/recetario_profile.b64 -Raw)

Nothing secret is printed.
"""

import argparse
import base64
import datetime
import pathlib
import sys
import time

import jwt
import requests

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.keatonmx.recetario"


def token(key_id, issuer_id, key_path):
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        pathlib.Path(key_path).read_text(),
        algorithm="ES256",
        headers={"kid": key_id},
    )


def call(session, method, path, **kw):
    r = session.request(method, API + path, **kw)
    if r.status_code >= 400:
        sys.exit(f"{method} {path} failed ({r.status_code}): {r.text[:500]}")
    return r.json() if r.text else {}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--key-id", required=True)
    p.add_argument("--issuer-id", required=True)
    p.add_argument("--key", required=True, help="path to AuthKey_XXXX.p8")
    p.add_argument("--out", default=str(pathlib.Path.home() / "recetario_profile.b64"))
    a = p.parse_args()

    s = requests.Session()
    s.headers["Authorization"] = "Bearer " + token(a.key_id.strip(), a.issuer_id.strip(), a.key)

    found = call(s, "GET", "/bundleIds", params={"filter[identifier]": BUNDLE_ID})["data"]
    found = [b for b in found if b["attributes"]["identifier"] == BUNDLE_ID]
    if found:
        bundle = found[0]["id"]
        print(f"bundle id {BUNDLE_ID} already registered")
    else:
        bundle = call(s, "POST", "/bundleIds", json={"data": {"type": "bundleIds", "attributes": {
            "identifier": BUNDLE_ID, "name": "Recetario de la Abuela", "platform": "IOS"}}})["data"]["id"]
        print(f"registered bundle id {BUNDLE_ID}")

    certs = call(s, "GET", "/certificates", params={
        "filter[certificateType]": "DISTRIBUTION,IOS_DISTRIBUTION", "limit": 200})["data"]
    if not certs:
        sys.exit("No Apple Distribution certificate on this team. Make one first (see the ios skill).")
    for c in certs:
        at = c["attributes"]
        print(f"trusting certificate: {at.get('displayName') or at.get('name')}, expires {at.get('expirationDate', '?')[:10]}")

    name = "Recetario App Store " + datetime.date.today().isoformat()
    profile = call(s, "POST", "/profiles", json={"data": {
        "type": "profiles",
        "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle}},
            "certificates": {"data": [{"type": "certificates", "id": c["id"]} for c in certs]},
        },
    }})["data"]["attributes"]

    content = profile["profileContent"]
    base64.b64decode(content)  # sanity check
    pathlib.Path(a.out).write_text(content)
    print(f"made profile '{name}', wrote it to {a.out}")


if __name__ == "__main__":
    main()
