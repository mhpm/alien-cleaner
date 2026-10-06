"""Earth art for the Arena Editor, cut from the user's sheets (levels back on Earth).

  tools/earth_terrain_ref.webp  6 rows of ground tiles (grass, dirt paths / mud, water and
                                shores, cliffs, roads, infested ground) on transparency
  tools/earth_decor_ref.webp    trees, plants, rocks, cliffs, waterfalls, bridges, fences,
                                barriers, roads, a military camp, logs, dead and infested
                                trees, a crashed ship, alien crystals

Terrain -> assets/arena/terrain/earth_*.png (64 px tiles: the inside of each painted tile,
its ragged border trimmed off), registered in terrain.json (water = solid).
The cliff row of the terrain sheet becomes scenery (it has height).
Decor -> assets/decor/earth/<category>/<name>.png + kit.json. Touching pieces are pulled
apart with a watershed on the alpha (one seed per object), then each piece is named by its
reading-order index (ITEMS below; any piece not listed and big enough lands in "Misc").

    python tools/make_earth_assets.py
"""
import json
import os
import shutil

import cv2
import numpy as np
from PIL import Image

import earth_autotile as AT

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
TERRAIN_SHEET = os.path.join(HERE, "earth_terrain_ref.webp")
DECOR_SHEET = os.path.join(HERE, "earth_decor_ref.webp")
TERRAIN = os.path.join(ROOT, "assets", "arena", "terrain")
KIT = os.path.join(ROOT, "assets", "decor", "earth")
T = 64
WORLD_PER_PX = 0.5  # decor sheet pixels -> world units (keeps the sheet's relative sizes)

# ---------------------------------------------------------------- terrain

# terrain rows (reading order of the 55 tiles) -> atlas
TERRAIN_ROWS = ["grass", "dirt", "water", "cliffs", "roads", "infested"]
# water row: which tiles are open water (solid) and which are shore (walkable)
WATER_SOLID = [0, 5, 6, 7, 8]
WATER_SHORE = [1, 2, 3, 4]
INNER = 0.1  # share of each tile's box trimmed off (the ragged painted border)


def terrain_tiles():
    a = np.asarray(Image.open(TERRAIN_SHEET).convert("RGBA"))
    m = (a[:, :, 3] > 40).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    comps = [k for k in range(1, n) if st[k, cv2.CC_STAT_AREA] > 3000]
    comps.sort(key=lambda k: (round((st[k, 1] + st[k, 3] / 2) / 150), st[k, 0]))
    rows, cur, last_y = [], [], None
    for k in comps:
        cy = st[k, 1] + st[k, 3] / 2
        if last_y is not None and abs(cy - last_y) > 60:
            rows.append(cur)
            cur = []
        cur.append(k)
        last_y = cy
    rows.append(cur)
    img = Image.fromarray(a)
    out = {}
    for name, row in zip(TERRAIN_ROWS, rows):
        tiles, whole = [], []
        for k in row:
            x, y, w, h = st[k, :4]
            piece = img.crop((x, y, x + w, y + h))
            whole.append(piece)
            s = min(w, h)
            mx, my = int(w * INNER), int(h * INNER)
            inner = img.crop((x + mx, y + my, x + w - mx, y + h - my)) if name != "cliffs" else piece
            tiles.append(inner.resize((T, T), Image.LANCZOS))
        out[name] = (tiles, whole)
    return out


