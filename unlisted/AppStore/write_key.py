#!/usr/bin/env python3
"""Writes the App Store Connect key from ASC_KEY_P8 to the path given, however it was pasted.
Same logic as the release workflow's Write API key step."""
import base64, os, re, sys
raw = os.environ["ASC_KEY_P8"].strip().replace("\\n", "\n")
def body_of(text):
    m = re.search(r"-----BEGIN [A-Z ]*PRIVATE KEY-----(.*?)-----END [A-Z ]*PRIVATE KEY-----", text, re.S)
    return re.sub(r"[^A-Za-z0-9+/=]", "", m.group(1)) if m else None
body = body_of(raw)
how = "pasted .p8"
if body is None:
    compact = re.sub(r"\s", "", raw)
    try:
        decoded = base64.b64decode(compact + "=" * (-len(compact) % 4)).decode("utf-8", "ignore")
    except Exception:
        decoded = ""
    body = body_of(decoded)
    how = "base64 of .p8"
    if body is None:
        body = re.sub(r"[^A-Za-z0-9+/=]", "", compact)
        how = "key body only"
try:
    der = base64.b64decode(body + "=" * (-len(body) % 4))
except Exception:
    der = b""
print(f"::notice title=API key format::Read as {how}; {len(der)} key bytes (a valid Apple key is 138 or 150).")
if not (100 <= len(der) <= 200 and der[:1] == b"\x30"):
    print("::error title=API key::APP_STORE_CONNECT_API_KEY_P8 doesn't look like an Apple .p8 key. Open the AuthKey_XXXX.p8 file in a text editor, copy everything from -----BEGIN PRIVATE KEY----- to -----END PRIVATE KEY-----, and paste it into the secret again.")
    sys.exit(1)
b64 = base64.b64encode(der).decode()
pem = "-----BEGIN PRIVATE KEY-----\n" + "\n".join(b64[i:i+64] for i in range(0, len(b64), 64)) + "\n-----END PRIVATE KEY-----\n"
open(sys.argv[1], "w").write(pem)
