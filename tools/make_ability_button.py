"""Empty round button for the in-game ability / mutate buttons (TouchControls).

python tools/make_ability_button.py
assets/room/hud_blast.png (the BLAST button with its comet) -> assets/ui/hud/ability_btn.png:
the same glowing rim, the inside wiped to a dark navy dish so any ability icon (and the
cooldown sweep) reads on it.
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "room", "hud_blast.png")
OUT = os.path.join(ROOT, "assets", "ui", "hud", "ability_btn.png")
INNER = 0.78  # share of the radius wiped (the rim stays)
CENTER_COL = np.array([34, 52, 92])
EDGE_COL = np.array([12, 18, 40])


def main() -> None:
    img = np.array(Image.open(SRC).convert("RGBA")).astype(np.float32)
    h, w = img.shape[:2]
    cy, cx = (h - 1) / 2.0, (w - 1) / 2.0
    r = min(w, h) / 2.0
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.hypot(xx - cx, yy - cy) / (r * INNER)
    inside = d <= 1.0
    k = np.clip(d, 0.0, 1.0)[..., None]
    dish = CENTER_COL * (1.0 - k) + EDGE_COL * k
    soft = np.clip((1.0 - d) / 0.05, 0.0, 1.0)[..., None]  # blend into the rim
    img[..., :3] = np.where(inside[..., None], dish * soft + img[..., :3] * (1.0 - soft), img[..., :3])
    img[..., 3] = np.where(inside, 255.0, img[..., 3])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(img.round().astype(np.uint8)).save(OUT)
    print("ok", OUT)


if __name__ == "__main__":
    main()
