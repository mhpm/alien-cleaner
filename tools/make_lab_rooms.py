"""ZONE ZERO del mapa EXPLORE (mundo 1): agranda la sala pintada y escribe sus datos.

python tools/make_lab_rooms.py   (después de tools/make_lab_pieces.py: usa sus decal_*)
Lee tools/rooms/zone_zero.webp (1536x1024, mismo estilo gris que las salas lab_1..5:
muros en los bordes, una puerta centrada en cada lado y el reactor en el centro) y la
abre por el centro para dar más suelo sin deformar el arte:
  1. borra el reactor del original (suelo encima) para que no quede repetido
  2. rellena el suelo con su baldosa limpia, alineada a su rejilla
  3. alarga los muros con tiras del propio muro
  4. pone las cuatro esquinas con sus muebles en las esquinas del lienzo nuevo
  5. salpica el suelo nuevo con rejillas y manchas de las salas de laboratorio
  6. vuelve a poner el reactor en el centro y las cuatro puertas en cada lado
y recorta al borde exterior del muro. Salida: assets/rooms/zone_zero.webp + .json (size,
doors, wall, solid, spots, start en px de la imagen nueva). Los muebles bloqueados
(FURNITURE) van en px del original y se mueven con su trozo.
"""
import json
import os
import random

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "rooms", "zone_zero.webp")
OUT = os.path.join(ROOT, "assets", "rooms")
DECALS = os.path.join(ROOT, "assets", "rooms", "lab")

TILE_BOX = (1098, 386, 1226, 499)  # a clean floor tile
TILE = (TILE_BOX[2] - TILE_BOX[0], TILE_BOX[3] - TILE_BOX[1])
GROW = (TILE[0] * 4, TILE[1] * 4)  # keeps the room as wide as the lab rooms for its height
BG = (12, 17, 26)
FEATHER = 44
ROOM_BOX = (58, 62, 1478, 908)  # outer edge of the walls (right / bottom move with GROW)
CENTRE = (560, 300, 990, 690)  # the reactor with its goo, re-centred
# corners (stop short of the door frames: plain wall strips fill the rest)
QUADS = {"tl": (0, 0, 632, 392), "tr": (902, 0, 1536, 392),
         "bl": (0, 578, 632, 1024), "br": (902, 578, 1536, 1024)}
FADE = {"tl": "rb", "tr": "lb", "bl": "rt", "br": "lt"}
DOORS = {"top": (636, 20, 904, 210), "bottom": (636, 830, 904, 1000),
         "left": (10, 385, 160, 580), "right": (1380, 385, 1530, 580)}
OPEN_X = (705, 832)  # top / bottom doorway
OPEN_Y = (430, 540)  # left / right doorway
WALL_IN = {"top": 120, "bottom": 848, "left": 118, "right": 1418}  # inner face of the walls
STRIPS = {"top": (380, 55, 440, 120), "bottom": (460, 846, 540, 912),
          "left": (52, 760, 120, 800), "right": (1416, 760, 1484, 800)}
FURNITURE = {
    "tl": [(110, 115, 150, 280), (260, 150, 80, 110), (340, 120, 270, 120), (440, 230, 50, 55)],
    "tr": [(955, 150, 80, 110), (1035, 120, 170, 160), (1195, 135, 110, 145), (1290, 120, 130, 255)],
    "c": [(590, 320, 370, 290)],
    "bl": [(110, 590, 95, 260), (185, 630, 95, 210), (120, 780, 90, 70), (270, 750, 150, 100)],
    "br": [(1150, 720, 95, 110), (1160, 810, 70, 40), (1245, 605, 175, 245)],
}


def feather(img: Image.Image, sides: str) -> Image.Image:
    a = np.array(img.convert("RGBA")).astype(np.float32)
    h, w = a.shape[:2]
    ramp = np.linspace(0.0, 1.0, FEATHER)
    m = np.ones((h, w), np.float32)
    if "l" in sides:
        m[:, :FEATHER] *= ramp[None, :]
    if "r" in sides:
        m[:, w - FEATHER:] *= ramp[::-1][None, :]
    if "t" in sides:
        m[:FEATHER, :] *= ramp[:, None]
    if "b" in sides:
        m[h - FEATHER:, :] *= ramp[::-1][:, None]
    a[..., 3] *= m
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def tile_fill(img: Image.Image, tile: Image.Image, box: tuple) -> None:
    """Floor tiles over `box`, aligned to the painting's grid."""
    ox, oy = TILE_BOX[0] % TILE[0] - TILE[0], TILE_BOX[1] % TILE[1] - TILE[1]
    layer = Image.new("RGBA", img.size)
    for y in range(oy, img.height, TILE[1]):
        for x in range(ox, img.width, TILE[0]):
            layer.paste(tile, (x, y))
    img.paste(layer.crop(box), box[:2])


