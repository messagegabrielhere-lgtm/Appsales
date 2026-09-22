#!/usr/bin/env python3
"""Turns raw simulator captures into captioned App Store screenshots.

Reads  build/screenshots/<set>/<screen>.jpg
Writes build/screenshots/marketing/<set>/NN-<screen>.jpg  at the same pixel size.

Requires Pillow: pip3 install pillow
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent.parent / "build" / "screenshots"

CAPTIONS = [
    ("widgets", "Check off from your home screen.", "Interactive widgets. Lock screen too."),
    ("list", "Pay once. Keep forever.", "No subscription. No account. No ads."),
    ("detail", "See your whole year.", "Streaks, stats, and a 12-month heatmap."),
    ("editor", "Rest days never break a streak.", "Weekdays only, or any days you choose."),
]

TOP_LEFT = (0x0F, 0x76, 0x6E)
BOTTOM_RIGHT = (0x22, 0xC5, 0x5E)

FONT_CANDIDATES_BOLD = [
    ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
    ("/System/Library/Fonts/Helvetica.ttc", 1),
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 0),
]
FONT_CANDIDATES_REGULAR = [
    ("/System/Library/Fonts/Supplemental/Arial.ttf", 0),
    ("/System/Library/Fonts/Helvetica.ttc", 0),
    ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 0),
]


def font(size, bold):
    for path, index in (FONT_CANDIDATES_BOLD if bold else FONT_CANDIDATES_REGULAR):
        try:
            return ImageFont.truetype(path, size=size, index=index)
        except OSError:
            continue
    return ImageFont.load_default()


def gradient(width, height):
    image = Image.new("RGB", (width, height))
    pixels = image.load()
    denom = float(width + height - 2)
    for y in range(height):
        for x in range(0, width):
            t = (x + y) / denom
            pixels[x, y] = tuple(int(a + (b - a) * t) for a, b in zip(TOP_LEFT, BOTTOM_RIGHT))
    return image


def fitted_font(draw, text, max_width, size, bold):
    while size > 20:
        f = font(size, bold)
        left, _, right, _ = draw.textbbox((0, 0), text, font=f)
        if right - left <= max_width:
            return f
        size = int(size * 0.92)
    return font(size, bold)


def compose(src, dst, title, subtitle):
    shot = Image.open(src).convert("RGB")
    width, height = shot.size
    canvas = gradient(width, height)
    draw = ImageDraw.Draw(canvas)

    margin = int(width * 0.08)
    title_font = fitted_font(draw, title, width - 2 * margin, int(width * 0.075), bold=True)
    subtitle_font = fitted_font(draw, subtitle, width - 2 * margin, int(width * 0.038), bold=False)

    y = int(height * 0.075)
    for text, f, fill in ((title, title_font, (255, 255, 255)), (subtitle, subtitle_font, (225, 245, 238))):
        left, top, right, bottom = draw.textbbox((0, 0), text, font=f)
        draw.text(((width - (right - left)) / 2 - left, y), text, font=f, fill=fill)
        y += (bottom - top) + int(height * 0.012)

    target_w = int(width * 0.80)
    scale = target_w / shot.width
    shot = shot.resize((target_w, int(shot.height * scale)), Image.LANCZOS)
    # iPhones have a large display corner radius; iPads a small one, and their status bar
    # text sits close to the corners.
    is_tablet = shot.width / shot.height > 0.6
    radius = int(target_w * (0.035 if is_tablet else 0.085))
    x = (width - shot.width) // 2
    top = y + int(height * 0.035)

    pad = 60
    shadow = Image.new("RGBA", (shot.width + 2 * pad, shot.height + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [pad, pad, pad + shot.width, pad + shot.height], radius=radius, fill=(0, 0, 0, 120)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.paste(shadow, (x - pad, top - pad + 24), shadow)

    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height - 1], radius=radius, fill=255)
    canvas.paste(shot, (x, top), mask)

    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dst, "JPEG", quality=92)
    print(f"  {dst.relative_to(ROOT.parent.parent)}")


def main():
    sets = [d for d in ROOT.iterdir() if d.is_dir() and d.name != "marketing"] if ROOT.exists() else []
    if not sets:
        print("No captures found. Run scripts/screenshots.sh first.", file=sys.stderr)
        sys.exit(1)
    for folder in sorted(sets):
        print(f"{folder.name}:")
        for index, (screen, title, subtitle) in enumerate(CAPTIONS, start=1):
            src = folder / f"{screen}.jpg"
            if not src.exists():
                print(f"  (missing {src.name}, skipped)")
                continue
            compose(src, ROOT / "marketing" / folder.name / f"{index:02d}-{screen}.jpg", title, subtitle)


if __name__ == "__main__":
    main()
