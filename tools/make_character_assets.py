"""Builds the CHARACTER (equipment) screen assets from tools/character_ref.webp (1024x1536).

Outputs into assets/ui/character/:
  bg.webp                    full art with every live value erased
  icon_<name>.png            UI icons with their panel background keyed out
  btn_back.png, btn_plus.png touch-reactive crops of baked buttons
  (item icons come from the suits: tools/make_suit_parts.py)
Rects are in art pixels and mirrored in scripts/character_screen.gd.
"""
import colorsys
import os
from collections import deque

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui", "character")

VARIANTS = ["standard", "recon", "heavy", "stealth", "hazard", "exploration", "titan", "final"]

# painted helmet cards (8), in VARIANTS order
CARD_X = [25, 200, 373, 547]
CARD_Y = [877, 1132]

SLOT_ICONS = {  # painted icon for each equipment slot (from the slot frames)
    "arms": (505, 240, 610, 306),
    "backpack": (60, 366, 150, 448),
    "weapon": (548, 382, 652, 448),
    "legs": (78, 503, 187, 588),
    "armor": (522, 503, 632, 588),
}

ICONS = {
    "tab_helmet": (50, 680, 120, 744),
    "tab_armor": (215, 678, 290, 744),
    "tab_arms": (385, 678, 460, 744),
    "tab_legs": (550, 678, 630, 744),
    "tab_backpack": (725, 678, 795, 744),
    "tab_weapon": (890, 678, 980, 744),
    "heart": (706, 190, 748, 230),
    "bolt": (706, 229, 748, 269),
    "damage": (706, 268, 748, 310),
    "lock": (711, 448, 747, 490),
    "wrench": (704, 338, 752, 384),
    "coin": (738, 20, 782, 72),
    "check": (161, 998, 188, 1038),
}

BUTTONS = {"back": (30, 12, 120, 86), "plus_power": (632, 18, 694, 76), "plus_coins": (934, 18, 996, 76)}

ERASE = [  # (x0, y0, x1, y1) repainted by per-row interpolation
    (526, 26, 620, 68),     # energy value
    (800, 26, 905, 68),     # coin value
    (860, 190, 1000, 312),  # stat values
    (32, 822, 420, 866),    # grid header
    (752, 822, 1000, 866),  # detail title
    (752, 1080, 1002, 1168),  # detail description
    (905, 1188, 990, 1310),  # detail stat values
    (240, 536, 498, 598),   # painted astronaut's feet on the platform ring (rows)
]
ERASE_COLUMNS = [(240, 318, 498, 536)]  # painted astronaut (replaced by the live suit rig)


