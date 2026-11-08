#!/usr/bin/env python3
"""Draws Flux's 1024 px app icon: three white waves, like the water.waves symbol, on a blue
gradient.

Run: python3 scripts/make-icon.py Sources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
Needs Pillow (pip install pillow). It draws at four times the size and scales down, for smooth
edges. Each wave is stamped from circles along its curve, so the stroke has round ends.
"""
import math
import sys

from PIL import Image, ImageDraw

SIZE = 1024
S = SIZE * 4  # drawn at 4x

TOP = (70, 140, 255)
BOTTOM = (24, 94, 226)
WAVE = (255, 255, 255)
STROKE = 0.058  # of the icon's width
ROWS = (0.37, 0.50, 0.63)  # the waves' middles, top to bottom
SPAN = (0.23, 0.77)  # where they start and end
AMPLITUDE = 0.042
CRESTS = 2


def gradient(top, bottom):
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(0, S, 4):
        t = y / S
        d.rectangle([0, y, S, y + 4], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def waves(img):
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    r = S * STROKE / 2
    x0, x1 = S * SPAN[0], S * SPAN[1]
    for row in ROWS:
        steps = 3000
        for i in range(steps + 1):
            t = i / steps
            x = x0 + (x1 - x0) * t
            y = S * row - S * AMPLITUDE * math.sin(t * 2 * math.pi * CRESTS)
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    img.paste(Image.new("RGB", (S, S), WAVE), (0, 0), mask)
    return img


def main(out):
    img = waves(gradient(TOP, BOTTOM))
    img.resize((SIZE, SIZE), Image.LANCZOS).save(out, "PNG")  # no alpha, as iOS wants
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1])
