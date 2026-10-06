"""Terrain atlases for the Arena Editor (addons/aliens_cleaner_arena_editor).

Every atlas is a grid of 64 px tiles (the arena floor tile: 32 world units, drawn at 0.5):
  assets/arena/terrain/walls.png         wall strips of the survival arena (assets/arena/wall_*.png,
                                         corner.png) squeezed to 64 px thick; each strip is cut
                                         into 4 tiles that repeat seamlessly in order
                                         (rows: top, bottom, left, right, corners)
  assets/arena/terrain/void_floor.png    world 3 floor tiles (assets/ui/world/world3_elements/)
  assets/arena/terrain/contamination.png splats, slime and grime decals centred in a tile

The TileSet itself (scenes/arena/terrain/arena_terrain.tres) is built inside Godot from
assets/arena/terrain/terrain.json: Arena dock -> TERRAIN -> "Sync TileSet". To swap art,
replace a PNG (same grid) or add a new source to terrain.json with a new id.

    python tools/make_arena_terrain.py
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
ARENA = os.path.join(ROOT, "assets", "arena")
OUT = os.path.join(ARENA, "terrain")
VOID_KIT = os.path.join(ROOT, "assets", "ui", "world", "world3_elements")
ENV2 = os.path.join(ROOT, "assets", "sprites", "enviroment", "enviroment_elements2")
ROOM = os.path.join(ROOT, "assets", "room")
T = 64

VOID_FLOOR = [1, 2, 3, 4, 5, 6, 13, 14]
VOID_SPLATS = [48, 53, 54, 55, 56, 58, 82, 86]
GRIME = ["076", "078", "095", "090", "105", "097"]


def wall_tiles():
    """4 tiles per strip, rows: top, bottom, left, right; then the 4 corners."""
    atlas = Image.new("RGBA", (T * 4, T * 5))
    for row, side in enumerate("tblr"):
        strip = Image.open(os.path.join(ARENA, "wall_%s.png" % side)).convert("RGBA")
        horizontal = side in "tb"
        # the strip repeats seamlessly along its length: squeeze it to exactly 4 tiles
        strip = strip.resize((T * 4, T) if horizontal else (T, T * 4), Image.LANCZOS)
        for i in range(4):
            box = (i * T, 0, i * T + T, T) if horizontal else (0, i * T, T, i * T + T)
            atlas.paste(strip.crop(box), (i * T, row * T))
    corner = Image.open(os.path.join(ARENA, "corner.png")).convert("RGBA").resize((T, T), Image.LANCZOS)
    flips = [corner, corner.transpose(Image.FLIP_LEFT_RIGHT), corner.transpose(Image.FLIP_TOP_BOTTOM),
             corner.transpose(Image.FLIP_LEFT_RIGHT).transpose(Image.FLIP_TOP_BOTTOM)]
    for i, c in enumerate(flips):
        atlas.paste(c, (i * T, 4 * T))
    return atlas


def fit_tile(img, pad=2, cover=False):
    """`img` trimmed and scaled into one tile (cover = fill it, cropping the overflow)."""
    img = img.convert("RGBA")
    box = img.getbbox()
    if box:
        img = img.crop(box)
    w, h = img.size
    s = (T / min(w, h)) if cover else ((T - pad * 2) / max(w, h))
    img = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    tile = Image.new("RGBA", (T, T))
    tile.paste(img, ((T - img.width) // 2, (T - img.height) // 2), img)
    return tile


def grid(tiles, cols):
    rows = (len(tiles) + cols - 1) // cols
    atlas = Image.new("RGBA", (T * cols, T * rows))
    for i, t in enumerate(tiles):
        atlas.paste(t, ((i % cols) * T, (i // cols) * T))
    return atlas


def main():
    os.makedirs(OUT, exist_ok=True)
    wall_tiles().save(os.path.join(OUT, "walls.png"))
    floor = [fit_tile(Image.open(os.path.join(VOID_KIT, "image_%03d.png" % n)), cover=True) for n in VOID_FLOOR]
    grid(floor, 4).save(os.path.join(OUT, "void_floor.png"))
    decals = [fit_tile(Image.open(os.path.join(ROOM, "prop_splat%d.png" % n))) for n in (1, 2, 3)]
    decals += [fit_tile(Image.open(os.path.join(ENV2, "enviroment_%s.png" % n))) for n in GRIME]
    decals += [fit_tile(Image.open(os.path.join(VOID_KIT, "image_%03d.png" % n))) for n in VOID_SPLATS]
    grid(decals, 6).save(os.path.join(OUT, "contamination.png"))
    print("terrain atlases ->", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
