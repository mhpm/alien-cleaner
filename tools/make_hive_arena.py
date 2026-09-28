"""Builds the world-2 survival arena (THE HIVE) from its painted reference.

Usage: python tools/make_hive_arena.py [repeats]
Reads tools/arena2_ref.webp (a walled room with the door at the top) and makes it
bigger by repeating, `repeats` extra times each, three bands picked so their edges
match (found by comparing pixel rows/columns, aligned to the floor tiles):
two 2-tile columns either side of the door and one 6-tile row. Writes
assets/arena/arena_hive_bg.webp and arena_hive.json: the art size and the walkable
floor rectangle in art px (Room.build_arena maps it to world units).
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "arena2_ref.webp")
OUT_DIR = os.path.join(HERE, "..", "assets", "arena")
COL_BANDS = [(259, 118), (707, 119)]  # (x0, width): wall panels + floor columns
ROW_BAND = (427, 352)  # (y0, height): side walls + floor rows
FLOOR = (84, 180, 1002, 1304)  # walkable floor in the reference (x0, y0, x1, y1)


def repeat_cols(img, bands, n):
    parts, x = [], 0
    for x0, w in bands:
        parts.append(img.crop((x, 0, x0 + w, img.height)))
        for _ in range(n):
            parts.append(img.crop((x0, 0, x0 + w, img.height)))
        x = x0 + w
    parts.append(img.crop((x, 0, img.width, img.height)))
    out = Image.new(img.mode, (sum(p.width for p in parts), img.height))
    cx = 0
    for p in parts:
        out.paste(p, (cx, 0))
        cx += p.width
    return out


def main(n):
    src = Image.open(SRC).convert("RGB")
    wide = repeat_cols(src, COL_BANDS, n)
    tall = repeat_cols(wide.transpose(Image.TRANSPOSE), [ROW_BAND], n).transpose(Image.TRANSPOSE)
    grow_x = sum(w for _, w in COL_BANDS) * n
    grow_y = ROW_BAND[1] * n
    floor = [FLOOR[0], FLOOR[1], FLOOR[2] + grow_x, FLOOR[3] + grow_y]
    door_x = 543 + COL_BANDS[0][1] * n  # the door sits between the two column bands
    os.makedirs(OUT_DIR, exist_ok=True)
    tall.save(os.path.join(OUT_DIR, "arena_hive_bg.webp"), quality=92, method=6)
    with open(os.path.join(OUT_DIR, "arena_hive.json"), "w") as f:
        json.dump({"size": [tall.width, tall.height], "floor": floor, "door_x": door_x}, f, indent=1)
    print("arena", tall.size, "floor", floor, "door_x", door_x)


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 3)
