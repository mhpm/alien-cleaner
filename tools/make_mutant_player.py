"""El astronauta mutado: los frames del jugador con el casco de la fase de mutación.

python tools/make_mutant_player.py [fase]
Para cada frame de assets/sprites/player/ (idle, walk, walk_up, shoot, hurt) localiza el
casco (la parte de arriba del cuerpo) y pega encima el casco mutado de la fase
(assets/sprites/mutations_player/fase <n>/fase<n>_elements/head_front.png, o head_back.png
en walk_up), escalado al ancho del casco original y apoyado en el cuello. Los frames
salen al mismo lienzo que el jugador con un margen para las púas (PAD) y el mismo
anclaje, en assets/sprites/mutations_player/fase <n>/player/<anim>_<i>.png; los recoge
el set `mutant<n>` de tools/slice_sprites.py (lienzo fijo, sin recortar).
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAYER = os.path.join(ROOT, "assets", "sprites", "player")
ANIMS = {"idle": 4, "walk": 4, "walk_up": 4, "shoot": 2, "hurt": 2}
PAD = 14          # margen extra arriba y a los lados (púas del casco)
HEAD_ROWS = 0.52  # el casco ocupa esta parte de arriba del cuerpo
HEAD_GROW = 1.12  # el casco mutado es algo más ancho que el original (sus púas)


def body_mask(a: np.ndarray) -> np.ndarray:
    """Píxeles del astronauta (sin las chispas rojas de `hurt`)."""
    r, g, b, al = (a[..., k].astype(int) for k in range(4))
    spark = (r > 200) & (g < 120) & (b < 80)
    return (al > 128) & ~spark


def helmet_box(a: np.ndarray) -> tuple:
    m = body_mask(a)
    ys, xs = np.nonzero(m)
    top, bot = ys.min(), ys.max()
    cut = top + int((bot - top) * HEAD_ROWS)
    hy, hx = np.nonzero(m[top:cut])
    return hx.min(), top, hx.max() + 1, cut


def helmet_center(a: np.ndarray) -> float:
    """Centro del casco: solo sus filas de arriba (el arma y los brazos van más abajo)."""
    m = body_mask(a)
    ys, xs = np.nonzero(m)
    top = ys.min()
    hy, hx = np.nonzero(m[top:top + 12])
    return (hx.min() + hx.max() + 1) / 2.0


def paste_head(frame: Image.Image, head: Image.Image, helmet_w: float) -> Image.Image:
    a = np.array(frame)
    x0, y0, x1, y1 = helmet_box(a)
    c0 = helmet_center(a)
    x0, x1 = round(c0 - helmet_w / 2), round(c0 + helmet_w / 2)
    w = helmet_w * HEAD_GROW
    h = head.height * w / head.width
    small = head.resize((max(1, round(w)), max(1, round(h))), Image.LANCZOS)
    s = np.array(small)
    s[..., 3] = np.where(s[..., 3] > 110, 255, 0)
    small = Image.fromarray(s)
    out = Image.new("RGBA", (frame.width + 2 * PAD, frame.height + PAD), (0, 0, 0, 0))
    out.alpha_composite(frame, (PAD, PAD))
    # borra el casco viejo (lo que quede fuera del nuevo no debe asomar)
    o = np.array(out)
    o[PAD + y0:PAD + y1 - 2, PAD + x0:PAD + x1][body_mask(a[y0:y1 - 2, x0:x1])] = 0
    out = Image.fromarray(o)
    cx = PAD + c0
    bottom = PAD + y1 + 1   # apoyado en el cuello
    out.alpha_composite(small, (round(cx - small.width / 2), round(bottom - small.height)))
    return out


def main(n: int) -> None:
    base = os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase %d" % n)
    heads = {k: Image.open(os.path.join(base, "fase%d_elements" % n, "head_%s.png" % k)).convert("RGBA")
             for k in ("front", "back")}
    heads = {k: v.crop(v.getbbox()) for k, v in heads.items()}
    out = os.path.join(base, "player")
    os.makedirs(out, exist_ok=True)
    # ancho del casco: el del reposo (en disparo / daño el arma y las chispas lo inflan)
    idle = [np.array(Image.open(os.path.join(PLAYER, "idle_%d.png" % i)).convert("RGBA")) for i in range(4)]
    helmet_w = float(np.median([helmet_box(x)[2] - helmet_box(x)[0] for x in idle]))
    for anim, count in ANIMS.items():
        for i in range(count):
            f = Image.open(os.path.join(PLAYER, "%s_%d.png" % (anim, i))).convert("RGBA")
            paste_head(f, heads["back" if anim == "walk_up" else "front"], helmet_w).save(
                os.path.join(out, "%s_%d.png" % (anim, i)))
    print("ok", out, "pad", PAD)


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
