#!/usr/bin/env python3
"""Fills in an App Store version through the App Store Connect API, and optionally submits it.

Everything you would otherwise click through by hand on the version page:

  - creates the version (e.g. 2.0.0) if it does not exist yet
  - name, subtitle, privacy policy URL and categories (App Information)
  - description, keywords, promotional text, What's New and support URL
  - replaces the iPhone 6.5" and iPad 13" screenshots
  - attaches the newest processed build for that version
  - App Review notes (contact details are carried over from the previous version)
  - with --submit, adds the version to a review submission and submits it

The text comes from a listing file such as docs/listing/v2.0.md, so what the store shows is
always what the repository says. Run by .github/workflows/app-store.yml.

Credentials come from the environment, never from arguments:
  APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_API_ISSUER_ID, APP_STORE_CONNECT_API_KEY_P8
The .p8 may be pasted as-is or base64-encoded.
"""
import argparse
import base64
import hashlib
import os
import re
import sys
import time
from pathlib import Path

API = "https://api.appstoreconnect.apple.com"

# Screenshot folder name -> App Store Connect display type.
SCREENSHOT_SETS = {
    "iphone-6.5-inch": "APP_IPHONE_65",
    "ipad-13-inch": "APP_IPAD_PRO_3GEN_129",
}

CATEGORIES = {
    "Health & Fitness": "HEALTH_AND_FITNESS",
    "Food & Drink": "FOOD_AND_DRINK",
    "Lifestyle": "LIFESTYLE",
    "Productivity": "PRODUCTIVITY",
    "Medical": "MEDICAL",
    "Utilities": "UTILITIES",
}

# Version states in which the version can still be edited.
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
            "INVALID_BINARY", "READY_FOR_REVIEW"}
