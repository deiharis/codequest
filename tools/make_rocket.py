#!/usr/bin/env python3
"""Generates the travel rocket sprite sheet into assets/sprites/ui/.

Run from the project root:  python3 tools/make_rocket.py

Side profile, pointing right, because that is the direction it flies. The sheet
it replaces was a top-down jet rotated 90 degrees and scaled 1.273 on one axis,
which is where its distortion came from.

Palette is the game's own (ADR-019): bone and gold over dark navy, with the
violet the Bug Lord's burst introduced. Nothing here is cyan.

Drawn at 4x and downsampled — that is what makes the edges clean without
hand-antialiasing anything.
"""
import math, os
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

SS = 4
FW, FH = 400, 200
FRAMES = 8
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "ui")

BONE       = (236, 230, 214)
BONE_DARK  = (118, 112, 100)
GOLD       = (214, 176, 56)
GOLD_LIT   = (248, 226, 150)
GOLD_DARK  = (126, 98, 22)
NAVY       = (34, 42, 68)
NAVY_LIT   = (64, 76, 116)
GLASS      = (92, 66, 148)
GLASS_LIT  = (188, 162, 244)
FLAME_CORE = (255, 252, 236)
FLAME_MID  = (255, 190, 84)
FLAME_EDGE = (168, 88, 206)

CY = FH * SS // 2

# Every station along the hull, in final pixels. Named because the numbers get
# referenced from four places and a typo in one of them is invisible.
ENGINE_BACK, ENGINE_FRONT = 78, 112
BODY_BACK, SHOULDER, NOSE_TIP = 112, 298, 372
BODY_R = 30


def px(v):
    return int(v * SS)


def radius_at(x):
    """Half-height of the hull at x, in supersampled pixels."""
    x /= SS
    if x < BODY_BACK or x > NOSE_TIP:
        return 0.0
    if x <= SHOULDER:
        return px(BODY_R)
    t = (x - SHOULDER) / (NOSE_TIP - SHOULDER)       # ogive, not a long ellipse
    return px(BODY_R) * math.sqrt(max(0.0, 1.0 - t * t))


def hull_polygon(x0, x1):
    xs = list(range(px(x0), px(x1), 2 * SS))
    return ([(x, CY - radius_at(x)) for x in xs]
            + [(x, CY + radius_at(x)) for x in reversed(xs)])


def shaded(size, poly, light, dark, rim=None):
    """A polygon filled with a top-lit vertical gradient.

    A flat fill reads as a sticker. One light source from above, a highlight
    band a third of the way down, and an optional bright rim on the very top
    edge is the whole difference between a shape and an object.
    """
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    m = np.array(mask).astype(bool)

    ys = np.array([p[1] for p in poly])
    top, bottom = ys.min(), ys.max()
    span = max(1.0, bottom - top)
    rows = (np.arange(size[1]) - top) / span
    k = np.clip(1.0 - np.abs(rows - 0.30) * 1.55, 0.0, 1.0) ** 0.75

    out = np.zeros((size[1], size[0], 4), dtype=float)
    for c in range(3):
        out[..., c] = (dark[c] + (light[c] - dark[c]) * k)[:, None]
    out[..., 3] = 255.0
    img = Image.fromarray(out.astype(np.uint8), "RGBA")
    img.putalpha(mask)

    if rim:
        d = ImageDraw.Draw(img)
        edge = [p for p in poly if p[1] < CY]
        d.line(edge, fill=rim + (190,), width=2 * SS)
    return img


