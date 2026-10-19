"""Pixel 2.5D prototype kit (scenes/prototype_pixel25d.tscn) from the user's sheet
tools/pixel25d_kit_ref.webp (3/4 lab pieces on a transparent background).

Every piece is cut by its connected component (index image: --index), reduced onto the
pixel grid of the prototype (1 art pixel = 1 world unit; a floor tile = Arena.TILE 32)
and saved as an INDEXED PNG (<= 32 colours + transparency, hard alpha): lossless,
crisp, and a few hundred bytes each, so the APK barely notices them.
  python tools/make_pixel25d_kit.py [--index out.png]  ->  assets/arena/pixel25d/
Also made here: the floor atlas (drawn pixel by pixel, 32 px tiles), side-wall
caps (the cap tile raised by the wall height) and flat dithered pixel shadows.
"""
import json
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "tools", "pixel25d_kit_ref.webp")
SRC2 = os.path.join(ROOT, "tools", "pixel25d_kit2_ref.webp")  # maze kit: 3/4 walls with pillars, sentries
OUT = os.path.join(ROOT, "assets", "arena", "pixel25d")  # the floor atlas
KIT = os.path.join(ROOT, "assets", "decor", "pixel_lab")  # every piece: an Arena Editor decor kit

K_WALL = 32 / 89  # sheet px -> world units for tiles, walls, caps (a tile is ~89 px)
K_PROP = 0.33  # props: a little smaller, so a console is about the astronaut's height
WALL_H = 42  # front face of the walls in the world (their cap is ~11 deep)
SHADOW = (8, 10, 22, 110)

# component index (see --index) -> (name, scale)
PIECES = {
    # walls (cap + blue brick face, lights, drips)
    3: ("wall_a", K_WALL), 4: ("wall_b", K_WALL), 12: ("wall_s", K_WALL),
    13: ("wall_c", K_WALL), 14: ("wall_d", K_WALL), 107: ("cap", K_WALL),
    # specimen tubes, racks, machines
    6: ("tube_big", K_PROP), 7: ("tube_tall", K_PROP), 9: ("tube_mid", K_PROP),
    10: ("tube_s", K_PROP), 8: ("tube_s2", K_PROP), 15: ("tube_dark", K_PROP),
    16: ("tube_s3", K_PROP), 20: ("cell_blue", K_PROP), 19: ("machine", K_PROP),
    22: ("rack_a", K_PROP), 23: ("rack_b", K_PROP), 24: ("rack_c", K_PROP),
    28: ("locker_a", K_PROP), 29: ("locker_b", K_PROP), 30: ("locker_c", K_PROP),
    21: ("console_big", K_PROP), 25: ("terminal_a", K_PROP), 38: ("desk_pc", K_PROP),
    39: ("desk_lab", K_PROP), 40: ("terminal_b", K_PROP), 41: ("printer", K_PROP),
    42: ("desk_papers", K_PROP), 62: ("terminal_c", K_PROP), 63: ("toolbox", K_PROP),
    64: ("desk_cups", K_PROP),
    # crates and barrels
    47: ("box_a", K_PROP), 51: ("box_b", K_PROP), 56: ("box_c", K_PROP),
    65: ("box_s", K_PROP), 66: ("box_xs", K_PROP), 48: ("crate_a", K_PROP),
    49: ("crate_b", K_PROP), 50: ("crate_big", K_PROP), 57: ("case", K_PROP),
    58: ("tank_pair", K_PROP), 67: ("crate_c", K_PROP), 72: ("crate_blue", K_PROP),
    73: ("crate_s", K_PROP), 59: ("cabinet_a", K_PROP), 60: ("cabinet_b", K_PROP),
    61: ("barrel", K_PROP),
    # pipes, barriers, rails
    26: ("pipe_valve", K_PROP), 27: ("pipe_bend", K_PROP), 35: ("pipe_drop", K_PROP),
    37: ("pipe_tall", K_PROP), 77: ("barrier_a", K_PROP), 78: ("barrier_b", K_PROP),
    86: ("rail_a", K_PROP), 89: ("rail_b", K_PROP),
    # floor bits (flat)
    85: ("trench", K_WALL), 31: ("vent_a", K_PROP), 32: ("vent_b", K_PROP),
    33: ("vent_c", K_PROP), 46: ("vent_x", K_PROP), 120: ("grate_red", K_PROP),
    71: ("hazard_a", K_PROP), 74: ("hazard_b", K_PROP), 75: ("hazard_c", K_PROP),
    81: ("goo_s", K_PROP), 82: ("goo_a", K_PROP), 83: ("goo_b", K_PROP),
    84: ("goo_c", K_PROP), 92: ("goo_d", K_PROP), 94: ("goo_e", K_PROP),
    90: ("goo_xs", K_PROP), 97: ("goo_xs2", K_PROP), 79: ("rubble", K_PROP),
    87: ("rocks", K_PROP), 95: ("rocks_s", K_PROP),
    # planters, wall lights, security cameras
    110: ("plant_a", K_PROP), 111: ("plant_b", K_PROP), 99: ("plant_c", K_PROP),
    112: ("plant_d", K_PROP), 100: ("light_white", K_PROP), 101: ("light_blue", K_PROP),
    102: ("light_red", K_PROP), 113: ("cam_mount", K_PROP), 114: ("cam_wall", K_PROP),
    115: ("cam_dome", K_PROP), 116: ("cam_mini", K_PROP), 117: ("cam_mini2", K_PROP),
}


