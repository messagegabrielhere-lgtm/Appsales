#!/usr/bin/env python3
"""Checks candidate app names against the US App Store, using Apple's public search API.

Usage: python3 scripts/check_names.py "Hunch" "Gut Check" ...

For each name it prints the apps whose title starts with or contains that name, with their
rating counts, so a name that is already somebody's brand stands out.
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request


def search(term):
    query = urllib.parse.urlencode({"term": term, "entity": "software", "country": "us", "limit": 50})
    with urllib.request.urlopen(f"https://itunes.apple.com/search?{query}", timeout=30) as response:
        return json.load(response)["results"]


def main(names):
    summary = []
    for name in names:
        words = re.escape(name.lower())
        pattern = re.compile(rf"\b{words}", re.I)
        apps = [a for a in search(name) if pattern.search(a["trackName"])]
        starts = [a for a in apps if a["trackName"].lower().startswith(name.lower())]
        print(f"\n## {name}: {len(starts)} start with it, {len(apps)} contain it")
        for app in sorted(apps, key=lambda a: -a.get("userRatingCount", 0))[:6]:
            print(f"   {app['trackName'][:60]:<60} {app.get('userRatingCount', 0):>8} ratings  {app.get('primaryGenreName', '')}")
        summary.append((len(starts), len(apps), name))
        time.sleep(3)
    print("\n## Cleanest first (starts-with, contains)")
    for starts, contains, name in sorted(summary):
        print(f"   {starts:>3} {contains:>3}  {name}")


if __name__ == "__main__":
    main(sys.argv[1:])
