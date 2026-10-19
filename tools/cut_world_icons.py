"""Iconos de mundos futuros: recorta la hoja del usuario en una pintura por mundo.

python tools/cut_world_icons.py
Lee tools/worlds_9_15_ref.webp (2 filas: 4 + 3 iconos sobre transparente) y escribe
tools/world<n>_ref.webp (n = 9..15, por filas), una por mundo, que
tools/make_world_select_assets.py (WORLD_PICS) convierte en assets/ui/world/world_<n>.png.
Las filas y columnas se tocan: cada corte va por la línea más vacía cerca de donde se espera
(ROW_CUT, COL_CUTS, SEARCH) y cada pieza suelta va al icono donde cae su centro (así los
drones del 13 se quedan con él aunque rocen el corte).
"""
import os

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "worlds_9_15_ref.webp")
FIRST = 9
ROW_CUT = 470
COL_CUTS = [[383, 755, 1124], [518, 995]]  # rough x between icons, per row
SEARCH = 45
PAD = 4


def emptiest(profile: np.ndarray, near: int) -> int:
    lo, hi = max(near - SEARCH, 0), min(near + SEARCH, len(profile))
    return lo + int(np.argmin(profile[lo:hi]))


def main() -> None:
    rgba = np.array(Image.open(SRC).convert("RGBA"))
    solid = (rgba[..., 3] > 20).astype(np.uint8)
    h, w = solid.shape
    yc = emptiest(solid.sum(1), ROW_CUT)
    n_out = FIRST
    for row, (y0, y1) in enumerate([(0, yc), (yc, h)]):
        band = solid[y0:y1]
        xs = [0] + [emptiest(band.sum(0), x) for x in COL_CUTS[row]] + [w]
        # every piece of the band goes to the icon its centre falls in (a drone flying near the
        # cut stays with its icon; the neighbour's chest-to-cut slivers belong to the neighbour)
        n, lab, st, cen = cv2.connectedComponentsWithStats(band, 8)
        for c in range(len(xs) - 1):
            x0, x1 = xs[c], xs[c + 1]
            mine = [i for i in range(1, n) if st[i][4] >= 30 and x0 <= cen[i][0] < x1]
            big = max(mine, key=lambda i: st[i][4])
            # slivers of the other row that cross the row cut go
            keep = [i for i in mine if i == big or (st[i][1] > 1 and st[i][1] + st[i][3] < band.shape[0] - 1)]
            mask = np.isin(lab, keep)
            ys, xs_ = np.nonzero(mask)
            piece = rgba[y0:y1].copy()
            piece[..., 3] = np.where(mask, piece[..., 3], 0)
            crop = piece[max(ys.min() - PAD, 0):ys.max() + PAD + 1, max(xs_.min() - PAD, 0):xs_.max() + PAD + 1]
            out = os.path.join(HERE, "world%d_ref.webp" % n_out)
            Image.fromarray(crop).save(out, lossless=True)
            print(os.path.basename(out), crop.shape[1], "x", crop.shape[0])
            n_out += 1


if __name__ == "__main__":
    main()