def components(rgba):
    a = np.array(rgba)[:, :, 3] > 40
    lab, _ = ndimage.label(a)
    boxes = []
    for s in ndimage.find_objects(lab):
        if (s[1].stop - s[1].start) * (s[0].stop - s[0].start) >= 60:
            boxes.append((s[1].start, s[0].start, s[1].stop, s[0].stop))
    boxes.sort(key=lambda b: (b[1] // 40, b[0]))  # reading order, as in the index image
    return boxes


def reduce(piece, w, h):
    small = piece.resize((max(1, w), max(1, h)), Image.Resampling.BOX)
    alpha = np.array(small.getchannel("A")) >= 128
    rgb = np.array(small.convert("RGB"))
    out = np.zeros((small.height, small.width, 4), np.uint8)
    out[:, :, :3] = rgb
    out[:, :, 3] = np.where(alpha, 255, 0)
    return Image.fromarray(out, "RGBA")


def scaled(piece, k):
    return reduce(piece, round(piece.width * k), round(piece.height * k))


def save_indexed(im, name, colors=32):
    """`name` = path without .png. PNG with a palette: index 0 = transparent, up to `colors` - 1 opaque colours."""
    rgba = np.array(im.convert("RGBA"))
    solid = rgba[:, :, 3] >= 128
    q = Image.fromarray(rgba[:, :, :3]).quantize(colors - 1, method=Image.Quantize.MEDIANCUT,
                                                 dither=Image.Dither.NONE)
    idx = np.array(q).astype(np.uint8) + 1
    idx[~solid] = 0
    out = Image.fromarray(idx, "P")
    pal = q.getpalette()[: (colors - 1) * 3]
    out.putpalette([0, 0, 0] + pal)
    out.save(name + ".png", optimize=True, transparency=0)


FC = {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for k, v in {
    "floor": "4a5f86", "floor2": "52688f", "fhi": "5f77a0", "fsh": "3d4e70", "ink": "141623",
    "yel": "ffcd75", "yel2": "c9963f", "goo": "8a2b6a", "goo2": "b13e8a", "red2": "b13e53",
    "cyan2": "41a6f6",
}.items()}


def _rect(im, x0, y0, x1, y1, col):
    for y in range(y0, y1):
        for x in range(x0, x1):
            im.putpixel((x, y), col)


def _panel(im, x0, y0, w, h, base):
    _rect(im, x0, y0, x0 + w, y0 + h, base)
    _rect(im, x0, y0, x0 + w, y0 + 1, FC["fhi"])
    _rect(im, x0, y0, x0 + 1, y0 + h, FC["fhi"])
    _rect(im, x0, y0 + h - 1, x0 + w, y0 + h, FC["fsh"])
    _rect(im, x0 + w - 1, y0, x0 + w, y0 + h, FC["fsh"])
    for px, py in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)):
        im.putpixel((x0 + px, y0 + py), FC["fsh"])