def shift(part: str, x: float, y: float) -> tuple:
    gx, gy = GROW
    if part == "c":
        return x + gx / 2, y + gy / 2
    return x + (gx if part in ("tr", "br") else 0), y + (gy if part in ("bl", "br") else 0)


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    tile = src.crop(TILE_BOX)
    clean = src.copy()
    tile_fill(clean, tile, CENTRE)  # 1. the reactor out of the original
    gx, gy = GROW
    W, H = src.width + gx, src.height + gy
    out = Image.new("RGBA", (W, H), BG + (255,))
    # 2. floor between the walls
    big = Image.new("RGBA", (W, H))
    tile_fill(big, tile, (0, 0, W, H))
    fl = (WALL_IN["left"], WALL_IN["top"], WALL_IN["right"] + gx, WALL_IN["bottom"] + gy)
    out.paste(big.crop(fl), fl[:2])
    # 3. walls along every side
    st = {k: src.crop(v) for k, v in STRIPS.items()}
    for x in range(ROOM_BOX[0], ROOM_BOX[2] + gx, st["top"].width):
        out.alpha_composite(st["top"], (x, STRIPS["top"][1]))
        out.alpha_composite(st["bottom"], (x, STRIPS["bottom"][1] + gy))
    for y in range(ROOM_BOX[1], ROOM_BOX[3] + gy, st["left"].height):
        out.alpha_composite(st["left"], (STRIPS["left"][0], y))
        out.alpha_composite(st["right"], (STRIPS["right"][0] + gx, y))
    # 4. corners
    for c, box in QUADS.items():
        out.alpha_composite(feather(clean.crop(box), FADE[c]), tuple(int(v) for v in shift(c, box[0], box[1])))
    # 5. decals over the new floor (same style: from the lab rooms)
    rng = random.Random(7)
    names = sorted(f for f in os.listdir(DECALS) if f.startswith("decal_") and f.endswith(".png"))
    keep_out = (CENTRE[0] + gx // 2 - 30, CENTRE[1] + gy // 2 - 30, CENTRE[2] + gx // 2 + 30, CENTRE[3] + gy // 2 + 30)
    for _i in range(10):
        d = Image.open(os.path.join(DECALS, rng.choice(names))).convert("RGBA")
        for _try in range(30):
            x = rng.randint(fl[0] + 200, fl[2] - 200 - d.width)
            y = rng.randint(fl[1] + 200, fl[3] - 200 - d.height)
            if x + d.width < keep_out[0] or x > keep_out[2] or y + d.height < keep_out[1] or y > keep_out[3]:
                out.alpha_composite(d, (x, y))
                break
    # 6. reactor and doors
    out.alpha_composite(feather(src.crop(CENTRE), "lrtb"), (CENTRE[0] + gx // 2, CENTRE[1] + gy // 2))
    at = {"top": (gx // 2, 0), "bottom": (gx // 2, gy), "left": (0, gy // 2), "right": (gx, gy // 2)}
    fade = {"top": "lrb", "bottom": "lrt", "left": "rtb", "right": "ltb"}
    for side, box in DOORS.items():
        out.alpha_composite(feather(src.crop(box), fade[side]), (box[0] + at[side][0], box[1] + at[side][1]))
    bx0, by0, bx1, by1 = ROOM_BOX[0], ROOM_BOX[1], ROOM_BOX[2] + gx, ROOM_BOX[3] + gy
    os.makedirs(OUT, exist_ok=True)
    out.crop((bx0, by0, bx1, by1)).convert("RGB").save(os.path.join(OUT, "zone_zero.webp"), quality=90)

    def r(x, y, w, h):
        return [round(x - bx0), round(y - by0), round(w), round(h)]

    solid = []
    for part, rects in FURNITURE.items():
        for x, y, w, h in rects:
            nx, ny = shift(part, x, y)
            solid.append(r(nx, ny, w, h))
    ox0, ox1 = OPEN_X[0] + gx // 2, OPEN_X[1] + gx // 2
    oy0, oy1 = OPEN_Y[0] + gy // 2, OPEN_Y[1] + gy // 2
    top, bot, left, right = WALL_IN["top"], WALL_IN["bottom"] + gy, WALL_IN["left"], WALL_IN["right"] + gx
    solid += [r(bx0, by0, ox0 - bx0, top - by0), r(ox1, by0, bx1 - ox1, top - by0),
              r(bx0, bot, ox0 - bx0, by1 - bot), r(ox1, bot, bx1 - ox1, by1 - bot),
              r(bx0, by0, left - bx0, oy0 - by0), r(bx0, oy1, left - bx0, by1 - oy1),
              r(right, by0, bx1 - right, oy0 - by0), r(right, oy1, bx1 - right, by1 - oy1)]
    cx, cy = (bx1 - bx0) / 2, (by1 - by0) / 2
    data = {"size": [bx1 - bx0, by1 - by0], "zero": True, "wall": top - by0,
            "doors": {"x": [ox0 - bx0, ox1 - bx0], "y": [oy0 - by0, oy1 - by0]},
            "solid": solid,
            "spots": [[round(cx - 520), round(cy - 200)], [round(cx + 520), round(cy - 200)],
                      [round(cx - 520), round(cy + 220)], [round(cx + 520), round(cy + 220)]],
            "start": [round(cx), round(cy + 330)]}
    with open(os.path.join(OUT, "zone_zero.json"), "w") as f:
        json.dump(data, f, indent=1)
    print("zone_zero", data["size"])


if __name__ == "__main__":
    main()
