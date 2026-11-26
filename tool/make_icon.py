"""Draws the WattWise app icon into assets/icon/ (needs Pillow: pip install pillow).

  icon.png             1024x1024, full icon (iPhone, legacy Android, store art)
  icon_background.png  1024x1024, the gradient background (Android adaptive icon)
  icon_foreground.png  1024x1024, transparent, artwork sized for the Android
                       adaptive-icon safe zone
  icon_monochrome.png  1024x1024, white artwork for Android 13+ themed icons

Design: a lightning bolt (emerald -> sky, the app's battery and grid colours)
inside a gauge ring with an amber "solar" arc, on a deep navy-to-teal background.
Run: python tool/make_icon.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "icon")
S = 4  # supersampling for smooth edges
N = 1024 * S

EMERALD = (52, 211, 153)
SKY = (56, 189, 248)
AMBER = (251, 191, 36)
BG_TOP = (11, 20, 36)
BG_BOTTOM = (13, 59, 58)

# Bolt outline in 1024 space, centred on (512, 515); drawn at BOLT_K so it sits inside the ring.
BOLT = [(562, 168), (318, 584), (488, 584), (430, 872), (712, 418), (540, 418), (650, 168)]
BOLT_K = 0.66
RING_C, RING_R, RING_W = (512, 515), 330, 40
ARC_FROM, ARC_SWEEP = 135, 270  # gauge opening at the bottom
ARC_FILL = 0.72  # share of the gauge lit in amber


def vertical_gradient(size, c1, c2):
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        col.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(c1, c2)))
    return col.resize((w, h))


def scaled(points, k, centre=(512, 515)):
    cx, cy = centre
    return [((cx + (x - cx) * k) * S, (cy + (y - cy) * k) * S) for x, y in points]


def ring_box(k):
    cx, cy = RING_C
    r = RING_R * k
    return [(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S]


def artwork(k, mono=False):
    """Transparent RGBA layer with ring + bolt, scaled by k around the centre."""
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    width = int(RING_W * k * S)
    box = ring_box(k)
    lit = (255, 255, 255, 255) if mono else AMBER + (255,)
    # Track and lit arc of the gauge.
    d.arc(box, ARC_FROM, ARC_FROM + ARC_SWEEP, fill=(255, 255, 255, 110 if mono else 70), width=width)
    d.arc(box, ARC_FROM, ARC_FROM + ARC_SWEEP * ARC_FILL, fill=lit, width=width)
    # Round caps on the lit arc.
    cx, cy = RING_C[0] * S, RING_C[1] * S
    r = (RING_R * k) * S - width / 2
    for ang in (ARC_FROM, ARC_FROM + ARC_SWEEP * ARC_FILL):
        a = math.radians(ang)
        px, py = cx + r * math.cos(a), cy + r * math.sin(a)
        d.ellipse([px - width / 2, py - width / 2, px + width / 2, py + width / 2], fill=lit)
    # Bolt: gradient fill through a polygon mask.
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).polygon(scaled(BOLT, k * BOLT_K), fill=255)
    if mono:
        fill = Image.new("RGBA", (N, N), (255, 255, 255, 255))
    else:
        fill = vertical_gradient((N, N), EMERALD, SKY).convert("RGBA")
        # Soft glow under the bolt.
        glow = Image.new("RGBA", (N, N), EMERALD + (0,))
        glow.putalpha(mask.filter(ImageFilter.GaussianBlur(28 * S)).point(lambda v: int(v * 0.55)))
        layer = Image.alpha_composite(layer, glow)
    layer.paste(fill, (0, 0), mask)
    return layer


def background():
    bg = vertical_gradient((N, N), BG_TOP, BG_BOTTOM).convert("RGBA")
    # Gentle light from the top-left.
    light = Image.new("L", (N, N), 0)
    ImageDraw.Draw(light).ellipse([-N * 0.3, -N * 0.4, N * 0.9, N * 0.7], fill=22)
    light = light.filter(ImageFilter.GaussianBlur(120 * S))
    white = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    white.putalpha(light)
    return Image.alpha_composite(bg, white)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    img.resize((1024, 1024), Image.LANCZOS).save(path)
    print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    full = Image.alpha_composite(background(), artwork(1.0))
    save(full.convert("RGB"), "icon.png")  # iOS wants no alpha
    # Adaptive icons show the middle ~61% (66 of 108 dp): artwork must fit that circle.
    save(background().convert("RGB"), "icon_background.png")
    save(artwork(0.9), "icon_foreground.png")
    save(artwork(0.9, mono=True), "icon_monochrome.png")