def floor_atlas():
    """The drawn floor (kept over the sheet's tiles): 4 x 2 tiles of 32 px, each four
    16 px riveted panels. 0 plain, 1 scuffed, 2 vent, 3 hazard plate, 4 crack,
    5 alien goo, 6 one big plate, 7 cable trench."""
    rng = random.Random(7)
    im = Image.new("RGBA", (128, 64))
    for t in range(8):
        ox, oy = (t % 4) * 32, (t // 4) * 32
        for py in (0, 16):
            for px in (0, 16):
                _panel(im, ox + px, oy + py, 16, 16, FC["floor2"] if t == 1 else FC["floor"])
        if t == 1:
            for _ in range(10):
                im.putpixel((ox + rng.randrange(3, 29), oy + rng.randrange(3, 29)), FC["fsh"])
        elif t == 2:
            _rect(im, ox + 4, oy + 4, ox + 28, oy + 28, FC["ink"])
            for y in range(6, 27, 3):
                _rect(im, ox + 5, oy + y, ox + 27, oy + y + 1, FC["fsh"])
            _rect(im, ox + 4, oy + 27, ox + 28, oy + 28, FC["fhi"])
        elif t == 3:
            for y in range(8, 24):
                for x in range(8, 24):
                    im.putpixel((ox + x, oy + y), FC["yel"] if ((x + y) // 4) % 2 == 0 else FC["ink"])
            _rect(im, ox + 8, oy + 23, ox + 24, oy + 24, FC["yel2"])
        elif t == 4:
            x, y = 6, 4
            while y < 28:
                im.putpixel((ox + x, oy + y), FC["ink"])
                im.putpixel((ox + x + 1, oy + y), FC["fsh"])
                y += 1
                x = max(2, min(29, x + rng.choice((-1, 0, 1, 1))))
        elif t == 5:
            for _ in range(70):
                x, y = 16 + int(rng.gauss(0, 5)), 16 + int(rng.gauss(0, 4))
                if 1 < x < 31 and 1 < y < 31:
                    im.putpixel((ox + x, oy + y), FC["goo"] if rng.random() < 0.7 else FC["goo2"])
        elif t == 6:
            _panel(im, ox, oy, 32, 32, FC["floor2"])
            _rect(im, ox + 15, oy + 15, ox + 17, oy + 17, FC["fsh"])
        elif t == 7:
            _rect(im, ox, oy + 12, ox + 32, oy + 20, FC["ink"])
            _rect(im, ox, oy + 12, ox + 32, oy + 13, FC["fsh"])
            _rect(im, ox, oy + 19, ox + 32, oy + 20, FC["fhi"])
            for x in range(32):
                im.putpixel((ox + x, oy + 15 + (1 if (x // 4) % 2 else 0)), FC["red2"])
                im.putpixel((ox + x, oy + 17), FC["cyan2"])
    return im


def side_walls(cap, wall_s):
    """Side walls seen from above: a 32 x 32 cap raised by WALL_H; the end piece also
    shows the brick face (the short wall's, under its own cap)."""
    cap = cap.resize((32, 32), Image.Resampling.NEAREST)
    mid = Image.new("RGBA", (32, 32 + WALL_H))
    mid.paste(cap, (0, 0))
    face = wall_s.resize((32, round(wall_s.height * 32 / wall_s.width)), Image.Resampling.NEAREST)
    face = face.crop((0, face.height - WALL_H, 32, face.height))
    end = Image.new("RGBA", (32, 32 + WALL_H))
    end.paste(cap, (0, 0))
    end.paste(face, (0, 32))
    return mid, end


def shadow(w, h, solid_frac=0.6):
    im = Image.new("RGBA", (w, h))
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            d = ((x - cx) / (w / 2)) ** 2 + ((y - cy) / (h / 2)) ** 2
            if d <= solid_frac or (d <= 1.0 and (x + y) % 2 == 0):
                im.putpixel((x, y), SHADOW)
    return im


def wall_shadow():
    im = Image.new("RGBA", (32, 8))
    for y in range(8):
        for x in range(32):
            if y < 3 or (y < 6 and (x + y) % 2 == 0) or (y < 7 and (x + y) % 4 == 0):
                im.putpixel((x, y), SHADOW)
    return im


def save_rgba(im, name):
    """Semi-transparent pieces (shadows): a plain RGBA PNG, still tiny."""
    im.save(name + ".png", optimize=True)


# second sheet (tools/pixel25d_kit2_ref.webp): component index -> (name, scale, category);
# only the piece's own pixels are kept (neighbours touching its box are masked out)
K_M = 0.42  # props of the second sheet (drawn bigger than the first)
PIECES2 = {
    1: ("m_wall", 128 / 276, "Maze · Walls"), 7: ("m_wall_goo", 0.5, "Maze · Walls"),
    8: ("m_wall_b", 0.5, "Maze · Walls"), 0: ("m_corner", 0.5, "Maze · Walls"),
    3: ("m_corner_b", 0.5, "Maze · Walls"), 9: ("m_pillars", 0.5, "Maze · Walls"),
    10: ("m_pillars_s", 0.5, "Maze · Walls"), 27: ("m_block", 0.5, "Maze · Walls"),
    28: ("m_low_a", 0.5, "Maze · Walls"), 29: ("m_low_b", 0.5, "Maze · Walls"),
    19: ("m_rail", 0.42, "Maze · Barriers"), 20: ("m_rail_s", 0.42, "Maze · Barriers"),
    30: ("m_rail_bend", 0.42, "Maze · Barriers"), 32: ("m_bench", 0.42, "Maze · Barriers"),
    15: ("m_stairs", 0.42, "Maze · Lab"), 4: ("m_tank_double", 0.42, "Maze · Lab"),
    6: ("m_tank_side", K_M, "Maze · Lab"), 16: ("m_desk", K_M, "Maze · Lab"),
    41: ("m_lockers", K_M, "Maze · Storage"), 48: ("m_crate", K_M, "Maze · Storage"),
    53: ("m_crate_hazard", K_M, "Maze · Storage"), 54: ("m_crate_yellow", K_M, "Maze · Storage"),
    55: ("m_crate_stack", K_M, "Maze · Storage"), 60: ("m_crate_red", K_M, "Maze · Storage"),
    66: ("m_crate_striped", K_M, "Maze · Storage"), 73: ("m_machine", K_M, "Maze · Storage"),
    67: ("m_rubble_blocks", K_M, "Maze · Debris"), 83: ("m_rubble", K_M, "Maze · Debris"),
    86: ("m_rubble_b", K_M, "Maze · Debris"), 87: ("m_goo_big", K_M, "Maze · Debris"),
    40: ("m_plate", K_M, "Maze · Floor"), 45: ("m_plate_hazard", K_M, "Maze · Floor"),
    46: ("m_grate", K_M, "Maze · Floor"), 47: ("m_plate_big", K_M, "Maze · Floor"),
    65: ("m_cam", K_M, "Cameras"), 77: ("m_cam_b", K_M, "Cameras"),
    76: ("m_sentry", K_M, "Cameras"),
}
FLAT2 = ("Maze · Floor",)


def own_piece(sheet, lab, box, idx_label):
    """The crop of one component with every other component's pixels cleared."""
    x0, y0, x1, y1 = box
    crop = np.array(sheet.crop(box))
    mask = lab[y0:y1, x0:x1] == idx_label
    crop[~mask] = 0
    return Image.fromarray(crop, "RGBA")


def components_labeled(rgba):
    a = np.array(rgba)[:, :, 3] > 40
    lab, _ = ndimage.label(a)
    found = []
    for i, s in enumerate(ndimage.find_objects(lab)):
        if (s[1].stop - s[1].start) * (s[0].stop - s[0].start) >= 60:
            found.append(((s[1].start, s[0].start, s[1].stop, s[0].stop), i + 1))
    found.sort(key=lambda f: (f[0][1] // 40, f[0][0]))
    return lab, found


# palette category (Arena Editor > OBJECTS: "Pixel Lab · <category>") by name prefix
CATEGORIES = [
    (("wall", "side_wall"), "Walls"), (("cam_",), "Cameras"), (("light_",), "Lights"),
    (("tube", "cell", "machine", "rack", "console", "terminal", "printer"), "Lab"),
    (("box", "crate", "case", "tank", "cabinet", "barrel", "toolbox"), "Storage"),
    (("desk", "locker", "plant"), "Office"), (("pipe", "barrier", "rail"), "Pipes & Barriers"),
    (("vent", "grate", "hazard", "goo", "rubble", "rocks", "trench"), "Floor"),
    (("shadow",), "Shadows"),
]


def category(name):
    for _, (n, _, cat) in PIECES2.items():
        if n == name:
            return cat
    for prefixes, cat in CATEGORIES:
        if name.startswith(prefixes):
            return cat
    return "Misc"


def kit_item(name, im, cat):
    """kit.json settings: real size (1 px = 1 unit), pixel filter, a footprint at the base."""
    w, h = im.size
    item = {"file": "%s/%s.png" % (folder(cat), name), "category": cat, "width": float(w),
            "solid": None, "sway": False, "fade": False, "flat": False, "bridge": False,
            "shadow": False, "blocks_bullets": False, "pixel": True}
    if cat in ("Floor", "Shadows") + FLAT2:
        item["flat"] = True
    elif cat == "Maze · Walls":
        item.update(solid=[float(w), 12.0], fade=True, blocks_bullets=True)
    elif cat == "Maze · Barriers":
        item.update(solid=[float(max(8, w - 6)), 8.0])  # low: bullets fly over
    elif name == "side_wall" or name == "side_wall_end":
        item.update(solid=[32.0, 32.0], fade=True, blocks_bullets=True)
    elif cat == "Walls":
        item.update(solid=[float(w), 12.0], fade=True, blocks_bullets=True)
    elif name.startswith("rail"):
        item.update(solid=[float(w - 4), 8.0])  # low rails: bullets fly over
    elif cat not in ("Cameras", "Lights"):
        item.update(solid=[float(max(8, w - 6)), float(min(12, max(6, round(w * 0.3))))],
                    fade=True, blocks_bullets=True)
    return item


def folder(cat):
    """Folder of a category: "Maze · Walls" -> maze_walls, "Pipes & Barriers" -> pipes_barriers."""
    return cat.lower().replace(" · ", "_").replace(" & ", "_").replace(" ", "_")


def clean(root):
    """Nothing is deleted: pictures are overwritten in place, so their .import (and the
    UID scenes refer to) survive a rebuild. Remove a dropped piece by hand."""


def main():
    sheet = Image.open(SRC).convert("RGBA")
    boxes = components(sheet)
    if "--index" in sys.argv:
        out = sys.argv[sys.argv.index("--index") + 1]
        bg = Image.new("RGBA", sheet.size, (40, 40, 40, 255))
        bg.alpha_composite(sheet)
        d = ImageDraw.Draw(bg)
        for i, b in enumerate(boxes):
            d.rectangle(b, outline=(255, 0, 0, 255))
            d.text((b[0] + 2, b[1] + 1), str(i), fill=(255, 255, 0, 255))
        bg.save(out)
    for root in (OUT, KIT):
        os.makedirs(root, exist_ok=True)
        clean(root)
    made = {}
    for i, (name, k) in PIECES.items():
        made[name] = scaled(sheet.crop(boxes[i]), k)
    mid, end = side_walls(made.pop("cap"), made["wall_s"])
    made["side_wall"] = mid
    made["side_wall_end"] = end
    sheet2 = Image.open(SRC2).convert("RGBA")
    lab2, found2 = components_labeled(sheet2)
    for i, (name, k, _) in PIECES2.items():
        box, label = found2[i]
        made[name] = scaled(own_piece(sheet2, lab2, box, label), k)
    soft = {"shadow_m": shadow(28, 8), "shadow_l": shadow(44, 10), "shadow_s": shadow(18, 6),
            "wall_shadow": wall_shadow()}
    items = []
    for name, im in list(made.items()) + list(soft.items()):
        cat = category(name)
        os.makedirs(os.path.join(KIT, folder(cat)), exist_ok=True)
        path = os.path.join(KIT, folder(cat), name)
        if name in soft:
            save_rgba(im, path)  # semi-transparent: plain RGBA, still tiny
        else:  # walls keep their bright lights with a bigger palette
            save_indexed(im, path, 64 if cat == "Walls" else 48)
        items.append(kit_item(name, im, cat))
    with open(os.path.join(KIT, "kit.json"), "w", encoding="utf-8") as f:
        json.dump({"name": "Pixel Lab", "items": items}, f, indent=1)
    save_indexed(floor_atlas(), os.path.join(OUT, "floor"), 32)
    total = 0
    count = 0
    for root in (OUT, KIT):
        for dirpath, _, files in os.walk(root):
            for fn in files:
                if fn.endswith(".png"):
                    total += os.path.getsize(os.path.join(dirpath, fn))
                    count += 1
    print("pixel lab kit -> %s + floor atlas (%d files, %.1f KB)" % (os.path.normpath(KIT), count, total / 1024))


if __name__ == "__main__":
    main()
