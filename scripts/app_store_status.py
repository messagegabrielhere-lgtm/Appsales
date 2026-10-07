#!/usr/bin/env python3
"""Read-only audit of an App Store version: what Apple has, compared with the listing file.

Prints the review state, then checks every field the submission depends on: name, subtitle,
categories, age rating, description, keywords, What's New, URLs (and that they load),
copyright, release type, build, screenshots and App Review details. Changes nothing.

Exit code 0 when everything matches, 1 when something is missing or different.
Run by .github/workflows/app-store-status.yml. Same credentials as app_store_connect.py.
"""
import argparse
import os
import sys

import app_store_connect as asc

problems = []


def ok(label, detail=""):
    print(f"  OK    {label}{': ' + detail if detail else ''}")


def bad(label, detail):
    problems.append(f"{label}: {detail}")
    print(f"  FIX   {label}: {detail}")


def info(label, detail):
    print(f"  ..    {label}: {detail}")


def compare(label, actual, expected):
    if (actual or "").strip() == (expected or "").strip():
        ok(label, f"{len(actual or '')} characters" if len(actual or "") > 40 else repr(actual))
    else:
        bad(label, f"App Store has {short(actual)}, listing says {short(expected)}")


def short(text):
    text = (text or "").replace("\n", " ")
    return repr(text if len(text) <= 60 else text[:57] + "...")


def related(client, path):
    body = client.request("GET", path, allow=(404,))
    return (body or {}).get("data")


def check_url(label, url, must_contain):
    import requests

    if not url:
        bad(label, "not set")
        return
    try:
        response = requests.get(url, timeout=30)
    except Exception as error:  # noqa: BLE001
        bad(label, f"{url} did not load ({error.__class__.__name__})")
        return
    if response.status_code != 200:
        bad(label, f"{url} returned {response.status_code}")
    elif must_contain not in response.text:
        bad(label, f"{url} loads but does not mention {must_contain}")
    else:
        ok(label, f"{url} loads and mentions {must_contain}")


