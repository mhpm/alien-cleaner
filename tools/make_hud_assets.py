"""In-level top bar kit: tools/hud_kit_ref.webp -> assets/ui/hud/.

  python tools/make_hud_assets.py

  hp.png      life panel with its heart; the painted red bar is wiped (the game draws it)
  clock.png   middle panel (timer / room)
  coins.png   coin panel with its coin
  pause.png   pause button
  badge.png   winged plate with gems (spare)
  corner_l/r, rod_s/m/l, bit_*.png   loose frame pieces (spare)
All used as 9-slices by Hud (margins in Hud.HUD_SLICE).
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "hud_kit_ref.webp")
OUT = os.path.join(ROOT, "assets", "ui", "hud")

# name: (x0, y0, x1, y1) in the sheet
PIECES = {
    "hp": (12, 167, 565, 327),
    "clock": (587, 167, 936, 327),
    "coins": (956, 168, 1275, 328),
    "pause": (1289, 167, 1435, 323),
    "badge": (485, 381, 964, 602),
    "corner_l": (34, 655, 193, 802),
    "corner_r": (1256, 655, 1414, 802),
    "rod_s": (208, 691, 390, 759),
    "rod_m": (406, 690, 706, 759),
    "rod_l": (730, 690, 1238, 759),
    "bit_tl": (123, 827, 237, 947),
    "bit_tr": (320, 827, 434, 947),
    "bit_cl": (521, 828, 580, 941),
    "bit_cr": (985, 828, 1045, 941),
    "bit_top": (673, 827, 914, 880),
    "bit_gem": (698, 899, 889, 967),
    "bit_sl": (1099, 804, 1162, 954),
    "bit_sr": (1257, 804, 1321, 954),
}
# the hp panel's painted red bar (in the piece): wiped to the panel's dark inside
HP_BAR = (146, 44, 512, 116)


def main():
    os.makedirs(OUT, exist_ok=True)
    src = np.array(Image.open(SRC).convert("RGBA"))
    src[src[..., 3] < 40] = 0
    for name, (x0, y0, x1, y1) in PIECES.items():
        a = src[y0:y1, x0:x1].copy()
        if name == "hp":
            bx0, by0, bx1, by1 = HP_BAR
            box = a[by0:by1, bx0:bx1]
            red = (box[..., 0].astype(int) > 120) & (box[..., 1] < 110)
            ring = a[by0 - 6:by1 + 6, bx0 - 6:bx1 + 6, :3].reshape(-1, 3)
            dark = ring[ring.mean(1) < 40]
            fill = np.median(dark, 0) if len(dark) else np.array([8, 14, 30])
            # grow the red mask a little to eat its anti-aliased edge
            m = red.copy()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
                m |= np.roll(np.roll(red, dy, 0), dx, 1)
            box[m, :3] = fill
            box[m, 3] = 255
        Image.fromarray(a).save(os.path.join(OUT, name + ".png"))
        print(name, a.shape[1], a.shape[0])


if __name__ == "__main__":
    main()
