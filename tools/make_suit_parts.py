"""Cuts the 8 suits of tools/suits_ref.webp into 6 layered parts each.

Every part is saved on the SAME 300x380 canvas (feet anchor at CANVAS_ANCHOR), so any
mix of parts from different suits stacks perfectly:
  assets/suits/<variant>_<slot>.png
Item icons for the CHARACTER screen are the same parts trimmed:
  assets/ui/character/item_<slot>_<variant>.png
Draw order (back -> front) is LAYERS; scripts use the same order.
"""
import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
OUT = os.path.join(ROOT, "assets", "suits")
ICONS = os.path.join(ROOT, "assets", "ui", "character")

CANVAS = (300, 380)
CANVAS_ANCHOR = (130, 376)  # legs centre / feet
TOP = 140  # source row mapped to canvas y=0

# suit order in the sheet (left -> right) mapped to gear variants
SHEET_ORDER = ["standard", "recon", "heavy", "exploration", "hazard", "stealth", "titan", "final"]
LAYERS = ["backpack", "legs", "armor", "arms", "helmet", "weapon"]


def poly_mask(points):
    m = Image.new("L", CANVAS, 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return np.asarray(m) > 0


def region_masks():
    w, h = CANVAS
    yy, xx = np.mgrid[0:h, 0:w]
    weapon = poly_mask([(166, 186), (300, 186), (300, 312), (206, 312), (192, 288), (166, 288)]) | poly_mask(
        [(142, 196), (166, 190), (166, 232), (142, 232)])
    backpack = ((xx < 50) & (yy < 282)) | ((xx < 86) & (yy >= 140) & (yy < 282))
    helmet = (yy < 150) | ((yy < 184) & (xx >= 100)) | ((yy < 168) & (xx >= 72))
    legs = yy >= 274
    arms = poly_mask([(86, 176), (140, 176), (150, 204), (146, 238), (124, 254), (100, 252), (86, 240)]) | poly_mask(
        [(136, 224), (172, 224), (172, 290), (136, 290)])
    order = [("weapon", weapon), ("backpack", backpack), ("helmet", helmet), ("legs", legs), ("arms", arms)]
    assigned = np.zeros((h, w), bool)
    masks = {}
    for name, m in order:
        masks[name] = m & ~assigned
        assigned |= m
    masks["armor"] = ~assigned
    return masks


def components(fg):
    h, w = fg.shape
    lab = np.zeros((h, w), np.int32)
    comps = []
    for sy in range(h):
        for sx in np.nonzero(fg[sy] & (lab[sy] == 0))[0]:
            if lab[sy, sx]:
                continue
            idx = len(comps) + 1
            q = deque([(sy, sx)])
            lab[sy, sx] = idx
            n, x0, x1 = 0, sx, sx
            while q:
                y, x = q.popleft()
                n += 1
                x0, x1 = min(x0, x), max(x1, x)
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = idx
                        q.append((ny, nx))
            comps.append((n, x0, x1, idx))
    return lab, sorted([c for c in comps if c[0] > 5000], key=lambda c: c[1])


def main():
    os.makedirs(OUT, exist_ok=True)
    src = np.asarray(Image.open(os.path.join(HERE, "suits_ref.webp")).convert("RGBA")).copy()
    alpha = src[:, :, 3]
    src[alpha < 60] = 0
    lab, comps = components(src[:, :, 3] > 100)
    assert len(comps) == 8, len(comps)
    masks = region_masks()
    for (n, x0, x1, idx), variant in zip(comps, SHEET_ORDER):
        own = src.copy()
        # keep this suit's pixels (plus faint edge pixels next to it)
        body = lab == idx
        grown = body.copy()
        grown[1:] |= body[:-1]; grown[:-1] |= body[1:]; grown[:, 1:] |= body[:, :-1]; grown[:, :-1] |= body[:, 1:]
        own[~grown] = 0
        feet = body[470:518]
        xs = np.nonzero(feet.any(axis=0))[0]
        cx = (xs.min() + xs.max()) / 2.0
        left = int(round(cx - CANVAS_ANCHOR[0]))
        canvas = np.zeros((CANVAS[1], CANVAS[0], 4), np.uint8)
        sx0, sx1 = max(0, left), min(src.shape[1], left + CANVAS[0])
        canvas[:, sx0 - left:sx1 - left] = own[TOP:TOP + CANVAS[1], sx0:sx1]
        for slot, m in masks.items():
            part = canvas.copy()
            part[~m] = 0
            img = Image.fromarray(part, "RGBA")
            img.save(os.path.join(OUT, f"{variant}_{slot}.png"))
            # the torso is mostly hidden behind the arms: its icon shows torso + arms
            icon_mask = (m | masks["arms"] | masks["backpack"]) if slot == "armor" else m
            icon = canvas.copy()
            icon[~icon_mask] = 0
            icon_img = Image.fromarray(icon, "RGBA")
            bbox = icon_img.getbbox()
            if bbox:
                icon_img.crop(bbox).save(os.path.join(ICONS, f"item_{slot}_{variant}.png"))
    print("ok")


if __name__ == "__main__":
    main()
