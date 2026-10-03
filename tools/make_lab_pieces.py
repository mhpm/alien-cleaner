"""Salas modulares de los mapas EXPLORE (mundo 1 = "lab", mundo 2 = "w2").

python tools/make_lab_pieces.py [lab|w2]   (SETS: pinturas, sala de las puertas, manchas)
Mundo 1: tools/rooms/lab_1..5.webp; mundo 2: tools/rooms/w2_1..8.webp (mismo marco, suelo
más oscuro; sus muebles bloqueados se detectan solos con auto_solid). Las pinturas comparten el mismo marco (1448x1086: muros,
suelo y una puerta centrada en cada lado) y solo cambian los muebles de las esquinas;
la 5 trae las puertas abiertas. Este script las convierte en piezas que el juego combina
para que ninguna sala se repita (LabRoomData / Explore):
  base.webp            sala vacía AMPLIADA (GROW): suelo con la baldosa limpia de la
                       pintura, muros alargados con tiras del muro y las 4 puertas abiertas
  corner_<n>_<c>.png   esquina c (tl, tr, bl, br) de la sala n (1-4) con sus muebles,
                       bordes interiores difuminados sobre el suelo
  door_<side>.png      puerta cerrada (top, bottom, left, right) de la sala 1, para los
                       lados del mapa que no dan a otra sala
  decal_<k>.png        rejillas y manchas sueltas para salpicar el suelo nuevo
  pieces.json          tamaños, posiciones (px de base.webp), rects sólidos por esquina,
                       muros, huecos de puerta y sitios libres para cofres
Todo en assets/rooms/<set>/. Los rects de muebles (FURNITURE, o auto_solid) se dan en px
de la pintura original y aquí se mueven con su esquina.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "rooms")
ROOMS = os.path.join(ROOT, "assets", "rooms")

ART = (1448, 1086)
TILE_BOX = (787, 545, 895, 668)  # a clean floor tile of the painting
TILE = (TILE_BOX[2] - TILE_BOX[0], TILE_BOX[3] - TILE_BOX[1])
GROW = (TILE[0] * 5, TILE[1] * 3)  # keeps the room as wide as ZONE ZERO for its height
BG = (10, 12, 23)
# the room is cut to the outer edge of its walls (painting px; right / bottom grow), so
# two rooms side by side only leave the game's thin seam between their walls
ROOM_BOX = (58, 66, 1390, 950)
FEATHER = 48
# corner crops (px of the painting): far enough in to keep all furniture unfaded
CORNERS = {"tl": (0, 0, 700, 490), "tr": (760, 0, ART[0], 490),
           "bl": (0, 530, 700, ART[1]), "br": (760, 530, ART[0], ART[1])}
FADE = {"tl": "rb", "tr": "lb", "bl": "rt", "br": "lt"}
# door pieces (px of the painting) and the doorway openings
DOORS = {"top": (598, 25, 852, 205), "bottom": (598, 872, 852, 1042),
         "left": (15, 385, 155, 615), "right": (1293, 385, 1433, 615)}
OPEN_X = (655, 795)
OPEN_Y = (455, 590)
# wall bands: top face ends at y 205, bottom starts at 875, left / right walls
WALL = {"top": 205, "bottom": 875, "left": 120, "right": 1330}
WALL_STRIPS = {"top": (812, 40, 892, 210), "bottom": (400, 878, 500, 968),
               "left": (30, 290, 118, 330), "right": (1334, 290, 1422, 330)}
# parts of a corner crop that belong to a doorway frame (painting px): covered with plain
# wall (and background outside it) so only the re-centred doors show
COVER = {"tl": [("top", 560, 700), ("left", 330, 490)], "tr": [("top", 760, 900), ("right", 330, 490)],
         "bl": [("bottom", 560, 700), ("left", 530, 700)], "br": [("bottom", 760, 900), ("right", 530, 700)]}
DECALS = [(1, (283, 548, 393, 622)), (1, (470, 770, 577, 846)), (1, (975, 825, 1050, 885)),
          (2, (335, 655, 420, 735)), (2, (365, 690, 435, 735)), (3, (160, 520, 255, 600)),
          (3, (920, 740, 1000, 800)), (2, (425, 305, 480, 350)), (4, (1195, 390, 1225, 415))]

# world 2 (THE HIVE: same frame, darker floor, alien hatchery): vents and stains of w2_1
W2_DECALS = [(1, (283, 548, 393, 622)), (1, (470, 772, 577, 842)), (1, (1083, 382, 1177, 457)),
             (1, (993, 760, 1082, 835)), (1, (190, 490, 260, 530)), (1, (380, 625, 430, 660)),
             (1, (890, 440, 945, 475)), (2, (920, 745, 1000, 790))]

# world 3 (THE VOID labs: same frame, green goo and purple growth)
W3_DECALS = [(1, (283, 548, 393, 622)), (1, (470, 772, 577, 842)), (1, (1083, 382, 1177, 457)),
             (1, (380, 625, 440, 665)), (2, (890, 440, 960, 490)), (3, (580, 820, 640, 860)),
             (1, (840, 445, 880, 470)), (4, (1180, 545, 1230, 580))]

# room sets: painting file pattern, how many give corners, which one gives the base doors
SETS = {
    "lab": {"src": "lab_%d", "paintings": 4, "doors": 5, "decals": "DECALS", "furniture": "FURNITURE"},
    "w2": {"src": "w2_%d", "paintings": 8, "doors": 1, "decals": "W2_DECALS", "furniture": None},
    "w3": {"src": "w3_%d", "paintings": 8, "doors": 1, "decals": "W3_DECALS", "furniture": None},
}
INTERIOR = (120, 205, 1330, 875)  # floor inside the walls (painting px)
CELL = 22  # auto-solid grid (painting px)
# floor vents of the template (walkable, but dark: auto_solid must not block them)
VENTS = [(280, 545, 400, 625), (465, 765, 585, 850), (1080, 375, 1180, 460), (990, 755, 1090, 840),
         (595, 240, 670, 310), (970, 820, 1055, 890), (1085, 730, 1170, 815), (330, 365, 415, 440),
         (260, 535, 395, 615), (950, 360, 1045, 430), (1065, 630, 1160, 715)]

# blocked furniture, per painting and corner (x, y, w, h in px of the painting)
FURNITURE = {
    1: {"tl": [(285, 130, 280, 170), (385, 270, 50, 50), (120, 200, 150, 125), (125, 325, 95, 110)],
        "tr": [(875, 180, 390, 140), (1255, 215, 80, 130)],
        "bl": [(115, 630, 105, 250), (165, 700, 105, 180), (270, 740, 120, 140)],
        "br": [(1195, 650, 140, 230)]},
    2: {"tl": [(120, 140, 450, 155), (395, 295, 45, 30), (120, 295, 100, 145)],
        "tr": [(820, 130, 505, 175), (1155, 290, 175, 185), (1205, 440, 75, 55), (1178, 485, 40, 55)],
        "bl": [(115, 630, 180, 250), (255, 740, 145, 140)],
        "br": [(1195, 655, 140, 235)]},
    3: {"tl": [(120, 120, 520, 175), (165, 295, 110, 50), (450, 290, 40, 25), (120, 295, 90, 140)],
        "tr": [(860, 140, 470, 160), (1050, 295, 100, 80), (1265, 295, 65, 75)],
        "bl": [(115, 620, 190, 265), (300, 745, 110, 140)],
        "br": [(1170, 615, 165, 270), (995, 740, 225, 145), (890, 795, 105, 90)]},
    4: {"tl": [(120, 130, 485, 190), (440, 295, 50, 30), (125, 320, 95, 125)],
        "tr": [(825, 130, 505, 195), (945, 295, 50, 35)],
        "bl": [(110, 615, 140, 270), (255, 710, 180, 175)],
        "br": [(1175, 575, 160, 310), (1095, 800, 105, 85)]},
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


def cover(img: Image.Image, corner: str, strips: dict) -> Image.Image:
    """Plain wall over the doorway frame bits a corner crop carries."""
    ox, oy = CORNERS[corner][0], CORNERS[corner][1]
    for side, a, b in COVER[corner]:
        st = strips[side]
        sx, sy = WALL_STRIPS[side][0], WALL_STRIPS[side][1]
        if side in ("top", "bottom"):
            img.paste(BG + (255,), (a - ox, 0 if side == "top" else sy - oy + st.height, b - ox, img.height if side == "bottom" else max(0, sy - oy)))
            for x in range(a, b, st.width):
                w = min(st.width, b - x)
                img.paste(st.crop((0, 0, w, st.height)), (x - ox, sy - oy))
        else:
            img.paste(BG + (255,), (0 if side == "left" else sx - ox + st.width, a - oy, max(0, sx - ox) if side == "left" else img.width, b - oy))
            for y in range(a, b, st.height):
                h = min(st.height, b - y)
                img.paste(st.crop((0, 0, st.width, h)), (sx - ox, y - oy))
    return img


def floor_key(img: Image.Image) -> Image.Image:
    """Clears the floor around a decal: pixels close to the crop's border colour (the
    floor) turn transparent, so only the vent / stain is left."""
    a = np.array(img.convert("RGBA")).astype(np.float32)
    edge = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    ref = np.median(edge, axis=0)
    d = np.sqrt(((a[..., :3] - ref) ** 2).sum(-1))
    a[..., 3] = np.clip((d - 14.0) / 26.0, 0.0, 1.0) * 255.0
    return Image.fromarray(a.astype(np.uint8))


def auto_solid(img: Image.Image, box: tuple) -> list:
    """Blocked rects of a corner found from the art: grid cells (CELL px) of the floor
    area that are mostly NOT floor colour (furniture, eggs, dense goo), merged into rects."""
    a = np.array(img.convert("RGB")).astype(np.float32)
    ref = np.median(a[400:700, 600:850].reshape(-1, 3), axis=0)
    obj = np.sqrt(((a - ref) ** 2).sum(-1)) > 42.0
    for vx0, vy0, vx1, vy1 in VENTS:
        obj[vy0:vy1, vx0:vx1] = False
    x0, y0 = max(box[0], INTERIOR[0]), max(box[1], INTERIOR[1])
    x1, y1 = min(box[2], INTERIOR[2]), min(box[3], INTERIOR[3])
    rows = []
    for y in range(y0, y1, CELL):
        run = []
        for x in range(x0, x1, CELL):
            if obj[y:y + CELL, x:x + CELL].mean() > 0.5:
                if run and run[-1][1] == x:
                    run[-1][1] = x + CELL
                else:
                    run.append([x, x + CELL])
        rows.append((y, run))
    rects = []
    for y, run in rows:
        for xa, xb in run:
            # grow the rect above if it has the same span
            for r in rects:
                if r[0] == xa and r[0] + r[2] == xb and r[1] + r[3] == y:
                    r[3] += CELL
                    break
            else:
                rects.append([xa, y, xb - xa, CELL])
    return [tuple(r) for r in rects]


def place(corner: str, x: float, y: float) -> tuple:
    """Original point of `corner` -> grown base px."""
    return (x + (GROW[0] if corner in ("tr", "br") else 0), y + (GROW[1] if corner in ("bl", "br") else 0))


def door_at(side: str) -> tuple:
    x0, y0, x1, y1 = DOORS[side]
    gx, gy = GROW
    return {"top": (x0 + gx // 2, y0), "bottom": (x0 + gx // 2, y0 + gy),
            "left": (x0, y0 + gy // 2), "right": (x0 + gx, y0 + gy // 2)}[side]


def main() -> None:
    name = sys.argv[1] if len(sys.argv) > 1 else "lab"
    cfg = SETS[name]
    OUT = os.path.join(ROOMS, name)
    os.makedirs(OUT, exist_ok=True)
    count = max(cfg["paintings"], cfg["doors"])
    paint = {n: Image.open(os.path.join(SRC, (cfg["src"] % n) + ".webp")).convert("RGBA") for n in range(1, count + 1)}
    furniture = globals()[cfg["furniture"]] if cfg["furniture"] else None
    decals = globals()[cfg["decals"]]
    W, H = ART[0] + GROW[0], ART[1] + GROW[1]
    gx, gy = GROW
    base = Image.new("RGBA", (W, H), BG + (255,))
    # floor
    src = paint[cfg["doors"]]
    tile = src.crop(TILE_BOX)
    ox, oy = TILE_BOX[0] % TILE[0] - TILE[0], TILE_BOX[1] % TILE[1] - TILE[1]
    for y in range(oy, WALL["bottom"] + gy, TILE[1]):
        for x in range(ox, W, TILE[0]):
            base.paste(tile, (x, y))
    # outside the walls back to the background
    base.paste(BG + (255,), (0, 0, W, 60))
    base.paste(BG + (255,), (0, WALL["bottom"] + gy + 75, W, H))
    base.paste(BG + (255,), (0, 0, 55, H))
    base.paste(BG + (255,), (W - 55, 0, W, H))
    # walls along the whole length (the corners and doors cover their own parts)
    st = {k: paint[1].crop(v) for k, v in WALL_STRIPS.items()}
    # the top strip: plain frame rows from x 380 (no doorway step) over the wall face
    frame = paint[1].crop((380, 40, 460, 130))
    st["top"].paste(frame, (0, 0))
    for x in range(0, W, st["top"].width):
        base.alpha_composite(st["top"], (x, WALL_STRIPS["top"][1]))
        base.alpha_composite(st["bottom"], (x, WALL_STRIPS["bottom"][1] + gy))
    for y in range(60, H - 60, st["left"].height):
        base.alpha_composite(st["left"], (WALL_STRIPS["left"][0], y))
        base.alpha_composite(st["right"], (WALL_STRIPS["right"][0] + gx, y))
    # the doorways of the "doors" painting
    for side, box in DOORS.items():
        base.alpha_composite(paint[cfg["doors"]].crop(box), door_at(side))
    bx0, by0, bx1, by1 = ROOM_BOX[0], ROOM_BOX[1], ROOM_BOX[2] + gx, ROOM_BOX[3] + gy
    base.crop((bx0, by0, bx1, by1)).convert("RGB").save(os.path.join(OUT, "base.webp"), quality=90)

    def clip(img: Image.Image, at: tuple) -> tuple:
        """`img` placed at `at` (grown px) cut to the room box: (image, new position)."""
        x0, y0 = max(at[0], bx0), max(at[1], by0)
        x1, y1 = min(at[0] + img.width, bx1), min(at[1] + img.height, by1)
        return img.crop((x0 - at[0], y0 - at[1], x1 - at[0], y1 - at[1])), (x0 - bx0, y0 - by0)

    def shift_r(r: list) -> list:
        return [r[0] - bx0, r[1] - by0, r[2], r[3]]

    data = {"size": [bx1 - bx0, by1 - by0], "grow": [gx, gy], "corners": {}, "doors": {}}
    for n in range(1, cfg["paintings"] + 1):
        for c, box in CORNERS.items():
            img, at = clip(feather(cover(paint[n].crop(box), c, st), FADE[c]), place(c, box[0], box[1]))
            img.save(os.path.join(OUT, "corner_%d_%s.png" % (n, c)))
            solid = []
            rects = furniture[n][c] if furniture else auto_solid(paint[n], box)
            for x, y, w, h in rects:
                px, py = place(c, x, y)
                solid.append(shift_r([px, py, w, h]))
            data["corners"].setdefault(c, {"at": list(at), "solid": {}})
            data["corners"][c]["solid"][str(n)] = solid
    for side, box in DOORS.items():
        img, at = clip(paint[1].crop(box), door_at(side))
        img.save(os.path.join(OUT, "door_%s.png" % side))
        data["doors"][side] = list(at)
    for k, (n, box) in enumerate(decals):
        floor_key(paint[n].crop(box)).save(os.path.join(OUT, "decal_%d.png" % k))
    data["decals"] = len(decals)
    data["paintings"] = cfg["paintings"]
    data["floor_color"] = [round(float(v) / 255.0, 3) for v in np.median(np.array(tile.convert("RGB")).reshape(-1, 3), axis=0)]
    ox0, ox1 = OPEN_X[0] + gx // 2, OPEN_X[1] + gx // 2
    oy0, oy1 = OPEN_Y[0] + gy // 2, OPEN_Y[1] + gy // 2
    top, bot, left, right = WALL["top"], WALL["bottom"] + gy, WALL["left"], WALL["right"] + gx
    data["walls"] = [shift_r(r) for r in [
        [bx0, by0, ox0 - bx0, top - by0], [ox1, by0, bx1 - ox1, top - by0],
        [bx0, bot, ox0 - bx0, by1 - bot], [ox1, bot, bx1 - ox1, by1 - bot],
        [bx0, by0, left - bx0, oy0 - by0], [bx0, oy1, left - bx0, by1 - oy1],
        [right, by0, bx1 - right, oy0 - by0], [right, oy1, bx1 - right, by1 - oy1]]]
    data["openings"] = {k: shift_r(v) for k, v in {
        "top": [ox0, by0, ox1 - ox0, top - by0], "bottom": [ox0, bot, ox1 - ox0, by1 - bot],
        "left": [bx0, oy0, left - bx0, oy1 - oy0], "right": [right, oy0, bx1 - right, oy1 - oy0]}.items()}
    # free floor for chests / the start: the grown middle
    cx, cy = W / 2, H / 2
    data["spots"] = [[x - bx0, y - by0] for x, y in
                     [[cx - 300, cy - 140], [cx + 300, cy - 140], [cx - 300, cy + 140], [cx + 300, cy + 140], [cx, cy]]]
    data["start"] = [cx - bx0, cy + 120 - by0]
    data["floor"] = shift_r([left + 140, top + 120, right - left - 280, bot - top - 240])  # decals go here
    with open(os.path.join(OUT, "pieces.json"), "w") as f:
        json.dump(data, f, indent=1)
    print(name, "pieces", (W, H))


if __name__ == "__main__":
    main()
