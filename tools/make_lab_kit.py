"""Kit de laboratorio del mundo 1 (EXPLORE): recorta cada pieza suelta de la hoja.

python tools/make_lab_kit.py
Lee tools/lab_kit_ref.webp (piezas sobre transparente) y escribe
assets/sprites/lab/lab_NNN.png (NNN por filas de arriba abajo y de izquierda a derecha)
+ tools/lab_kit_index.png (cada pieza con su número, para elegir cuál usar).
Piezas pequeñas sueltas (astillas, cristales) se juntan con la pieza grande más cercana
si están a menos de MERGE px; las que quedan solas y son mínimas se descartan.
"""
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "lab_kit_ref.webp")
OUT = os.path.join(ROOT, "assets", "sprites", "lab")
INDEX = os.path.join(ROOT, "tools", "lab_kit_index.png")
FLOOR = os.path.join(ROOT, "assets", "arena", "lab_floor_atlas.png")
# floor pieces 0..10 -> one row of 64 px tiles; groups used by Explore to mix them
FLOOR_TILES = 11
MIN_AREA = 120
ROW_H = 40  # pieces whose tops are this close share a row for numbering


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    a = (np.array(img)[..., 3] > 24).astype(np.uint8)
    n, lab, st, _c = cv2.connectedComponentsWithStats(a, 8)
    boxes = [tuple(int(v) for v in st[i][:4]) + (i,) for i in range(1, n) if st[i][4] >= MIN_AREA]
    # reading order: rows by top edge, then x
    boxes.sort(key=lambda b: (b[1] // ROW_H, b[0]))
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("lab_") and f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    arr = np.array(img)
    idx = Image.new("RGBA", img.size, (30, 34, 52, 255))
    idx.alpha_composite(img)
    d = ImageDraw.Draw(idx)
    for k, (x, y, w, h, comp) in enumerate(boxes):
        piece = arr[y:y + h, x:x + w].copy()
        piece[..., 3] = np.where(lab[y:y + h, x:x + w] == comp, piece[..., 3], 0)
        Image.fromarray(piece).save(os.path.join(OUT, "lab_%03d.png" % k))
        d.rectangle((x, y, x + w, y + h), outline=(255, 60, 60, 255))
        d.text((x + 2, y + 1), str(k), fill=(255, 255, 0, 255))
    idx.save(INDEX)
    atlas = Image.new("RGBA", (64 * FLOOR_TILES, 64))
    for k in range(FLOOR_TILES):
        t = Image.open(os.path.join(OUT, "lab_%03d.png" % k)).convert("RGBA")
        t = t.crop((2, 2, t.width - 2, t.height - 2)).resize((64, 64), Image.LANCZOS)
        atlas.alpha_composite(t, (64 * k, 0))
    atlas.save(FLOOR)
    print(len(boxes), "pieces ->", OUT)


if __name__ == "__main__":
    main()
