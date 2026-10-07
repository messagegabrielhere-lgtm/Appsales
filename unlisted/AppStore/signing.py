#!/usr/bin/env python3
"""Temporary App Store signing for CI, made with the App Store Connect API key.

  signing.py create OUT_DIR   registers the bundle ID if needed, creates an Apple
                              Distribution certificate and an App Store profile,
                              writes dist.p12 and the profile to OUT_DIR, and
                              exports their details to $GITHUB_ENV.
  signing.py revoke           deletes the profile and certificate made by create.

Revoking a distribution certificate doesn't affect builds already uploaded or
apps on the App Store, so each release makes its own and cleans it up, and no
certificate has to be exported from a Mac or stored as a secret.

Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, BUNDLE_ID,
and for revoke SIGN_CERT_ID / SIGN_PROFILE_ID.
"""
import base64
import os
import secrets
import sys
import time

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from submit import api, ok, ref, why  # noqa: E402


def env_out(name, value):
    with open(os.environ["GITHUB_ENV"], "a") as f:
        f.write(f"{name}={value}\n")


def fail(title, text):
    print(f"::error title={title}::{text}", flush=True)
    sys.exit(1)


def bundle_id_resource(identifier):
    s, r = api("GET", f"/v1/bundleIds?filter[identifier]={identifier}&limit=200")
    match = next((b for b in r.get("data") or [] if b["attributes"]["identifier"] == identifier), None)
    if match:
        return match["id"]
    s, r = api("POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier, "name": "Unlisted", "platform": "IOS"}}})
    if not ok(s):
        fail("Bundle ID", f"Couldn't register {identifier}: {why(r)}")
    print(f"::notice title=Bundle ID::Registered {identifier}.")
    return r["data"]["id"]


def create(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    bid = bundle_id_resource(os.environ["BUNDLE_ID"])

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Unlisted CI")]))
           .sign(key, hashes.SHA256()))
    csr_pem = csr.public_bytes(serialization.Encoding.PEM).decode()

    for kind in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
        s, r = api("POST", "/v1/certificates", {"data": {"type": "certificates", "attributes": {
            "certificateType": kind, "csrContent": csr_pem}}})
        if ok(s):
            break
    if not ok(s):
        text = why(r)
        if "maximum" in text.lower() or "limit" in text.lower():
            text += (" -> Your team has the most distribution certificates Apple allows. Revoke an unused one at "
                     "developer.apple.com > Certificates, IDs & Profiles > Certificates, then re-run.")
        elif s in (401, 403):
            text += " -> The API key needs the Admin role to create certificates (App Store Connect > Users and Access > Integrations)."
        fail("Certificate", text)
    cert_id = r["data"]["id"]
    env_out("SIGN_CERT_ID", cert_id)
    cert = x509.load_der_x509_certificate(base64.b64decode(r["data"]["attributes"]["certificateContent"]))

    password = secrets.token_hex(16)
    # macOS's keychain tool only reads the older PKCS#12 encryption.
    legacy = (serialization.PrivateFormat.PKCS12.encryption_builder()
              .kdf_rounds(50000)
              .key_cert_algorithm(pkcs12.PBES.PBESv1SHA1And3KeyTripleDESCBC)
              .hmac_hash(hashes.SHA1())
              .build(password.encode()))
    p12 = pkcs12.serialize_key_and_certificates(b"Unlisted CI", key, cert, None, legacy)
    p12_path = os.path.join(out_dir, "dist.p12")
    with open(p12_path, "wb") as f:
        f.write(p12)
    print(f"::add-mask::{password}")
    env_out("SIGN_P12", p12_path)
    env_out("SIGN_P12_PASSWORD", password)

    name = f"Unlisted App Store CI {int(time.time())}"
    s, r = api("POST", "/v1/profiles", {"data": {"type": "profiles", "attributes": {
        "name": name, "profileType": "IOS_APP_STORE"}, "relationships": {
        "bundleId": ref("bundleIds", bid),
        "certificates": {"data": [{"type": "certificates", "id": cert_id}]}}}})
    if not ok(s):
        fail("Profile", why(r))
    profile = r["data"]
    env_out("SIGN_PROFILE_ID", profile["id"])
    env_out("SIGN_PROFILE_NAME", name)
    profiles_dir = os.path.expanduser("~/Library/MobileDevice/Provisioning Profiles")
    os.makedirs(profiles_dir, exist_ok=True)
    with open(os.path.join(profiles_dir, f"{profile['attributes']['uuid']}.mobileprovision"), "wb") as f:
        f.write(base64.b64decode(profile["attributes"]["profileContent"]))
    print(f"::notice title=Signing::Created a temporary distribution certificate and App Store profile ({name}).")


def revoke():
    for kind, var in (("profiles", "SIGN_PROFILE_ID"), ("certificates", "SIGN_CERT_ID")):
        ident = os.environ.get(var, "").strip()
        if ident:
            s, r = api("DELETE", f"/v1/{kind}/{ident}")
            if not ok(s):
                print(f"::warning title=Clean up::Couldn't delete the temporary {kind[:-1]} {ident}: {why(r)}")
    print("::notice title=Signing::Temporary certificate and profile removed.")


if __name__ == "__main__":
    if sys.argv[1:2] == ["create"]:
        create(sys.argv[2])
    elif sys.argv[1:2] == ["revoke"]:
        revoke()
    else:
        sys.exit(__doc__)
