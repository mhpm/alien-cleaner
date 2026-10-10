"""World building kits (ForgeMap): tools/<set>_build_kit_ref.webp -> assets/rooms/<set>/build/.

A kit sheet has a floor of tiles, 4 corner blocks of machinery, 10 horizontal wall
segments (post + slab + front face + post) and vertical columns; an extra sheet brings
more corner blocks. The game (ForgeMap, scripts/data/forge_map.gd) lays walls on a
lattice: a POST on every wall node, a horizontal segment between two posts and a column
SHAFT between two posts on top of each other, so walls of any shape (rooms, corridors,
mazes) can be built from them.

Output:
  floor.png   the floor tiles, regularized to TILE px each and without the coloured glows
              (the game adds glows of its own, so no tile shows a cut glow); tiles covered
              in goo are left out
  atlas.png   every wall piece + the corner machinery, padded and edge-extruded (mipmaps)
  build.json  atlas regions: posts, caps, feats (interiors of the segments), filler (plain
              slab + face, tileable), shafts (tileable), corners, extra corners + their side

python tools/make_forge_walls.py [w5|w6|w7|w8]   (worlds 5 THE FORGE, 6 GENE VAULT, 7 WARP NEXUS, 8 BIODOME)
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILE = 76
POST_W = 37   # every post is resized to this width
POST_H = 90   # top of the cap to the bottom of the front leg
CAP_H = 46    # the cap alone (a wall continues south of the node)
PAD = 3

# One entry per world kit:
#   floor_x / floor_y  grout lines of the floor sheet (sheet px, brightness minima)
#   glow               how the floor's coloured glows are found: "warm" (orange, world 5),
#                      "purple" (world 6)
#   segments           horizontal segments (x, y, w, h): posts found by the top row
#   columns            (x, y, w, h, shaft start share, shaft end share)
#   corners            (x, y, w, h, corner) of the kit sheet
#   extra              more corner blocks (top corners) from their own sheet; extra_side =
#                      the corner they are drawn for, "auto" = found by the wall they show
#   post_cut           (optional) the kit has no raised posts: the segments' end brackets
#                      (this many px of each end) are the posts; post_h / cap_h = their
#                      height and the cap's (default POST_H / CAP_H)
#   skip_tiles         (optional) floor tiles left out [(tx, ty)], e.g. a big emblem cut in
#                      pieces
#   floor_from         (optional) no floor of its own: the PLAINEST tiles of another kit's
#                      floor.png (fewest cracks / panels), all evened out to one colour
#                      (floor_tint), so the floor fits any world's walls
SETS = {
    "w5": {
        "src": "w5_build_kit_ref.webp",
        "floor_x": [37, 111, 188, 261, 336, 408, 477, 545, 617, 691],  # last 101 px: 2 squeezed tiles, left out
        "floor_y": [52, 127, 201, 276, 351, 427, 502, 587],
        "glow": "warm",
        "segments": [(29, 624, 264, 92), (300, 624, 235, 92), (540, 624, 224, 93), (771, 624, 197, 95),
                     (975, 624, 144, 96), (27, 727, 264, 109), (299, 727, 234, 102), (540, 727, 223, 100),
                     (773, 728, 195, 97), (982, 732, 137, 95)],
        "columns": [(1044, 847, 46, 123, 0.29, 0.71), (1106, 848, 38, 122, 0.29, 0.71),
                    (1159, 848, 39, 122, 0.29, 0.71), (1217, 847, 49, 123, 0.29, 0.71),
                    (1140, 631, 48, 191, 0.29, 0.71)],
        "corners": [(848, 25, 292, 276, "tl"), (1192, 24, 316, 277, "tr"), (847, 319, 304, 292, "bl"),
                    (1192, 319, 318, 291, "br")],
        "extra_src": "w5_corners_ref.webp",
        "extra": [(51, 35, 323, 338), (405, 49, 315, 325), (755, 49, 309, 326), (1100, 50, 322, 316),
                  (42, 401, 327, 322), (408, 401, 315, 302), (761, 389, 312, 322), (1097, 394, 318, 330),
                  (344, 723, 350, 338), (752, 728, 312, 329)],
        "extra_side": "tl",
    },
    "w6": {
        "src": "w6_build_kit_ref.webp",
        "floor_x": [24, 96, 168, 242, 318, 390, 464, 537, 609, 683, 756],
        "floor_y": [42, 115, 186, 259, 330, 402, 475, 548],
        "glow": "purple",
        "drop": 0.7,  # tiles more than this covered in goo / glow are left out
        "segments": [(22, 581, 230, 102), (259, 581, 225, 100), (490, 581, 232, 101), (729, 581, 212, 106),
                     (948, 581, 121, 100), (22, 702, 230, 103), (260, 702, 225, 103), (491, 702, 231, 103),
                     (729, 702, 212, 103), (948, 702, 121, 103)],
        "columns": [(1057, 827, 45, 126, 0.3, 0.7), (1118, 827, 44, 126, 0.3, 0.7),
                    (1180, 826, 48, 127, 0.3, 0.7), (1089, 585, 45, 211, 0.27, 0.73)],
        "corners": [(809, 25, 306, 259, "tl"), (1152, 25, 328, 259, "tr"), (809, 290, 306, 278, "bl"),
                    (1152, 290, 328, 278, "br")],
        "extra_src": "w6_corners_ref.webp",
        "extra": [(107, 11, 361, 337), (540, 11, 377, 337), (1005, 10, 374, 338), (24, 379, 347, 305),
                  (394, 376, 326, 302), (755, 383, 314, 300), (1105, 377, 319, 322), (106, 710, 379, 332),
                  (548, 704, 373, 338), (992, 707, 388, 335)],
        "extra_side": "auto",
    },
    "w7": {
        "src": "w7_build_kit_ref.webp",
        # inside the sheet's frame; the octagon emblem in the middle is left out
        "floor_x": [85, 165, 245, 327, 406, 488, 573, 654],
        "floor_y": [114, 195, 274, 354, 427, 508],
        "floor_from": "w5",  # the user's call: general plain tiles, not the kit's own
        "floor_tint": (92, 100, 128),
        "plain": 18,  # how many of the plainest tiles are kept
        "glow": "none",
        "segments": [(23, 619, 227, 116), (251, 619, 229, 116), (481, 619, 213, 116), (695, 619, 229, 116),
                     (925, 619, 94, 116), (23, 748, 227, 116), (251, 748, 229, 116), (481, 748, 213, 116),
                     (695, 748, 229, 116), (925, 748, 94, 116)],
        "post_cut": 34,
        "post_h": 116,
        "cap_h": 58,
        "columns": [(701, 880, 83, 134, 0.24, 0.76), (795, 880, 71, 133, 0.24, 0.76), (873, 881, 64, 132, 0.24, 0.76),
                    (1056, 880, 59, 134, 0.24, 0.76), (1125, 880, 63, 134, 0.24, 0.76), (324, 879, 75, 134, 0.24, 0.76)],
        "corners": [(763, 32, 309, 292, "tl"), (1097, 32, 328, 292, "tr"), (763, 336, 309, 269, "bl"),
                    (1097, 336, 328, 268, "br")],
        "extra_src": None,
        "extra": [],
        "extra_side": "tl",
    },
}
SETS["w8"] = {
    # world 8 (BIODOME): white walls with orange brackets and blue lights, greenery
    "src": "w8_build_kit_ref.webp",
    # the floor comes as loose tiles on its own sheet: the plain ones and those with a
    # small sprout / vent (no big bushes, cracks or vine paths, so it tiles calmly)
    "floor_src": "w8_floor_ref.webp",
    "floor_boxes": [(48, 85, 160, 150), (236, 84, 163, 151), (426, 84, 164, 151), (617, 84, 162, 151),
                    (804, 84, 170, 151), (1000, 85, 161, 150), (1189, 84, 162, 151), (1380, 84, 159, 151),
                    (1569, 84, 159, 151), (48, 257, 160, 145), (236, 257, 163, 145), (426, 257, 164, 145),
                    (617, 257, 162, 145), (804, 257, 170, 145), (1000, 257, 161, 145), (1189, 257, 162, 145),
                    (1380, 257, 159, 145), (48, 421, 161, 145), (48, 590, 161, 119), (48, 729, 140, 123),
                    (218, 729, 142, 123), (387, 729, 132, 123), (549, 730, 136, 122), (713, 730, 139, 122)],
    "floor_inset": 1,  # thin borders already: just the outermost pixel
    "glow": "none",
    # rows 2-3 of the sheet (row 1 is taller; the 373 px one would squash too much)
    "segments": [(13, 154, 131, 97), (149, 154, 148, 97), (300, 153, 140, 98), (444, 154, 181, 98),
                 (629, 154, 212, 98), (845, 154, 142, 98), (990, 152, 123, 100), (387, 268, 129, 96),
                 (522, 267, 191, 97), (717, 268, 261, 96), (980, 266, 134, 98)],
    "post_cut": 22,  # the rounded end with its blue tube is the post
    "filler_max": 256,  # white walls: the plain slab is bright
    "post_h": 97,
    "cap_h": 48,
    "columns": [(14, 382, 62, 184, 0.24, 0.76), (86, 383, 62, 183, 0.24, 0.76), (157, 382, 59, 184, 0.24, 0.76),
                (224, 382, 62, 184, 0.24, 0.76), (295, 382, 61, 184, 0.24, 0.76), (364, 382, 62, 184, 0.24, 0.76),
                (433, 382, 61, 184, 0.24, 0.76), (575, 382, 63, 185, 0.24, 0.76), (647, 382, 62, 185, 0.24, 0.76),
                (718, 382, 62, 184, 0.24, 0.76), (875, 382, 62, 185, 0.24, 0.76)],
    "corners": [],  # only top corners, on their own sheet
    "extra_src": "w8_corners_ref.webp",
    "extra": [(14, 152, 301, 326), (334, 156, 290, 321), (639, 156, 290, 329), (943, 151, 294, 332),
              (1253, 156, 271, 323), (15, 512, 300, 323), (333, 528, 291, 318), (639, 542, 289, 302),
              (944, 521, 288, 326), (1246, 525, 281, 310)],
    "extra_side": "auto",
    # loose props saved as build/prop_<n>.png: the 14 plant tanks (world 8 SeedTank)
    "props": [(10, 581, 70, 151), (88, 581, 70, 151), (166, 582, 76, 151), (253, 582, 76, 150),
              (338, 582, 74, 150), (420, 581, 71, 150), (501, 581, 70, 151), (581, 582, 71, 149)],
}
C = SETS["w5"]
SRC = OUT = ""


def load():
    return np.array(Image.open(SRC).convert("RGBA")).astype(np.float32)


# ---------------------------------------------------------------- floor

def shared_floor():
    """The plainest tiles of another kit's floor, evened out to one colour."""
    sheet = np.array(Image.open(os.path.join(ROOT, "assets", "rooms", C["floor_from"], "build", "floor.png")).convert("RGBA")).astype(np.float32)
    rows, cols = sheet.shape[0] // TILE, sheet.shape[1] // TILE
    tiles = [sheet[y * TILE:(y + 1) * TILE, x * TILE:(x + 1) * TILE] for y in range(rows) for x in range(cols)]
    inner = slice(8, TILE - 8)  # leave the grout out of the measure

    def busy(t):
        g = t[inner, inner, :3].mean(2)
        return np.abs(np.diff(g, axis=0)).mean() + np.abs(np.diff(g, axis=1)).mean() + g.std() * 0.3

    tiles.sort(key=busy)
    keep = tiles[:C.get("plain", 18)]
    want = np.array(C.get("floor_tint", (92, 100, 128)), np.float32)
    out = []
    for t in keep:
        t = t.copy()
        mean = t[inner, inner, :3].reshape(-1, 3).mean(0)
        t[..., :3] = np.clip(t[..., :3] - mean + want, 0, 255)  # same colour, same light
        out.append(t)
    cols = 6
    rows = len(out) // cols
    sheet = np.zeros((rows * TILE, cols * TILE, 4), np.float32)
    for i, t in enumerate(out[:cols * rows]):
        y, x = divmod(i, cols)
        sheet[y * TILE:(y + 1) * TILE, x * TILE:(x + 1) * TILE] = t
    Image.fromarray(sheet.astype(np.uint8)).save(os.path.join(OUT, "floor.png"))
    return {"tile": TILE, "cols": cols, "rows": rows}


