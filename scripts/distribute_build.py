"""Hand a TestFlight build to every tester group once Apple finishes processing it.

The TestFlight workflow runs this after each upload (distribute.yml), and it can be run on its
own from the Actions tab for a build that is already in App Store Connect:

    pip install pyjwt cryptography requests
    ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_P8=... python scripts/distribute_build.py --build 106

It waits for the build to finish processing, fills in What to Test, adds the build to every
group that doesn't already get every build, and sends it to Beta App Review when any group
has external testers. It prints group names only, never tester emails (the logs are public).
"""
import argparse
import base64
import os
import sys
import time

import jwt
import requests

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.keatonmx.recetario"
DEFAULT_NOTE = "Prueba las recetas, las tarjetas y el cambio de idioma. Try the recipes, the cards and the language switch."


def clean(name):
    return os.environ.get(name, "").strip()


def private_key():
    p8 = os.environ.get("ASC_KEY_P8", "")
    if "BEGIN PRIVATE KEY" in p8:
        return p8.replace("\r", "")
    return base64.b64decode("".join(p8.split())).decode()


KEY_ID, ISSUER, P8 = clean("ASC_KEY_ID"), clean("ASC_ISSUER_ID"), private_key()


def call(method, path, ok=(), **kw):
    now = int(time.time())
    token = jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
                       P8, algorithm="ES256", headers={"kid": KEY_ID})
    r = requests.request(method, API + path, headers={"Authorization": "Bearer " + token}, **kw)
    if r.status_code >= 400 and r.status_code not in ok:
        sys.exit(f"::error::{method} {path} failed ({r.status_code}): {r.text[:500]}")
    return r.status_code, (r.json() if r.text else {})


def wait_for_build(app, number, minutes):
    deadline = time.time() + minutes * 60
    while True:
        _, data = call("GET", "/builds", params={"filter[app]": app, "filter[version]": number})
        if data["data"]:
            build = data["data"][0]
            state = build["attributes"]["processingState"]
            if state == "VALID":
                print(f"build {number} finished processing")
                return build
            if state in ("FAILED", "INVALID"):
                sys.exit(f"::error::Apple marked build {number} {state}.")
            print(f"build {number} is {state.lower()}, checking again in 30 seconds")
        else:
            print(f"build {number} isn't in App Store Connect yet, checking again in 30 seconds")
        if time.time() > deadline:
            sys.exit(f"::error::Build {number} still wasn't ready after {minutes} minutes. "
                     "Run the Distribute workflow again later.")
        time.sleep(30)


def set_what_to_test(build, text):
    # External testing needs a What to Test note. Without one given, fill only empty notes.
    given = bool(text)
    text = text or DEFAULT_NOTE
    _, data = call("GET", f"/builds/{build}/betaBuildLocalizations")
    for loc in data["data"]:
        if not given and (loc["attributes"].get("whatsNew") or "").strip():
            continue
        call("PATCH", f"/betaBuildLocalizations/{loc['id']}", json={"data": {
            "type": "betaBuildLocalizations", "id": loc["id"], "attributes": {"whatsNew": text}}})
    if not data["data"]:
        call("POST", "/betaBuildLocalizations", json={"data": {
            "type": "betaBuildLocalizations", "attributes": {"locale": "en-US", "whatsNew": text},
            "relationships": {"build": {"data": {"type": "builds", "id": build}}}}})
    print("set What to Test")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--build", required=True, help="build number, like 106")
    p.add_argument("--what-to-test", default="")
    p.add_argument("--wait-minutes", type=int, default=60)
    a = p.parse_args()
    if not (KEY_ID and ISSUER and P8):
        sys.exit("::error::Set ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8.")

    _, data = call("GET", "/apps", params={"filter[bundleId]": BUNDLE_ID})
    app = data["data"][0]["id"]
    build = wait_for_build(app, a.build, a.wait_minutes)
    bid = build["id"]

    if build["attributes"].get("usesNonExemptEncryption") is None:
        call("PATCH", f"/builds/{bid}", json={"data": {
            "type": "builds", "id": bid, "attributes": {"usesNonExemptEncryption": False}}})
        print("answered the export compliance question (no encryption)")

    set_what_to_test(bid, a.what_to_test.strip())

    _, data = call("GET", f"/apps/{app}/betaGroups", params={"limit": 200})
    external = False
    for g in data["data"]:
        attrs, name = g["attributes"], g["attributes"]["name"]
        if attrs.get("isInternalGroup") and attrs.get("hasAccessToAllBuilds"):
            print(f"{name}: internal, already gets every build")
            continue
        # TestFlight can answer 404 for a few minutes after a build finishes processing.
        for _ in range(20):
            status, _ = call("POST", f"/betaGroups/{g['id']}/relationships/builds", ok=(404,),
                             json={"data": [{"type": "builds", "id": bid}]})
            if status != 404:
                break
            print(f"{name}: TestFlight doesn't know build {a.build} yet, trying again in 30 seconds")
            time.sleep(30)
        else:
            sys.exit(f"::error::TestFlight still didn't know build {a.build} after 10 minutes. "
                     "Run the Distribute workflow again later.")
        print(f"{name}: added build {a.build}")
        external = external or not attrs.get("isInternalGroup")
    if not data["data"]:
        print("::warning::There are no tester groups yet. Make one in App Store Connect > TestFlight.")

    if external:
        status, data = call("POST", "/betaAppReviewSubmissions", ok=(409,), json={"data": {
            "type": "betaAppReviewSubmissions",
            "relationships": {"build": {"data": {"type": "builds", "id": bid}}}}})
        if status == 409:
            print(f"Beta App Review: {data['errors'][0].get('detail', 'already submitted')}")
        else:
            state = data["data"]["attributes"].get("betaReviewState", "submitted")
            print(f"sent to Beta App Review ({state.lower()}); external testers get it once Apple approves")
    print(f"::notice::Build {a.build} is out to the tester groups.")


if __name__ == "__main__":
    main()
