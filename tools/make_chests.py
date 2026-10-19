"""Cofres de exploración: recorta los 12 cofres (cerrado y abierto) de la hoja del usuario.

python tools/make_chests.py
Lee tools/chests2_ref.webp (4 filas x 3 parejas cerrado|abierto sobre transparente) y escribe
assets/sprites/chests/chest_<n>.png (cerrado) y chest_<n>_open.png (abierto), n = 1..12 por
filas y parejas, a MAX_W px de ancho como máximo, PNG de paleta (COLORS) optimizado. El orden es el de
ChestData.CHESTS (scripts/data/chest_data.gd): botiquín, escudo, munición, XP, velocidad,
monedas, corazón, dron, cohete, imán, radiactivo, vórtice.
Las columnas están separadas por huecos vacíos; dentro de una columna los cofres abiertos se
tocan (la tapa sube), así que cada columna se corta por su línea más vacía cerca de cada
fila (BANDS, SEARCH) y cada cofre se recorta con sus piezas (destellos, cruces).
La hoja vieja tools/chests_ref.webp ya no se usa.
"""
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "chests2_ref.webp")
OUT = os.path.join(ROOT, "assets", "sprites", "chests")
MAX_W = 112  # in game a chest is ~28 units wide; the HUD cards show it bigger
PAD = 2
BANDS = [300, 535, 765]  # rough y between rows: each column is cut at its emptiest line near them
SEARCH = 70  # px around each band to look for that line
MIN_PIECE = 12  # px: smaller specks are dropped
COLORS = 128  # palette PNG (alpha kept): ~4x smaller than RGBA


def columns(alpha: np.ndarray) -> list:
    """x ranges of the 6 columns (separated by fully empty strips)."""
    filled = (alpha > 20).sum(0) > 0
    out, start = [], None
    for x, f in enumerate(filled):
        if f and start is None:
            start = x
        if not f and start is not None:
            if x - start > 40:
                out.append((start, x))
            start = None
    if start is not None:
        out.append((start, len(filled)))
    return out


def cuts(strip: np.ndarray) -> list:
    """y of the emptiest line near each band in this column (open lids touch the row above)."""
    filled = strip.sum(1)
    out = [0]
    for b in BANDS:
        lo, hi = b - SEARCH, b + SEARCH
        out.append(lo + int(np.argmin(filled[lo:hi])))
    out.append(strip.shape[0])
    return out


def _on_cut(stat, top: int, bot: int) -> bool:
    return stat[1] <= top + 1 or stat[1] + stat[3] >= bot - 1


def save(crop: Image.Image, path: str) -> None:
    if crop.width > MAX_W:
        crop = crop.resize((MAX_W, round(crop.height * MAX_W / crop.width)), Image.LANCZOS)
    crop.quantize(COLORS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(path, optimize=True)
    print(os.path.basename(path), crop.size)


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    rgba = np.array(img)
    alpha = rgba[..., 3]
    cols = columns(alpha)
    assert len(cols) == 6, cols
    os.makedirs(OUT, exist_ok=True)
    for ci, (x0, x1) in enumerate(cols):
        strip = (alpha[:, x0:x1] > 20).astype(np.uint8)
        ys_cut = cuts(strip)
        for row in range(4):
            part = strip.copy()
            part[:ys_cut[row]] = 0
            part[ys_cut[row + 1]:] = 0
            n, lab, st, _cen = cv2.connectedComponentsWithStats(part, 8)
            big = max(range(1, n), key=lambda i: st[i][4]) if n > 1 else 0
            # slivers of the neighbouring chest that cross a cut line go; the chest itself and
            # its sparkles stay
            keep = [i for i in range(1, n) if st[i][4] >= MIN_PIECE and (i == big or not _on_cut(st[i], ys_cut[row], ys_cut[row + 1]))]
            if not keep:
                continue
            mask = np.isin(lab, keep)
            ys, xs = np.nonzero(mask)
            top, bot = max(ys.min() - PAD, 0), ys.max() + PAD + 1
            left, right = max(xs.min() - PAD, 0), xs.max() + PAD + 1
            piece = rgba[:, x0:x1].copy()
            piece[..., 3] = np.where(mask, piece[..., 3], 0)
            n_chest = row * 3 + ci // 2 + 1
            name = "chest_%d%s.png" % (n_chest, "_open" if ci % 2 else "")
            save(Image.fromarray(piece[top:bot, left:right]), os.path.join(OUT, name))

if __name__ == "__main__":
    main()
