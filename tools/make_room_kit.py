"""Kit de piezas para el interior de las salas EXPLORE (mundo 3: muros, columnas, tanques;
mundo 5: muros con lava, bobinas, reactores, tuberías, cajas).

python tools/make_room_kit.py [w3|w5]
Lee tools/<set>_kit_ref.webp (piezas sueltas sobre transparente) y escribe
assets/rooms/<set>/kit/k_NN.png (NN = orden de lectura por filas, el mismo que usa
RoomKit.KITS[set] en scripts/data/room_kit.gd) + tools/<set>_kit_index.png con cada número.
"""
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw

import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SET = sys.argv[1] if len(sys.argv) > 1 else "w3"
SRC = os.path.join(ROOT, "tools", "%s_kit_ref.webp" % SET)
OUT = os.path.join(ROOT, "assets", "rooms", SET, "kit")
INDEX = os.path.join(ROOT, "tools", "%s_kit_index.png" % SET)


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    a = np.array(img)
    solid = (a[..., 3] > 30) & ~((a[..., 0] > 235) & (a[..., 1] > 235) & (a[..., 2] > 235))
    n, lab, st, _ = cv2.connectedComponentsWithStats(solid.astype(np.uint8), 8)
    boxes = sorted([tuple(int(v) for v in st[i][:4]) + (i,) for i in range(1, n) if st[i][4] > 600],
                   key=lambda b: (b[1] // 80, b[0]))
    os.makedirs(OUT, exist_ok=True)
    idx = img.copy()
    d = ImageDraw.Draw(idx)
    for k, (x, y, w, h, comp) in enumerate(boxes):
        p = a[y:y + h, x:x + w].copy()
        keep = lab[y:y + h, x:x + w] == comp
        keep = cv2.dilate(keep.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
        p[..., 3] = np.where(keep, p[..., 3], 0)
        Image.fromarray(p).save(os.path.join(OUT, "k_%02d.png" % k))
        d.rectangle((x, y, x + w, y + h), outline=(255, 0, 0, 255))
        d.text((x + 3, y + 2), str(k), fill=(255, 0, 0, 255))
    idx.save(INDEX)
    print(len(boxes), "pieces")


if __name__ == "__main__":
    main()
