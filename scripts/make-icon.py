#!/usr/bin/env python3
"""Draws Flux's 1024 px app icon: three ribbons flowing across a night-to-aurora gradient.

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


def gradient(size, stops, angle_deg):
    """A linear gradient through `stops` [(t, (r, g, b)), ...] at `angle_deg`, 0 = left to right."""
    w, h = size
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    # Project each corner to find the range the gradient runs over.
    proj = [x * dx + y * dy for x, y in ((0, 0), (w, 0), (0, h), (w, h))]
    lo, hi = min(proj), max(proj)
    line = Image.new("RGB", (512, 1))
    px = line.load()
    for i in range(512):
        t = i / 511
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                px[i, 0] = lerp(c0, c1, (t - t0) / (t1 - t0) if t1 > t0 else 0)
                break
    # Map every pixel's projection onto the line.
    img = Image.new("RGB", size)
    ip = img.load()
    lp = line.load()
    for y in range(h):
        for x in range(w):
            t = ((x * dx + y * dy) - lo) / (hi - lo)
            ip[x, y] = lp[min(511, max(0, int(t * 511))), 0]
    return img


def ribbon_mask(phase, amp, center, thickness, wavelength):
    """A band that flows across the icon as a sine wave, thin at both ends and thick in the middle."""
    upper, lower = [], []
    steps = 240
    for i in range(steps + 1):
        x = -0.1 * S + i * (1.2 * S) / steps
        u = i / steps
        y = center + amp * math.sin(2 * math.pi * x / wavelength + phase)
        half = thickness / 2 * (0.25 + 0.75 * math.sin(math.pi * u) ** 0.8)
        upper.append((x, y - half))
        lower.append((x, y + half))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(upper + lower[::-1], fill=255)
    return mask


def main(out):
    # Background: deep night blue to violet, with a soft aurora glow low in the middle.
    small = (256, 256)
    bg = gradient(small, [(0, (8, 12, 38)), (0.55, (22, 20, 74)), (1, (58, 22, 104))], 70).resize((S, S), Image.BICUBIC)
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse((int(0.05 * S), int(0.45 * S), int(0.95 * S), int(1.15 * S)), fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
    bg = Image.composite(Image.new("RGB", (S, S), (24, 110, 170)), bg, glow)

    ribbons = [
        # phase, amplitude, centre y, thickness, wavelength, colours left to right
        (0.4, 0.09 * S, 0.36 * S, 0.13 * S, 1.05 * S, [(0, (90, 240, 255)), (1, (70, 140, 255))]),
        (1.6, 0.10 * S, 0.50 * S, 0.15 * S, 1.15 * S, [(0, (60, 170, 255)), (1, (150, 90, 255))]),
        (2.9, 0.08 * S, 0.64 * S, 0.11 * S, 0.95 * S, [(0, (120, 110, 255)), (1, (230, 110, 230))]),
    ]
    img = bg
    for phase, amp, center, thick, wave, stops in ribbons:
        mask = ribbon_mask(phase, amp, center, thick, wave)
        fill = gradient(small, stops, 0).resize((S, S), Image.BICUBIC)
        # A glow under the ribbon, then the ribbon, then a glassy highlight along its top edge.
        halo = mask.filter(ImageFilter.GaussianBlur(S * 0.025)).point(lambda v: int(v * 0.55))
        img = Image.composite(fill, img, halo)
        img = Image.composite(fill, img, mask.filter(ImageFilter.GaussianBlur(1.5)))
        shifted = ImageChops.offset(mask, 0, int(thick * 0.18))
        edge = ImageChops.subtract(mask, shifted).filter(ImageFilter.GaussianBlur(S * 0.006))
        img = Image.composite(Image.new("RGB", (S, S), (255, 255, 255)), img, edge.point(lambda v: int(v * 0.45)))

    img.resize((SIZE, SIZE), Image.LANCZOS).save(out, "PNG")  # RGB, no alpha, as iOS wants
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1])
