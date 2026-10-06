#!/usr/bin/env python3
"""Generates the Fuelprint app icon with no third-party dependencies.

A sunrise gradient (amber to orange to rose) behind a white page. Three entry lines are cut
out of the page, and a sparkle sits just clear of its top-right corner: your day, filed,
ready for AI. The sparkle never overlaps the page, so neither shape needs carving.
iOS applies the rounded mask itself, so the PNG is a full-bleed square with no transparency.

Usage: python3 scripts/make_icon.py
"""
import math
import struct
import zlib
from pathlib import Path

ASSETS = Path(__file__).resolve().parent.parent / "Kept/Assets.xcassets"
OUTPUTS = [
    (1024, ASSETS / "AppIcon.appiconset/AppIcon-1024.png"),
    # 72pt @3x, shown in Settings (iOS never exposes the real icon to apps).
    (216, ASSETS / "AppIconPreview.imageset/AppIconPreview@3x.png"),
]

# Brand gradient stops, top-left to bottom-right.
STOPS = [
    (0.0, (0xFB, 0xBF, 0x24)),  # amber
    (0.5, (0xF9, 0x73, 0x16)),  # orange
    (1.0, (0xE1, 0x1D, 0x48)),  # rose
]

WHITE = (255, 255, 255)

# Geometry in 1024-space.
PAGE_CENTER = (468.0, 584.0)
PAGE_HALF = (226.0, 284.0)
PAGE_RADIUS = 64.0
LINES = [  # (x0, x1, y), half-thickness below
    (332.0, 604.0, 472.0),
    (332.0, 564.0, 584.0),
    (332.0, 494.0, 696.0),
]
LINE_HALF = 26.0
SPARKLE_CENTER = (786.0, 250.0)
SPARKLE_RADIUS = 118.0
SPARKLE_GAP = 22.0
SPARKLE_EXPONENT = 2.0 / 3.0  # an astroid: four concave points


def gradient(t):
    t = max(0.0, min(1.0, t))
    for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
        if t <= t1:
            u = (t - t0) / (t1 - t0)
            return tuple(a + (b - a) * u for a, b in zip(c0, c1))
    return STOPS[-1][1]


def rounded_rect_distance(px, py, center, half, radius):
    qx = abs(px - center[0]) - (half[0] - radius)
    qy = abs(py - center[1]) - (half[1] - radius)
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    return outside + inside - radius


def capsule_distance(px, py, x0, x1, y, half):
    cx = max(x0, min(x1, px))
    return math.hypot(px - cx, py - y) - half


def sparkle_distance(px, py, center, radius):
    """Approximate signed distance to an astroid |x|^e + |y|^e = r^e."""
    dx = abs(px - center[0]) / radius
    dy = abs(py - center[1]) / radius
    if dx == 0.0 and dy == 0.0:
        return -radius
    e = SPARKLE_EXPONENT
    f = dx ** e + dy ** e - 1.0
    # Gradient magnitude of f, for a first-order distance estimate in pixels.
    gx = e * dx ** (e - 1.0) if dx > 1e-6 else 1e6
    gy = e * dy ** (e - 1.0) if dy > 1e-6 else 1e6
    grad = math.hypot(gx, gy) / radius
    return f / grad


def coverage(distance):
    """Signed distance to a one-pixel anti-aliased alpha."""
    return max(0.0, min(1.0, 0.5 - distance))


def blend(base, top, alpha):
    return tuple(b + (t - b) * alpha for b, t in zip(base, top))


def png_bytes(width, height, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def render(size):
    s = size / 1024.0
    center = (PAGE_CENTER[0] * s, PAGE_CENTER[1] * s)
    half = (PAGE_HALF[0] * s, PAGE_HALF[1] * s)
    radius = PAGE_RADIUS * s
    lines = [(x0 * s, x1 * s, y * s) for x0, x1, y in LINES]
    line_half = LINE_HALF * s
    spark_center = (SPARKLE_CENTER[0] * s, SPARKLE_CENTER[1] * s)
    spark_radius = SPARKLE_RADIUS * s
    gap_radius = (SPARKLE_RADIUS + SPARKLE_GAP) * s
    denom = 2.0 * (size - 1)

    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            px, py = x + 0.5, y + 0.5
            background = gradient((x + y) / denom)

            page = coverage(rounded_rect_distance(px, py, center, half, radius))
            cut = 0.0
            for x0, x1, ly in lines:
                cut = max(cut, coverage(capsule_distance(px, py, x0, x1, ly, line_half)))
            halo = coverage(sparkle_distance(px, py, spark_center, gap_radius))
            spark = coverage(sparkle_distance(px, py, spark_center, spark_radius))

            white = page * (1.0 - cut) * (1.0 - halo)
            white = max(white, spark)
            color = blend(background, WHITE, white)
            row += bytes(int(round(c)) for c in color)
        rows.append(bytes(row))
    return png_bytes(size, size, rows)


def main():
    for size, out in OUTPUTS:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(render(size))
        print(f"wrote {out.relative_to(ASSETS.parent.parent)} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
