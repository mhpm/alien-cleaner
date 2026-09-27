"""Builds the big world-1 ship room from tools/room_big_ref.webp (941x1672, empty room).

  python tools/make_big_room.py [repeats]

The painted room is made taller by repeating a band of wall + floor that tiles
seamlessly (rows BAND_Y and BAND_Y + BAND_H match; found by searching for the
smallest row difference), with a short cross-fade over the seam.

Output: assets/room/room_ship_bg.webp. The mapping to world units lives in
Room.ART_THEMES.ship (scripts/room.gd): floor top-left at art px FLOOR_TL, one
16-unit tile = TILE_PX art px, rows = floor height / TILE_PX.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "room")

BAND_Y = 630   # first row of the repeated band
BAND_H = 445   # band height (the side walls repeat with this period)
FADE = 10      # cross-fade rows at each seam
FLOOR_TL = (90, 216)
FLOOR_BR = (857, 1502)
TILE_PX = (FLOOR_BR[0] - FLOOR_TL[0]) / 12.0  # 12 floor columns


def main() -> None:
    repeats = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    src = np.asarray(Image.open(os.path.join(HERE, "room_big_ref.webp")).convert("RGB")).astype(np.float32)
    band = src[BAND_Y:BAND_Y + BAND_H]
    parts = [src[:BAND_Y + BAND_H]]
    for _ in range(repeats):
        parts.append(band.copy())
    parts.append(src[BAND_Y + BAND_H:])
    # smooth each seam: the rows after it fade in from the rows that followed before
    out = parts[0]
    for p in parts[1:]:
        prev_next = src[BAND_Y + BAND_H:BAND_Y + BAND_H + FADE]
        head = p[:FADE].copy()
        for k in range(FADE):
            a = (k + 1) / (FADE + 1)
            head[k] = prev_next[k] * (1.0 - a) + head[k] * a
        p = np.concatenate([head, p[FADE:]], axis=0)
        out = np.concatenate([out, p], axis=0)
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    img.save(os.path.join(OUT, "room_ship_bg.webp"), quality=92)
    floor_h = FLOOR_BR[1] - FLOOR_TL[1] + BAND_H * repeats
    print("room_ship_bg.webp", img.size)
    print("floor origin", FLOOR_TL, "tile px %.3f" % TILE_PX,
          "rows %.2f" % (floor_h / TILE_PX), "scale %.5f" % (16.0 / TILE_PX))


if __name__ == "__main__":
    main()