def main(argv=None, client=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--version", required=True)
    parser.add_argument("--listing", required=True)
    parser.add_argument("--bundle-id", default="com.messagegabrielhere.kept")
    args = parser.parse_args(argv)

    fields = asc.parse_listing(args.listing)
    brand = fields["Name"].split(":")[0].strip()
    if client is None:
        client = asc.Client(os.environ.get("APP_STORE_CONNECT_API_KEY_ID", "").strip(),
                            os.environ.get("APP_STORE_CONNECT_API_ISSUER_ID", "").strip(),
                            asc.load_private_key())

    app = asc.find_app(client, args.bundle_id)
    locale = app["attributes"]["primaryLocale"]
    versions = client.get_all(f"/v1/apps/{app['id']}/appStoreVersions", **{"filter[platform]": "IOS"})
    version = next((v for v in versions if v["attributes"]["versionString"] == args.version), None)
    if not version:
        print(f"ERROR: version {args.version} does not exist")
        return 1
    attributes = version["attributes"]

    asc.step("Review status")
    state = asc.version_state(version)
    print(f"  STATE {args.version}: {state}")
    for other in versions:
        if other is not version:
            info("Other version", f"{other['attributes']['versionString']} is {asc.version_state(other)}")
    submissions = client.get_all("/v1/reviewSubmissions", **{"filter[app]": app["id"], "filter[platform]": "IOS"})
    for submission in submissions[:3]:
        a = submission["attributes"]
        info("Review submission", f"{a.get('state')} (submitted {a.get('submittedDate') or 'not yet'})")

    asc.step("App Information")
    infos = client.get_all(f"/v1/apps/{app['id']}/appInfos")
    live_states = asc.LIVE
    editable = [i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState")) not in live_states]
    app_info = (editable or infos)[0]
    localization = asc.localization_for(client.get_all(f"/v1/appInfos/{app_info['id']}/appInfoLocalizations"), locale)
    compare("Name", localization["attributes"].get("name"), fields["Name"])
    compare("Subtitle", localization["attributes"].get("subtitle"), fields.get("Subtitle"))
    compare("Privacy policy URL", localization["attributes"].get("privacyPolicyUrl"), fields.get("Privacy Policy URL"))
    primary = related(client, f"/v1/appInfos/{app_info['id']}/primaryCategory")
    secondary = related(client, f"/v1/appInfos/{app_info['id']}/secondaryCategory")
    actual_categories = [c["id"] for c in (primary, secondary) if c]
    if actual_categories == fields.get("Category", actual_categories):
        ok("Categories", ", ".join(actual_categories))
    else:
        bad("Categories", f"App Store has {actual_categories}, listing says {fields.get('Category')}")
    rating = app_info["attributes"].get("appStoreAgeRating")
    if rating:
        ok("Age rating", rating)
    else:
        bad("Age rating", "not set; answer the age rating questions under App Information")
    if app["attributes"].get("contentRightsDeclaration"):
        ok("Content rights", app["attributes"]["contentRightsDeclaration"])
    else:
        bad("Content rights", "not declared")

    asc.step(f"Version {args.version}")
    if fields.get("Copyright"):
        compare("Copyright", attributes.get("copyright"), fields["Copyright"])
    elif attributes.get("copyright"):
        ok("Copyright", attributes["copyright"])
    else:
        bad("Copyright", "empty")
    release = attributes.get("releaseType")
    if release == "AFTER_APPROVAL":
        ok("Release", "goes live automatically once approved")
    elif release == "MANUAL":
        bad("Release", "set to manual: after approval someone must press Release This Version")
    else:
        info("Release", f"{release} {attributes.get('earliestReleaseDate') or ''}")

    text = asc.localization_for(
        client.get_all(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"), locale)["attributes"]
    compare("Description", text.get("description"), fields["Description"])
    compare("Keywords", text.get("keywords"), fields["Keywords"])
    compare("Promotional text", text.get("promotionalText"), fields.get("Promotional text"))
    compare("What's New", text.get("whatsNew"), fields.get("What's New"))
    compare("Support URL", text.get("supportUrl"), fields.get("Support URL"))
    if text.get("marketingUrl"):
        info("Marketing URL", text["marketingUrl"])

    asc.step("Build")
    build = related(client, f"/v1/appStoreVersions/{version['id']}/build")
    if not build:
        bad("Build", "none attached")
    else:
        b = build["attributes"]
        detail = f"{b.get('version')} ({b.get('processingState')}), uploaded {b.get('uploadedDate', '')[:10]}"
        if b.get("processingState") == "VALID" and not b.get("expired"):
            ok("Build", detail)
        else:
            bad("Build", detail)
        if b.get("usesNonExemptEncryption") is False:
            ok("Export compliance", "no non-exempt encryption")
        else:
            bad("Export compliance", f"usesNonExemptEncryption is {b.get('usesNonExemptEncryption')}")

    asc.step("Screenshots")
    localization_id = asc.localization_for(
        client.get_all(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations"), locale)["id"]
    sets = client.get_all(f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")
    by_type = {s["attributes"]["screenshotDisplayType"]: s for s in sets}
    for display_type in asc.SCREENSHOT_SETS.values():
        screenshot_set = by_type.get(display_type)
        shots = client.get_all(f"/v1/appScreenshotSets/{screenshot_set['id']}/appScreenshots") if screenshot_set else []
        states = [((s["attributes"].get("assetDeliveryState") or {}).get("state")) for s in shots]
        names = ", ".join(s["attributes"].get("fileName", "?") for s in shots)
        if shots and all(st == "COMPLETE" for st in states):
            ok(display_type, f"{len(shots)}: {names}")
        else:
            bad(display_type, f"{len(shots)} screenshots, states {states}")
    for display_type in by_type:
        if display_type not in asc.SCREENSHOT_SETS.values():
            info("Other screenshot set", display_type)

    asc.step("App Review information")
    detail = asc.review_detail(client, version["id"])
    if not detail:
        bad("Review details", "missing")
    else:
        d = detail["attributes"]
        compare("Review notes", d.get("notes"), fields.get("App Review notes"))
        if d.get("demoAccountRequired"):
            bad("Sign-in", "marked as required, but the app has no account")
        else:
            ok("Sign-in", "not required")
        missing = [k for k in ("contactFirstName", "contactLastName", "contactPhone", "contactEmail") if not d.get(k)]
        if missing:
            bad("Review contact", f"missing {', '.join(missing)}")
        else:
            ok("Review contact", "name, phone and email present")

    asc.step("Public pages")
    check_url("Support page", text.get("supportUrl"), brand)
    check_url("Privacy page", localization["attributes"].get("privacyPolicyUrl"), brand)

    asc.step("Summary")
    print(f"  STATE {args.version}: {state}")
    if problems:
        print(f"  {len(problems)} thing(s) to fix:")
        for problem in problems:
            print(f"   - {problem}")
        return 1
    print("  Nothing missing. Everything matches the listing file.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except asc.Failure as error:
        print(f"\nERROR: {error}", file=sys.stderr)
        sys.exit(1)
