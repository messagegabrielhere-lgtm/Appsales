#!/usr/bin/env python3
"""Fill in Unlisted's App Store listing and submit it for review.

Runs in CI with the App Store Connect API key. Every step is safe to re-run:
it updates what's there instead of adding duplicates. It reports each step as a
GitHub Actions notice or error, and stops before submitting if anything Apple
requires is missing.

Two things Apple only lets the account holder do on the website:
App Privacy answers, and (unless the review contact secrets are set) the
App Review contact name and phone. The script says so if they're missing.

Usage: submit.py METADATA_JSON SCREENSHOT_DIR
Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, BUNDLE_ID, VERSION,
optional REVIEW_FIRST_NAME, REVIEW_LAST_NAME, REVIEW_PHONE.
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"
problems = []


def notice(title, text):
    print(f"::notice title={title}::{text}", flush=True)


def error(title, text):
    problems.append(title)
    print(f"::error title={title}::{text}", flush=True)


def token():
    now = int(time.time())
    with open(os.environ["ASC_KEY_PATH"]) as f:
        key = f.read()
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900,
                       "aud": "appstoreconnect-v1"}, key, algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def api(method, path, body=None):
    """Returns (status, parsed JSON or {})."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={"Authorization": f"Bearer {token()}",
                                          "Content-Type": "application/json"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                return r.status, (json.loads(raw) if raw else {})
        except urllib.error.HTTPError as e:
            raw = e.read()
            if e.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            try:
                return e.code, json.loads(raw)
            except ValueError:
                return e.code, {"errors": [{"detail": raw.decode(errors="ignore")[:300]}]}
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            if attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            return 0, {"errors": [{"title": "Network", "detail": str(e)}]}


def why(resp):
    errs = list(resp.get("errors") or [])
    # Submission errors list the actual reasons under meta.associatedErrors.
    for e in list(errs):
        for group in ((e.get("meta") or {}).get("associatedErrors") or {}).values():
            errs += group if isinstance(group, list) else []
    return " | ".join(f"{e.get('title', '')}: {e.get('detail', '')}".strip(": ") for e in errs)[:1800] or "no detail"


def ok(status):
    return 200 <= status < 300


def ref(kind, ident):
    return {"data": {"type": kind, "id": ident}}


# ---------------------------------------------------------------------------

def find_app(bundle_id):
    s, r = api("GET", f"/v1/apps?filter[bundleId]={bundle_id}")
    if not ok(s) or not r.get("data"):
        error("App record", f"No app in App Store Connect with bundle ID {bundle_id} ({why(r)}). "
              "Create it at appstoreconnect.apple.com > Apps > + > New App.")
        sys.exit(1)
    app = r["data"][0]
    notice("App", f"Found {app['attributes'].get('name')} ({app['id']}).")
    return app["id"]