def loose_floor():
    """Floor tiles drawn apart on their own sheet: each box cropped and set to TILE px."""
    a = np.array(Image.open(os.path.join(ROOT, "tools", C["floor_src"])).convert("RGBA"))
    a[a[..., 3] < 40] = 0
    im = Image.fromarray(a)
    tiles = []
    k = C.get("floor_inset", 0)
    for (x, y, w, h) in C["floor_boxes"]:
        t = im.crop((x, y, x + w, y + h))
        t = t.crop(t.getbbox())
        t = t.crop((k, k, t.width - k, t.height - k))
        flat = Image.new("RGBA", t.size, (200, 205, 218, 255))  # no see-through edges
        flat.alpha_composite(t)
        tiles.append(np.array(flat.resize((TILE, TILE), Image.LANCZOS)).astype(np.float32))
    cols = max(c for c in range(6, 13) if len(tiles) % c == 0) if any(len(tiles) % c == 0 for c in range(6, 13)) else 8
    rows = len(tiles) // cols  # only full rows
    sheet = np.zeros((rows * TILE, cols * TILE, 4), np.float32)
    for i, t in enumerate(tiles[:cols * rows]):
        yy, xx = divmod(i, cols)
        sheet[yy * TILE:(yy + 1) * TILE, xx * TILE:(xx + 1) * TILE] = t
    Image.fromarray(sheet.astype(np.uint8)).save(os.path.join(OUT, "floor.png"))
    out = {"tile": TILE, "cols": cols, "rows": rows}
    if C.get("stud"):
        cx, cy, r = C["stud"]
        st = np.array(im.crop((cx - r, cy - r, cx + r, cy + r))).copy()
        rgb = st[..., :3].astype(int)
        keep = (rgb[..., 2] > rgb[..., 0] + 40) & (st[..., 3] > 100)  # cyan stone + its blue rim
        st[~keep] = 0
        Image.fromarray(st).save(os.path.join(OUT, "stud.png"))
        # its size as a share of a tile (the tile is the box minus the inset on both sides)
        out["stud"] = (2.0 * r) / (C["floor_boxes"][0][2] - 2 * k)
    return out


