"""Shared helpers to turn the user's sheets into an Arena Editor decoration kit.

A kit = assets/decor/<kit>/<folder>/*.png + kit.json (+ README.txt): every PNG shows up
in the palette (OBJECTS > <Kit> > <Folder>); kit.json gives each picture its defaults
(width in world units, solid footprint, see-through...). Used by make_biodome_kit.py
(world 8); copy that script for a new world and change only its tables.

  pieces(sheet)          connected pieces of a sheet with a transparent background
  owner(boxes, box)      the piece in `box`: its biggest blob + the specks around it
  cut(img, lab, box, ids) the picture of that piece alone
  nearest(boxes, tl)     the piece whose top-left is nearest `tl` (tables of names)
  stretch_run(img, post, width)  a wall run brought to `width`, end posts kept
  Kit(name, folder)      save() pictures, entry()/prop_entry() defaults, finish()
  floor_atlas(...)       floor tiles -> a 64 px terrain atlas + its terrain.json source
  index_sheet(sheet, out)  numbered boxes over a sheet, to name the pieces (Read it)
  contact_sheet(kit, out)  every picture of a kit on one image, to check the cut

Walls in the game's 3/4 view (see the skill arena-decor-kit): a straight run's posts sit
on the lattice nodes; its solid is the bottom RUN_SOLID of its drawing; a column's solid
is SIDE_PAD wider than its drawing (the astronaut collides with a 5.5 radius circle at
the feet but is drawn ~22 wide).
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DECOR = os.path.join(ROOT, "assets", "decor")
TERRAIN = os.path.join(ROOT, "assets", "arena", "terrain")
TILE = 64  # terrain atlas cell (px)
RUN_SOLID = 0.8
SIDE_PAD = 12.0
SPECK = 300  # px: blobs smaller than this belong to the piece around them


def pieces(path, alpha=40):
    """(img, labels, [(box (l, t, r, b), label id, area)]) of a sheet's connected pieces."""
    img = Image.open(path).convert("RGBA")
    a = np.array(img)[..., 3]
    lab, _ = ndimage.label(a > alpha)
    out = []
    for i, s in enumerate(ndimage.find_objects(lab)):
        area = int((lab[s] == i + 1).sum())
        out.append(((s[1].start, s[0].start, s[1].stop, s[0].stop), i + 1, area))
    return img, lab, out


def cut(img, lab, box, ids):
    """The picture inside `box`, keeping only the pixels of components `ids`."""
    l, t, r, b = box
    arr = np.array(img.crop(box))
    keep = np.isin(lab[t:b, l:r], ids)
    arr[..., 3] = np.where(keep, arr[..., 3], 0)
    return Image.fromarray(arr)


def owner(boxes, box):
    """(component ids, box) of the piece in `box`: the biggest blob inside and the specks."""
    l, t, r, b = box
    inside = [p for p in boxes if p[0][0] >= l - 4 and p[0][1] >= t - 4 and p[0][2] <= r + 4 and p[0][3] <= b + 4]
    if not inside:
        return [], box
    main = max(inside, key=lambda p: p[2])
    ids = [main[1]] + [p[1] for p in inside if p is not main and p[2] < SPECK]
    return ids, main[0]


def nearest(boxes, tl):
    """The big piece whose top-left corner is nearest `tl` (x, y)."""
    big = [p for p in boxes if p[2] >= SPECK]
    return min(big, key=lambda q: abs(q[0][0] - tl[0]) + abs(q[0][1] - tl[1]))


def piece_at(img, lab, boxes, tl):
    """The picture of the piece nearest `tl` (a names table: name -> top-left)."""
    p = nearest(boxes, tl)
    ids, b = owner(boxes, p[0])
    return cut(img, lab, b, ids)


def stretch_run(img, post, width):
    """A straight wall run brought to `width` px: both end posts (`post` px) kept, the
    middle resized. Only for small differences (the sheet's runs drawn 280-328 px):
    never lengthen art a lot (the user did not like it)."""
    w, h = img.size
    if w == width:
        return img
    mid = img.crop((post, 0, w - post, h)).resize((width - post * 2, h), Image.LANCZOS)
    out = Image.new("RGBA", (width, h))
    out.alpha_composite(img.crop((0, 0, post, h)), (0, 0))
    out.alpha_composite(mid, (post, 0))
    out.alpha_composite(img.crop((w - post, 0, w, h)), (width - post, 0))
    return out


