"""Builds the world-3 survival arena (THE VOID: an infested alien lab) from its tile kit.

Usage: python tools/make_void_arena.py [seed]
Reads the loose pieces in assets/ui/world/world3_elements/ (image_NNN.png = floor tiles,
wall blocks, pipes, goo and biomass; image_NNN(1).png = specimen tanks, consoles, vents,
lab pipes and more biomass) and lays out the whole walled room:
  floor   COLS x ROWS tiles of T px (plain panels, cracked ones, vents, a hazard emblem
          in the middle; slime and alien biomass creep in from the walls and corners)
  walls   a row of wall blocks along the top with the lab door in the middle, pillar
          columns down both sides, a low wall at the bottom, corner pieces
  props   tanks, consoles and pipes behind the walls, biomass heaps in the corners,
          goo drips hanging off the top wall, splats on the floor
  light   soft shadow where the floor meets the walls, green / magenta glows, vignette
Everything is picked with a fixed seed, so the arena only changes when this is re-run
with another one. Writes assets/arena/arena_void_bg.webp and arena_void.json (art size
and the walkable floor rectangle in art px; Room.build_arena maps it to world units).
"""
import json
import os
import random
import sys

import numpy as np
from PIL import Image, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.join(HERE, "..", "assets", "ui", "world", "world3_elements")
OUT_DIR = os.path.join(HERE, "..", "assets", "arena")

T = 64  # floor tile, art px
COLS, ROWS = 26, 34
BAND_L, BAND_R, BAND_T, BAND_B = 136, 136, 260, 112  # wall bands around the floor
K = 0.45  # the kit is drawn at ~140 px per tile: scale pieces to match T
WK = 0.68  # wall pieces are drawn chunkier
FLOOR_X0, FLOOR_Y0 = BAND_L, BAND_T
FLOOR_X1, FLOOR_Y1 = BAND_L + COLS * T, BAND_T + ROWS * T
W, H = FLOOR_X1 + BAND_R, FLOOR_Y1 + BAND_B

PLAIN = [1] * 14 + [2, 3, 3]
GOO_TILES = [4, 13]
INFESTED = [5, 6, 14]
H_WALL = [16, 20, 23, 24, 19, 31, 33, 16, 20]  # top wall blocks
V_WALL = [65, 68, 63, 70, 65, 68]  # side wall columns (left wall; flipped on the right)
B_WALL = [66, 75, 77, 66, 36, 37]  # low wall along the bottom
TANKS = ["2(1)", "3(1)", "4(1)", "5(1)", "6(1)", "9(1)", "21(1)"]
CONSOLES = ["12(1)", "15(1)", "22(1)", "13(1)", "28(1)", "30(1)"]
SIDE_PROPS = ["7(1)", "11(1)", "39(1)", "20(1)", "14(1)", "8(1)", "3(1)", "5(1)"]
BIOMASS = [95, 89, 52, 85, 50, "59(1)", "66(1)", 39, 43]
DRIPS = [84, 98, 100, 93]
PURPLE_SPLATS = [56, 58, 82, 86, 92, 94, 96, 97, 99, 101]
GREEN_SPLATS = [48, 53, 54, 55, 57, 59, 60, 80, 93, 102, "75(1)", "76(1)", "77(1)"]
EGGS = [90, 87, 104, "64(1)", "70(1)", 103, 83]

_cache = {}


def piece(name, s=K, flip=False):
    """A kit piece trimmed and scaled: ints are image_NNN.png, "N(1)" image_NNN(1).png."""
    key = (name, s, flip)
    if key not in _cache:
        if isinstance(name, int):
            fn = "image_%03d.png" % name
        else:
            fn = "image_%03d(1).png" % int(str(name)[:-3])
        img = Image.open(os.path.join(KIT, fn)).convert("RGBA")
        img = img.crop(img.getbbox())
        img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
        if flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        _cache[key] = img
    return _cache[key]