def erase(a, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        left = a[y, x0 - 1].astype(float)
        right = a[y, x1].astype(float)
        for x in range(x0, x1):
            k = (x - x0) / float(x1 - x0)
            a[y, x] = (left * (1 - k) + right * k).astype(np.uint8)


def erase_columns(a, box):
    """Vertical interpolation: keeps the vertical light beam behind the astronaut."""
    x0, y0, x1, y1 = box
    for x in range(x0, x1):
        top = a[y0 - 1, x].astype(float)
        bottom = a[y1, x].astype(float)
        for y in range(y0, y1):
            k = (y - y0) / float(y1 - y0)
            a[y, x] = (top * (1 - k) + bottom * k).astype(np.uint8)


def key_out(img, tol=34):
    """Flood-fill the dark panel background from the crop border and make it transparent."""
    a = np.asarray(img.convert("RGBA")).astype(int)
    h, w = a.shape[:2]
    seen = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        q.append((0, x)); q.append((h - 1, x))
    for y in range(h):
        q.append((y, 0)); q.append((y, w - 1))
    border = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    bg = np.median(border, axis=0)
    while q:
        y, x = q.popleft()
        if seen[y, x]:
            continue
        c = a[y, x, :3]
        # background = close to the panel colour and fairly dark
        if np.abs(c - bg).sum() > tol * 3 or c.max() > 110:
            continue
        seen[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx]:
                q.append((ny, nx))
    a[seen, 3] = 0
    _drop_specks(a, min_px=max(12, (h * w) // 120))
    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    return out.crop(out.getbbox())


def _drop_specks(a, min_px):
    """Remove small opaque islands (frame corners, badge leftovers)."""
    h, w = a.shape[:2]
    lab = np.zeros((h, w), int)
    comps = []
    for sy in range(h):
        for sx in range(w):
            if a[sy, sx, 3] == 0 or lab[sy, sx]:
                continue
            idx = len(comps) + 1
            q = deque([(sy, sx)])
            lab[sy, sx] = idx
            pix = []
            while q:
                y, x = q.popleft()
                pix.append((y, x))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and a[ny, nx, 3] and not lab[ny, nx]:
                            lab[ny, nx] = idx
                            q.append((ny, nx))
            comps.append(pix)
    for pix in comps:
        if len(pix) < min_px:
            for y, x in pix:
                a[y, x, 3] = 0


def recolor(img, variant):
    """Paint a variant of a gear icon: accents are the saturated orange pixels, 'shell' the whites."""
    if variant == "standard":
        return img
    a = np.asarray(img).astype(float) / 255.0
    out = a.copy()
    h, w = a.shape[:2]
    for y in range(h):
        for x in range(w):
            r, g, b, al = a[y, x]
            if al == 0:
                continue
            hh, s, v = colorsys.rgb_to_hsv(r, g, b)
            accent = s > 0.35 and (hh < 0.14 or hh > 0.95)
            shell = s < 0.22 and v > 0.55
            if variant == "recon":
                if accent:
                    hh, s, v = 0.6, 0.08, v * 0.75
            elif variant == "heavy":
                if accent:
                    hh, s = 0.99, min(1, s * 1.1)
                elif shell:
                    hh, s, v = 0.0, 0.12, v * 0.92
            elif variant == "stealth":
                if accent:
                    hh, s, v = 0.33, 0.85, min(1, v * 1.1)
                elif shell:
                    hh, s, v = 0.62, 0.15, v * 0.42
            elif variant == "hazard":
                if accent:
                    hh, s, v = 0.08, 0.9, v * 0.8
                elif shell:
                    hh, s, v = 0.11, 0.75, v * 0.98
            elif variant == "exploration":
                if accent:
                    hh, s = 0.6, min(1, s * 1.05)
            elif variant == "titan":
                if accent:
                    hh, s, v = 0.02, 0.8, v * 0.7
                elif shell:
                    hh, s, v = 0.12, 0.7, v * 0.95
            elif variant == "final":
                if accent:
                    hh, s, v = 0.52, 0.9, min(1, v * 1.15)
                elif shell:
                    hh, s = 0.55, 0.18
            out[y, x, :3] = colorsys.hsv_to_rgb(hh, s, v)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def brighten_grey(img):
    """The unequipped slot icons are drawn greyed out: lift them to a white suit with orange trim."""
    a = np.asarray(img).astype(float) / 255.0
    out = a.copy()
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            r, g, b, al = a[y, x]
            if al == 0:
                continue
            hh, s, v = colorsys.rgb_to_hsv(r, g, b)
            if s > 0.2 and (hh < 0.14 or hh > 0.9):  # faint orange trim
                s, v = 0.85, min(1, v * 1.5)
            else:
                v = min(1, (v - 0.2) * 1.7 + 0.2)
                s *= 0.5
            out[y, x, :3] = colorsys.hsv_to_rgb(hh, s, v)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(os.path.join(HERE, "character_ref.webp")).convert("RGB")
    for name, box in ICONS.items():
        key_out(src.crop(box)).save(os.path.join(OUT, f"icon_{name}.png"))
    for name, box in BUTTONS.items():
        src.crop(box).save(os.path.join(OUT, f"btn_{name}.png"))
    a = np.asarray(src).copy()
    for box in ERASE:
        erase(a, box)
    for box in ERASE_COLUMNS:
        erase_columns(a, box)
    Image.fromarray(a).save(os.path.join(OUT, "bg.webp"), quality=92)
    print("ok")


if __name__ == "__main__":
    main()
