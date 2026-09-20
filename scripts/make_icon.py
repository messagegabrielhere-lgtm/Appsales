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

ASSETS = Path(__file__).resolve().parent.parent / "Kept/Assets.xcassets"
OUTPUTS = [
    (1024, ASSETS / "AppIcon.appiconset/AppIcon-1024.png"),
    # 72pt @3x, shown inside the About screen (iOS never exposes the real icon to apps).
    (216, ASSETS / "AppIconPreview.imageset/AppIconPreview@3x.png"),
]

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


def render(size):
    scale = size / 1024.0
    ax, ay = A[0] * scale, A[1] * scale
    bx, by = B[0] * scale, B[1] * scale
    cx, cy = C[0] * scale, C[1] * scale
    half_width = HALF_WIDTH * scale
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            t = (x + y) / (2.0 * (size - 1))
            r = TOP_LEFT[0] + (BOTTOM_RIGHT[0] - TOP_LEFT[0]) * t
            g = TOP_LEFT[1] + (BOTTOM_RIGHT[1] - TOP_LEFT[1]) * t
            b = TOP_LEFT[2] + (BOTTOM_RIGHT[2] - TOP_LEFT[2]) * t

            d = min(
                dist_to_segment(x, y, ax, ay, bx, by),
                dist_to_segment(x, y, bx, by, cx, cy),
            )
            alpha = max(0.0, min(1.0, half_width - d + 0.5))  # 1px anti-alias feather
            if alpha > 0:
                r = r + (255 - r) * alpha
                g = g + (255 - g) * alpha
                b = b + (255 - b) * alpha
            row += bytes((int(r), int(g), int(b)))
        rows.append(bytes(row))
    return png_bytes(size, size, rows)


def main():
    for size, out in OUTPUTS:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(render(size))
        print(f"wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
