"""Builds the world-select screen assets from tools/world_select_ref.webp (941x1672).

Usage: python tools/make_world_select_assets.py
- assets/ui/world/bg.webp: the art with every live value erased (name, level, the
  three counters, the world title, "Longest Survived", the painted START button
  and chest label and the badges / locks of the nav slots that are redrawn in code).
- assets/ui/world/btn_<name>.png: crops for the pressable parts.
- assets/ui/world/world_<n>.png: the isometric picture of each world. World 1 is cut
  out of the art (grabCut) and then removed from bg.webp (the sky behind it is
  rebuilt), so every world picture sits on empty space; the others come from their
  own paintings (WORLD_PICS) or, until they have one, a recoloured world 1 (WORLD_TINTS).
Rects are mirrored in scripts/world_select.gd (BUTTONS / WORLD_RECT).
"""
import os

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui", "world")

BUTTONS = {
    "menu": (22, 166, 130, 274),
    "start": (212, 1222, 732, 1407),  # START_PIC, placed here (not cropped from the art)
    "chest": (367, 995, 561, 1145),   # CHEST_PIC
    "shop": (8, 1478, 178, 1665),
    "gear": (182, 1478, 352, 1665),
    "battle": (358, 1458, 585, 1662),
    "talents": (590, 1478, 765, 1665),
    "lab": (770, 1478, 935, 1665),
    "plus_power": (498, 34, 540, 76),
    "plus_gems": (688, 34, 730, 76),
    "plus_coins": (882, 34, 924, 76),
}
WORLD_RECT = (118, 398, 858, 1012)

# painted over by interpolating each row between its left and right edge
ERASE = [
    (120, 22, 300, 62),      # player name
    (120, 64, 200, 100),     # "Lv. 12"
    (208, 75, 321, 92),      # level bar fill
    (408, 36, 492, 74),      # energy count
    (612, 36, 680, 74),      # gem count
    (800, 36, 876, 74),      # coin count
    (270, 342, 672, 382),    # "Longest Survived: 2m 16s"
    (222, 1196, 722, 1432),  # the painted START button (replaced by START_PIC)
    (380, 1128, 566, 1184),  # "Ch. Chest" label (the new chest is drawn over the old one)
    (40, 1502, 150, 1630),   # shop: lock + label
    (212, 1502, 324, 1630),  # heroes: lock + label
    (872, 1470, 922, 1512),  # lab badge
    (96, 158, 136, 196),     # menu badge
]
# own art for two buttons: a plain PLAY button and the chest (transparent images in tools/)
START_PIC = "start_play_ref.webp"
CHEST_PIC = "chest_ref.png"
# the world title is cut out of textured space: inpainted from its surroundings
TITLE = (168, 186, 796, 289)
# recolour of the world-1 picture for the worlds that have no painting yet:
# hue shift (degrees on OpenCV's 0-180 scale) and saturation / value gain
WORLD_TINTS = {}  # e.g. {n: (hue, sat, val)} recolours world 1 for a world without art
# worlds with their own painting (transparent png/webp in tools/)
WORLD_PICS = {2: "world2_ref.webp", 3: "world3_ref.webp", 4: "world4_ref.webp", 5: "world5_ref.webp", 6: "world6_ref.webp", 7: "world7_ref.webp", 8: "world8_ref.webp"}