def draw_hull():
    size = (FW * SS, FH * SS)
    img = Image.new("RGBA", size, (0, 0, 0, 0))

    # Fins first, so the hull overlaps their roots and they read as attached
    # rather than stuck on. Navy is the game's shadow colour; the gold outline
    # is what stops them disappearing into a dark backdrop.
    d = ImageDraw.Draw(img)
    for s in (-1, 1):
        fin = [(px(118), CY + s * px(26)), (px(206), CY + s * px(29)),
               (px(156), CY + s * px(78)), (px(96), CY + s * px(72))]
        d.polygon(fin, fill=NAVY + (255,))
        d.line(fin + [fin[0]], fill=GOLD_DARK + (255,), width=3 * SS, joint="curve")
        d.line([fin[1], fin[2]], fill=GOLD + (255,), width=3 * SS)
        d.line([fin[0], fin[1]], fill=NAVY_LIT + (255,), width=2 * SS)

    body = hull_polygon(BODY_BACK, SHOULDER + 1)
    img = Image.alpha_composite(img, shaded(size, body, BONE, BONE_DARK, rim=(255, 255, 255)))
    nose = hull_polygon(SHOULDER, NOSE_TIP)
    img = Image.alpha_composite(img, shaded(size, nose, GOLD_LIT, GOLD_DARK, rim=(255, 246, 210)))

    d = ImageDraw.Draw(img)

    # Panel lines and rivets. Small, dark, and the reason the hull reads as
    # plated metal instead of a painted tube.
    for x in (150, 196, 242, 280):
        r = radius_at(px(x))
        d.line([(px(x), CY - r + 2 * SS), (px(x), CY + r - 2 * SS)],
               fill=BONE_DARK + (140,), width=SS)
    for x in range(140, 290, 18):
        r = radius_at(px(x))
        d.ellipse([px(x) - SS, CY - r + 5 * SS - SS, px(x) + SS, CY - r + 5 * SS + SS],
                  fill=BONE_DARK + (180,))

    # Gold collar at the shoulder, where the nose meets the hull.
    r = radius_at(px(SHOULDER))
    d.line([(px(SHOULDER), CY - r), (px(SHOULDER), CY + r)],
           fill=GOLD_DARK + (255,), width=6 * SS)
    d.line([(px(SHOULDER) - 2 * SS, CY - r), (px(SHOULDER) - 2 * SS, CY + r)],
           fill=GOLD + (255,), width=2 * SS)

    # Cockpit: small, forward, violet glass in a gold frame with one hard
    # highlight. Big enough to be seen at 200px wide on screen, no bigger.
    cx, cy = px(258), CY - px(7)
    d.ellipse([cx - px(26), cy - px(14), cx + px(26), cy + px(14)],
              fill=GLASS + (255,), outline=GOLD + (255,), width=3 * SS)
    d.ellipse([cx - px(17), cy - px(9), cx - px(2), cy - px(2)],
              fill=GLASS_LIT + (170,))

    # Engine bell: flared outward toward the back.
    bell = [(px(ENGINE_FRONT), CY - px(28)), (px(ENGINE_FRONT), CY + px(28)),
            (px(ENGINE_BACK), CY + px(38)), (px(ENGINE_BACK), CY - px(38))]
    img = Image.alpha_composite(img, shaded(size, bell, GOLD_LIT, GOLD_DARK))
    d = ImageDraw.Draw(img)
    d.polygon([(px(ENGINE_BACK + 6), CY - px(30)), (px(ENGINE_BACK + 6), CY + px(30)),
               (px(ENGINE_BACK), CY + px(33)), (px(ENGINE_BACK), CY - px(33))],
              fill=(38, 24, 14, 255))
    return img


def tongue(d, length, half, col, alpha, wobble):
    """One flame tongue: full width at the bell, pinched to a point behind it."""
    pts_top, pts_bottom = [], []
    N = 16
    for i in range(N + 1):
        t = i / N
        w = half * (1.0 - t) ** 0.75 * (1.0 + 0.10 * math.sin(t * 7.0 + wobble))
        x = px(ENGINE_BACK) - length * t
        pts_top.append((x, CY - w))
        pts_bottom.append((x, CY + w))
    d.polygon(pts_top + pts_bottom[::-1], fill=col + (alpha,))


def draw_flame(phase):
    """The only thing that changes between frames. Three nested tongues, each
    breathing at a slightly different rate, so the flicker reads as heat rather
    than as one shape being scaled."""
    img = Image.new("RGBA", (FW * SS, FH * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    a = phase * math.tau
    for length, half, col, alpha, rate in (
            (px(132), px(27), FLAME_EDGE, 130, 1.0),
            (px(96),  px(18), FLAME_MID,  205, 1.7),
            (px(58),  px(10), FLAME_CORE, 255, 2.3)):
        breathe = 1.0 + 0.16 * math.sin(a * rate)
        tongue(d, length * breathe, half, col, alpha, a * rate)
    return img.filter(ImageFilter.GaussianBlur(2.5 * SS))


def main():
    os.makedirs(OUT, exist_ok=True)
    hull = draw_hull()
    sheet = Image.new("RGBA", (FW * FRAMES, FH), (0, 0, 0, 0))
    for i in range(FRAMES):
        frame = Image.alpha_composite(draw_flame(i / FRAMES), hull)
        sheet.paste(frame.resize((FW, FH), Image.LANCZOS), (i * FW, 0))
    path = os.path.join(OUT, "rocket_sheet_v2.png")
    sheet.save(path)
    print(f"{FRAMES} frames of {FW}x{FH} -> {os.path.basename(path)}")


if __name__ == "__main__":
    main()