def content_rights(app_id):
    s, r = api("PATCH", f"/v1/apps/{app_id}", {"data": {"type": "apps", "id": app_id, "attributes": {
        "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
    if ok(s):
        notice("Content rights", "Does not use third-party content.")
    else:
        error("Content rights", why(r))


def editable_app_info(app_id):
    s, r = api("GET", f"/v1/apps/{app_id}/appInfos")
    infos = r.get("data") or []
    live = {"READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "REPLACED_WITH_NEW_INFO"}
    for info in infos:
        a = info["attributes"]
        if (a.get("state") or a.get("appStoreState")) not in live:
            return info["id"]
    return infos[0]["id"] if infos else None


def app_info(info_id, meta):
    s, r = api("PATCH", f"/v1/appInfos/{info_id}", {"data": {"type": "appInfos", "id": info_id, "relationships": {
        "primaryCategory": ref("appCategories", meta["primaryCategory"]),
        "secondaryCategory": ref("appCategories", meta["secondaryCategory"])}}})
    if ok(s):
        notice("Categories", f"{meta['primaryCategory']} and {meta['secondaryCategory']}.")
    else:
        error("Categories", why(r))

    s, r = api("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations")
    locs = r.get("data") or []
    loc = next((l for l in locs if l["attributes"]["locale"] == "en-US"), locs[0] if locs else None)
    attrs = {"name": meta["name"], "subtitle": meta["subtitle"], "privacyPolicyUrl": meta["privacyPolicyUrl"]}
    if loc:
        s, r = api("PATCH", f"/v1/appInfoLocalizations/{loc['id']}",
                   {"data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": attrs}})
    else:
        s, r = api("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations",
                   "attributes": dict(attrs, locale="en-US"), "relationships": {"appInfo": ref("appInfos", info_id)}}})
    if ok(s):
        notice("Name and privacy policy", f"{meta['name']} / {meta['subtitle']}.")
    else:
        error("Name and privacy policy", why(r))


AGE_LEVELS = {
    "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
    "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation",
    "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity",
    "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic",
}
AGE_FLAGS = {
    "gambling", "unrestrictedWebAccess", "lootBox", "messagingAndChat", "parentalControls",
    "ageAssurance", "userGeneratedContent", "advertising", "healthOrWellnessTopics", "seventeenPlus",
    "socialMedia", "socialMediaAgeRestricted",
}


def age_rating(info_id):
    s, r = api("GET", f"/v1/appInfos/{info_id}/ageRatingDeclaration")
    if not ok(s):
        error("Age rating", why(r))
        return
    decl = r["data"]
    current = decl.get("attributes") or {}
    attrs = {k: "NONE" for k in current if k in AGE_LEVELS}
    attrs.update({k: False for k in current if k in AGE_FLAGS})
    unknown = [k for k, v in current.items() if k not in AGE_LEVELS | AGE_FLAGS and v is None
               and not k.lower().endswith(("override", "overridev2", "url", "band"))]
    for _ in range(4):
        s, r = api("PATCH", f"/v1/ageRatingDeclarations/{decl['id']}",
                   {"data": {"type": "ageRatingDeclarations", "id": decl["id"], "attributes": attrs}})
        if ok(s):
            notice("Age rating", f"Answered None/No to {len(attrs)} questions (4+).")
            if unknown:
                notice("Age rating", "Questions this script doesn't know, left blank: " + ", ".join(unknown))
            return
        bad = [e.get("source", {}).get("pointer", "").rsplit("/", 1)[-1] for e in r.get("errors", [])]
        bad = [b for b in bad if b in attrs]
        if not bad:
            break
        for b in bad:
            attrs.pop(b)
    error("Age rating", why(r))


def price_free(app_id):
    s, r = api("GET", f"/v1/apps/{app_id}/appPriceSchedule?include=manualPrices")
    if ok(s) and (r.get("data") or {}).get("relationships", {}).get("manualPrices", {}).get("data"):
        notice("Price", "Already set.")
        return
    s, r = api("GET", f"/v1/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=200")
    free = next((p["id"] for p in r.get("data") or [] if float(p["attributes"].get("customerPrice") or 1) == 0), None)
    if not free:
        error("Price", f"Couldn't find the free price point ({why(r)}).")
        return
    body = {"data": {"type": "appPriceSchedules", "relationships": {
        "app": ref("apps", app_id),
        "baseTerritory": ref("territories", "USA"),
        "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
        "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": ref("appPricePoints", free)}}]}
    s, r = api("POST", "/v1/appPriceSchedules", body)
    if ok(s):
        notice("Price", "Free.")
    else:
        error("Price", why(r))


def availability(app_id):
    s, r = api("GET", f"/v1/apps/{app_id}/appAvailabilityV2")
    if ok(s) and r.get("data"):
        notice("Availability", "Already set.")
        return
    territories, path = [], "/v1/territories?limit=200"
    while path:
        s, r = api("GET", path)
        territories += [t["id"] for t in r.get("data") or []]
        nxt = (r.get("links") or {}).get("next")
        path = nxt.replace(API, "") if nxt else None
    if not territories:
        error("Availability", f"Couldn't list territories ({why(r)}).")
        return
    body = {"data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True},
                     "relationships": {"app": ref("apps", app_id), "territoryAvailabilities": {
                         "data": [{"type": "territoryAvailabilities", "id": f"${{{t}}}"} for t in territories]}}},
            "included": [{"type": "territoryAvailabilities", "id": f"${{{t}}}", "attributes": {"available": True},
                          "relationships": {"territory": ref("territories", t)}} for t in territories]}
    s, r = api("POST", "/v2/appAvailabilities", body)
    if ok(s):
        notice("Availability", f"All {len(territories)} countries and regions.")
    else:
        error("Availability", why(r))


