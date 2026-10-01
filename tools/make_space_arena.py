"""Builds the world-4 survival arena (ORBITAL PLATFORM: an open-air deck floating in space).

Usage: python tools/make_space_arena.py [seed]
Uses the loose pieces in assets/ui/world/world_4/ (image_NNN.png: floor plates, vents,
wall blocks, railings, trusses, crates, consoles, lamps, dishes, antennas, solar panels,
planets, a space station and lots of asteroids). Writes to assets/arena/:
  arena_space_deck.webp  the platform alone, transparent around it: clean floor plates,
                         machinery and railings round the
                         edge, props on the rim, bridges running out into space, the
                         hull under the front edge
  arena_space_sky.webp   what is behind it: deep space, nebulae, a galaxy, stars,
                         planets and far stations (drawn bigger than the deck so it can
                         drift with parallax, see scripts/fx/space_backdrop.gd)
  arena_space.json       deck size, walkable floor rect (art px), beacons (blinking
                         lights, art px) and the sky's padding
The deck is drawn at Room.ART_ARENAS["space"].scale; everything alive (asteroids, UFOs,
comets, twinkles) is animated in code by SpaceBackdrop.
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.join(HERE, "..", "assets", "ui", "world", "world_4")
OUT_DIR = os.path.join(HERE, "..", "assets", "arena")

T = 64  # floor plate, art px
COLS, ROWS = 26, 34  # walkable floor in plates (832 x 1088 world units at scale 0.5)
RIM = 2  # plates of deck round the walkable floor (props stand there)
SPACE = 380  # empty space round the deck, art px
K = 0.88  # kit pieces are drawn at ~73 px per plate
SKY_PAD = 220  # extra sky on every side (parallax room)

DX0 = SPACE  # deck plates start here
DY0 = SPACE
DW, DH = (COLS + 2 * RIM) * T, (ROWS + 2 * RIM) * T
FX0, FY0 = DX0 + RIM * T, DY0 + RIM * T  # walkable floor
FX1, FY1 = FX0 + COLS * T, FY0 + ROWS * T
W, H = DW + 2 * SPACE, DH + 2 * SPACE

PLAIN = [16, 17, 22, 33, 34, 90, 91, 95, 107, 108, 120, 16, 17, 22]
RIVET = [23, 47]
VENTS = [20, 26, 43, 96, 89]
ASTEROIDS_S = [8, 10, 12, 15, 19, 21, 28, 29, 31, 32, 39, 45, 49, 52, 62, 63, 64, 68, 72, 75, 83, 134, 142, 143, 145, 146, 147]
ASTEROIDS_M = [9, 14, 25, 36, 37, 40, 41, 44, 53, 54, 61, 65, 73, 76, 144]
ASTEROIDS_L = [27, 50, 51, 35, 136, 137]

_cache = {}


def piece(n, s=K, flip=False, rot=0):
    key = (n, s, flip, rot)
    if key not in _cache:
        img = Image.open(os.path.join(KIT, "image_%03d.png" % n)).convert("RGBA")
        img = img.crop(img.getbbox())
        if rot:
            img = img.rotate(rot, expand=True, resample=Image.BICUBIC)
        img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
        if flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        _cache[key] = img
    return _cache[key]


def put(c, n, x, y, anchor="tl", s=K, flip=False, rot=0, bright=1.0):
    img = piece(n, s, flip, rot)
    if bright != 1.0:
        img = ImageEnhance.Brightness(img).enhance(bright)
    ax = {"l": 0, "c": img.width // 2, "r": img.width}[anchor[1]]
    ay = {"t": 0, "m": img.height // 2, "b": img.height}[anchor[0]]
    c.alpha_composite(img, (int(x - ax), int(y - ay)))
    return img.size


PLATE_LUMA = 88.0  # every plain plate is evened out to this brightness (no checkerboard)


def plate(n, size=T, inset=4, even=True):
    key = ("plate", n, size, even)
    if key not in _cache:
        img = piece(n, 1.0)
        img = img.crop((inset, inset, img.width - inset, img.height - inset)).resize((size, size), Image.LANCZOS)
        if even:
            a = np.asarray(img).astype(np.float32)
            luma = (a[..., :3] * (0.3, 0.59, 0.11)).sum(axis=2)[a[..., 3] > 128].mean()
            a[..., :3] *= PLATE_LUMA / luma
            img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
        _cache[key] = img
    return _cache[key]


# ------------------------------------------------------------------ sky

def sky(rng):
    w, h = W + 2 * SKY_PAD, H + 2 * SKY_PAD
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    a = np.zeros((h, w, 3), np.float32)
    a[:] = (6, 7, 22)
    a += (np.clip(yy / h, 0, 1)[..., None]) * np.array([10, 6, 24], np.float32)
    # nebulae: blurred noise tinted violet / blue / magenta
    small = np.random.default_rng(rng.randint(0, 10**6))
    def noise(sc):
        n = small.random((h // sc + 2, w // sc + 2)).astype(np.float32)
        n = Image.fromarray((n * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        return np.asarray(n.filter(ImageFilter.GaussianBlur(sc * 0.6))).astype(np.float32) / 255

    for col, k, scs in [((90, 40, 170), 0.55, (420, 160, 60)), ((30, 70, 170), 0.45, (520, 200, 80)), ((170, 40, 140), 0.3, (360, 120, 50))]:
        n = noise(scs[0]) * 0.6 + noise(scs[1]) * 0.3 + noise(scs[2]) * 0.1
        n = np.clip((n - 0.47) * 4.0, 0, 1) ** 1.8
        a += n[..., None] * np.array(col, np.float32) * k
    # a spiral galaxy in the top right
    gx, gy = w * 0.8, h * 0.1
    dx, dy = (xx - gx) / 1.0, (yy - gy) / 0.55
    r = np.sqrt(dx * dx + dy * dy) + 1e-3
    th = np.arctan2(dy, dx)
    arm = (np.cos(2 * th - r / 38.0) * 0.5 + 0.5) ** 3
    g = np.exp(-r / 150.0) * (0.35 + 0.65 * arm) + np.exp(-r / 22.0) * 1.2
    a += g[..., None] * np.array([170, 110, 240], np.float32)
    # stars
    for _ in range(int(w * h / 900)):
        x, y = rng.randrange(w), rng.randrange(h)
        b = rng.uniform(60, 200)
        a[y, x] = np.maximum(a[y, x], (b, b, min(255, b + 50)))
    for _ in range(int(w * h / 26000)):
        x, y = rng.randrange(2, w - 2), rng.randrange(2, h - 2)
        b = rng.uniform(170, 255)
        a[y, x] = (b, b, 255)
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a[y + d[1], x + d[0]] = np.maximum(a[y + d[1], x + d[0]], (b * 0.55, b * 0.55, b * 0.7))
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    # planets and far stations (dimmed a little: they are far away)
    far = lambda n, x, y, s, b=0.8, flip=False: put(img, n, x, y, "mc", s, flip, bright=b)
    far(7, SKY_PAD + 90, SKY_PAD + H * 0.2, 2.6, 0.85)  # big blue planet, half off the left edge
    far(6, W + SKY_PAD - 150, SKY_PAD + H * 0.62, 1.6, 0.8)  # violet planet on the right
    far(7, SKY_PAD + W * 0.2, H + SKY_PAD - 40, 3.2, 0.7)  # a huge one rising at the bottom left
    far(5, W + SKY_PAD - 170, SKY_PAD + 260, 0.95, 0.75)
    far(5, SKY_PAD + 150, SKY_PAD + H * 0.55, 0.7, 0.6, True)
    far(5, W + SKY_PAD - 120, H + SKY_PAD - 120, 0.8, 0.65)
    # far asteroid dust
    for _ in range(90):
        n = rng.choice(ASTEROIDS_S)
        put(img, n, rng.randrange(w), rng.randrange(h), "mc", rng.uniform(0.35, 0.7), bright=rng.uniform(0.35, 0.6))
    return img.convert("RGB")


# ------------------------------------------------------------------ deck

def hull(c):
    """The platform's underside below the front edge, and its dark sides."""
    front = ImageEnhance.Brightness(plate(47, even=False)).enhance(0.62)
    under = ImageEnhance.Brightness(plate(96, even=False)).enhance(0.45)
    for x in range(DX0 - 20, DX0 + DW + 20, T):
        c.alpha_composite(front, (x, DY0 + DH))
        c.alpha_composite(under if (x // T) % 5 == 2 else ImageEnhance.Brightness(front).enhance(0.7), (x, DY0 + DH + T - 20))
    # a band of yellow running lights along the hull
    for x in range(DX0 + 40, DX0 + DW - 40, 150):
        put(c, 55 if (x // 150) % 2 else 57, x, DY0 + DH + 56, "mc", 0.8)


def deck_floor(c, rng):
    for r in range(ROWS + 2 * RIM):
        for q in range(COLS + 2 * RIM):
            k = rng.random()
            n = rng.choice(PLAIN)
            if k < 0.018:
                n = rng.choice(VENTS)
            elif k < 0.05:
                n = rng.choice(RIVET)
            elif k < 0.06:
                n = 98  # cracked
            img = plate(n, even=n in PLAIN or n in RIVET)
            if not (RIM <= q < COLS + RIM and RIM <= r < ROWS + RIM):
                img = ImageEnhance.Brightness(img).enhance(0.72)  # the rim: a lower ledge
            c.alpha_composite(img, (DX0 + q * T, DY0 + r * T))
    # scuffs: darker blotches and a few burn marks
    a = np.asarray(c).astype(np.float32)
    sm = np.random.default_rng(rng.randint(0, 10**6))
    n = sm.random((DH // 40 + 2, DW // 40 + 2)).astype(np.float32)
    n = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((DW, DH), Image.BICUBIC)).astype(np.float32) / 255
    dirt = 1.0 - 0.1 * np.clip((n - 0.5) * 3, 0, 1)
    a[DY0 : DY0 + DH, DX0 : DX0 + DW, :3] *= dirt[..., None]
    return Image.fromarray(a.astype(np.uint8))


def border(c):
    """Hazard stripes round the walkable floor: where the ledge with the props begins."""
    b = 10
    a = np.asarray(c).copy()
    yy, xx = np.mgrid[0:H, 0:W]
    outer = (xx >= FX0 - b) & (xx < FX1 + b) & (yy >= FY0 - b) & (yy < FY1 + b)
    inner = (xx >= FX0) & (xx < FX1) & (yy >= FY0) & (yy < FY1)
    band = outer & ~inner
    stripe = ((xx + yy) // 12) % 2 == 0
    a[band & stripe, :3] = (232, 176, 40)
    a[band & ~stripe, :3] = (34, 32, 40)
    edge = outer & ~((xx >= FX0 - b + 2) & (xx < FX1 + b - 2) & (yy >= FY0 - b + 2) & (yy < FY1 + b - 2))
    a[edge | (inner & ~((xx >= FX0 + 2) & (xx < FX1 - 2) & (yy >= FY0 + 2) & (yy < FY1 - 2))), :3] = (16, 16, 22)
    return Image.fromarray(a)


def rim_props(c, rng):
    """Crates, consoles, lamps and machines standing on the rim, against the edge."""
    big = [87, 100, 104, 110, 135, 78, 74, 88, 118]
    small = [93, 94, 101, 92, 66, 86, 105, 113, 119, 99, 114, 55, 56, 57, 117]
    lamps = [85, 102, 103]
    # top rim: stands at the back, bottoms on the walkable floor's top edge
    x = DX0 + 150
    while x < DX0 + DW - 150:
        if abs(x - (DX0 + DW // 2)) < 190:
            x = DX0 + DW // 2 + 190
            continue
        n = rng.choice(lamps) if rng.random() < 0.18 else rng.choice(big + small)
        w, _ = put(c, n, x, FY0 - 6, "bl", K * rng.uniform(0.9, 1.05))
        x += w + rng.randint(6, 40)
    # side rims: clusters every few plates
    for side in (0, 1):
        y = FY0 + 60
        while y < FY1 - 40:
            n = rng.choice(big + small + lamps)
            img = piece(n, K * 0.95, side == 1)
            x = FX0 - 8 - img.width if side == 0 else FX1 + 8
            if img.width > RIM * T - 10:
                x = DX0 + 6 if side == 0 else DX0 + DW - 6 - img.width
            c.alpha_composite(img, (x, y))
            y += img.height + rng.randint(30, 140)
    # bottom rim: low stuff only, so the front edge stays open
    x = DX0 + 110
    while x < DX0 + DW - 110:
        if abs(x - (DX0 + DW // 2)) < 190:
            x = DX0 + DW // 2 + 190
            continue
        n = rng.choice([55, 56, 57, 111, 115, 117, 99, 114, 113])
        w, _ = put(c, n, x, FY1 + 8, "tl", K * 0.9)
        x += w + rng.randint(40, 130)


def edges(c, rng, beacons):
    """Machinery round the deck edge: walls and railings on top, pillars down the
    sides with bridges out into space, a railing on the open front edge."""
    top = DY0 + 18
    # top edge: walls with gaps of railing, a gate in the middle
    gate = piece(106, 1.0)
    gx = DX0 + DW // 2 - gate.width // 2
    x = DX0 - 10
    while x < DX0 + DW + 10:
        if gx - 10 < x < gx + gate.width:
            x = gx + gate.width
            continue
        n = rng.choice([3, 2, 69, 70, 131, 3, 2, 80])
        img = piece(n)
        if x < gx and x + img.width > gx + 8:
            img = img.crop((0, 0, gx + 8 - x, img.height))
        c.alpha_composite(img, (x, top - img.height + 20))
        x += img.width - 8
    c.alpha_composite(gate, (gx, top - gate.height + 40))
    beacons += [(gx + 26, top - gate.height + 58), (gx + gate.width - 26, top - gate.height + 58)]
    # sides: vertical pieces stacked on the edge; two bridges per side
    bridges = [DY0 + int(DH * 0.3), DY0 + int(DH * 0.68)]
    for side in (0, 1):
        ex = DX0 if side == 0 else DX0 + DW
        for by in bridges:  # trusses running out to the edge of the art
            tr = piece(131, K, side == 1)
            x = ex - tr.width + 10 if side == 0 else ex - 10
            while (side == 0 and x + tr.width > -tr.width) or (side == 1 and x < W + tr.width):
                c.alpha_composite(tr, (x, by - tr.height // 2))
                x += -tr.width + 14 if side == 0 else tr.width - 14
        y = DY0 - 10
        while y < DY0 + DH - 20:
            if any(abs(y + 60 - by) < 70 for by in bridges):
                n = 112  # the bridge's end cap
                img = piece(n, K, side == 1)
            else:
                n = rng.choice([38, 128, 59, 24, 38, 48])
                img = piece(n, K * 1.05, side == 1)
            x = ex - img.width // 2
            c.alpha_composite(img, (x, y))
            if n in (24, 38):
                beacons.append((x + img.width // 2, y + img.height // 2))
            y += img.height - 10
    # front edge: open railings, the ramp gate in the middle
    ramp = piece(130, 1.0)
    rx = DX0 + DW // 2 - ramp.width // 2
    x = DX0 - 10
    while x < DX0 + DW + 10:
        if rx - 10 < x < rx + ramp.width:
            x = rx + ramp.width
            continue
        n = rng.choice([79, 80, 81, 82, 69, 70])
        img = piece(n)
        c.alpha_composite(img, (x, DY0 + DH - img.height + 30))
        x += img.width - 8
    c.alpha_composite(ramp, (rx, DY0 + DH - ramp.height + 70))
    # corners: towers, dishes and antennas with blinking tips
    for cx, cy, fl in [(DX0, DY0, False), (DX0 + DW, DY0, True), (DX0, DY0 + DH, False), (DX0 + DW, DY0 + DH, True)]:
        put(c, 60, cx, cy + 30, "bc", K * 1.25, fl)
        if cy == DY0:
            w, h = put(c, 58, cx + (-40 if not fl else 40), cy + 10, "bc", K * 1.1)
            beacons.append((cx + (-40 if not fl else 40), cy + 10 - h + 12))
            put(c, 71, cx + (70 if not fl else -70), cy + 20, "bc", K, fl)
        else:
            put(c, 84, cx + (-10 if not fl else 10), cy + 20, "bc", K, fl)
            w, h = put(c, 58, cx + (60 if not fl else -60), cy + 30, "bc", K * 0.9)
            beacons.append((cx + (60 if not fl else -60), cy + 30 - h + 11))
    # solar wings hanging off the sides, between the bridges
    for side in (0, 1):
        for yk in (0.12, 0.5, 0.86):
            n = rng.choice([124, 125, 127, 138, 139])
            img = piece(n, K * 1.1, side == 1)
            x = DX0 - img.width - 26 if side == 0 else DX0 + DW + 26
            c.alpha_composite(img, (x, DY0 + int(DH * yk) - img.height // 2))


def shadow(c):
    """Soft drop shadow of the deck on the space below (sells the floating)."""
    a = np.asarray(c)[:, :, 3].astype(np.float32)
    sh = Image.fromarray(a.astype(np.uint8)).filter(ImageFilter.GaussianBlur(26))
    sh = np.asarray(sh).astype(np.float32) * 0.55
    out = np.zeros((H, W, 4), np.uint8)
    out[..., 3] = np.roll(np.roll(sh, 30, axis=0), 12, axis=1).astype(np.uint8)
    base = Image.fromarray(out)
    base.alpha_composite(c)
    return base


def lighting(c):
    a = np.asarray(c).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # the walkable floor gets a soft blue-white key light from the middle
    cx, cy = (FX0 + FX1) / 2, (FY0 + FY1) / 2
    d = np.sqrt(((xx - cx) / (FX1 - FX0)) ** 2 + ((yy - cy) / (FY1 - FY0)) ** 2)
    k = 1.05 - 0.3 * np.clip(d - 0.2, 0, 1)
    a[..., :3] *= k[..., None]
    a[..., 2] *= 1.04  # a touch of space-blue
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def main(seed):
    rng = random.Random(seed)
    deck = Image.new("RGBA", (W, H))
    beacons = []
    hull(deck)
    deck = border(deck_floor(deck, rng))
    rim_props(deck, rng)
    edges(deck, rng, beacons)
    deck = lighting(shadow(deck))
    os.makedirs(OUT_DIR, exist_ok=True)
    deck.save(os.path.join(OUT_DIR, "arena_space_deck.webp"), quality=90, method=6)
    sky_img = sky(rng)
    sky_img.resize((sky_img.width // 2, sky_img.height // 2), Image.LANCZOS).save(
        os.path.join(OUT_DIR, "arena_space_sky.webp"), quality=88, method=6)
    info = {"size": [W, H], "floor": [FX0, FY0, FX1, FY1], "deck": [DX0, DY0, DX0 + DW, DY0 + DH],
            "sky_pad": SKY_PAD, "beacons": [[int(x), int(y)] for x, y in beacons]}
    with open(os.path.join(OUT_DIR, "arena_space.json"), "w") as f:
        json.dump(info, f, indent=1)
    print("deck", deck.size, "floor", info["floor"], "beacons", len(beacons))


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 5)
