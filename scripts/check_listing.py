#!/usr/bin/env python3
"""Checks App Store listing fields against Apple's character limits.

Usage: python3 scripts/check_listing.py docs/listing/v2.0.md
"""
import re
import sys
from pathlib import Path

LIMITS = {
    "Name": 30,
    "Subtitle": 30,
    "Promotional text": 170,
    "Description": 4000,
    "Keywords": 100,
    "App Review notes": 4000,
    "What's New": 4000,
}


def main(path):
    text = Path(path).read_text()
    sections = re.split(r"^## ", text, flags=re.M)[1:]
    failed = False
    for section in sections:
        heading, _, body = section.partition("\n")
        limit = next((v for k, v in LIMITS.items() if heading.startswith(k)), None)
        match = re.search(r"```\n(.*?)\n```", body, re.S)
        if limit is None or not match:
            continue
        value = match.group(1)
        count = len(value)
        ok = count <= limit
        extra = ""
        if heading.startswith("Keywords"):
            if " " in value:
                ok = False
                extra = " (contains a space)"
            words = value.split(",")
            if len(words) != len(set(words)):
                ok = False
                extra += " (duplicate keyword)"
        failed |= not ok
        print(f"{'OK  ' if ok else 'FAIL'} {heading.strip():<40} {count:>5} / {limit}{extra}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "docs/listing/v2.0.md")