def erase(a, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        left = a[y, x0 - 1].astype(float)
        right = a[y, x1].astype(float)
        for x in range(x0, x1):
            k = (x - x0) / float(x1 - x0)
            a[y, x] = (left * (1 - k) + right * k).astype(np.uint8)


def button_picture(name, box):
    """An own image trimmed and scaled to fill `box` (x0, y0, x1, y1) keeping its aspect."""
    img = Image.open(os.path.join(HERE, name)).convert("RGBA")
    img = img.crop(img.getbbox())
    w, h = box[2] - box[0], box[3] - box[1]
    k = min(w / img.width, h / img.height)
    img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(img, ((w - img.width) // 2, (h - img.height) // 2))
    return out


def erase_title(a):
    # refill it with the sky just above, reflected back and forth (stars and the
    # planet's edge carry on naturally), then blend the seam with the row below
    x0, y0, x1, y1 = TITLE
    top, span = y0 - 1, 70
    for i in range(y1 - y0):
        k = i % (2 * span)
        src = top - (k if k < span else 2 * span - k)
        a[y0 + i, x0:x1] = a[src, x0:x1]
    for i in range(8):
        k = (i + 1) / 9.0
        y = y1 - 8 + i
        a[y, x0:x1] = (a[y, x0:x1] * (1 - k) + a[y1, x0:x1] * k).astype(np.uint8)


def clear_world(a, alpha):
    """Rebuild the sky under the world-1 picture: smooth colour from the edges
    (inpainted at 1/4 size), film grain and a few twinkles."""
    x0, y0, x1, y1 = WORLD_RECT
    mask = np.zeros(a.shape[:2], np.uint8)
    mask[y0:y1, x0:x1] = (alpha > 8).astype(np.uint8) * 255
    mask = cv2.dilate(mask, np.ones((9, 9), np.uint8))
    small = cv2.resize(a, None, fx=0.25, fy=0.25, interpolation=cv2.INTER_AREA)
    msmall = cv2.resize(mask, (small.shape[1], small.shape[0]), interpolation=cv2.INTER_NEAREST)
    fill = cv2.inpaint(small, cv2.dilate(msmall, np.ones((3, 3), np.uint8)), 12, cv2.INPAINT_TELEA)
    fill = cv2.resize(fill, (a.shape[1], a.shape[0]), interpolation=cv2.INTER_CUBIC)
    fill = cv2.GaussianBlur(fill, (0, 0), 6).astype(np.float32)
    rng = np.random.default_rng(7)
    fill += rng.normal(0.0, 3.0, fill.shape).astype(np.float32)
    ys, xs = np.nonzero(mask)
    for i in rng.choice(len(xs), 70, replace=False):
        x, y = xs[i], ys[i]
        b = rng.uniform(120, 230)
        fill[y, x] = (b, b, min(255, b + 30))
        if rng.random() < 0.3:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                fill[y + dy, x + dx] = (b * 0.6, b * 0.6, b * 0.7)
    fill = np.clip(fill, 0, 255).astype(np.uint8)
    soft = cv2.GaussianBlur(mask, (0, 0), 3).astype(np.float32)[..., None] / 255.0
    return (a * (1 - soft) + fill * soft).astype(np.uint8)


def own_picture(name):
    """A world painting scaled to fit WORLD_RECT (keeping its aspect), trimmed."""
    img = Image.open(os.path.join(HERE, name)).convert("RGBA")
    img = img.crop(img.getbbox())
    w, h = WORLD_RECT[2] - WORLD_RECT[0], WORLD_RECT[3] - WORLD_RECT[1]
    k = min(w / img.width, h / img.height)
    return np.asarray(img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS))


def cut_world(src):
    """World-1 picture with alpha. The station's thick black outline is traced by
    flooding the sky from the borders (the outline stops it); the filled convex
    hull of what is left, plus grabCut's pick for the slime drips below, is the mask."""
    x0, y0, x1, y1 = WORLD_RECT
    img = np.asarray(src).copy()
    c = img[y0:y1, x0:x1].astype(int)
    ink = cv2.dilate((c.max(axis=2) < 34).astype(np.uint8), np.ones((3, 3), np.uint8))
    free = ((1 - ink) * 255).astype(np.uint8)
    h, w = free.shape
    seen = np.zeros((h + 2, w + 2), np.uint8)
    for px, py in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (0, h // 2), (w - 1, h // 2)]:
        if free[py, px] == 255:
            cv2.floodFill(free, seen, (px, py), 128)
    fg = (free != 128).astype(np.uint8) * 255
    n, lab, stats, _ = cv2.connectedComponentsWithStats(fg)
    if n > 1:
        fg = np.where(lab == 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA])), 255, 0).astype(np.uint8)
    hull = np.zeros_like(fg)
    pts = cv2.findNonZero(fg)
    cv2.fillPoly(hull, [cv2.convexHull(pts)], 255)
    # grabCut adds the drips hanging under the platform
    mask = np.zeros(img.shape[:2], np.uint8)
    bgd = np.zeros((1, 65), np.float64)
    fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(img, cv2.COLOR_RGB2BGR), mask, (x0, y0, x1 - x0, y1 - y0), bgd, fgd, 5, cv2.GC_INIT_WITH_RECT)
    gc = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)[y0:y1, x0:x1]
    alpha = cv2.GaussianBlur(hull | gc, (3, 3), 0)
    return np.dstack([img[y0:y1, x0:x1], alpha])


def tint(rgba, hue, sat, val):
    rgb = np.ascontiguousarray(rgba[:, :, :3])
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.int32)
    slime = (hsv[:, :, 0] > 30) & (hsv[:, :, 0] < 80) & (hsv[:, :, 1] > 120)  # keep the green goo
    hsv[:, :, 0] = np.where(slime, hsv[:, :, 0], (hsv[:, :, 0] + hue) % 180)
    hsv[:, :, 1] = np.clip(hsv[:, :, 1] * sat, 0, 255)
    hsv[:, :, 2] = np.clip(hsv[:, :, 2] * val, 0, 255)
    out = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)
    return np.dstack([out, rgba[:, :, 3]])


def main():
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(os.path.join(HERE, "world_select_ref.webp")).convert("RGB")
    a = np.asarray(src).copy()
    for box in ERASE:
        erase(a, box)
    erase_title(a)
    world = cut_world(src)
    a = clear_world(a, world[:, :, 3])
    clean = Image.fromarray(a)
    clean.save(os.path.join(OUT, "bg.webp"), quality=92)
    own = {"start": START_PIC, "chest": CHEST_PIC}
    for name, box in BUTTONS.items():
        if name in own:
            button_picture(own[name], box).save(os.path.join(OUT, f"btn_{name}.png"))
        else:
            clean.crop(box).save(os.path.join(OUT, f"btn_{name}.png"))
    Image.fromarray(world).save(os.path.join(OUT, "world_1.png"))
    for n, (h, s, v) in WORLD_TINTS.items():
        Image.fromarray(tint(world, h, s, v)).save(os.path.join(OUT, f"world_{n}.png"))
    for n, name in WORLD_PICS.items():
        Image.fromarray(own_picture(name)).save(os.path.join(OUT, f"world_{n}.png"))
    print("ok", list(BUTTONS), "worlds", 1 + len(WORLD_TINTS) + len(WORLD_PICS))


if __name__ == "__main__":
    main()
