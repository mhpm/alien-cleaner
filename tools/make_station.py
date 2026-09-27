"""Builds a space station level from its painted art.

Usage: python tools/make_station.py station01 [overlay.png]

tools/<id>_ref.webp  ->  assets/stations/<id>.webp        painted map (drawn as is)
                         assets/stations/<id>_walk.png    walk grid, 1 px per CELL x CELL
                                                          art px (white = floor)
The floor of these maps is a uniform grey-blue plate; a cell is walkable when most of
its pixels have that colour and little texture. Crates, barrels, walls, pipes and space
all fail the test, so they block. FIX lists hand corrections (art px rects): "walk" for
floor decals the detector misses (vents, slime, emblems), "block" for anything else.
Pass an overlay path to get a preview (red = blocked) for checking the grid.
The level data (sectors, start, exit) lives in scripts/data/station_data.gd.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "stations")
CELL = 16  # art px per walk cell (keep in sync with StationData)

FLOOR = np.array([66, 79, 108])

FIX = {
    "station01": [
        # floor vents / grates the colour test rejects
        ("walk", (365, 180, 410, 220)), ("walk", (480, 295, 530, 335)), ("walk", (425, 400, 470, 445)),
        ("walk", (480, 510, 530, 550)), ("walk", (340, 710, 385, 755)), ("walk", (480, 695, 530, 745)),
        ("walk", (465, 1005, 530, 1055)), ("walk", (480, 1270, 530, 1315)), ("walk", (690, 820, 735, 865)),
        ("walk", (330, 255, 370, 300)), ("walk", (190, 365, 235, 405)), ("walk", (195, 1230, 235, 1270)),
        ("walk", (765, 1370, 805, 1415)),
        # planet emblems painted on the floor
        ("walk", (150, 270, 270, 345)), ("walk", (450, 765, 550, 840)),
        # ramp joining the upper and lower spine, arrival landing
        ("walk", (455, 550, 580, 640)), ("walk", (455, 1395, 560, 1440)),
        # grated bridge from the plaza to the hangar
        ("walk", (700, 752, 850, 800)),
    ],
}


def classify(a):
    h, w = a.shape[:2]
    gh, gw = h // CELL, w // CELL
    grid = np.zeros((gh, gw), bool)
    for gy in range(gh):
        for gx in range(gw):
            c = a[gy * CELL:(gy + 1) * CELL, gx * CELL:(gx + 1) * CELL].reshape(-1, 3)
            d = np.abs(c - FLOOR).sum(axis=1)
            frac = (d < 70).mean()
            grid[gy, gx] = frac > 0.55
    return grid


def clean(grid):
    """Close single-cell holes (grid lines, small decals) and drop floor specks."""
    g = grid.copy()
    for _ in range(2):
        n = np.zeros_like(g, int)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy or dx:
                    n += np.roll(np.roll(g, dy, 0), dx, 1)
        g = np.where(~g & (n >= 6), True, g)
        g = np.where(g & (n <= 1), False, g)
    return g


def main():
    sid = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(os.path.join(HERE, f"{sid}_ref.webp")).convert("RGB")
    a = np.asarray(src).astype(int)
    grid = clean(classify(a))
    for mode, (x0, y0, x1, y1) in FIX.get(sid, []):
        grid[y0 // CELL:(y1 + CELL - 1) // CELL, x0 // CELL:(x1 + CELL - 1) // CELL] = mode == "walk"
    # map edges are always solid
    grid[0, :] = grid[-1, :] = False
    grid[:, 0] = grid[:, -1] = False
    src.save(os.path.join(OUT, f"{sid}.webp"), quality=92)
    Image.fromarray((grid * 255).astype(np.uint8), "L").save(os.path.join(OUT, f"{sid}_walk.png"))
    print(sid, "grid", grid.shape[::-1], "walkable", int(grid.sum()))
    if len(sys.argv) > 2:
        ov = src.convert("RGBA")
        lay = Image.new("RGBA", ov.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        for gy, gx in zip(*np.nonzero(~grid)):
            d.rectangle((gx * CELL, gy * CELL, gx * CELL + CELL - 1, gy * CELL + CELL - 1), fill=(255, 0, 0, 90))
        ov.alpha_composite(lay)
        ov.convert("RGB").save(sys.argv[2])


if __name__ == "__main__":
    main()
