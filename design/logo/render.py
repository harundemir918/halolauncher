#!/usr/bin/env python3
"""Renders the Halo mark (halo.svg) to the PNGs that can't be vector drawables:
the store icon and macOS's app icon set. Needs Pillow:

    python3 design/logo/render.py

Android's icon is vector (launcher/android/app/src/main/res/drawable/
ic_launcher_foreground.xml and _monochrome.xml); keep them, this file and
halo.svg in step if the mark changes.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
CARBON = (12, 12, 11, 255)
BONE = (242, 240, 232)
VOLT = (214, 255, 63, 255)

# The mark on a 108 x 108 canvas, as in halo.svg.
CENTER, RING_R, TRACK_W, ARC_W, DOT_R = 54, 29, 3.2, 7.2, 8.4
ARC_FROM, ARC_SWEEP = -90, 120  # degrees: 12 o'clock, clockwise
SS = 4  # supersampling


def mark(size, body=None):
    """The mark in a [size] x [size] square. With [body], a rounded carbon
    square of that size (as a fraction of [size]) behind it, the rest clear;
    without, the carbon fills the square."""
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if body is None:
        draw.rectangle([0, 0, n, n], fill=CARBON)
        side, off = n, 0
    else:
        side = n * body
        off = (n - side) / 2
        draw.rounded_rectangle(
            [off, off, off + side, off + side], radius=side * 0.2237, fill=CARBON
        )
    s = side / 108.0
    cx = cy = off + CENTER * s
    r = RING_R * s

    ring = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    w = TRACK_W * s
    ImageDraw.Draw(ring).ellipse(
        [cx - r - w / 2, cy - r - w / 2, cx + r + w / 2, cy + r + w / 2],
        outline=(*BONE, int(255 * 0.30)),
        width=int(round(w)),
    )
    img = Image.alpha_composite(img, ring)
    draw = ImageDraw.Draw(img)

    aw = ARC_W * s
    steps = 600
    for i in range(steps + 1):
        a = math.radians(ARC_FROM + ARC_SWEEP * i / steps)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        draw.ellipse([x - aw / 2, y - aw / 2, x + aw / 2, y + aw / 2], fill=VOLT)
    d = DOT_R * s
    draw.ellipse([cx - d, cy - d, cx + d, cy + d], fill=VOLT)
    return img.resize((size, size), Image.LANCZOS)


def main():
    # Play Store: full bleed, the store rounds it.
    mark(512).save(Path(__file__).parent / "halo-icon-512.png")
    # macOS: the Big Sur shape, a body 824 of 1024 wide, centered.
    icons = ROOT / "launcher/macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        mark(size, body=824 / 1024).save(icons / f"app_icon_{size}.png")


if __name__ == "__main__":
    main()