def floor(src):
    if C.get("floor_from"):
        return shared_floor()
    if C.get("floor_boxes"):
        return loose_floor()
    tiles = []
    fx, fy = C["floor_x"], C["floor_y"]
    skip = set(tuple(t) for t in C.get("skip_tiles", []))
    for ty in range(len(fy) - 1):
        for tx in range(len(fx) - 1):
            if (tx, ty) in skip:
                continue
            t = Image.fromarray(src[fy[ty]:fy[ty + 1], fx[tx]:fx[tx + 1]].astype(np.uint8))
            tiles.append(np.array(t.resize((TILE, TILE), Image.LANCZOS)).astype(np.float32))
    tiles = np.array(tiles)
    r, g, b = tiles[..., 0], tiles[..., 1], tiles[..., 2]
    if C["glow"] == "none":
        warm = np.zeros_like(r)  # nothing to clean
    elif C["glow"] == "purple":
        warm = np.clip((r - g + 2.0) / 25.0, 0.0, 1.0)  # blue-grey floor: red ~8 under green
    else:
        warm = np.clip((r - b + 22.0) / 30.0, 0.0, 1.0)  # blue-grey floor: red ~30 under blue
    # soften the mask so the patch blends in
    soft = np.array([np.array(Image.fromarray((w * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
                              .filter(ImageFilter.GaussianBlur(4))) / 255.0 for w in warm])
    cover = (warm.reshape(len(tiles), -1) > 0.5).mean(1)
    clean = [i for i in range(len(tiles)) if cover[i] < 0.0075] or list(range(len(tiles)))
    keep = [i for i in range(len(tiles)) if cover[i] < C.get("drop", 1.0)]  # goo-covered tiles are left out
    out = tiles.copy()
    rng = np.random.default_rng(7)
    for i in range(len(tiles)):
        if cover[i] < 0.0075:
            continue
        d = tiles[clean[rng.integers(len(clean))]]
        a = soft[i][..., None]
        out[i, ..., :3] = tiles[i, ..., :3] * (1.0 - a) + d[..., :3] * a
    # whatever tint is left: back to the floor's blue-grey
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    if C["glow"] == "none":
        pass
    elif C["glow"] == "purple":
        out[..., 0] = r - np.clip(r - (g - 8.0), 0, None) * 0.9
        out[..., 2] = b - np.clip(b - (g + 42.0), 0, None) * 0.9
    else:
        out[..., 0] = r - np.clip(r - (b - 30.0), 0, None) * 0.9
        out[..., 1] = g - np.clip(g - (b - 27.0), 0, None) * 0.9
    out[..., 3] = 255
    out = out[keep]
    cols = 9 if len(out) % 9 == 0 or len(out) < 40 else 10
    cols = min(cols, len(out))
    rows = len(out) // cols
    out = out[:cols * rows]
    sheet = np.zeros((rows * TILE, cols * TILE, 4), np.float32)
    for i, t in enumerate(out):
        y, x = divmod(i, cols)
        sheet[y * TILE:(y + 1) * TILE, x * TILE:(x + 1) * TILE] = t
    Image.fromarray(np.clip(sheet, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "floor.png"))
    return {"tile": TILE, "cols": cols, "rows": rows}


# ---------------------------------------------------------------- wall pieces

def crop(src, x, y, w, h):
    return Image.fromarray(src[y:y + h, x:x + w].astype(np.uint8))


def segment_parts(src):
    posts, feats, interiors = [], [], []
    ph = C.get("post_h", POST_H)
    for (x, y, w, h) in C["segments"]:
        if C.get("post_cut"):
            k = C["post_cut"]
            for p0, p1 in ((0, k), (w - k, w)):
                posts.append(crop(src, x + p0, y, p1 - p0, ph).resize((POST_W, ph), Image.LANCZOS))
            feats.append(crop(src, x + k, y, w - 2 * k, h))
            interiors.append(src[y:y + h, x + k:x + w - k])
            continue
        a = src[y:y + h, x:x + w, 3] > 100
        row = a[4]
        runs, s = [], None
        for i in range(w):
            if row[i] and s is None:
                s = i
            if not row[i] and s is not None:
                runs.append((s, i))
                s = None
        if s is not None:
            runs.append((s, w))
        (l0, l1), (r0, r1) = runs[0], runs[-1]
        for p0, p1 in ((l0, l1), (r0, r1)):
            p = crop(src, x + p0, y, p1 - p0, POST_H)
            if (np.array(p)[POST_H - 6:, :, 3] > 100).mean() > 0.6:  # whole leg (some are cut short)
                posts.append(p.resize((POST_W, POST_H), Image.LANCZOS))
        feats.append(crop(src, x + l1, y, r0 - l1, h))
        interiors.append(src[y:y + h, x + l1:x + r0])
    return posts, feats, interiors


def filler(interiors):
    """Plain slab + face: per row, the median of the calm (grey, not glowing) pixels."""
    rows = []
    for yy in range(C.get("post_h", 92) if C.get("post_cut") else 92):
        px = []
        for it in interiors:
            if yy < it.shape[0]:
                line = it[yy]
                ok = (line[:, 3] > 200) & (np.abs(line[:, 0] - line[:, 1]) < 22) & (line[:, :3].max(1) < C.get("filler_max", 150))
                px.extend(line[ok, :4].tolist())
        rows.append(np.median(np.array(px), 0) if len(px) > 8 else np.zeros(4))
    col = np.array(rows)
    img = np.repeat(col[:, None, :], 24, 1)
    rng = np.random.default_rng(3)
    img[..., :3] += rng.normal(0, 2.2, img[..., :3].shape)
    img[..., :3] = np.clip(img[..., :3], 0, 255)
    keep = np.where(img[:, 0, 3] > 100)[0]
    img = img[keep.min():keep.max() + 1]
    return Image.fromarray(img.astype(np.uint8)), int(keep.min())


def shafts(src):
    out = []
    for (x, y, w, h, k0, k1) in C["columns"]:
        y0 = y + int(h * k0)
        y1 = y + int(h * k1)
        out.append(crop(src, x, y0, w, y1 - y0).resize((POST_W, y1 - y0), Image.LANCZOS))
    return out


def corners(src):
    return [(crop(src, x, y, w, h), c) for (x, y, w, h, c) in C["corners"]]


def extra_side(img):
    """'tl' or 'tr': the side of the block that shows a wall (grey stone) rather than
    machinery spilling out to the open floor."""
    a = np.array(img).astype(np.float32)
    h, w = a.shape[:2]
    band = max(8, w // 9)
    rows = slice(int(h * 0.3), int(h * 0.75))

    def wallish(part):
        rgb, al = part[..., :3], part[..., 3]
        grey = (np.abs(rgb[..., 0] - rgb[..., 1]) < 18) & (rgb[..., 2] - rgb[..., 1] < 45) & (al > 200)
        return grey.mean()

    return "tl" if wallish(a[rows, :band]) >= wallish(a[rows, w - band:]) else "tr"


def extra_corners():
    if not C.get("extra_src"):
        return []
    src = np.array(Image.open(os.path.join(ROOT, "tools", C["extra_src"])).convert("RGBA")).astype(np.float32)
    out = []
    for (x, y, w, h) in C["extra"]:
        img = crop(src, max(0, x - 2), max(0, y - 2), w + 4, h + 4)
        img = img.crop(img.getbbox())
        out.append((img, extra_side(img) if C["extra_side"] == "auto" else C["extra_side"]))
    return out


GRID = 12      # corner blocks: collision measured on a GRID x GRID of the picture
FOOT = 0.5     # of each column of drawn machinery, the lower share is solid (3/4 view:
               # the top of a tall tank stands over floor that can be walked behind)


def footprint(img):
    """Solid rects of a corner block, as shares of its picture [x, y, w, h]: grid cells
    mostly covered by the drawing, keeping only the lower FOOT of each column."""
    a = np.array(img)[..., 3] > 120
    h, w = a.shape
    cov = np.zeros((GRID, GRID))
    for gy in range(GRID):
        for gx in range(GRID):
            cell = a[gy * h // GRID:(gy + 1) * h // GRID, gx * w // GRID:(gx + 1) * w // GRID]
            cov[gy, gx] = cell.mean() if cell.size else 0.0
    on = cov > 0.6
    solid = np.zeros_like(on)
    for gx in range(GRID):
        rows = np.where(on[:, gx])[0]
        if len(rows) == 0:
            continue
        top = rows.min() + int((rows.max() - rows.min() + 1) * (1.0 - FOOT))
        solid[top:rows.max() + 1, gx] = on[top:rows.max() + 1, gx]
    for gy in range(GRID):  # no holes between pipes inside a row
        cols = np.where(solid[gy])[0]
        if len(cols):
            solid[gy, cols.min():cols.max() + 1] = True
    rects = []
    for gy in range(GRID):
        gx = 0
        while gx < GRID:
            if solid[gy, gx]:
                x0 = gx
                while gx < GRID and solid[gy, gx]:
                    gx += 1
                rects.append([x0 / GRID, gy / GRID, (gx - x0) / GRID, 1.0 / GRID])
            gx += 1
    return rects


# ---------------------------------------------------------------- atlas

def extrude(img):
    """PAD px of border copied from the edge (so mipmaps don't bleed into neighbours)."""
    a = np.pad(np.array(img), ((PAD, PAD), (PAD, PAD), (0, 0)), mode="edge")
    return Image.fromarray(a)


def pack(items, width=1024):
    """Shelf packing; items = [(name, image)]; returns atlas image and regions."""
    x = y = shelf = 0
    places = []
    for name, img in sorted(items, key=lambda it: -it[1].height):
        w, h = img.width + PAD * 2, img.height + PAD * 2
        if x + w > width:
            x = 0
            y += shelf
            shelf = 0
        places.append((name, img, x, y))
        x += w
        shelf = max(shelf, h)
    atlas = Image.new("RGBA", (width, y + shelf), (0, 0, 0, 0))
    regions = {}
    for name, img, px, py in places:
        atlas.paste(extrude(img), (px, py))
        regions[name] = [px + PAD, py + PAD, img.width, img.height]
    return atlas, regions


def main():
    global C, SRC, OUT
    set_id = sys.argv[1] if len(sys.argv) > 1 else "w5"
    C = SETS[set_id]
    SRC = os.path.join(ROOT, "tools", C["src"])
    OUT = os.path.join(ROOT, "assets", "rooms", set_id, "build")
    os.makedirs(OUT, exist_ok=True)
    src = load()
    fl = floor(src)
    posts, feats, interiors = segment_parts(src)
    fill, fill_top = filler(interiors)
    items = []
    for i, p in enumerate(posts):
        items.append(("post_%d" % i, p))
        items.append(("cap_%d" % i, p.crop((0, 0, POST_W, C.get("cap_h", CAP_H)))))
    for i, f in enumerate(feats):
        items.append(("feat_%d" % i, f))
    items.append(("filler", fill))
    for i, s in enumerate(shafts(src)):
        items.append(("shaft_%d" % i, s))
    feet = {}
    for img, c in corners(src):
        items.append(("corner_" + c, img))
        feet["corner_" + c] = footprint(img)
    extra = extra_corners()
    for i, (img, _side) in enumerate(extra):
        items.append(("corner_x%d" % i, img))
        feet["corner_x%d" % i] = footprint(img)
    for i, (x, y, w, h) in enumerate(C.get("props", [])):
        pr = crop(src, x, y, w, h)
        a = np.array(pr)
        a[a[..., 3] < 40] = 0
        pr = Image.fromarray(a)
        pr.crop(pr.getbbox()).save(os.path.join(OUT, "prop_%d.png" % i))
    atlas, regions = pack(items, 2048)
    atlas.save(os.path.join(OUT, "atlas.png"))
    data = {
        "floor": fl,
        "post": [POST_W, C.get("post_h", POST_H)],
        "cap_h": C.get("cap_h", CAP_H),
        "filler_top": fill_top,
        "posts": len(posts),
        "feats": len(feats),
        "shafts": len(C["columns"]),
        "extra_corners": len(extra),
        "extra_sides": [side for _img, side in extra],
        "props": len(C.get("props", [])),
        "corner_feet": feet,
        "regions": regions,
    }
    with open(os.path.join(OUT, "build.json"), "w") as fh:
        json.dump(data, fh, indent=1)
    print(set_id, "atlas", atlas.size, "pieces", len(regions), "floor", fl, "posts", len(posts),
          "extra sides", data["extra_sides"])


if __name__ == "__main__":
    main()