def stretch_column(img, cap, height):
    """A column brought to `height` px: `cap` px at the top and at the bottom kept, the
    tube in between resized (a plain glowing tube: a few % never shows)."""
    w, h = img.size
    if h == height:
        return img
    mid = img.crop((0, cap, w, h - cap)).resize((w, height - cap * 2), Image.LANCZOS)
    out = Image.new("RGBA", (w, height))
    out.alpha_composite(img.crop((0, 0, w, cap)), (0, 0))
    out.alpha_composite(mid, (0, cap))
    out.alpha_composite(img.crop((0, h - cap, w, h)), (0, height - cap))
    return out


def split_at_gap(img, lo, hi):
    """Two pictures from one where two pieces touch: cut at the emptiest column in lo..hi."""
    a = np.array(img)[..., 3]
    x = lo + int(np.argmin((a[:, lo:hi] > 40).sum(axis=0)))
    return img.crop((0, 0, x, img.height)), img.crop((x, 0, img.width, img.height))


class Kit:
    """A decoration kit being (re)made: save() its pictures, then finish() writes kit.json
    (keeping the entries of pictures added by hand) and README.txt."""

    def __init__(self, name, folder):
        self.name = name
        self.folder = folder
        self.out = os.path.join(DECOR, folder)
        self.made = {}

    def save(self, img, sub, name, item, palette=True):
        os.makedirs(os.path.join(self.out, sub), exist_ok=True)
        img = img.crop(img.getbbox()) if img.getbbox() else img
        if palette:  # 256-colour PNG: a third of the size, the art reads the same
            img = img.quantize(256, method=Image.Quantize.FASTOCTREE)
        img.save(os.path.join(self.out, sub, name + ".png"), optimize=True)
        file = sub + "/" + name + ".png"
        item = dict(item)
        item["file"] = file
        self.made[file] = item
        return img

    @staticmethod
    def entry(cat, width, solid, fade=False, flat=False):
        """Palette defaults: `solid` = (w, h) footprint at the feet, or None."""
        e = {"category": cat, "width": round(width, 2), "sway": False, "fade": fade, "flat": flat,
             "bridge": False, "shadow": False, "blocks_bullets": not flat, "pixel": False}
        if solid:
            e["solid"] = [round(solid[0], 2), round(solid[1], 2)]
        return e

    @staticmethod
    def prop_entry(cat, w, h, kind="solid", tall=45.0):
        """A prop's defaults by kind: "solid" (footprint 80% wide, 6-22 deep), "flat" (on
        the floor, no solid), "walk_under" (arches: no solid), "post" (lamps: tiny)."""
        if kind == "flat":
            return Kit.entry(cat, w, None, flat=True)
        if kind == "walk_under":
            return Kit.entry(cat, w, None, fade=True)
        if kind == "post":
            return Kit.entry(cat, w, (w * 0.6, 5.0))
        return Kit.entry(cat, w, (w * 0.8, max(6.0, min(22.0, w * 0.35))), fade=h > tall)

    @staticmethod
    def run_entry(cat, w, h):
        """A straight wall run (posts on the nodes): solid the bottom RUN_SOLID."""
        return Kit.entry(cat, w, (w + SIDE_PAD * 0.5, h * RUN_SOLID))

    @staticmethod
    def column_entry(cat, w, h, run_h):
        """A column from the far post's top to the near post's base: SIDE_PAD wider."""
        return Kit.entry(cat, w, (w + SIDE_PAD, h - run_h * (1.0 - RUN_SOLID)), fade=True)

    def finish(self, readme):
        kit_path = os.path.join(self.out, "kit.json")
        kept = []
        if os.path.exists(kit_path):
            for it in json.load(open(kit_path, encoding="utf-8")).get("items", []):
                f = str(it.get("file", ""))
                if f not in self.made and os.path.exists(os.path.join(self.out, f)):
                    kept.append(it)
        with open(kit_path, "w", encoding="utf-8") as fh:
            json.dump({"name": self.name, "items": list(self.made.values()) + kept}, fh, indent=1, ensure_ascii=False)
        with open(os.path.join(self.out, "README.txt"), "w", encoding="utf-8") as fh:
            fh.write(readme)
        return len(self.made), len(kept)