EDITABLE = "PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED,INVALID_BINARY"


def app_version(app_id, version, meta):
    s, r = api("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&filter[appStoreState]={EDITABLE}")
    versions = r.get("data") or []
    attrs = {"versionString": version, "copyright": meta["copyright"]}
    if versions:
        vid = versions[0]["id"]
        s, r = api("PATCH", f"/v1/appStoreVersions/{vid}", {"data": {"type": "appStoreVersions", "id": vid, "attributes": attrs}})
    else:
        s, r = api("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS")
        waiting = [v for v in r.get("data") or [] if v["attributes"].get("appStoreState") in
                   ("WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "READY_FOR_SALE", "READY_FOR_DISTRIBUTION")]
        if waiting:
            notice("Version", f"Version {waiting[0]['attributes']['versionString']} is already "
                   f"{waiting[0]['attributes']['appStoreState'].replace('_', ' ').lower()}. Nothing to do.")
            sys.exit(0)
        s, r = api("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions",
                   "attributes": dict(attrs, platform="IOS"), "relationships": {"app": ref("apps", app_id)}}})
        vid = (r.get("data") or {}).get("id")
    if not ok(s) or not vid:
        error("Version", why(r))
        sys.exit(1)
    notice("Version", f"{version}, {meta['copyright']}.")
    return vid


def version_text(vid, meta):
    s, r = api("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")
    locs = r.get("data") or []
    loc = next((l for l in locs if l["attributes"]["locale"] == "en-US"), locs[0] if locs else None)
    attrs = {"description": meta["description"], "keywords": meta["keywords"],
             "promotionalText": meta["promotionalText"], "supportUrl": meta["supportUrl"]}
    if loc:
        lid = loc["id"]
        s, r = api("PATCH", f"/v1/appStoreVersionLocalizations/{lid}",
                   {"data": {"type": "appStoreVersionLocalizations", "id": lid, "attributes": attrs}})
    else:
        s, r = api("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations",
                   "attributes": dict(attrs, locale="en-US"), "relationships": {"appStoreVersion": ref("appStoreVersions", vid)}}})
        lid = (r.get("data") or {}).get("id")
    if ok(s):
        notice("Description", "Description, keywords, promotional text and support link set.")
    else:
        error("Description", why(r))
    return lid


