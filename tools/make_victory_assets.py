"""Builds the "WORLD n CLEARED!" screen assets from tools/victory_ref.webp (1024x1536).

Usage: python tools/make_victory_assets.py
- assets/ui/victory/panel.png: the whole panel with its live parts erased (the world
  number, the three stat values, the four reward slots' icons and counts, the buttons).
- assets/ui/victory/title.png: "CLEARED!" on its own, punched in by the screen.
- assets/ui/victory/reward_<n>.png: the reward icons (coins, gem, chip, chest).
- assets/ui/victory/btn_menu.png / btn_next.png: the two buttons.
Rects are mirrored in scripts/ui/victory_screen.gd.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui", "victory")

TITLE = (196, 640, 836, 756)
SLOTS = [(215, 1110, 350, 1262), (370, 1110, 503, 1262), (525, 1110, 658, 1262), (680, 1110, 813, 1262)]
ICON_H = 108  # icon band at the top of each slot
BUTTONS = {"menu": (136, 1336, 488, 1464), "next": (506, 1330, 890, 1472)}
# painted over by interpolating each row between its left and right edge
ERASE = [
    (640, 572, 724, 642),     # world number
    (640, 834, 792, 880),     # clear time
    (640, 898, 792, 944),     # aliens
    (640, 962, 792, 1008),    # coins
] + [(x0 + 9, y0 + 8, x1 - 9, y1 - 7) for x0, y0, x1, y1 in SLOTS]


def erase(a, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        left = a[y, x0 - 1].astype(float)
        right = a[y, x1].astype(float)
        for x in range(x0, x1):
            k = (x - x0) / float(x1 - x0)
            a[y, x] = (left * (1 - k) + right * k).astype(np.uint8)


def icon(src, slot):
    """The slot's icon on a transparent background (the slot's flat fill removed)."""
    x0, y0, x1, y1 = slot
    c = np.asarray(src.crop((x0 + 9, y0 + 8, x1 - 9, y0 + 8 + ICON_H))).copy()
    ref = c[2, 2, :3].astype(int)  # the slot's dark fill
    d = np.abs(c[:, :, :3].astype(int) - ref).sum(axis=2)
    c[:, :, 3] = np.where(d < 34, 0, 255).astype(np.uint8)
    img = Image.fromarray(c)
    return img.crop(img.getbbox())


def main():
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(os.path.join(HERE, "victory_ref.webp")).convert("RGBA")
    src.crop(TITLE).save(os.path.join(OUT, "title.png"))
    for i, slot in enumerate(SLOTS):
        icon(src, slot).save(os.path.join(OUT, f"reward_{i}.png"))
    for name, box in BUTTONS.items():
        src.crop(box).save(os.path.join(OUT, f"btn_{name}.png"))
    a = np.asarray(src).copy()
    for box in ERASE:
        erase(a, box)
    for x0, y0, x1, y1 in BUTTONS.values():  # the buttons are separate, slid in later
        a[y0:y1, x0:x1, 3] = 0
    Image.fromarray(a).save(os.path.join(OUT, "panel.png"))
    print("ok")


if __name__ == "__main__":
    main()
