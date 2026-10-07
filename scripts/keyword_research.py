#!/usr/bin/env python3
"""Sizes up App Store search terms using Apple's public search API (US store).

Usage: python3 scripts/keyword_research.py "food diary" "supplement tracker" ...

For each term it prints the top ten apps Apple returns, with rating counts and price, and two
signals for choosing keywords:

  demand      total ratings across the top ten. Busy searches have well-reviewed apps.
  competition how many of the top ten have the term in their name or subtitle-like title.

A term with real demand but few top apps naming it is the best place to rank.
"""
import json
import statistics
import sys
import time
import urllib.parse
import urllib.request


def search(term):
    query = urllib.parse.urlencode({"term": term, "entity": "software", "country": "us", "limit": 10})
    with urllib.request.urlopen(f"https://itunes.apple.com/search?{query}", timeout=30) as response:
        return json.load(response)["results"]


def main(terms):
    rows = []
    for term in terms:
        apps = search(term)
        words = term.lower().split()
        naming = sum(1 for a in apps if all(w in a["trackName"].lower() for w in words))
        ratings = [a.get("userRatingCount", 0) for a in apps]
        paid = sum(1 for a in apps if a.get("price", 0) > 0)
        rows.append((term, sum(ratings), statistics.median(ratings) if ratings else 0, naming, paid))
        print(f"\n## {term}")
        for a in apps:
            price = "free" if not a.get("price") else f"${a['price']:.2f}"
            print(f"   {a['trackName'][:58]:<58} {a.get('userRatingCount', 0):>9} ratings  {price:>6}  {a.get('primaryGenreName', '')}")
        time.sleep(3)

    print("\n## Summary (sorted by demand)")
    print(f"   {'term':<26} {'demand':>10} {'median':>8} {'naming':>7} {'paid':>5}")
    for term, total, median, naming, paid in sorted(rows, key=lambda r: -r[1]):
        print(f"   {term:<26} {total:>10} {int(median):>8} {naming:>5}/10 {paid:>5}")


if __name__ == "__main__":
    main(sys.argv[1:])