def upload_screenshots(lid, folder, files):
    if not lid:
        error("Screenshots", "No English listing to attach them to.")
        return
    s, r = api("GET", f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets")
    sets = {x["attributes"]["screenshotDisplayType"]: x["id"] for x in r.get("data") or []}
    set_id = None
    # 1320 x 2868 is the 6.9" iPhone size. Newer API versions name it APP_IPHONE_69;
    # older ones accept it in the 6.7" set.
    for kind in ("APP_IPHONE_69", "APP_IPHONE_67"):
        if kind in sets:
            set_id = sets[kind]
            break
        s, r = api("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                   "attributes": {"screenshotDisplayType": kind},
                   "relationships": {"appStoreVersionLocalization": ref("appStoreVersionLocalizations", lid)}}})
        if ok(s):
            set_id = r["data"]["id"]
            break
    if not set_id:
        error("Screenshots", f"Couldn't create the iPhone screenshot set ({why(r)}).")
        return

    s, r = api("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots")
    existing = r.get("data") or []
    checksums = [hashlib.md5(open(os.path.join(folder, n), "rb").read()).hexdigest() for n in files]
    have = [x["attributes"].get("sourceFileChecksum") for x in existing]
    states = [((x["attributes"].get("assetDeliveryState") or {}).get("state")) for x in existing]
    if have == checksums and "FAILED" not in states:
        if all(st == "COMPLETE" for st in states):
            notice("Screenshots", "Already uploaded and unchanged.")
            return
        # Some are stuck in Apple's processing queue: upload just those again,
        # then put the set back in order.
        ids = [x["id"] for x in existing]
        stuck = [i for i, st in enumerate(states) if st != "COMPLETE"]
        for i in stuck:
            api("DELETE", f"/v1/appScreenshots/{ids[i]}")
            ids[i] = upload_one(set_id, folder, files[i])
        ids = [i for i in ids if i]
        s, r = api("PATCH", f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots",
                   {"data": [{"type": "appScreenshots", "id": i} for i in ids]})
        if not ok(s):
            error("Screenshots", f"Couldn't reorder the screenshots: {why(r)}")
        if wait_for_screenshots(ids):
            notice("Screenshots", f"Re-uploaded {len(stuck)} screenshot(s) that were stuck processing.")
        return
    for old in existing:
        api("DELETE", f"/v1/appScreenshots/{old['id']}")

    uploaded = [i for i in (upload_one(set_id, folder, name) for name in files) if i]
    if uploaded and wait_for_screenshots(uploaded):
        notice("Screenshots", f"Uploaded {len(uploaded)} iPhone screenshots.")


def upload_one(set_id, folder, name):
    """Uploads one screenshot into the set; returns its id, or None after reporting an error."""
    blob = open(os.path.join(folder, name), "rb").read()
    s, r = api("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
               "attributes": {"fileName": name, "fileSize": len(blob)},
               "relationships": {"appScreenshotSet": ref("appScreenshotSets", set_id)}}})
    if not ok(s):
        error("Screenshots", f"{name}: {why(r)}")
        return None
    shot = r["data"]
    for op in shot["attributes"].get("uploadOperations") or []:
        part = blob[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=part, method=op["method"],
                                     headers={h["name"]: h["value"] for h in op.get("requestHeaders") or []})
        urllib.request.urlopen(req, timeout=120).read()
    s, r = api("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
               "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
    if not ok(s):
        error("Screenshots", f"{name}: {why(r)}")
        return None
    return shot["id"]


def wait_for_screenshots(ids):
    """Apple checks each image after upload; submitting before it finishes fails."""
    states = []
    for _ in range(60):
        states = []
        for sid in ids:
            s, r = api("GET", f"/v1/appScreenshots/{sid}")
            d = ((r.get("data") or {}).get("attributes") or {}).get("assetDeliveryState") or {}
            states.append((d.get("state"), d.get("errors")))
        if all(st in ("COMPLETE", "FAILED") for st, _ in states):
            break
        time.sleep(10)
    failed = [e for st, e in states if st == "FAILED"]
    if failed:
        error("Screenshots", f"Apple rejected {len(failed)} image(s): {json.dumps(failed)[:500]}")
        return False
    if not all(st == "COMPLETE" for st, _ in states):
        error("Screenshots", "Apple is still processing the screenshots. Re-run in a few minutes. "
              f"States: {json.dumps(states)[:400]}")
        return False
    return True


def run_input(name):
    """A workflow_dispatch input, read from the event file so it's never echoed."""
    try:
        with open(os.environ["GITHUB_EVENT_PATH"]) as f:
            value = ((json.load(f).get("inputs") or {}).get(name) or "").strip()
    except (KeyError, OSError, ValueError):
        return ""
    if value:
        print(f"::add-mask::{value}", flush=True)
    return value


def review_details(vid, meta):
    attrs = {"contactEmail": meta["reviewEmail"], "notes": meta["reviewNotes"], "demoAccountRequired": False}
    for env, key in (("REVIEW_FIRST_NAME", "contactFirstName"), ("REVIEW_LAST_NAME", "contactLastName"),
                     ("REVIEW_PHONE", "contactPhone")):
        value = os.environ.get(env, "").strip() or run_input(env.lower())
        if value:
            attrs[key] = value
    s, r = api("GET", f"/v1/appStoreVersions/{vid}/appStoreReviewDetail")
    existing = r.get("data") if ok(s) else None
    if existing:
        s, r = api("PATCH", f"/v1/appStoreReviewDetails/{existing['id']}",
                   {"data": {"type": "appStoreReviewDetails", "id": existing["id"], "attributes": attrs}})
        have = dict(existing.get("attributes") or {}, **attrs)
    else:
        s, r = api("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
                   "relationships": {"appStoreVersion": ref("appStoreVersions", vid)}}})
        have = attrs
    if not ok(s):
        error("App Review contact", why(r))
        return
    missing = [k for k in ("contactFirstName", "contactLastName", "contactPhone") if not (have.get(k) or "").strip()]
    if missing:
        error("App Review contact", "Apple needs a contact name and phone for the reviewer. In App Store Connect, open "
              "the app > iOS App 1.0 > App Review Information and fill in First name, Last name and Phone, then re-run. "
              "(Or add repository secrets UNLISTED_REVIEW_FIRST_NAME, UNLISTED_REVIEW_LAST_NAME, UNLISTED_REVIEW_PHONE.)")
    else:
        notice("App Review contact", "Contact, email and review notes set.")