def floor_atlas(src_png, tile_px, cols, rows, out_name, source_id, name, group, fill=1):
    """Floor tiles (a grid of `tile_px` squares) -> assets/arena/terrain/<out_name> as a
    64 px atlas, registered in terrain.json as source `source_id` (Arena dock > PAINT).
    Tile 0 = the plain one (New Arena fills with the first `fill`)."""
    floor = Image.open(src_png).convert("RGBA")
    out = Image.new("RGBA", (cols * TILE, rows * TILE))
    for j in range(rows):
        for i in range(cols):
            tile = floor.crop((i * tile_px, j * tile_px, (i + 1) * tile_px, (j + 1) * tile_px))
            out.paste(tile.resize((TILE, TILE), Image.LANCZOS), (i * TILE, j * TILE))
    out.save(os.path.join(TERRAIN, out_name), optimize=True)
    tj_path = os.path.join(TERRAIN, "terrain.json")
    tj = json.load(open(tj_path, encoding="utf-8"))
    src = {"id": source_id, "name": name, "group": group,
           "path": "res://assets/arena/terrain/" + out_name, "fill": fill}
    taken = [s for s in tj["sources"] if s["id"] == source_id and s["path"] != src["path"]]
    if taken:
        raise SystemExit("terrain id %d already belongs to %s: pick a free id" % (source_id, taken[0]["name"]))
    tj["sources"] = [s for s in tj["sources"] if s["id"] != source_id] + [src]
    with open(tj_path, "w", encoding="utf-8") as fh:
        json.dump(tj, fh, indent="\t", ensure_ascii=False)
        fh.write("\n")


def free_terrain_id():
    tj = json.load(open(os.path.join(TERRAIN, "terrain.json"), encoding="utf-8"))
    return max(s["id"] for s in tj["sources"]) + 1


def index_sheet(sheet, out, scale=2):
    """Every piece of `sheet` boxed and numbered (sorted in rows), saved to `out`: look at it
    with Read, then write the names table with each piece's top-left (printed)."""
    img, _, boxes = pieces(sheet)
    big = sorted([p for p in boxes if p[2] >= SPECK], key=lambda p: (p[0][1] // 60, p[0][0]))
    bg = Image.new("RGBA", img.size, (40, 40, 50, 255))
    bg.alpha_composite(img)
    d = ImageDraw.Draw(bg)
    for i, p in enumerate(big):
        d.rectangle(p[0], outline=(255, 0, 0, 255))
        d.text((p[0][0] + 2, p[0][1] + 2), str(i), fill=(255, 255, 0, 255))
        print(i, p[0])
    bg.resize((img.width * scale, img.height * scale)).save(out)


def contact_sheet(folder, out, k=0.5, width=1400):
    """Every picture of kit `folder` side by side (at `k`), to check the cut with Read."""
    files = sorted(f for f in _walk(os.path.join(DECOR, folder)) if f.endswith(".png"))
    x = y = rowh = 0
    sheet = Image.new("RGBA", (width, 4000), (40, 40, 50, 255))
    for f in files:
        im = Image.open(f).convert("RGBA")
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))))
        if x + im.width > width:
            x, y, rowh = 0, y + rowh + 4, 0
        sheet.alpha_composite(im, (x, y))
        x += im.width + 4
        rowh = max(rowh, im.height)
    sheet.crop((0, 0, width, y + rowh)).save(out)


def _walk(d):
    for base, _, names in os.walk(d):
        for n in names:
            yield os.path.join(base, n)


if __name__ == "__main__":
    import sys
    if len(sys.argv) >= 3 and sys.argv[1] == "index":
        index_sheet(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "sheet_index.png")
    elif len(sys.argv) >= 3 and sys.argv[1] == "contact":
        contact_sheet(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "kit_contact.png")
    else:
        print("python tools/kit_cut.py index <sheet> [out.png] | contact <kit folder> [out.png]")
