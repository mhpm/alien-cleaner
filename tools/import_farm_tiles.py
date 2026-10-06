"""Farm ground sheet (tools/farm_tiles_ref.webp, transparent background) ->
  - tools/farm_tiles/grass_<n>.png   6 plain grass tiles (inner part, 64 px) for a
                                     "Farm grass" terrain source (seamless floor fill)
  - tools/farm_tiles/patch_<n>.png   12 grass tiles with a dirt patch (64 px, rounded
                                     grass rim kept) for a "Farm dirt patches" source
  - assets/decor/farm/terrain/<category>/<name>.png + entries in assets/decor/farm/kit.json:
      Paths    strips, corners, crosses (flat pieces laid on the ground)
      Patches  big organic dirt / grass patches (flat)
      Plants   grass tufts, bushes and flowers (flat, sway)
      Dirt     small bare-earth spots (flat)
The two tile sources are added to the terrain library by the Arena Editor (group "Farm").
Scale: one square tile of the sheet (~107 px) = one arena tile (32 world units).

    python tools/import_farm_tiles.py
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "tools/farm_tiles_ref.webp"
TILES = "tools/farm_tiles"
DECOR = "assets/decor/farm"
SUB = "terrain"
KIT = DECOR + "/kit.json"
TILE_PX = 107.0  # a square tile in the sheet
UNITS = 32.0 / TILE_PX  # world units per sheet pixel
INSET = 7  # grass tiles: drop the rounded rim so they repeat as a floor


def pieces(img):
    a = np.array(img)
    fg = a[:, :, 3] > 40
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        mask = lab[sl] == i + 1
        if mask.sum() < 60:
            continue
        crop = a[sl].copy()
        crop[~mask] = 0  # only this piece (no bits of a neighbour)
        out.append((sl[0].start, sl[1].start, Image.fromarray(crop)))
    out.sort(key=lambda p: (p[0] // 40, p[1]))
    return out


def brownish(im):
    a = np.array(im).astype(float)
    m = a[:, :, 3] > 128
    r, g = a[:, :, 0][m].mean(), a[:, :, 1][m].mean()
    return r > g * 1.05


def main():
    img = Image.open(SRC).convert("RGBA")
    os.makedirs(TILES, exist_ok=True)
    tiles, paths, patches, plants, dirt = [], [], [], [], []
    for y, x, im in pieces(img):
        w, h = im.size
        if y < 262 and 95 <= w <= 120 and 95 <= h <= 120:
            tiles.append((y, x, im))
        elif y < 457:
            paths.append(im)
        elif w >= 60 and h >= 60:
            patches.append(im)
        elif brownish(im):
            dirt.append(im)
        else:
            plants.append(im)
    tiles.sort(key=lambda t: (t[0] // 60, t[1]))
    grass = tiles[:6]
    dirt_tiles = tiles[6:]
    for i, (_, _, im) in enumerate(grass):
        w, h = im.size
        im.crop((INSET, INSET, w - INSET, h - INSET)).resize((64, 64), Image.LANCZOS).save(f"{TILES}/grass_{i + 1}.png")
    for i, (_, _, im) in enumerate(dirt_tiles):
        im.resize((64, 64), Image.LANCZOS).save(f"{TILES}/patch_{i + 1}.png")

    kit = json.load(open(KIT, encoding="utf-8")) if os.path.exists(KIT) else {"name": "Farm", "items": []}
    kit["items"] = [it for it in kit["items"] if not str(it.get("file", "")).startswith(SUB + "/")]
    groups = [("Paths", "path", paths, False), ("Patches", "patch", patches, False),
              ("Plants", "plant", plants, True), ("Dirt", "dirt", dirt, False)]
    for cat, stem, items, sway in groups:
        folder = f"{DECOR}/{SUB}/{cat.lower()}"
        os.makedirs(folder, exist_ok=True)
        for f in os.listdir(folder):
            if f.endswith(".png") or f.endswith(".png.import"):
                os.remove(os.path.join(folder, f))
        for i, im in enumerate(items):
            name = f"{stem}_{i + 1:02d}.png"
            im.save(f"{folder}/{name}")
            kit["items"].append({
                "file": f"{SUB}/{cat.lower()}/{name}", "category": "Ground · " + cat,
                "width": round(im.size[0] * UNITS, 1), "solid": None,
                "sway": sway, "fade": False, "flat": True, "shadow": False,
            })
    json.dump(kit, open(KIT, "w", encoding="utf-8"), indent=1)
    print(f"grass tiles {len(grass)}, dirt-patch tiles {len(dirt_tiles)}, paths {len(paths)}, "
          f"patches {len(patches)}, plants {len(plants)}, dirt spots {len(dirt)}")


if __name__ == "__main__":
    main()
