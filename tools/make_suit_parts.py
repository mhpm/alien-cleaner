"""Cuts the equipment sheet tools/suit_pieces_ref.webp.

The sheet is a grid: 8 columns (suits, SHEET_ORDER) x 9 rows (ROWS). The astronaut in
game always uses the reference-sheet sprite; only the blaster changes, so this makes:
  assets/suits/<variant>_weapon.png   the rifle of each suit (trimmed + PAD)
  assets/suits/weapons.json           {variant: {size, grip, tip}} in image pixels
                                      (the Astronaut rotates it around the grip,
                                      bullets leave the tip)
  assets/ui/character/item_<slot>_<variant>.png   CHARACTER icons, pieces as drawn on
                                      the sheet (pairs kept for arms / boots)
  assets/ui/character/preview_astronaut.png   the CHARACTER screen astronaut: the first
                                      (standard) suit of tools/suits_ref.webp, whole
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
OUT = os.path.join(ROOT, "assets", "suits")
ICONS = os.path.join(ROOT, "assets", "ui", "character")

SHEET_ORDER = ["standard", "recon", "heavy", "exploration", "hazard", "stealth", "titan", "final"]
# row name, y0, y1 (sheet pixels; a piece belongs to the row holding its centroid)
ROWS = [("helmet", 0, 120), ("armor", 120, 220), ("arms_a", 220, 299), ("arms_b", 299, 378),
        ("boots", 378, 470), ("backpack", 470, 580), ("rifle", 580, 652), ("gun_m", 652, 721),
        ("pistols", 721, 844)]
COL_W = 1125 / 8.0
PAD = 2
MIN_PIECE = 600  # px; smaller blobs are sparkles/spikes merged into the nearest piece


def label(fg):
    """Connected components (4-neighbour) with min-label propagation + pointer jumping."""
    h, w = fg.shape
    big = h * w + 1
    lab = np.where(fg, np.arange(h * w).reshape(h, w), big)
    while True:
        prev = lab.copy()
        for _ in range(8):
            lab[1:] = np.minimum(lab[1:], np.where(fg[1:], lab[:-1], big))
            lab[:-1] = np.minimum(lab[:-1], np.where(fg[:-1], lab[1:], big))
            lab[:, 1:] = np.minimum(lab[:, 1:], np.where(fg[:, 1:], lab[:, :-1], big))
            lab[:, :-1] = np.minimum(lab[:, :-1], np.where(fg[:, :-1], lab[:, 1:], big))
            lab = np.where(fg, lab, big)
        flat = lab.ravel()
        m = flat < big
        jumped = flat.copy()
        jumped[m] = flat[flat[m]]
        lab = jumped.reshape(h, w)
        if (lab == prev).all():
            return np.where(fg, lab, -1)


def row_of(y):
    for i, (_, y0, y1) in enumerate(ROWS):
        if y0 <= y < y1:
            return i
    return len(ROWS) - 1


def split_pieces(src):
    """{(row, col): [mask, ...]} with each list sorted left -> right."""
    fg = src[:, :, 3] > 40
    lab = label(fg)
    ids, counts = np.unique(lab[fg], return_counts=True)
    yy, xx = np.mgrid[0:fg.shape[0], 0:fg.shape[1]]
    big, small = [], []
    for i, n in zip(ids, counts):
        m = lab == i
        ys = yy[m]
        # a blob spanning two rows (titan helmet touching its torso) is cut at the row line
        r0, r1 = row_of(ys.min()), row_of(ys.max())
        parts = [m] if r0 == r1 or ys.max() - ys.min() < 140 else [m & (yy < ROWS[r1][1]), m & (yy >= ROWS[r1][1])]
        for p in parts:
            (big if p.sum() >= MIN_PIECE else small).append(p)
    cells = {}
    for m in big:
        cy, cx = yy[m].mean(), xx[m].mean()
        cells.setdefault((row_of(cy), int(cx // COL_W)), []).append(m)
    for key in cells:
        cells[key].sort(key=lambda m: xx[m].mean())
    # sparkles / detached bits join the nearest piece of their cell
    for m in small:
        cy, cx = yy[m].mean(), xx[m].mean()
        cand = cells.get((row_of(cy), int(cx // COL_W)), [])
        best, best_d = None, 1e9
        for k, pm in enumerate(cand):
            ys, xs = np.nonzero(pm)
            d = np.min(np.abs(ys - cy) + np.abs(xs - cx))
            if d < best_d:
                best, best_d = k, d
        if best is not None and best_d < 25:
            cand[best] |= m
    return cells


def grow(m):
    g = m.copy()
    g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
    return g


def cut(src, mask):
    """Trimmed RGBA piece + its top-left in sheet coords."""
    m = grow(mask)
    ys, xs = np.nonzero(m)
    x0, y0, x1, y1 = xs.min() - PAD, ys.min() - PAD, xs.max() + 1 + PAD, ys.max() + 1 + PAD
    x0, y0 = max(0, x0), max(0, y0)
    piece = src[y0:y1, x0:x1].copy()
    piece[~m[y0:y1, x0:x1]] = 0
    return piece, (x0, y0)


def centroid(sel):
    ys, xs = np.nonzero(sel)
    return [float(xs.mean()), float(ys.mean())]


def rows_band(a, frm, n):
    """Mask of the opaque pixels in n rows starting at the top ('top') or bottom."""
    ys = np.nonzero(a.any(axis=1))[0]
    band = np.zeros_like(a)
    if frm == "top":
        band[ys.min():ys.min() + n] = a[ys.min():ys.min() + n]
    else:
        band[ys.max() - n + 1:ys.max() + 1] = a[ys.max() - n + 1:ys.max() + 1]
    return band


def weapon_joints(piece):
    a = piece[:, :, 3] > 100
    h, w = a.shape
    ys, xs = np.nonzero(a)
    right = a & (np.arange(w)[None, :] >= xs.max() - 6)
    tip = [float(xs.max()), centroid(right)[1]]
    # pistol grip: lowest opaque pixels of the rear 45%, slightly up into the hand
    rear = a & (np.arange(w)[None, :] < xs.min() + (xs.max() - xs.min()) * 0.45)
    g = centroid(rows_band(rear, "bottom", 16))
    return {"grip": [g[0], g[1] - 6.0], "tip": tip}


def main():
    os.makedirs(OUT, exist_ok=True)
    src = np.asarray(Image.open(os.path.join(HERE, "suit_pieces_ref.webp")).convert("RGBA")).copy()
    src[src[:, :, 3] < 20] = 0
    cells = split_pieces(src)
    pairs = {"arms_a", "arms_b", "boots", "pistols"}
    for (r, c), masks in cells.items():
        assert len(masks) == (2 if ROWS[r][0] in pairs else 1), (ROWS[r][0], c, len(masks))
    assert len(cells) == len(ROWS) * 8, len(cells)
    row_idx = {name: i for i, (name, _, _) in enumerate(ROWS)}
    icons = {"helmet": "helmet", "armor": "armor", "arms": "arms_a", "legs": "boots",
             "backpack": "backpack", "weapon": "rifle"}
    # only the blasters live in assets/suits
    for f in os.listdir(OUT):
        os.remove(os.path.join(OUT, f))
    weapons = {}
    for col, variant in enumerate(SHEET_ORDER):
        piece, _ = cut(src, cells[(row_idx["rifle"], col)][0])
        Image.fromarray(piece, "RGBA").save(os.path.join(OUT, f"{variant}_weapon.png"))
        info = {"size": [piece.shape[1], piece.shape[0]]}
        info.update({j: [round(v, 1) for v in p] for j, p in weapon_joints(piece).items()})
        weapons[variant] = info
        for slot, row in icons.items():
            union = np.zeros(src.shape[:2], bool)
            for m in cells[(row_idx[row], col)]:
                union |= m
            icon, _ = cut(src, union)
            Image.fromarray(icon, "RGBA").save(os.path.join(ICONS, f"item_{slot}_{variant}.png"))
    # CHARACTER preview: the left-most full suit of suits_ref.webp (feet = bottom centre)
    ref = np.asarray(Image.open(os.path.join(HERE, "suits_ref.webp")).convert("RGBA")).copy()
    ref[ref[:, :, 3] < 20] = 0
    fg = ref[:, :, 3] > 100
    lab = label(fg)
    ids, counts = np.unique(lab[fg], return_counts=True)
    suits = [i for i, n in zip(ids, counts) if n > 5000]
    first = min(suits, key=lambda i: np.nonzero(lab == i)[1].min())
    piece, _ = cut(ref, lab == first)
    Image.fromarray(piece, "RGBA").save(os.path.join(ICONS, "preview_astronaut.png"))
    with open(os.path.join(OUT, "weapons.json"), "w") as f:
        json.dump(weapons, f, indent=1)
    print("ok")


if __name__ == "__main__":
    main()
