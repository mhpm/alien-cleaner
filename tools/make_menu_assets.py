"""Builds main-menu assets from tools/main_menu_ref.webp (941x1672).

- assets/ui/menu_bg.webp: full art with the coin number and the best/runs line
  erased (they are drawn live by main_menu.gd).
- assets/ui/btn_<name>.png: every button cropped so it can react to touches.
Button rects are mirrored in scripts/main_menu.gd (BUTTONS).
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui")

BUTTONS = {
    "play": (208, 1098, 736, 1246),
    "upgrades": (243, 1250, 701, 1369),
    "characters": (205, 1393, 362, 1537),
    "achievements": (392, 1393, 562, 1537),
    "settings": (598, 1393, 738, 1537),
    "gear": (844, 22, 921, 93),
}

# areas repainted by interpolating each row between its left and right edge
ERASE = [
    (712, 36, 806, 80),     # coin count
    (318, 1560, 664, 1598),  # "BEST: ROOM ... RUNS: ..."
]


def erase(a, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        left = a[y, x0 - 1].astype(float)
        right = a[y, x1].astype(float)
        for x in range(x0, x1):
            k = (x - x0) / float(x1 - x0)
            a[y, x] = (left * (1 - k) + right * k).astype(np.uint8)


def main():
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(os.path.join(HERE, "main_menu_ref.webp")).convert("RGB")
    for name, box in BUTTONS.items():
        src.crop(box).save(os.path.join(OUT, f"btn_{name}.png"))
    a = np.asarray(src).copy()
    for box in ERASE:
        erase(a, box)
    Image.fromarray(a).save(os.path.join(OUT, "menu_bg.webp"), quality=92)
    print("ok", list(BUTTONS))


if __name__ == "__main__":
    main()
