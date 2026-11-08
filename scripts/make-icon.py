#!/usr/bin/env python3
"""Draws Flux's 1024 px app icon: one puffy blue wave, like soft clay, on a pale blue ground.

Run: python3 scripts/make-icon.py Sources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
Needs Pillow (pip install pillow). It draws at twice the size and scales down, for smooth edges.
"""
import math
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
S = SIZE * 2  # drawn at 2x


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(top, bottom):
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        d.line([(0, y), (S, y)], fill=lerp(top, bottom, y / (S - 1)))
    return img


def wave(cy, amp, x0, x1, wavelength, phase):
    """Points along a sine wave across the icon, as fractions of its width."""
    return [
        (S * x, cy + amp * math.sin(2 * math.pi * x / wavelength + phase))
        for x in (x0 + (x1 - x0) * i / 300 for i in range(301))
    ]


def stroke(points, thickness):
    """A mask of a round-capped stroke along `points`."""
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    r = thickness / 2
    for a, b in zip(points, points[1:]):
        steps = max(1, int(math.dist(a, b) / 2))
        for k in range(steps):
            x = a[0] + (b[0] - a[0]) * k / steps
            y = a[1] + (b[1] - a[1]) * k / steps
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    return mask


def paint(img, color, mask):
    return Image.composite(Image.new("RGBA", (S, S), color + (255,)), img, mask)


def main(out):
    img = vertical_gradient((232, 240, 255), (202, 220, 252)).convert("RGBA")
    points = wave(S * 0.5, S * 0.09, 0.2, 0.8, 0.6, 0.3)
    body = stroke(points, S * 0.2)

    # A soft shadow under the clay, the clay itself, light on its top edge and shade on its bottom.
    shadow = body.filter(ImageFilter.GaussianBlur(S * 0.035)).point(lambda v: int(v * 0.45))
    img = paint(img, (30, 70, 160), ImageChops.offset(shadow, 0, int(S * 0.045)))
    img = paint(img, (40, 110, 230), body)
    top = ImageChops.subtract(body, ImageChops.offset(body, 0, int(S * 0.05)))
    img = paint(img, (150, 200, 255), top.filter(ImageFilter.GaussianBlur(S * 0.02)).point(lambda v: int(v * 0.8)))
    bottom = ImageChops.subtract(body, ImageChops.offset(body, 0, -int(S * 0.05)))
    img = paint(img, (20, 70, 170), bottom.filter(ImageFilter.GaussianBlur(S * 0.02)).point(lambda v: int(v * 0.6)))
    # A glossy highlight along the first crest.
    gloss = stroke([(x, y - S * 0.045) for x, y in points[60:140]], S * 0.03)
    img = paint(img, (255, 255, 255), gloss.filter(ImageFilter.GaussianBlur(S * 0.01)).point(lambda v: int(v * 0.7)))

    img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).save(out, "PNG")  # no alpha, as iOS wants
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1])
