#!/usr/bin/env python3
"""Generate the 1024x1024 App Store icon with no third-party dependencies.

A teal-to-green diagonal gradient with a bold white checkmark. iOS applies the rounded
mask itself, so the PNG is a full-bleed square with no transparency.

Usage: python3 scripts/make_icon.py
"""
import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "Kept/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

TOP_LEFT = (0x0F, 0x76, 0x6E)      # deep teal
BOTTOM_RIGHT = (0x22, 0xC5, 0x5E)  # green

# Checkmark polyline in icon coordinates, drawn with round caps.
A = (285.0, 535.0)
B = (455.0, 705.0)
C = (760.0, 370.0)
HALF_WIDTH = 58.0


def dist_to_segment(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    length_sq = dx * dx + dy * dy
    t = ((px - ax) * dx + (py - ay) * dy) / length_sq
    t = max(0.0, min(1.0, t))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)


def png_bytes(width, height, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def main():
    rows = []
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            t = (x + y) / (2.0 * (SIZE - 1))
            r = TOP_LEFT[0] + (BOTTOM_RIGHT[0] - TOP_LEFT[0]) * t
            g = TOP_LEFT[1] + (BOTTOM_RIGHT[1] - TOP_LEFT[1]) * t
            b = TOP_LEFT[2] + (BOTTOM_RIGHT[2] - TOP_LEFT[2]) * t

            d = min(
                dist_to_segment(x, y, *A, *B),
                dist_to_segment(x, y, *B, *C),
            )
            alpha = max(0.0, min(1.0, HALF_WIDTH - d + 0.5))  # 1px anti-alias feather
            if alpha > 0:
                r = r + (255 - r) * alpha
                g = g + (255 - g) * alpha
                b = b + (255 - b) * alpha
            row += bytes((int(r), int(g), int(b)))
        rows.append(bytes(row))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(png_bytes(SIZE, SIZE, rows))
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
