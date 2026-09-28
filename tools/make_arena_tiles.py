"""Builds the survival arena art (world 1) from the floor reference and the big room art.

  python tools/make_arena_tiles.py

Outputs in assets/arena/:
  floor_atlas.png  64x64 floor cells of tools/arena_floor_ref.webp, 12 per row: first the
                   plain plates, then the ones with a vent grille (counts in
                   floor_atlas.json, read by Room)
  wall_l.png       left wall strip (floor side on the right), tiles vertically
  wall_r.png       right wall strip (floor side on the left), tiles vertically
  wall_t.png       top wall (the left strip turned), tiles horizontally
  wall_b.png       bottom wall, tiles horizontally
  corner.png       wall corner block
"""
import json
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
OUT = os.path.join(ROOT, "assets", "arena")

TILE = 64
# floor: the cells of tools/arena_floor_ref.webp (muted metal plates) between these grid
# lines; plain cells become the floor, cells with a vent grille become rare variants
FLOOR_XS = [13, 109, 225, 349, 470, 591, 715, 831, 928]
FLOOR_YS = [11, 124, 236, 345, 459, 580, 696, 813, 938, 1055, 1172, 1290, 1405, 1521, 1653]
DARKEN = 0.94  # keep the floor quiet so aliens and the astronaut stand out

# the big room art: its side walls repeat seamlessly over this band (make_big_room.py)
BAND_Y, BAND_H = 630, 445
WALL_W = 90


def floor_cells():
    ref = Image.open(os.path.join(HERE, "arena_floor_ref.webp")).convert("RGB")
    plain, vents = [], []
    for j in range(len(FLOOR_YS) - 1):
        for i in range(len(FLOOR_XS) - 1):
            box = (FLOOR_XS[i], FLOOR_YS[j], FLOOR_XS[i + 1], FLOOR_YS[j + 1])
            cell = ref.crop(box)
            px = list(cell.get_flattened_data()) if hasattr(cell, "get_flattened_data") else list(cell.getdata())
            orange = sum(1 for r, g, b in px if r > 150 and g > 90 and b < 80)
            # vent grilles: lots of near-black pixels inside the plate (grid lines excluded)
            w, h = cell.size
            core = cell.crop((int(w * 0.15), int(h * 0.15), int(w * 0.85), int(h * 0.85)))
            cpx = list(core.get_flattened_data()) if hasattr(core, "get_flattened_data") else list(core.getdata())
            dark = sum(1 for r, g, b in cpx if r + g + b < 70) / len(cpx)
            if orange > 20:
                continue  # the hazard-striped corners
            cell = cell.resize((TILE, TILE), Image.LANCZOS).point(lambda v: int(v * DARKEN))
            (vents if dark > 0.1 else plain).append(cell)
    return plain, vents


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    plain, vents = floor_cells()
    tiles = plain + vents
    cols = 12  # a grid keeps the atlas small enough for any phone GPU
    atlas = Image.new("RGBA", (TILE * cols, TILE * ((len(tiles) + cols - 1) // cols)))
    for i, t in enumerate(tiles):
        atlas.paste(t, ((i % cols) * TILE, (i // cols) * TILE))
    atlas.save(os.path.join(OUT, "floor_atlas.png"))
    with open(os.path.join(OUT, "floor_atlas.json"), "w") as f:
        json.dump({"plain": len(plain), "vent": len(vents), "cols": cols}, f)
    print("floor tiles: %d plain, %d vent" % (len(plain), len(vents)))
    room = Image.open(os.path.join(HERE, "room_big_ref.webp")).convert("RGBA")
    w, _ = room.size
    left = room.crop((0, BAND_Y, WALL_W, BAND_Y + BAND_H))
    right = room.crop((w - WALL_W, BAND_Y, w, BAND_Y + BAND_H))
    left.save(os.path.join(OUT, "wall_l.png"))
    right.save(os.path.join(OUT, "wall_r.png"))
    left.rotate(-90, expand=True).save(os.path.join(OUT, "wall_t.png"))
    left.rotate(90, expand=True).save(os.path.join(OUT, "wall_b.png"))
    room.crop((0, 0, WALL_W, WALL_W)).save(os.path.join(OUT, "corner.png"))
    print("arena art ->", OUT)


if __name__ == "__main__":
    main()