def put(canvas, name, x, y, anchor="tl", s=K, flip=False, alpha=1.0):
    """Pastes a piece; anchor = vertical (t/m/b) + horizontal (l/c/r)."""
    img = piece(name, s, flip)
    if alpha < 1.0:
        img = img.copy()
        img.putalpha(img.getchannel("A").point(lambda v: int(v * alpha)))
    ax = {"l": 0, "c": img.width // 2, "r": img.width}[anchor[1]]
    ay = {"t": 0, "m": img.height // 2, "b": img.height}[anchor[0]]
    canvas.alpha_composite(img, (int(x - ax), int(y - ay)))
    return img.size


INSET = 5  # source px of the tiles' thick black outline, cut off so the floor reads as one surface


def tile(name, size=T):
    img = piece(name, 1.0)
    img = img.crop((INSET, INSET, img.width - INSET, img.height - INSET))
    return img.resize((size, size), Image.LANCZOS)


def edge_dist(c, r):
    """Tiles from the nearest wall, and from the nearest corner."""
    d = min(c, r, COLS - 1 - c, ROWS - 1 - r)
    corner = min(np.hypot(c - cx, r - cy) for cx in (0, COLS - 1) for cy in (0, ROWS - 1))
    return d, corner


def floor(canvas, rng):
    for r in range(ROWS):
        for c in range(COLS):
            d, corner = edge_dist(c, r)
            p_inf = 0.55 if corner < 1.5 else 0.2 if corner < 3.0 else 0.0
            p_goo = 0.18 if d == 0 else 0.05 if d == 1 else 0.01
            k = rng.random()
            if k < p_inf:
                name = rng.choice(INFESTED)
            elif k < p_inf + p_goo:
                name = rng.choice(GOO_TILES)
            elif rng.random() < 0.03:
                name = rng.choice([15, 9, 8, 10])
            else:
                name = rng.choice(PLAIN)
            px, py = FLOOR_X0 + c * T, FLOOR_Y0 + r * T
            if name in (8, 9):  # narrow vent tiles sit on a plain panel
                canvas.alpha_composite(tile(1), (px, py))
                v = piece(name, T / 142.0)
                canvas.alpha_composite(v, (px + (T - v.width) // 2, py + (T - v.height) // 2))
            else:
                canvas.alpha_composite(tile(name), (px, py))
    # the hazard emblem in the middle (2x2 tiles)
    em = tile(12, 2 * T)
    canvas.alpha_composite(em, (FLOOR_X0 + (COLS // 2 - 1) * T, FLOOR_Y0 + (ROWS // 2 - 1) * T))
    # hazard stripes in front of the door
    for c in range(COLS // 2 - 1, COLS // 2 + 1):
        canvas.alpha_composite(tile(11), (FLOOR_X0 + c * T, FLOOR_Y0))


def walls_back(canvas, rng):
    """Everything behind the wall blocks: dark bulkhead, pipes, tanks and consoles."""
    dark = ImageEnhance.Brightness(tile(1)).enhance(0.34)
    for y in range(0, H, T):
        for x in range(0, W, T):
            if not (FLOOR_X0 <= x < FLOOR_X1 and FLOOR_Y0 <= y < FLOOR_Y1):
                canvas.alpha_composite(dark, (x, y))
    # pipes running along the top
    x = -10
    while x < W:
        w, _ = put(canvas, rng.choice([37, 36, 77, 75, "40(1)", "57(1)"]), x, 8, "tl", 0.62)
        x += w - 8
    # tanks and consoles standing behind the top wall (not behind the door)
    door_l, door_r = W // 2 - 170, W // 2 + 170
    x = 10
    while x < W - 30:
        name = rng.choice(TANKS if rng.random() < 0.6 else CONSOLES)
        img = piece(name, rng.uniform(0.62, 0.72))
        if x + img.width > door_l and x < door_r:
            x = door_r
            continue
        canvas.alpha_composite(img, (x, FLOOR_Y0 - 58 - img.height))
        x += img.width + rng.randint(-6, 14)
    # the side bands: vertical pipes and small tanks behind the pillars
    for side in (0, 1):
        y = FLOOR_Y0 - 40
        while y < FLOOR_Y1 + 20:
            name = rng.choice(SIDE_PROPS + [42, 41, "49(1)", "43(1)", "53(1)", "45(1)"])
            img = piece(name, 0.62, side == 1)
            band = BAND_L - 50
            x = max(4, (band - img.width) // 2) if side == 0 else W - max(4, (band - img.width) // 2) - img.width
            canvas.alpha_composite(img, (x, y))
            y += img.height + rng.randint(4, 30)


def walls_front(canvas, rng):
    # top wall: chunky blocks sitting on the floor's top edge, the door in the middle
    door = piece(64, 0.74)
    dx = W // 2 - door.width // 2
    x = -20
    while x < W:
        if dx - 4 < x < dx + door.width:
            x = dx + door.width - 4
            if x < dx + door.width:
                x = dx + door.width
            continue
        img = piece(rng.choice(H_WALL), WK)
        if x < dx and x + img.width > dx + 8:
            img = img.crop((0, 0, dx + 8 - x, img.height))
        canvas.alpha_composite(img, (x, FLOOR_Y0 + 10 - img.height))
        x += img.width - 4
    canvas.alpha_composite(door, (dx, FLOOR_Y0 + 14 - door.height))
    # side walls: pillar columns stacked from the top wall down to the bottom
    for side in (0, 1):
        y = FLOOR_Y0 - 40
        while y < FLOOR_Y1 + 10:
            img = piece(rng.choice(V_WALL), WK, side == 1)
            x = FLOOR_X0 + 12 - img.width if side == 0 else FLOOR_X1 - 12
            canvas.alpha_composite(img, (x, y))
            y += img.height - 10
    # bottom wall
    x = -20
    while x < W:
        img = piece(rng.choice(B_WALL), WK)
        canvas.alpha_composite(img, (x, FLOOR_Y1 - 14))
        x += img.width - 4
    # corners
    put(canvas, 21, FLOOR_X0 + 26, FLOOR_Y0 + 12, "br", WK)
    put(canvas, 21, FLOOR_X1 - 26, FLOOR_Y0 + 12, "bl", WK, True)
    put(canvas, 29, FLOOR_X0 + 22, FLOOR_Y1 + 50, "br", WK)
    put(canvas, 29, FLOOR_X1 - 22, FLOOR_Y1 + 50, "bl", WK, True)


def infestation(canvas, rng):
    # biomass heaps in the corners, spilling a little onto the floor
    for cx in (FLOOR_X0, FLOOR_X1):
        for cy in (FLOOR_Y0, FLOOR_Y1):
            sx = 1 if cx == FLOOR_X0 else -1
            sy = 1 if cy == FLOOR_Y0 else -1
            for _ in range(5):
                x = cx + sx * rng.randint(-20, 90)
                y = cy + sy * rng.randint(-10, 110)
                put(canvas, rng.choice(BIOMASS), x, y, "mc", rng.uniform(0.45, 0.6), rng.random() < 0.5)
    # a few heaps along the side walls
    for side in (0, 1):
        for _ in range(3):
            y = rng.randint(FLOOR_Y0 + 300, FLOOR_Y1 - 300)
            x = FLOOR_X0 + rng.randint(-10, 14) if side == 0 else FLOOR_X1 - rng.randint(-10, 14)
            put(canvas, rng.choice([52, 85, 89, 50, "62(1)", "68(1)"]), x, y, "mc", 0.45, side == 1)
    # goo drips hanging off the top wall
    x = FLOOR_X0 + 20
    while x < FLOOR_X1 - 60:
        if abs(x - W // 2) > 140 and rng.random() < 0.45:
            put(canvas, rng.choice(DRIPS), x, FLOOR_Y0 - 4, "tc", rng.uniform(0.4, 0.55))
        x += rng.randint(60, 140)


def splats(canvas, rng):
    for _ in range(80):
        c, r = rng.uniform(0, COLS), rng.uniform(0, ROWS)
        d, _ = edge_dist(int(c), int(r))
        if d > 4 and rng.random() < 0.6:
            continue  # most of the mess sits near the walls
        name = rng.choice(PURPLE_SPLATS if rng.random() < 0.55 else GREEN_SPLATS)
        put(canvas, name, FLOOR_X0 + c * T, FLOOR_Y0 + r * T, "mc", rng.uniform(0.4, 0.6), rng.random() < 0.5, 0.9)
    for _ in range(7):  # eggs near the walls
        side = rng.choice("lrb")
        if side == "l":
            x, y = FLOOR_X0 + rng.randint(20, 60), rng.randint(FLOOR_Y0 + 200, FLOOR_Y1 - 200)
        elif side == "r":
            x, y = FLOOR_X1 - rng.randint(20, 60), rng.randint(FLOOR_Y0 + 200, FLOOR_Y1 - 200)
        else:
            x, y = rng.randint(FLOOR_X0 + 100, FLOOR_X1 - 100), FLOOR_Y1 - rng.randint(16, 40)
        put(canvas, rng.choice(EGGS), x, y, "bc", 0.42)


def lighting(canvas):
    a = np.asarray(canvas).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # contact shadow where the floor meets the walls
    dx = np.minimum(xx - FLOOR_X0, FLOOR_X1 - xx)
    dy = np.minimum(yy - FLOOR_Y0, FLOOR_Y1 - yy)
    d = np.clip(np.minimum(dx, dy), 0, None)
    shade = np.where((dx > 0) & (dy > 0), 1.0 - 0.35 * np.exp(-d / 26.0), 1.0)
    # vignette
    nx, ny = (xx / W - 0.5) * 2, (yy / H - 0.5) * 2
    shade *= 1.0 - 0.28 * np.clip(nx * nx + ny * ny - 0.35, 0, 1)
    a[..., :3] *= shade[..., None]

    def glow(cx, cy, rad, col, k):
        g = np.exp(-((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * rad * rad)) * k
        a[..., :3] += g[..., None] * np.array(col, np.float32)

    glow(W / 2, FLOOR_Y0 + 20, 120, (60, 255, 90), 0.22)  # the door
    for cx in (FLOOR_X0, FLOOR_X1):
        for cy in (FLOOR_Y0, FLOOR_Y1):
            glow(cx, cy, 150, (220, 40, 200), 0.16)  # biomass in the corners
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def main(seed):
    rng = random.Random(seed)
    canvas = Image.new("RGBA", (W, H), (14, 16, 28, 255))
    walls_back(canvas, rng)
    floor(canvas, rng)
    splats(canvas, rng)
    walls_front(canvas, rng)
    infestation(canvas, rng)
    img = lighting(canvas).convert("RGB")
    os.makedirs(OUT_DIR, exist_ok=True)
    img.save(os.path.join(OUT_DIR, "arena_void_bg.webp"), quality=92, method=6)
    floor_rect = [FLOOR_X0, FLOOR_Y0, FLOOR_X1, FLOOR_Y1]
    with open(os.path.join(OUT_DIR, "arena_void.json"), "w") as f:
        json.dump({"size": [W, H], "floor": floor_rect, "door_x": W // 2}, f, indent=1)
    print("arena", img.size, "floor", floor_rect)


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 3)
