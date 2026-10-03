"""Panel RESCUE del HUD (mapas EXPLORE): recorta las piezas de tools/rescue_hud_ref.webp.

python tools/make_rescue_hud.py -> assets/ui/rescue/
  frame.png   marco vacío (9-slice en el HUD)
  icon.png    retrato del astronauta
  label.png   placa "RESCUE"
  count.png   placa del contador, vacía (el número lo dibuja el juego)
  pip_on.png / pip_off.png  tripulante rescatado / por rescatar
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "rescue_hud_ref.webp")
OUT = os.path.join(ROOT, "assets", "ui", "rescue")
PIECES = {"frame": (89, 431, 1270, 191), "icon": (79, 686, 178, 178), "label": (296, 721, 305, 112),
          "count": (636, 721, 220, 112), "pip_on": (575, 910, 100, 121), "pip_off": (750, 910, 101, 121)}


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    os.makedirs(OUT, exist_ok=True)
    for name, (x, y, w, h) in PIECES.items():
        p = img.crop((x - 2, y - 2, x + w + 2, y + h + 2))
        if name == "count":  # wipe the painted "1/5"
            a = np.array(p)
            fill = a[22, 30].copy()
            a[24:a.shape[0] - 24, 26:a.shape[1] - 26] = fill
            p = Image.fromarray(a)
        p.save(os.path.join(OUT, name + ".png"))
        print(name, p.size)


if __name__ == "__main__":
    main()