def attach_build(app_id, vid, version):
    deadline = time.time() + 45 * 60
    while True:
        s, r = api("GET", f"/v1/builds?filter[app]={app_id}&filter[preReleaseVersion.version]={version}"
                          "&sort=-uploadedDate&limit=1")
        builds = r.get("data") or []
        state = builds[0]["attributes"].get("processingState") if builds else None
        if state == "VALID":
            break
        if state in ("FAILED", "INVALID"):
            error("Build", f"Apple marked build {builds[0]['attributes'].get('version')} {state}. Check your email from Apple.")
            return False
        if time.time() > deadline:
            error("Build", f"No processed build for version {version} yet (state: {state or 'not uploaded'}). "
                  "Run the Unlisted release workflow first, then re-run this one.")
            return False
        print(f"Waiting for Apple to process the build (state: {state or 'not visible yet'})...", flush=True)
        time.sleep(30)
    build = builds[0]
    if build["attributes"].get("usesNonExemptEncryption") is None:
        api("PATCH", f"/v1/builds/{build['id']}", {"data": {"type": "builds", "id": build["id"],
            "attributes": {"usesNonExemptEncryption": False}}})
    s, r = api("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", ref("builds", build["id"]))
    if ok(s):
        notice("Build", f"Attached build {build['attributes'].get('version')}.")
        return True
    error("Build", why(r))
    return False


