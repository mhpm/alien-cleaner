"""Builds the survival arena art (world 1) from the loose environment sprites and the
big room art.

  python tools/make_arena_tiles.py

Outputs in assets/arena/:
  floor_atlas.png  64x64 floor plates in one row (index = atlas x, see Room.ARENA_TILES):
                   0-4 plain / cracked plates, 5 planet emblem, 6 glowing vent,
                   7 grate, 8 hazard-striped plate, 9 floor grille
  wall_l.png       left wall strip (floor side on the right), tiles vertically
  wall_r.png       right wall strip (floor side on the left), tiles vertically
  wall_t.png       top wall (the left strip turned), tiles horizontally
  wall_b.png       bottom wall, tiles horizontally
  corner.png       wall corner block
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
ENV2 = os.path.join(ROOT, "assets", "sprites", "enviroment", "enviroment_elements2", "enviroment_%03d.png")
OUT = os.path.join(ROOT, "assets", "arena")

TILE = 64
GROUT = (20, 24, 39, 255)  # shows through the rounded plate corners
PLATES = [1, 2, 14, 15, 16, 3, 4, 5, 17, 102]

# the big room art: its side walls repeat seamlessly over this band (make_big_room.py)
BAND_Y, BAND_H = 630, 445
WALL_W = 90


def plate(n: int) -> Image.Image:
    im = Image.open(ENV2 % n).convert("RGBA")
    im = im.crop(im.getbbox())
    base = Image.new("RGBA", (TILE, TILE), GROUT)
    # grilles are not square: centre them on a plain plate
    if n == 102:
        base = plate(2)
        im.thumbnail((TILE - 10, TILE - 10), Image.LANCZOS)
        base.alpha_composite(im, ((TILE - im.width) // 2, (TILE - im.height) // 2))
        return base
    im = im.resize((TILE, TILE), Image.LANCZOS)
    base.alpha_composite(im)
    return base


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    atlas = Image.new("RGBA", (TILE * len(PLATES), TILE))
    for i, n in enumerate(PLATES):
        atlas.paste(plate(n), (i * TILE, 0))
    atlas.save(os.path.join(OUT, "floor_atlas.png"))
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