def atlas(tiles, cols=5):  # noqa: D103
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (T * cols, T * rows))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * T, (i // cols) * T))
    return sheet


# ---------------------------------------------------------------- decor

# reading-order index of a watershed piece -> (name, category, flags, footprint)
# flags: s = sway in the wind, f = see-through when walked behind, p = flat on the floor,
#        b = bridge (makes the water under it walkable); footprint = share of [w, h]
#        that is solid at the base (None = walk-through)
TREE = (0.2, 0.08)
ITEMS = {
    3: ("oak_green", "Trees", "sf", TREE), 4: ("oak_yellow", "Trees", "sf", TREE),
    5: ("oak_autumn", "Trees", "sf", TREE), 6: ("pine_tall_1", "Trees", "sf", TREE),
    7: ("pine_tall_2", "Trees", "sf", TREE), 8: ("cherry_blossom", "Trees", "sf", TREE),
    9: ("pine_small_1", "Trees", "sf", TREE), 12: ("oak_small", "Trees", "sf", TREE),
    13: ("tree_yellow_small", "Trees", "sf", TREE), 14: ("pine_small_2", "Trees", "sf", TREE),
    23: ("pine_berries", "Trees", "sf", TREE), 24: ("pine_small_3", "Trees", "sf", TREE),
    28: ("pine_small_4", "Trees", "sf", TREE),
    21: ("bush_flowers", "Plants", "s", None), 22: ("bushes_flowers", "Plants", "s", None),
    25: ("bush_yellow", "Plants", "s", None), 26: ("grass_tuft_1", "Plants", "s", None),
    27: ("grass_flowers", "Plants", "s", None), 15: ("bush_tiny", "Plants", "s", None),
    43: ("bush_flowers_2", "Plants", "s", None), 44: ("grass_tuft_2", "Plants", "s", None),
    45: ("fern", "Plants", "s", None), 46: ("grass_tuft_3", "Plants", "s", None),
    47: ("grass_tuft_4", "Plants", "s", None), 59: ("grass_tuft_5", "Plants", "s", None),
    104: ("grass_tuft_6", "Plants", "s", None),
    0: ("rocks_big_1", "Rocks", "f", (0.8, 0.3)), 1: ("rocks_big_2", "Rocks", "f", (0.8, 0.3)),
    2: ("rock_mossy", "Rocks", "", (0.8, 0.35)), 10: ("pebbles", "Rocks", "p", None),
    11: ("rock_small", "Rocks", "", (0.8, 0.35)), 16: ("rocks_big_3", "Rocks", "f", (0.8, 0.3)),
    17: ("rocks_big_4", "Rocks", "f", (0.8, 0.3)), 20: ("rock_mossy_big", "Rocks", "f", (0.8, 0.3)),
    29: ("rocks_moss_small", "Rocks", "", (0.8, 0.35)),
    33: ("cliff_1", "Cliffs", "f", (0.9, 0.5)), 34: ("cliff_2", "Cliffs", "f", (0.9, 0.5)),
    35: ("cliff_3", "Cliffs", "f", (0.9, 0.5)), 36: ("cliff_4", "Cliffs", "f", (0.9, 0.5)),
    37: ("cliff_5", "Cliffs", "f", (0.9, 0.5)), 38: ("cliff_6", "Cliffs", "f", (0.9, 0.5)),
    39: ("cliff_7", "Cliffs", "f", (0.9, 0.5)), 42: ("cliff_rocks", "Cliffs", "", (0.9, 0.4)),
    40: ("waterfall_1", "Water", "f", (0.95, 0.6)), 41: ("waterfall_2", "Water", "f", (0.95, 0.6)),
    49: ("bridge_1", "Water", "pb", None), 50: ("bridge_2", "Water", "pb", None),
    51: ("bridge_3", "Water", "pb", None), 52: ("bridge_4", "Water", "pb", None),
    53: ("dock_steps", "Fences", "", (0.8, 0.3)), 54: ("sawhorse", "Fences", "", (0.8, 0.25)),
    55: ("fence_wood_1", "Fences", "", (0.95, 0.15)), 56: ("fence_wood_2", "Fences", "", (0.95, 0.15)),
    48: ("guardrail_1", "Fences", "", (0.95, 0.15)), 57: ("guardrail_2", "Fences", "", (0.95, 0.15)),
    58: ("guardrail_3", "Fences", "", (0.95, 0.15)), 60: ("guardrail_short", "Fences", "", (0.95, 0.15)),
    64: ("guardrail_long", "Fences", "", (0.95, 0.15)), 61: ("bollard_1", "Fences", "", (0.8, 0.2)),
    62: ("bollard_2", "Fences", "", (0.8, 0.2)), 65: ("bollard_3", "Fences", "", (0.8, 0.2)),
    63: ("road_stone", "Fences", "", (0.8, 0.3)), 66: ("signpost", "Fences", "", (0.3, 0.1)),
    71: ("barrier_concrete", "Barriers", "", (0.95, 0.3)), 72: ("barrier_hazard", "Barriers", "", (0.95, 0.3)),
    73: ("barrier_red", "Barriers", "", (0.95, 0.3)), 74: ("traffic_cone", "Barriers", "", (0.7, 0.25)),
    75: ("sign_chevron", "Barriers", "", (0.9, 0.2)), 76: ("sandbags", "Barriers", "", (0.95, 0.35)),
    77: ("barrier_concrete_long", "Barriers", "", (0.95, 0.3)), 78: ("roadblock", "Barriers", "", (0.9, 0.2)),
    79: ("barrier_frame", "Barriers", "", (0.9, 0.2)),
    67: ("road_straight", "Roads", "p", None), 68: ("road_cracked", "Roads", "p", None),
    69: ("road_lot", "Roads", "p", None), 70: ("road_turn", "Roads", "p", None),
    84: ("camp_tent", "Camp", "f", (0.85, 0.35)), 85: ("camp_awning", "Camp", "f", (0.85, 0.3)),
    80: ("crate_wood", "Camp", "", (0.85, 0.35)), 81: ("crate_green_1", "Camp", "", (0.85, 0.35)),
    82: ("crate_green_2", "Camp", "", (0.85, 0.35)), 87: ("crate_stack", "Camp", "", (0.85, 0.35)),
    97: ("coolers", "Camp", "", (0.85, 0.35)), 86: ("cooking_tripod", "Camp", "", (0.5, 0.2)),
    94: ("campfire", "Camp", "", (0.7, 0.3)), 93: ("stump_1", "Camp", "", (0.8, 0.35)),
    95: ("stump_2", "Camp", "", (0.8, 0.35)), 96: ("log_pile", "Camp", "", (0.85, 0.35)),
    88: ("radio_desk", "Camp", "", (0.85, 0.3)), 89: ("satellite_dish", "Camp", "f", (0.4, 0.15)),
    90: ("field_radio", "Camp", "", (0.6, 0.2)), 91: ("generator_1", "Camp", "", (0.85, 0.35)),
    101: ("generator_2", "Camp", "", (0.85, 0.35)), 98: ("jerrycan_1", "Camp", "", (0.8, 0.3)),
    99: ("jerrycan_2", "Camp", "", (0.8, 0.3)), 100: ("jerrycan_3", "Camp", "", (0.8, 0.3)),
    102: ("jerrycan_4", "Camp", "", (0.8, 0.3)), 92: ("floodlight", "Camp", "f", (0.4, 0.12)),
    83: ("radio_tower", "Camp", "f", (0.6, 0.12)),
    105: ("log_mossy_1", "Forest", "", (0.9, 0.3)), 106: ("log_mossy_2", "Forest", "", (0.9, 0.3)),
    108: ("log_mossy_3", "Forest", "", (0.9, 0.3)), 109: ("branches", "Forest", "p", None),
    110: ("stump_old", "Forest", "", (0.8, 0.3)), 111: ("dead_tree_1", "Forest", "f", TREE),
    112: ("dead_tree_2", "Forest", "f", TREE),
    113: ("infested_tree_1", "Alien Invasion", "f", TREE), 114: ("infested_tree_2", "Alien Invasion", "f", TREE),
    115: ("infested_tree_3", "Alien Invasion", "f", TREE), 117: ("crashed_ship", "Alien Invasion", "f", (0.85, 0.35)),
    118: ("ship_debris_1", "Alien Invasion", "", (0.8, 0.3)), 119: ("ship_debris_2", "Alien Invasion", "", (0.5, 0.2)),
    120: ("ship_debris_3", "Alien Invasion", "", (0.8, 0.3)), 124: ("ship_debris_4", "Alien Invasion", "", (0.8, 0.3)),
    125: ("ship_debris_5", "Alien Invasion", "", (0.8, 0.3)), 129: ("alien_hive_roots", "Alien Invasion", "", (0.6, 0.25)),
    116: ("crystals_1", "Alien Invasion", "", (0.6, 0.25)), 121: ("crystals_2", "Alien Invasion", "", (0.6, 0.25)),
    122: ("crystals_3", "Alien Invasion", "", (0.6, 0.25)), 123: ("crystals_4", "Alien Invasion", "", (0.6, 0.25)),
    126: ("crystals_5", "Alien Invasion", "", (0.6, 0.25)), 128: ("crystals_6", "Alien Invasion", "", (0.6, 0.25)),
    131: ("crystals_7", "Alien Invasion", "", (0.6, 0.25)),
}
MISC_MIN_AREA = 600


def decor_pieces():
    """Watershed split of the decor sheet: [(index, piece image, area)] in reading order."""
    img = Image.open(DECOR_SHEET).convert("RGBA")
    a = np.asarray(img)
    mask = (a[:, :, 3] > 40).astype(np.uint8)
    core = cv2.erode((a[:, :, 3] > 200).astype(np.uint8), np.ones((5, 5), np.uint8))
    n, mk = cv2.connectedComponents(core)
    markers = np.zeros(mk.shape, np.int32)
    j = 0
    for k in range(1, n):
        if (mk == k).sum() >= 40:
            j += 1
            markers[mk == k] = j
    markers[mask == 0] = j + 1
    ws = cv2.watershed(cv2.cvtColor(a[:, :, :3], cv2.COLOR_RGB2BGR).copy(), markers)
    boxes = []
    for k in range(1, j + 1):
        ys, xs = np.where(ws == k)
        if len(xs) < 80:
            continue
        boxes.append((k, xs.min(), ys.min(), xs.max() - xs.min() + 1, ys.max() - ys.min() + 1, len(xs)))
    boxes.sort(key=lambda b: (round((b[2] + b[4] / 2) / 40), b[1]))
    out = []
    for i, (k, x, y, w, h, area) in enumerate(boxes):
        b = a.copy()
        sel = ws == k
        # watershed borders (-1) next to this piece keep their pixels too
        border = (ws == -1) & cv2.dilate(sel.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
        b[~(sel | border)] = 0
        piece = Image.fromarray(b).crop((x - 1, y - 1, x + w + 1, y + h + 1))
        bbox = piece.getbbox()
        out.append((i, piece.crop(bbox) if bbox else piece, area))
    return out


def earth_terrain(tiles):
    """Seamless ground and corner autotiles (see earth_autotile.py) + the road tiles as painted."""
    whole = {k: v[1] for k, v in tiles.items()}
    grass = [AT.seamless(AT.inner(t)) for t in whole["grass"]]
    atlas([AT.finish(g) for g in grass], 8).save(os.path.join(TERRAIN, "earth_grass.png"))
    base = grass[0]
    sand = AT.seamless(AT.inner(whole["dirt"][0], 0.3))
    water = AT.seamless(AT.inner(whole["water"][0]))
    infested = AT.seamless(AT.inner(whole["infested"][2]))
    shapes = {}
    for name, other, style, extras, seed in [
            ("water", water, "water", [], 11),
            ("path", AT._shade(sand, 0.93), "path", [], 23),
            ("infested", infested, "infested", [whole["infested"][k] for k in (0, 1, 3, 4, 5, 7, 8)], 37)]:
        wt, polys = AT.wang(base, other, style, seed, rim=sand)
        wt += [AT.finish(AT.seamless(AT.inner(e))) for e in extras]
        atlas(wt, 8).save(os.path.join(TERRAIN, "earth_%s_edges.png" % name))
        if style == "water":
            # the extra open-water tiles are solid all over
            polys += [[[[-32, -32], [32, -32], [32, 32], [-32, 32]]] for _ in extras]
            shapes = {str(i): p for i, p in enumerate(polys)}
    with open(os.path.join(TERRAIN, "earth_water_edges.json"), "w") as f:
        json.dump(shapes, f)
    mud = [AT.finish(AT.seamless(AT.inner(t, 0.2))) for t in whole["dirt"][6:10]]
    atlas(mud, 8).save(os.path.join(TERRAIN, "earth_mud.png"))
    atlas(tiles["roads"][0]).save(os.path.join(TERRAIN, "earth_roads.png"))
    for old in ("earth_dirt.png", "earth_water.png", "earth_shore.png", "earth_infested.png"):
        for f in (old, old + ".import"):
            if os.path.exists(os.path.join(TERRAIN, f)):
                os.remove(os.path.join(TERRAIN, f))


def main():
    # ---- terrain
    tiles = terrain_tiles()
    for old in ("earth_ground.png", "earth_roads.png"):  # previous placeholders
        p = os.path.join(TERRAIN, old)
        if os.path.exists(p):
            os.remove(p)
            if os.path.exists(p + ".import"):
                os.remove(p + ".import")
    earth_terrain(tiles)
    # ---- decor kit (fresh: only the user's art)
    if os.path.isdir(KIT):
        shutil.rmtree(KIT)
    os.makedirs(KIT)
    items = []

    def add(name, cat, flags, foot, piece):
        if "b" in flags:
            # bridges: drop the water painted around them (the map's own river shows instead)
            a = np.asarray(piece.convert("RGBA")).copy().astype(np.int32)
            blue = (a[:, :, 2] > a[:, :, 0] + 50) & (a[:, :, 2] > a[:, :, 1] + 10)
            a[blue, 3] = 0
            piece = Image.fromarray(a.astype(np.uint8))
            piece = piece.crop(piece.getbbox())
        folder = os.path.join(KIT, cat.lower().replace(" ", "_"))
        os.makedirs(folder, exist_ok=True)
        piece.save(os.path.join(folder, name + ".png"))
        w, h = piece.size
        width = round(w * WORLD_PER_PX, 1)
        height = h * WORLD_PER_PX
        solid = [round(width * foot[0], 1), round(max(3.0, height * foot[1]), 1)] if foot else None
        rel = "%s/%s.png" % (cat.lower().replace(" ", "_"), name)
        items.append({"file": rel, "category": cat, "width": width, "solid": solid,
                      "sway": "s" in flags, "fade": "f" in flags, "flat": "p" in flags, "bridge": "b" in flags,
                      "shadow": foot is TREE})

    for i, piece, area in decor_pieces():
        if i in ITEMS:
            name, cat, flags, foot = ITEMS[i]
            add(name, cat, flags, foot, piece)
        elif area >= MISC_MIN_AREA:
            add("piece_%03d" % i, "Misc", "", (0.8, 0.3), piece)
    # the terrain sheet's cliff tiles: one-tile plateaus
    for i, piece in enumerate(tiles["cliffs"][1]):
        piece = piece.resize((piece.width // 2, piece.height // 2), Image.LANCZOS)
        add("plateau_%d" % (i + 1), "Cliffs", "f", (0.95, 0.55), piece)
    with open(os.path.join(KIT, "kit.json"), "w") as f:
        json.dump({"name": "Earth", "items": items}, f, indent=1)
    cats = {}
    for it in items:
        cats[it["category"]] = cats.get(it["category"], 0) + 1
    print("earth terrain: seamless grass, water / path / infested autotiles, mud, roads")
    print("earth decor: %d pieces %s" % (len(items), cats))


if __name__ == "__main__":
    main()
