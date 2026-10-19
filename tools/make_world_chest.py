"""Cofre de recompensa de la selección de mundo (cofre del mundo y cofre dorado del BOSS
CHALLENGE): recorta el cofre cerrado y el abierto de la hoja del usuario.

python tools/make_world_chest.py
Lee tools/world_chest_ref.webp (cerrado a la izquierda, abierto a la derecha, fondo
transparente) y escribe assets/ui/world/chest_closed.png y chest_open.png, a escala común
(el ancho de la caja es el mismo en los dos: world_select.gd los coloca por el pie) y como
PNG de paleta optimizado.
"""
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "world_chest_ref.webp")
OUT = os.path.join(ROOT, "assets", "ui", "world")
SCALE = 0.42  # sheet px -> output px (closed chest ~270 px wide: crisp at the 194-wide slot)
COLORS = 160


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    a = np.array(img)
    mask = (a[..., 3] > 16).astype(np.uint8)
    half = mask.shape[1] // 2
    for name, x0, x1 in (("chest_closed", 0, half), ("chest_open", half, mask.shape[1])):
        part = mask[:, x0:x1]
        n, lab, st, _c = cv2.connectedComponentsWithStats(part, 8)
        keep = [i for i in range(1, n) if st[i][4] > 40]
        m = np.isin(lab, keep)
        ys, xs = np.nonzero(m)
        crop = a[ys.min():ys.max() + 1, x0 + xs.min():x0 + xs.max() + 1].copy()
        crop[..., 3] = np.where(m[ys.min():ys.max() + 1, xs.min():xs.max() + 1], crop[..., 3], 0)
        im = Image.fromarray(crop)
        im = im.resize((round(im.width * SCALE), round(im.height * SCALE)), Image.LANCZOS)
        im.quantize(COLORS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(
            os.path.join(OUT, name + ".png"), optimize=True)
        print(name, im.size, os.path.getsize(os.path.join(OUT, name + ".png")) // 1024, "KB")


if __name__ == "__main__":
    main()
