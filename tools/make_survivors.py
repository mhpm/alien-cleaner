"""Supervivientes para rescatar (mapas EXPLORE): recorta las hojas de tripulantes.

python tools/make_survivors.py
Cada hoja de SHEETS trae filas por pares: una fila de tripulantes asustados y debajo la
misma fila felices tras el rescate (con sus marcas de alegría), sobre transparente.
Escribe assets/sprites/survivors/<id>_sad.png y <id>_happy.png recortados por el alfa,
con los pies abajo y a tamaño original (el juego escala los dos estados igual). Quita
los trocitos de los vecinos que tocan el borde de la celda. Los ids son los de
SurvivorData.CREW (scripts/data/survivor_data.gd).
"""
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "survivors")

SHEETS = [
    {"src": "survivors_ref.webp", "cols": [0, 367, 683, 1000, 1332, 1672],
     "rows": [((100, 505), (505, 941), ["pilot", "scientist", "engineer", "medic", "agent"])]},
    {"src": "survivors2_ref.webp", "cols": [0, 243, 459, 683, 910, 1125],
     "rows": [((0, 243), (243, 462), ["ace", "mechanic", "botanist", "comms", "guard"]),
              ((462, 682), (682, 900), ["chef", "navigator", "nurse", "chemist", "miner"])]},
]


def clean(c: Image.Image) -> Image.Image:
    """Drops small pieces touching the cell's edge (neighbours' bits)."""
    arr = np.array(c)
    m = (arr[..., 3] > 20).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
    total = m.sum()
    for i in range(1, n):
        x, y, w, h, area = st[i]
        edge = y == 0 or y + h >= m.shape[0] or x == 0 or x + w >= m.shape[1]
        if edge and area < total * 0.04:
            arr[lab == i, 3] = 0
    return Image.fromarray(arr)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for sh in SHEETS:
        img = Image.open(os.path.join(ROOT, "tools", sh["src"])).convert("RGBA")
        cols = sh["cols"]
        for sad, happy, ids in sh["rows"]:
            for state, (y0, y1) in (("sad", sad), ("happy", happy)):
                for i, cid in enumerate(ids):
                    c = clean(img.crop((cols[i], y0, cols[i + 1], y1)))
                    ys, xs = np.nonzero(np.array(c)[..., 3] > 20)
                    c = c.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
                    c.save(os.path.join(OUT, "%s_%s.png" % (cid, state)))
                    print(cid, state, c.size)


if __name__ == "__main__":
    main()