def privacy_not_collected(app_id):
    """App Privacy: "No, we do not collect data from this app", then publish.
    These endpoints aren't in Apple's public API docs (App Store Connect's own
    site uses them), so a refusal here just means doing it on the website."""
    s, r = api("GET", f"/v1/apps/{app_id}/dataUsagePublishState")
    state = r.get("data") if ok(s) else None
    if state and (state.get("attributes") or {}).get("published"):
        notice("App Privacy", "Already published.")
        return
    s, r = api("GET", f"/v1/apps/{app_id}/dataUsages?include=dataProtection&limit=50")
    existing = r.get("data") or [] if ok(s) else []
    if not existing:
        s, r = api("POST", "/v1/appDataUsages", {"data": {"type": "appDataUsages", "relationships": {
            "app": ref("apps", app_id),
            "dataProtection": ref("appDataUsageDataProtections", "DATA_NOT_COLLECTED")}}})
        if not ok(s):
            print(f"::warning title=App Privacy::Apple didn't accept the answer through the API ({why(r)}).", flush=True)
            return
    if not state:
        s, r = api("GET", f"/v1/apps/{app_id}/dataUsagePublishState")
        state = r.get("data") if ok(s) else None
    if not state:
        print(f"::warning title=App Privacy::Couldn't find the publish switch ({why(r)}).", flush=True)
        return
    s, r = api("PATCH", f"/v1/appDataUsagesPublishState/{state['id']}", {"data": {
        "type": "appDataUsagesPublishState", "id": state["id"], "attributes": {"published": True}}})
    if ok(s):
        notice("App Privacy", "Data Not Collected, published.")
    else:
        print(f"::warning title=App Privacy::Couldn't publish ({why(r)}).", flush=True)


def submit(app_id, vid):
    s, r = api("GET", f"/v1/reviewSubmissions?filter[app]={app_id}&filter[platform]=IOS"
                      "&filter[state]=READY_FOR_REVIEW,UNRESOLVED_ISSUES")
    subs = r.get("data") or []
    if subs:
        sub_id = subs[0]["id"]
    else:
        s, r = api("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions",
                   "attributes": {"platform": "IOS"}, "relationships": {"app": ref("apps", app_id)}}})
        if not ok(s):
            error("Submit", why(r))
            return
        sub_id = r["data"]["id"]
    s, r = api("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
        "reviewSubmission": ref("reviewSubmissions", sub_id), "appStoreVersion": ref("appStoreVersions", vid)}}})
    if not ok(s):
        s2, r2 = api("GET", f"/v1/reviewSubmissions/{sub_id}/items")
        if not (r2.get("data") or []):
            text = why(r)
            if "privacy" in text.lower():
                text += (" -> In App Store Connect open the app > App Privacy > Get Started, choose "
                         "'No, we do not collect data from this app', save, press Publish, then re-run.")
            error("Submit", f"Apple wouldn't add version to the submission: {text}")
            return
    s, r = api("PATCH", f"/v1/reviewSubmissions/{sub_id}", {"data": {"type": "reviewSubmissions", "id": sub_id,
               "attributes": {"submitted": True}}})
    if ok(s):
        notice("Submitted", "Unlisted is submitted for App Review. Apple usually replies within 1 to 3 days.")
    else:
        text = why(r)
        if "privacy" in text.lower():
            text += (" -> In App Store Connect open the app > App Privacy > Get Started, choose "
                     "'No, we do not collect data from this app', save, press Publish, then re-run.")
        error("Submit", text)


def main():
    for name in ("review_first_name", "review_last_name", "review_phone"):
        run_input(name)
    meta = json.load(open(sys.argv[1]))
    folder = sys.argv[2]
    version = os.environ["VERSION"]
    app_id = find_app(os.environ["BUNDLE_ID"])

    content_rights(app_id)
    info_id = editable_app_info(app_id)
    if info_id:
        app_info(info_id, meta)
        age_rating(info_id)
    else:
        error("App information", "Couldn't find the app's information record.")
    price_free(app_id)
    availability(app_id)

    vid = app_version(app_id, version, meta)
    lid = version_text(vid, meta)
    upload_screenshots(lid, folder, meta["screenshots"])
    review_details(vid, meta)
    built = attach_build(app_id, vid, version)

    if problems or not built:
        print(f"::error title=Not submitted::Fix the items above, then re-run. Everything else is saved. "
              f"({', '.join(dict.fromkeys(problems))})")
        sys.exit(1)
    privacy_not_collected(app_id)
    submit(app_id, vid)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
