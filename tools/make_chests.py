"""Cofres de exploración (mundo 1, prototipo): recorta los 12 cofres de la hoja.

python tools/make_chests.py
Lee tools/chests_ref.webp (3 filas x 4 cofres sobre transparente) y escribe
assets/sprites/chests/chest_<n>.png (n = 1..12, por filas, recortados y a 160 px de ancho
como máximo). El orden es el de ChestData.CHESTS (scripts/data/chest_data.gd).
"""
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "chests_ref.webp")
OUT = os.path.join(ROOT, "assets", "sprites", "chests")
MAX_W = 160


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    a = (np.array(img)[..., 3] > 20).astype(np.uint8)
    n, _lab, st, _c = cv2.connectedComponentsWithStats(a, 8)
    boxes = [tuple(st[i][:4]) for i in range(1, n) if st[i][4] > 2000]
    # rows by y (three bands), then left to right
    boxes.sort(key=lambda b: (round(b[1] / 300), b[0]))
    os.makedirs(OUT, exist_ok=True)
    for i, (x, y, w, h) in enumerate(boxes):
        c = img.crop((x - 2, y - 2, x + w + 2, y + h + 2))
        if c.width > MAX_W:
            c = c.resize((MAX_W, round(c.height * MAX_W / c.width)), Image.LANCZOS)
        c.save(os.path.join(OUT, "chest_%d.png" % (i + 1)))
        print("chest_%d" % (i + 1), c.size)


if __name__ == "__main__":
    main()
