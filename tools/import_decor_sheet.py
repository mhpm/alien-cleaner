"""Cut a sheet of decoration art into Arena Editor kit pieces.

Every separate shape on the sheet (connected alpha; a sheet without transparency gets
its background colour keyed out from the corners) becomes one PNG in
assets/decor/<kit>/<category>/<prefix>_NN.png, ordered top-to-bottom, left-to-right,
and an entry in assets/decor/<kit>/kit.json with sensible defaults you can tune later:

  width   world units: the piece's pixel width x --scale (relative sizes are kept)
  solid   a footprint at the base (--solid), or none for walk-through pieces
  sway    lean in the wind (--sway: trees, bushes, grass)
  fade    see-through when the astronaut is behind it (auto for tall pieces)
  flat    lies on the floor, never sorted with the entities (--flat: puddles, cracks)

Then press the palette's reload (or reopen the project): they show up as
"<Kit> · <Category>" in OBJECTS and in DECOR.

    python tools/import_decor_sheet.py tools/earth_trees_ref.png --kit earth --category Trees --prefix tree --sway --solid
    python tools/import_decor_sheet.py sheet.webp --kit earth --category Rocks --prefix rock --solid --scale 0.25
"""
import argparse
import json
import os

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DECOR = os.path.join(HERE, "..", "assets", "decor")


def key_background(img, tol):
    """Transparent where the sheet shows its background (the corners' colour)."""
    a = np.asarray(img.convert("RGBA")).copy()
    if (a[:, :, 3] < 250).mean() > 0.02:
        return a  # already has transparency
    h, w = a.shape[:2]
    corners = np.array([a[0, 0, :3], a[0, w - 1, :3], a[h - 1, 0, :3], a[h - 1, w - 1, :3]], dtype=np.int32)
    bg = np.median(corners, axis=0)
    dist = np.abs(a[:, :, :3].astype(np.int32) - bg).sum(axis=2)
    a[:, :, 3] = np.where(dist <= tol, 0, a[:, :, 3])
    return a


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet")
    ap.add_argument("--kit", required=True)
    ap.add_argument("--category", default="Misc")
    ap.add_argument("--prefix", default="piece")
    ap.add_argument("--scale", type=float, default=0.33, help="world units per sheet pixel")
    ap.add_argument("--solid", action="store_true", help="give each piece a base footprint")
    ap.add_argument("--sway", action="store_true")
    ap.add_argument("--flat", action="store_true")
    ap.add_argument("--min-area", type=int, default=400, help="ignore specks smaller than this (px)")
    ap.add_argument("--bg-tolerance", type=int, default=40)
    ap.add_argument("--max-side", type=int, default=512, help="downscale bigger pieces to this")
    args = ap.parse_args()

    a = key_background(Image.open(args.sheet), args.bg_tolerance)
    mask = cv2.dilate((a[:, :, 3] > 24).astype(np.uint8), np.ones((5, 5), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(mask)
    comps = [k for k in range(1, n) if st[k, cv2.CC_STAT_AREA] >= args.min_area]
    # reading order: rows of pieces (by their middle), then left to right
    comps.sort(key=lambda k: (round((st[k, cv2.CC_STAT_TOP] + st[k, cv2.CC_STAT_HEIGHT] / 2) / 120), st[k, cv2.CC_STAT_LEFT]))

    kit_dir = os.path.join(DECOR, args.kit)
    cat_dir = os.path.join(kit_dir, args.category.lower().replace(" ", "_"))
    os.makedirs(cat_dir, exist_ok=True)
    kit_path = os.path.join(kit_dir, "kit.json")
    kit = {"name": args.kit.capitalize(), "items": []}
    if os.path.exists(kit_path):
        with open(kit_path) as f:
            kit = json.load(f)
    by_file = {i["file"]: i for i in kit.get("items", [])}

    for i, k in enumerate(comps, 1):
        b = a.copy()
        b[lab != k] = 0
        piece = Image.fromarray(b)
        piece = piece.crop(piece.getbbox())
        w_px, h_px = piece.size
        if max(piece.size) > args.max_side:
            f = args.max_side / max(piece.size)
            piece = piece.resize((round(w_px * f), round(h_px * f)), Image.LANCZOS)
        name = "%s_%02d.png" % (args.prefix, i)
        piece.save(os.path.join(cat_dir, name))
        width = round(w_px * args.scale, 1)
        rel = os.path.relpath(os.path.join(cat_dir, name), kit_dir).replace("\\", "/")
        by_file[rel] = {
            "file": rel, "category": args.category, "width": width,
            "solid": [round(width * 0.3, 1), round(max(4.0, width * 0.12), 1)] if args.solid else None,
            "sway": args.sway, "fade": (h_px > w_px * 1.4 and not args.flat), "flat": args.flat,
        }
        print("  %-28s %4dx%-4d px -> %5.1f units" % (rel, w_px, h_px, width))
    kit["items"] = list(by_file.values())
    with open(kit_path, "w") as f:
        json.dump(kit, f, indent=1)
    print("%d pieces -> %s (kit.json updated)" % (len(comps), os.path.normpath(cat_dir)))


if __name__ == "__main__":
    main()
