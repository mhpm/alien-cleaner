"""Builds the MUTATION LAB screen assets from tools/mutation_lab_ref.webp (941x1672).

Usage: python tools/make_lab_assets.py
- assets/ui/lab/bg.webp: the art with its live parts erased (bank amount, the hint
  box, the mode name and stat lines, the progress fill and count, each card's price
  and check / lock, the MUTATE subtitle and the big mutant on the pedestal).
- assets/ui/lab/look_<n>.png (1-5): the 5 mutation guns, from
  assets/sprites/mutations_player/mutation_guns/guns_elements/gun_<n>.png. The painted portraits are cleared off the cards;
  the screen draws these instead (on the cards and large on the pedestal).
- The art has 2 rows of 5 cards (10 levels); the lab now sells 5 guns, so each column
  becomes one card a bit taller than the painted ones (the top of the row-1 card with
  "Lv n", its middle stretched, the bottom of the row-2 card with the price band) and
  the space left below is cleared for the power-name plates the screen draws.
- assets/ui/lab/btn_<name>.png: close, back, mutate.
Rects are mirrored in scripts/lab_screen.gd.
"""
import os

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui", "lab")

COLS = [(50, 208), (220, 378), (390, 546), (555, 718), (732, 893)]
ROWS = [(977, 1194), (1208, 1430)]
BUTTONS = {"close": (30, 48, 100, 114), "back": (98, 1492, 392, 1622), "mutate": (458, 1466, 868, 1642)}
HERO = (330, 300, 612, 592)  # the painted mutant on the pedestal
LOOKS = os.path.join(HERE, "..", "assets", "sprites", "mutations_player", "mutation_guns",
                     "guns_elements", "gun_%d.png")
PHASES = 5
TALL = (ROWS[0][0], 1240)        # one card per column (mirrored in lab_screen.gd)
BELOW = (1246, 1436)             # cleared for the power plates
HEAD, FOOT = 64, 56               # rows kept from the top card / bottom card

ERASE = [
    (478, 208, 608, 248),     # bank amount ("17 coins")
    (192, 620, 764, 688),     # hint text
    (104, 728, 640, 768),     # mode name
    (150, 770, 640, 876),     # stat lines (icons kept)
    (778, 910, 878, 954),     # "4/10"
    (512, 1566, 830, 1604),   # "UPGRADE SELECTED LEVEL"
]


def cards():
    for y0, y1 in ROWS:
        for x0, x1 in COLS:
            yield x0, y0, x1, y1


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
    src = np.asarray(Image.open(os.path.join(HERE, "mutation_lab_ref.webp")).convert("RGB")).copy()
    for n in range(1, PHASES + 1):
        img = Image.open(LOOKS % n).convert("RGBA")
        img.crop(img.getbbox()).save(os.path.join(OUT, f"look_{n}.png"))
    for f in os.listdir(OUT):  # looks of the old 10-level lab
        if f.startswith("look_") and f.split("_")[1].split(".")[0].isdigit()                 and int(f.split("_")[1].split(".")[0]) > PHASES:
            os.remove(os.path.join(OUT, f))
    a = src.copy()
    # clear the painted portraits (the screen draws the looks there)
    reg = src[1020:1140, 60:200].reshape(-1, 3)  # the Lv 1 card's navy fill, for every card
    fill = np.median(reg[(reg.max(axis=1) < 60) & (reg[:, 2] > reg[:, 0])], axis=0).astype(np.uint8)
    for x0, y0, x1, y1 in cards():
        a[y0 + 36:y1 - 48, x0 + 7:x1 - 7] = fill
    for box in ERASE:
        erase(a, box)
    # flat dark fills (a gradient between the edges would pick up the coloured borders)
    reg = src[922:944, 560:760].reshape(-1, 3)  # progress bar: empty track
    a[918:947, 207:764] = np.median(reg[reg.max(axis=1) < 70], axis=0).astype(np.uint8)
    reg = src[1152:1184, 782:885].reshape(-1, 3)  # a locked card's price band
    band = np.median(reg[reg.max(axis=1) < 70], axis=0).astype(np.uint8)
    for x0, y0, x1, y1 in cards():
        by = y1 - 44  # price band: keep the coin, clear the number and the check / lock
        a[by:y1 - 10, x0 + 50:x1 - 12] = band
    # one tall card per column
    (r0, r1), (s0, s1) = ROWS
    for x0, x1 in COLS:
        top = a[r0:r0 + HEAD, x0 - 4:x1 + 4].copy()
        mid = a[r0 + HEAD:r1 - FOOT, x0 - 4:x1 + 4].copy()
        bot = a[s1 - FOOT:s1, x0 - 4:x1 + 4].copy()
        h = TALL[1] - TALL[0] - HEAD - FOOT
        mid = np.asarray(Image.fromarray(mid).resize((mid.shape[1], h), Image.NEAREST))
        a[TALL[0]:TALL[1], x0 - 4:x1 + 4] = np.concatenate([top, mid, bot])
    # the old second row: the cards' navy (the power plates are drawn on top)
    a[BELOW[0]:BELOW[1], COLS[0][0] - 6:COLS[-1][1] + 6] = (fill * 0.8).astype(np.uint8)
    # the pedestal mutant: rebuilt from its surroundings (the selected look goes on top)
    x0, y0, x1, y1 = HERO
    mask = np.zeros(a.shape[:2], np.uint8)
    mask[y0:y1, x0:x1] = 255
    a = cv2.inpaint(a, mask, 15, cv2.INPAINT_TELEA)
    Image.fromarray(a).save(os.path.join(OUT, "bg.webp"), quality=92)
    for name, box in BUTTONS.items():
        Image.fromarray(a).crop(box).save(os.path.join(OUT, f"btn_{name}.png"))
    print("ok")


if __name__ == "__main__":
    main()
