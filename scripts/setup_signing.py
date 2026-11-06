"""One-time signing setup for the TestFlight workflow, run on Windows by the owner.

    pip install pyjwt cryptography requests
    python scripts/setup_signing.py --key C:/path/AuthKey_XXXXXXXXXX.p8 --issuer-id <Issuer ID>

With just the API key it:
  1. registers the bundle id com.keatonmx.recetario if needed,
  2. makes a new Apple Distribution certificate from a key generated here, and saves it as a
     .p12 (legacy 3DES encryption, which macOS `security import` needs) plus its password in
     ~/RecetarioSigning, outside the repo,
  3. makes an IOS_APP_STORE profile for the bundle id with that certificate,
  4. sets all six repository secrets testflight.yml reads, through gh (values go in on stdin,
     no CRLF, nothing printed).

To reuse an existing distribution certificate instead of making one, add
    --p12 C:/path/dist.p12 --p12-password <password>
The Key ID is read from the AuthKey_<KEYID>.p8 file name unless --key-id is given.
"""

import argparse
import base64
import datetime
import pathlib
import re
import secrets
import subprocess
import sys
import time

import jwt
import requests
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.keatonmx.recetario"
REPO = "Keatonmx/Recetario-de-la-abuela"
OUT_DIR = pathlib.Path.home() / "RecetarioSigning"


def call(session, method, path, **kw):
    r = session.request(method, API + path, **kw)
    if r.status_code >= 400:
        sys.exit(f"{method} {path} failed ({r.status_code}): {r.text[:500]}")
    return r.json() if r.text else {}


def set_secret(name, value):
    subprocess.run(["gh", "secret", "set", name, "-R", REPO], input=value.encode(), check=True)
    print(f"set secret {name}")


def legacy_p12(key, cert, password):
    # macOS rejects modern AES p12s with "MAC verification failed", so use 3DES/SHA1.
    enc = (serialization.PrivateFormat.PKCS12.encryption_builder()
           .kdf_rounds(50000)
           .key_cert_algorithm(pkcs12.PBES.PBESv1SHA1And3KeyTripleDESCBC)
           .hmac_hash(hashes.SHA1())
           .build(password.encode()))
    return pkcs12.serialize_key_and_certificates(b"Recetario Distribution", key, cert, None, enc)


def new_certificate(s):
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Recetario Distribution")]))
           .sign(key, hashes.SHA256()))
    pem = csr.public_bytes(serialization.Encoding.PEM).decode()
    data = call(s, "POST", "/certificates", json={"data": {"type": "certificates", "attributes": {
        "certificateType": "DISTRIBUTION", "csrContent": pem}}})["data"]
    cert = x509.load_der_x509_certificate(base64.b64decode(data["attributes"]["certificateContent"]))
    print(f"made Apple Distribution certificate, expires {cert.not_valid_after_utc.date()}")
    password = secrets.token_urlsafe(18)
    p12 = legacy_p12(key, cert, password)
    OUT_DIR.mkdir(exist_ok=True)
    (OUT_DIR / "recetario_distribution.p12").write_bytes(p12)
    (OUT_DIR / "recetario_distribution_password.txt").write_text(password)
    print(f"saved the .p12 and its password in {OUT_DIR} (keep them, they are not in the repo)")
    return data["id"], p12, password


def existing_certificate(s, p12_path, password):
    p12 = pathlib.Path(p12_path).read_bytes()
    _, cert, _ = pkcs12.load_key_and_certificates(p12, password.encode())
    serial = format(cert.serial_number, "X")
    certs = call(s, "GET", "/certificates", params={
        "filter[certificateType]": "DISTRIBUTION,IOS_DISTRIBUTION", "limit": 200})["data"]
    for c in certs:
        if c["attributes"].get("serialNumber", "").upper().lstrip("0") == serial.lstrip("0"):
            print("found that certificate on the team")
            return c["id"], p12, password
    sys.exit("That .p12's certificate isn't an active distribution certificate on this team.")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--key", required=True, help="path to AuthKey_XXXX.p8")
    p.add_argument("--issuer-id", required=True)
    p.add_argument("--key-id", help="defaults to the id in the .p8 file name")
    p.add_argument("--p12", help="reuse this distribution .p12 instead of making a new certificate")
    p.add_argument("--p12-password")
    a = p.parse_args()

    key_path = pathlib.Path(a.key)
    key_id = a.key_id or (re.search(r"AuthKey_([A-Z0-9]+)\.p8$", key_path.name) or sys.exit(
        "Pass --key-id, the .p8 file name doesn't contain it."))[1]
    issuer = a.issuer_id.strip()
    p8 = key_path.read_text()

    now = int(time.time())
    s = requests.Session()
    s.headers["Authorization"] = "Bearer " + jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        p8, algorithm="ES256", headers={"kid": key_id})

    found = [b for b in call(s, "GET", "/bundleIds", params={"filter[identifier]": BUNDLE_ID})["data"]
             if b["attributes"]["identifier"] == BUNDLE_ID]
    if found:
        bundle = found[0]["id"]
        print(f"bundle id {BUNDLE_ID} already registered")
    else:
        bundle = call(s, "POST", "/bundleIds", json={"data": {"type": "bundleIds", "attributes": {
            "identifier": BUNDLE_ID, "name": "Recetario de la Abuela", "platform": "IOS"}}})["data"]["id"]
        print(f"registered bundle id {BUNDLE_ID}")

    if a.p12:
        if not a.p12_password:
            sys.exit("--p12 needs --p12-password")
        cert_id, p12, password = existing_certificate(s, a.p12, a.p12_password)
    else:
        cert_id, p12, password = new_certificate(s)

    name = "Recetario App Store " + datetime.datetime.now().strftime("%Y-%m-%d %H%M")
    profile = call(s, "POST", "/profiles", json={"data": {
        "type": "profiles",
        "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle}},
            "certificates": {"data": [{"type": "certificates", "id": cert_id}]},
        },
    }})["data"]["attributes"]["profileContent"]
    print(f"made profile '{name}'")

    set_secret("ASC_KEY_ID", key_id)
    set_secret("ASC_ISSUER_ID", issuer)
    set_secret("ASC_KEY_P8", base64.b64encode(p8.encode()).decode())
    set_secret("DIST_P12_B64", base64.b64encode(p12).decode())
    set_secret("DIST_P12_PASSWORD", password)
    set_secret("PROFILE_APP_B64", profile)
    print("All six secrets are set. Run the TestFlight workflow next.")


if __name__ == "__main__":
    main()
