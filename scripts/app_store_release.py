#!/usr/bin/env python3
"""Release day for 2.3: sets the app's price to Free and releases the approved version, in
that order, so nobody downloads the paid-era build for free.

    python3 scripts/app_store_release.py --version 2.3.0 [--price-free] [--release]

Uses the same App Store Connect API key secrets as scripts/app_store_connect.py.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from app_store_connect import Client, Failure, find_app, load_private_key, step, version_state  # noqa: E402


def set_price_free(client, app_id):
    points = client.get_all(f"/v1/apps/{app_id}/appPricePoints", **{"filter[territory]": "USA", "limit": 200})
    free = next((p for p in points if float(p["attributes"]["customerPrice"]) == 0), None)
    if not free:
        raise Failure("No free price point found for the US storefront")
    client.request("POST", "/v1/appPriceSchedules", json={
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": app_id}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
        "included": [{"type": "appPrices", "id": "${free}",
                      "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
    print("Price: Free in every storefront, starting now")


def release(client, app_id, version_string):
    versions = client.get_all(f"/v1/apps/{app_id}/appStoreVersions", **{"filter[platform]": "IOS"})
    version = next((v for v in versions if v["attributes"]["versionString"] == version_string), None)
    if not version:
        raise Failure(f"No version {version_string}")
    state = version_state(version)
    if state in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION"):
        print(f"{version_string} is already live")
        return
    if state != "PENDING_DEVELOPER_RELEASE":
        raise Failure(f"{version_string} is {state}; it can be released once Apple approves it")
    client.create("appStoreVersionReleaseRequests", relationships={"appStoreVersion": ("appStoreVersions", version["id"])})
    print(f"{version_string} released; it reaches the App Store within a few hours")


def main(argv=None, client=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--version", required=True)
    parser.add_argument("--bundle-id", default="com.messagegabrielhere.kept")
    parser.add_argument("--price-free", action="store_true")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args(argv)
    try:
        if client is None:
            client = Client(os.environ.get("APP_STORE_CONNECT_API_KEY_ID", "").strip(),
                            os.environ.get("APP_STORE_CONNECT_API_ISSUER_ID", "").strip(),
                            load_private_key())
        step("Finding the app")
        app = find_app(client, args.bundle_id)
        if args.release:
            # Check it's approved before touching the price.
            versions = client.get_all(f"/v1/apps/{app['id']}/appStoreVersions", **{"filter[platform]": "IOS"})
            version = next((v for v in versions if v["attributes"]["versionString"] == args.version), None)
            if not version or version_state(version) not in ("PENDING_DEVELOPER_RELEASE", "READY_FOR_SALE", "READY_FOR_DISTRIBUTION"):
                raise Failure(f"{args.version} isn't approved yet ({version_state(version) if version else 'missing'}); nothing changed")
        if args.price_free:
            step("Price")
            set_price_free(client, app["id"])
        if args.release:
            step("Release")
            release(client, app["id"], args.version)
    except Failure as error:
        print(f"\nERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