LIVE = {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION"}


class Failure(Exception):
    pass


def step(message):
    print(f"\n==> {message}", flush=True)


# ---------------------------------------------------------------------------------------------
# Listing file


def parse_listing(path):
    """Returns {heading: value} for every '## Heading' followed by a fenced block, plus the
    categories from the Category section."""
    text = Path(path).read_text()
    fields = {}
    for section in re.split(r"^## ", text, flags=re.M)[1:]:
        heading, _, body = section.partition("\n")
        heading = re.sub(r"\s*\(.*$", "", heading).strip()
        match = re.search(r"```\n(.*?)\n```", body, re.S)
        if match:
            fields[heading] = match.group(1)
        elif heading == "Category":
            names = re.findall(r"\*\*(.+?)\*\*", body)
            unknown = [n for n in names if n not in CATEGORIES]
            if unknown:
                raise Failure(f"Unknown category {unknown}; add it to CATEGORIES")
            fields["Category"] = [CATEGORIES[n] for n in names[:2]]
    return fields


def require(fields, *names):
    missing = [n for n in names if n not in fields]
    if missing:
        raise Failure(f"Listing file is missing sections: {', '.join(missing)}")


# ---------------------------------------------------------------------------------------------
# API client


def load_private_key():
    raw = os.environ.get("APP_STORE_CONNECT_API_KEY_P8", "").strip()
    if not raw:
        raise Failure("APP_STORE_CONNECT_API_KEY_P8 is empty")
    if "BEGIN PRIVATE KEY" not in raw:
        try:
            raw = base64.b64decode(raw).decode()
        except Exception as error:
            raise Failure("APP_STORE_CONNECT_API_KEY_P8 is neither a .p8 file nor base64") from error
    return raw


class Client:
    def __init__(self, key_id, issuer_id, private_key, session=None):
        import requests

        self.key_id = key_id
        self.issuer_id = issuer_id
        self.private_key = private_key
        self.session = session or requests.Session()

    def token(self):
        import jwt

        now = int(time.time())
        payload = {"iss": self.issuer_id, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
        return jwt.encode(payload, self.private_key, algorithm="ES256", headers={"kid": self.key_id})

    def request(self, method, path, json=None, params=None, allow=()):
        url = path if path.startswith("http") else API + path
        for attempt in range(4):
            response = self.session.request(
                method, url, json=json, params=params,
                headers={"Authorization": f"Bearer {self.token()}"}, timeout=60)
            if response.status_code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            break
        if response.status_code in allow:
            return None
        if response.status_code >= 400:
            raise Failure(f"{method} {path} failed ({response.status_code}):\n{describe_errors(response)}")
        if response.status_code == 204 or not response.content:
            return {}
        return response.json()

    def get(self, path, **params):
        return self.request("GET", path, params=params or None)

    def get_all(self, path, **params):
        params.setdefault("limit", 50)
        body = self.get(path, **params)
        items = list(body.get("data") or [])
        while body.get("links", {}).get("next"):
            body = self.request("GET", body["links"]["next"])
            items += body.get("data") or []
        return items

    def create(self, kind, attributes=None, relationships=None):
        data = {"type": kind}
        if attributes:
            data["attributes"] = attributes
        if relationships:
            data["relationships"] = {
                name: {"data": {"type": rel_type, "id": rel_id}}
                for name, (rel_type, rel_id) in relationships.items()}
        return self.request("POST", f"/v1/{kind}", json={"data": data})["data"]

    def update(self, kind, item_id, attributes=None, relationships=None):
        data = {"type": kind, "id": item_id}
        if attributes:
            data["attributes"] = attributes
        if relationships:
            data["relationships"] = {
                name: {"data": {"type": rel_type, "id": rel_id}}
                for name, (rel_type, rel_id) in relationships.items()}
        return self.request("PATCH", f"/v1/{kind}/{item_id}", json={"data": data}).get("data")


def describe_errors(response):
    try:
        errors = response.json().get("errors", [])
    except ValueError:
        return response.text[:2000]
    lines = []
    for error in errors:
        line = f"  - {error.get('title', '')}: {error.get('detail', '')}"
        pointer = (error.get("source") or {}).get("pointer")
        if pointer:
            line += f" [{pointer}]"
        lines.append(line)
        for related in (error.get("meta") or {}).get("associatedErrors", {}).values():
            for item in related:
                lines.append(f"      {item.get('title', '')}: {item.get('detail', '')}")
    return "\n".join(lines) or response.text[:2000]


def version_state(version):
    attributes = version["attributes"]
    return attributes.get("appVersionState") or attributes.get("appStoreState") or ""


# ---------------------------------------------------------------------------------------------
# Steps


def find_app(client, bundle_id):
    apps = client.get_all("/v1/apps", **{"filter[bundleId]": bundle_id})
    apps = [a for a in apps if a["attributes"]["bundleId"] == bundle_id]
    if not apps:
        raise Failure(f"No app with bundle ID {bundle_id}. Does the API key have access to it?")
    app = apps[0]
    print(f"App: {app['attributes']['name']} ({app['id']}), primary language {app['attributes']['primaryLocale']}")
    return app


def ensure_version(client, app_id, version_string):
    versions = client.get_all(f"/v1/apps/{app_id}/appStoreVersions", **{"filter[platform]": "IOS"})
    previous = next((v for v in versions if version_state(v) in LIVE), None)
    for version in versions:
        if version["attributes"]["versionString"] == version_string:
            print(f"Version {version_string} exists ({version_state(version)})")
            return version, previous
    editable = next((v for v in versions if version_state(v) in EDITABLE), None)
    if editable:
        old = editable["attributes"]["versionString"]
        print(f"Renaming the editable version {old} to {version_string}")
        version = client.update("appStoreVersions", editable["id"], {"versionString": version_string})
        return version, previous
    print(f"Creating version {version_string}")
    version = client.create(
        "appStoreVersions", {"platform": "IOS", "versionString": version_string},
        {"app": ("apps", app_id)})
    return version, previous


def update_app_info(client, app_id, locale, fields):
    infos = client.get_all(f"/v1/apps/{app_id}/appInfos")
    editable = [i for i in infos
                if (i["attributes"].get("state") or i["attributes"].get("appStoreState")) not in LIVE]
    info = (editable or infos)[0]

    if "Category" in fields:
        categories = fields["Category"]
        relationships = {"primaryCategory": ("appCategories", categories[0])}
        if len(categories) > 1:
            relationships["secondaryCategory"] = ("appCategories", categories[1])
        client.update("appInfos", info["id"], relationships=relationships)
        print(f"Categories: {', '.join(categories)}")

    attributes = {}
    if "Name" in fields:
        attributes["name"] = fields["Name"]
    if "Subtitle" in fields:
        attributes["subtitle"] = fields["Subtitle"]
    if "Privacy Policy URL" in fields:
        attributes["privacyPolicyUrl"] = fields["Privacy Policy URL"]
    localization = localization_for(client.get_all(f"/v1/appInfos/{info['id']}/appInfoLocalizations"), locale)
    try:
        client.update("appInfoLocalizations", localization["id"], attributes)
    except Failure as error:
        if "name" in str(error).lower():
            raise Failure(f"{error}\n\nIf the name is taken, change the Name section of the listing file.") from error
        raise
    print(f"Name: {attributes.get('name')}\nSubtitle: {attributes.get('subtitle')}")


def localization_for(localizations, locale):
    match = next((l for l in localizations if l["attributes"]["locale"] == locale), None)
    if not match:
        found = ", ".join(l["attributes"]["locale"] for l in localizations)
        raise Failure(f"No {locale} localization (found {found or 'none'})")
    return match


def update_version_text(client, version, previous, locale, fields):
    attributes = {}
    copyright_text = version["attributes"].get("copyright")
    wanted = fields.get("Copyright")
    if wanted and wanted != copyright_text:
        attributes["copyright"] = wanted
    elif not copyright_text and previous:
        attributes["copyright"] = previous["attributes"].get("copyright")
    if attributes.get("copyright"):
        client.update("appStoreVersions", version["id"], attributes)
        print(f"Copyright: {attributes['copyright']}")

    localization = localization_for(
        client.get_all(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"), locale)
    text = {
        "description": fields["Description"],
        "keywords": fields["Keywords"],
        "promotionalText": fields.get("Promotional text"),
        "supportUrl": fields.get("Support URL"),
    }
    if previous and "What's New" in fields:
        text["whatsNew"] = fields["What's New"]
    client.update("appStoreVersionLocalizations", localization["id"],
                  {k: v for k, v in text.items() if v is not None})
    print("Description, keywords, promotional text, What's New and support URL set")
    return localization


def update_screenshots(client, localization_id, folder):
    sets = client.get_all(f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")
    by_type = {s["attributes"]["screenshotDisplayType"]: s for s in sets}
    uploaded = []
    for subfolder, display_type in SCREENSHOT_SETS.items():
        files = sorted(p for p in (Path(folder) / subfolder).glob("*") if p.suffix.lower() in (".png", ".jpg", ".jpeg"))
        if not files:
            raise Failure(f"No screenshots in {Path(folder) / subfolder}")
        screenshot_set = by_type.get(display_type) or client.create(
            "appScreenshotSets", {"screenshotDisplayType": display_type},
            {"appStoreVersionLocalization": ("appStoreVersionLocalizations", localization_id)})

        existing = client.get_all(f"/v1/appScreenshotSets/{screenshot_set['id']}/appScreenshots")
        wanted = [(p.name, hashlib.md5(p.read_bytes()).hexdigest()) for p in files]
        have = [(s["attributes"].get("fileName"), s["attributes"].get("sourceFileChecksum")) for s in existing]
        if have == wanted:
            print(f"{display_type}: {len(files)} screenshots already up to date")
            continue

        for screenshot in existing:
            client.request("DELETE", f"/v1/appScreenshots/{screenshot['id']}")
        for path in files:
            uploaded.append(upload_screenshot(client, screenshot_set["id"], path))
        print(f"{display_type}: replaced {len(existing)} with {len(files)} screenshots")
    wait_for_screenshots(client, uploaded)


def upload_screenshot(client, set_id, path):
    data = path.read_bytes()
    screenshot = client.create(
        "appScreenshots", {"fileName": path.name, "fileSize": len(data)},
        {"appScreenshotSet": ("appScreenshotSets", set_id)})
    for operation in screenshot["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
        chunk = data[operation["offset"]:operation["offset"] + operation["length"]]
        response = client.session.request(operation["method"], operation["url"], data=chunk, headers=headers, timeout=120)
        if response.status_code >= 400:
            raise Failure(f"Uploading {path.name} failed ({response.status_code}): {response.text[:500]}")
    client.update("appScreenshots", screenshot["id"],
                  {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()})
    return screenshot["id"], path.name


def wait_for_screenshots(client, uploaded, timeout=600):
    pending = dict(uploaded)
    deadline = time.time() + timeout
    while pending and time.time() < deadline:
        for screenshot_id, name in list(pending.items()):
            state = (client.get(f"/v1/appScreenshots/{screenshot_id}")["data"]["attributes"]
                     .get("assetDeliveryState") or {})
            if state.get("state") == "COMPLETE":
                del pending[screenshot_id]
            elif state.get("state") == "FAILED":
                raise Failure(f"Apple rejected screenshot {name}: {state.get('errors')}")
        if pending:
            time.sleep(10)
    if pending:
        raise Failure(f"Screenshots still processing after {timeout}s: {', '.join(pending.values())}")
    if uploaded:
        print("All screenshots processed by Apple")


def attach_build(client, app_id, version, build_number, timeout):
    params = {"filter[app]": app_id, "filter[preReleaseVersion.version]": version["attributes"]["versionString"],
              "sort": "-uploadedDate", "limit": 20}
    if build_number:
        params["filter[version]"] = build_number
    deadline = time.time() + timeout
    while True:
        builds = client.get("/v1/builds", **params).get("data") or []
        usable = [b for b in builds if not b["attributes"].get("expired")]
        if usable and usable[0]["attributes"]["processingState"] == "VALID":
            build = usable[0]
            break
        state = usable[0]["attributes"]["processingState"] if usable else "not uploaded yet"
        if time.time() > deadline:
            raise Failure(f"No processed build for {params['filter[preReleaseVersion.version]']} "
                          f"(newest is {state}). Run scripts/release.sh first, then try again.")
        print(f"Waiting for the build to finish processing ({state})...")
        time.sleep(60)

    if build["attributes"].get("usesNonExemptEncryption") is None:
        client.update("builds", build["id"], {"usesNonExemptEncryption": False})
    client.request("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build",
                   json={"data": {"type": "builds", "id": build["id"]}})
    print(f"Build {build['attributes']['version']} attached")


def review_detail(client, version_id):
    body = client.request("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail", allow=(404,))
    return (body or {}).get("data")


def update_review_details(client, version, previous, notes):
    detail = review_detail(client, version["id"])
    attributes = {"notes": notes, "demoAccountRequired": False}
    if detail:
        client.update("appStoreReviewDetails", detail["id"], attributes)
    else:
        contact = {}
        if previous:
            old = review_detail(client, previous["id"])
            if old:
                contact = {k: old["attributes"].get(k) for k in
                           ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")}
        if not contact or not all(contact.values()):
            raise Failure("No App Review contact details to carry over. Fill in the contact fields under "
                          "App Review Information once in App Store Connect, then run this again.")
        client.create("appStoreReviewDetails", {**contact, **attributes},
                      {"appStoreVersion": ("appStoreVersions", version["id"])})
    print("App Review notes set; sign-in not required")


def submit(client, app_id, version):
    current = client.get(f"/v1/appStoreVersions/{version['id']}")["data"]
    state = version_state(current)
    if state not in EDITABLE:
        print(f"Version is {state}; nothing to submit")
        return
    open_submissions = client.get_all(
        "/v1/reviewSubmissions", **{"filter[app]": app_id, "filter[platform]": "IOS",
                                    "filter[state]": "READY_FOR_REVIEW,UNRESOLVED_ISSUES"})
    submission = open_submissions[0] if open_submissions else client.create(
        "reviewSubmissions", {"platform": "IOS"}, {"app": ("apps", app_id)})
    items = client.get_all(f"/v1/reviewSubmissions/{submission['id']}/items", include="appStoreVersion")
    has_version = any(((i.get("relationships") or {}).get("appStoreVersion") or {}).get("data", {}) and
                      i["relationships"]["appStoreVersion"]["data"].get("id") == version["id"] for i in items)
    if not has_version:
        client.create("reviewSubmissionItems", relationships={
            "reviewSubmission": ("reviewSubmissions", submission["id"]),
            "appStoreVersion": ("appStoreVersions", version["id"])})
    client.update("reviewSubmissions", submission["id"], {"submitted": True})
    print("Submitted for App Review")


# ---------------------------------------------------------------------------------------------


def main(argv=None, client=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--version", required=True)
    parser.add_argument("--listing", required=True)
    parser.add_argument("--screenshots", help="Folder with iphone-6.5-inch/ and ipad-13-inch/")
    parser.add_argument("--build", default="", help="Build number; default is the newest for --version")
    parser.add_argument("--bundle-id", default="com.messagegabrielhere.kept")
    parser.add_argument("--build-wait", type=int, default=1800, help="Seconds to wait for build processing")
    parser.add_argument("--submit", action="store_true", help="Submit for App Review at the end")
    args = parser.parse_args(argv)

    try:
        fields = parse_listing(args.listing)
        require(fields, "Name", "Subtitle", "Description", "Keywords", "App Review notes")
        if client is None:
            client = Client(os.environ.get("APP_STORE_CONNECT_API_KEY_ID", "").strip(),
                            os.environ.get("APP_STORE_CONNECT_API_ISSUER_ID", "").strip(),
                            load_private_key())

        step("Finding the app")
        app = find_app(client, args.bundle_id)
        locale = app["attributes"]["primaryLocale"]

        step(f"Preparing version {args.version}")
        version, previous = ensure_version(client, app["id"], args.version)

        step("App Information: name, subtitle, categories")
        update_app_info(client, app["id"], locale, fields)

        step("Version text")
        localization = update_version_text(client, version, previous, locale, fields)

        if args.screenshots:
            step("Screenshots")
            update_screenshots(client, localization["id"], args.screenshots)

        step("Build")
        attach_build(client, app["id"], version, args.build, args.build_wait)

        step("App Review information")
        update_review_details(client, version, previous, fields["App Review notes"])

        if args.submit:
            step("Submitting for review")
            submit(client, app["id"], version)
        else:
            step("Ready. Not submitted: run again with submit enabled, or press Add for Review in App Store Connect.")
    except Failure as error:
        print(f"\nERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
