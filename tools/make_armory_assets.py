"""Assets de la pantalla ARMORY (armas, ataque y vida) y de las 10 armas del juego.

python tools/make_armory_assets.py

Entradas (tools/):
  armory_ref.webp      maqueta de la pantalla (solo referencia de composición)
  armory_bg_ref.webp   fondo pintado 941x1672 -> assets/ui/armory/bg.webp
  armory_kit_ref.webp  kit de piezas sobre transparente (botón atrás, píldoras, marcos,
                       tarjetas ATTACK / LIFE, botón verde, iconos, astronauta, pedestal)
  armory_guns_ref.webp las 10 armas mirando a la derecha y, en su fila, su disparo e impacto
  armory_catalog_ref.webp catálogo con nombres y habilidades (solo referencia)

Salidas:
  assets/ui/armory/*.png  piezas del kit; los marcos se limpian por dentro para usarlos
                          como 9-slice (NinePatchRect) y el botón verde pierde su moneda
  assets/guns/gun_<n>.png arma n (1-10): icono de la UI y arma en la mano del astronauta
  assets/guns/*.png       proyectiles, impactos y efectos de cada arma
  assets/guns/guns.json   por arma `grip` (mano) y `tip` (boca) en px de gun_<n>.png
"""
import json
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
UI = os.path.join(ROOT, "assets", "ui", "armory")
GUNS = os.path.join(ROOT, "assets", "guns")

# ---------------------------------------------------------------- kit (x, y, w, h)
KIT = {
    "back": (33, 31, 96, 87),
    "pill_power": (167, 32, 236, 79),
    "pill_coins": (419, 32, 246, 79),
    "pill_heart": (688, 32, 226, 80),
    "detail": (587, 129, 337, 445),
    "banner": (30, 136, 544, 98),
    "weapons": (18, 589, 906, 213),
    "slot": (30, 823, 211, 163),
    "dot_on": (412, 996, 28, 29),
    "dot_off": (454, 997, 26, 27),
    "card_attack": (25, 1034, 440, 282),
    "card_life": (477, 1033, 440, 283),
    "btn_green": (36, 1325, 421, 99),
    "icon_dmg": (24, 1437, 96, 86),
    "icon_rate": (140, 1446, 91, 84),
    "icon_range": (250, 1438, 98, 100),
    "icon_heart": (367, 1446, 91, 85),
    "icon_coin": (480, 1446, 78, 80),
    "icon_plus": (584, 1445, 82, 82),
    "ornate": (698, 1436, 220, 187),
    "box": (25, 1545, 96, 95),
    "pill": (139, 1567, 238, 72),
    "bracket": (394, 1544, 287, 95),
}

# ---------------------------------------------------------------- guns sheet
# fila de cada arma: (y0, y1) y dónde acaba el arma (x1)
GUN_ROWS = [
    (8, 90, 126), (76, 164, 153), (160, 250, 172), (246, 326, 133), (316, 414, 158),
    (408, 506, 163), (500, 592, 152), (586, 670, 137), (664, 754, 138), (736, 840, 161),
]
# mano: encima de la empuñadura, en px de gun_<n>.png (medido a ojo sobre los recortes)
GRIPS = [(28, 44), (28, 56), (36, 60), (24, 44), (64, 64), (68, 60), (64, 60), (46, 60), (34, 54), (55, 55)]

# piezas sueltas de cada fila: nombre -> (x0, y0, x1, y1[, "main"])  "main" = solo la
# pieza mayor (quita astillas de lo que roza el recorte)
FX = {
    "shot_pulse": (290, 24, 372, 64, "main"),
    "hit_pulse": (556, 6, 642, 82),
    "shot_nova": (248, 103, 300, 130, "main"),
    "bolt_drill": (182, 166, 344, 246),
    "beam_drill": (440, 176, 500, 236),
    "hit_drill": (560, 162, 656, 250),
    "shot_spark": (142, 260, 192, 300, "main"),
    "hit_spark": (272, 274, 318, 320, "main"),
    "flake": (394, 322, 430, 356, "main"),
    "crystal": (552, 318, 664, 410),
    "glob": (338, 450, 380, 490, "main"),
    "splash": (496, 422, 668, 500),
    "shot_grav": (172, 515, 224, 570, "main"),
    "hole": (462, 500, 652, 592),
    "spark_tesla": (580, 590, 662, 670, "main"),
    "rocket": (312, 666, 360, 702, "main"),
    "boom": (400, 690, 445, 738, "main"),
    "orb_solar": (160, 764, 204, 812, "main"),
    "beam_solar": (470, 772, 560, 804),
    "hit_solar": (556, 734, 670, 830),
    "germ": (606, 668, 656, 716, "main"),
}


# ray segments stretched along a beam: their ends fade out so the beam never shows a cut
FEATHER = {"beam_solar": 0.3, "beam_drill": 0.25}


def feather_x(img: Image.Image, share: float) -> Image.Image:
    """Fades alpha to 0 over `share` of the width at the left and right ends."""
    arr = np.array(img).astype(np.float32)
    w = arr.shape[1]
    ramp = np.ones(w, np.float32)
    n = max(1, int(w * share))
    k = np.linspace(0.0, 1.0, n) ** 1.5
    ramp[:n] = k
    ramp[w - n:] = k[::-1]
    arr[..., 3] *= ramp[None, :]
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def load(name: str) -> Image.Image:
    return Image.open(os.path.join(TOOLS, name)).convert("RGBA")


def crop(img: Image.Image, r) -> Image.Image:
    x, y, w, h = r
    return img.crop((x, y, x + w, y + h))


def trim(img: Image.Image, pad: int = 2) -> Image.Image:
    a = np.array(img)[..., 3]
    ys, xs = np.nonzero(a > 8)
    if len(xs) == 0:
        return img
    x0, y0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
    x1, y1 = min(img.width, xs.max() + 1 + pad), min(img.height, ys.max() + 1 + pad)
    return img.crop((x0, y0, x1, y1))


def main_piece(img: Image.Image, keep_near: int = 0) -> Image.Image:
    """Keeps the largest connected piece (alpha > 20) and whatever lies within
    `keep_near` px of it (glow), clearing the splinters of neighbouring frames."""
    arr = np.array(img)
    m = (arr[..., 3] > 20).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
    if n <= 2:
        return img
    big = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
    keep = (lab == big).astype(np.uint8)
    keep = cv2.dilate(keep, np.ones((3, 3), np.uint8), iterations=max(1, keep_near))
    arr[..., 3] = (arr[..., 3] * keep).astype(np.uint8)
    return Image.fromarray(arr)


def fill_rect(img: Image.Image, box, sample) -> None:
    """Paints box (x0, y0, x1, y1) with the colour at `sample`."""
    px = img.load()
    c = px[sample]
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            px[x, y] = c


def clear_inside(img: Image.Image, margin: int, sample: tuple = None) -> Image.Image:
    """Frame with its inside (`margin` px in) painted flat with the colour at `sample`
    (default: the middle), so it 9-slices cleanly."""
    arr = np.array(img).copy()
    h, w = arr.shape[:2]
    sx, sy = sample if sample else (w // 2, h // 2)
    arr[margin:h - margin, margin:w - margin] = arr[sy, sx]
    return Image.fromarray(arr)


def recolor(img: Image.Image, hue_from: tuple, hue_to: float, sat_mult: float = 1.0) -> Image.Image:
    """Shifts the hues in [hue_from] (OpenCV 0-180) to hue_to (the neon border)."""
    arr = np.array(img)
    rgb = arr[..., :3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.int32)
    sel = (hsv[..., 0] >= hue_from[0]) & (hsv[..., 0] <= hue_from[1]) & (hsv[..., 1] > 60) & (hsv[..., 2] > 110)
    hsv[..., 0] = np.where(sel, hue_to, hsv[..., 0])
    hsv[..., 1] = np.where(sel, np.clip(hsv[..., 1] * sat_mult, 0, 255), hsv[..., 1])
    arr[..., :3] = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)
    return Image.fromarray(arr)


def save(img: Image.Image, folder: str, name: str) -> None:
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name))


# ---------------------------------------------------------------- UI kit

def make_kit() -> None:
    kit = load("armory_kit_ref.webp")
    Image.open(os.path.join(TOOLS, "armory_bg_ref.webp")).convert("RGB").save(
        os.path.join(UI, "bg.webp"), quality=92)
    for name, r in KIT.items():
        img = crop(kit, r)
        if name == "detail":
            img = clear_inside(img, 30, (60, 200))
        elif name == "banner":
            img = clear_inside(img, 22, (80, 49))
        elif name == "weapons":
            # the 4 painted slots go: the screen lays its own scrolling slots there
            img = clear_band(img, 66, 840, 28, 198, (266, 100))
            save(trim(crop(kit, (18, 667, 52, 72))), UI, "arrow_l.png")
            save(trim(crop(kit, (870, 667, 54, 72))), UI, "arrow_r.png")
        elif name == "slot":
            img = clear_inside(img, 14, (30, 30))
        elif name == "btn_green":
            # the painted coin goes: the screen draws coin + price where it wants
            fill_cols(img, 128, 198, -110)
        elif name in ("box", "pill", "bracket", "ornate"):
            pass
        save(img, UI, name + ".png")
    slot = Image.open(os.path.join(UI, "slot.png"))
    save(recolor(slot, (85, 125), 24, 1.1), UI, "slot_sel.png")  # gold: equipped
    save(recolor(slot, (85, 125), 150, 1.0), UI, "slot_pick.png")  # pink: on show
    green = Image.open(os.path.join(UI, "btn_green.png"))
    save(recolor(green, (35, 85), 104, 1.0), UI, "btn_blue.png")  # EQUIP
    # the heart pill is reused as the SUITS tab (empty)
    pill = crop(kit, KIT["pill_heart"])
    save(pill, UI, "pill_heart.png")
    # astronaut and pedestal stand side by side in the kit: split them
    both = crop(kit, (25, 255, 559, 321))
    astro = main_piece(both.crop((0, 0, 240, 321)), 2)
    save(trim(astro), UI, "astronaut.png")
    ped = both.crop((228, 110, 559, 321))
    ped.paste((0, 0, 0, 0), (0, 0, 40, 70))
    ped.paste((0, 0, 0, 0), (0, 0, 11, 125))  # the astronaut's muzzle glow
    ped = main_piece(ped, 2)
    save(trim(ped), UI, "pedestal.png")


def clear_band(img: Image.Image, x0: int, x1: int, y0: int, y1: int, sample: tuple) -> Image.Image:
    """Paints the box x0..x1, y0..y1 flat with the colour at `sample`."""
    arr = np.array(img).copy()
    arr[y0:y1, x0:x1] = arr[sample[1], sample[0]]
    return Image.fromarray(arr)


def fill_cols(img: Image.Image, x0: int, x1: int, src_dx: int) -> None:
    """Replaces columns x0..x1 with the columns src_dx px to their left."""
    arr = np.array(img)
    arr[:, x0:x1] = arr[:, x0 - src_dx:x1 - src_dx]
    img.paste(Image.fromarray(arr))


# ---------------------------------------------------------------- guns

def make_guns() -> None:
    sheet = load("armory_guns_ref.webp")
    data = {"guns": []}
    for i, (y0, y1, x1) in enumerate(GUN_ROWS):
        g = main_piece(sheet.crop((0, y0, x1, y1)), 3)
        g = trim(g, 1)
        save(g, GUNS, "gun_%d.png" % (i + 1))
        a = np.array(g)[..., 3] > 128
        ys, xs = np.nonzero(a)
        right = xs > xs.max() - 5
        tip = [float(xs.max()), round(float(ys[right].mean()), 1)]
        data["guns"].append({"size": [g.width, g.height], "grip": list(GRIPS[i]), "tip": tip})
    for name, box in FX.items():
        img = sheet.crop(box[:4])
        if len(box) > 4:
            img = main_piece(img, 3)
        img = trim(img, 1)
        if name in FEATHER:
            img = feather_x(img, FEATHER[name])
        save(img, GUNS, name + ".png")
    with open(os.path.join(GUNS, "guns.json"), "w") as f:
        json.dump(data, f, indent=1)


def preview() -> None:
    """tools/armory_preview.png: every gun with its grip (green) and tip (red)."""
    data = json.load(open(os.path.join(GUNS, "guns.json")))
    sheet = Image.new("RGBA", (980, 760), (30, 34, 52, 255))
    x, y = 10, 10
    for i, g in enumerate(data["guns"]):
        im = Image.open(os.path.join(GUNS, "gun_%d.png" % (i + 1)))
        im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        sheet.alpha_composite(im, (x, y))
        px = sheet.load()
        for (cx, cy), col in ((g["grip"], (0, 255, 0, 255)), (g["tip"], (255, 0, 0, 255))):
            for dx in range(-3, 4):
                for dy in range(-3, 4):
                    xx, yy = int(x + cx * 2 + dx), int(y + cy * 2 + dy)
                    if 0 <= xx < sheet.width and 0 <= yy < sheet.height:
                        px[xx, yy] = col
        x += 330
        if x > 700:
            x = 10
            y += 190
    fx_x, fx_y = 10, 10
    names = sorted(FX)
    strip = Image.new("RGBA", (980, 300), (30, 34, 52, 255))
    for n in names:
        im = Image.open(os.path.join(GUNS, n + ".png"))
        if fx_x + im.width > 970:
            fx_x = 10
            fx_y += 110
        strip.alpha_composite(im, (fx_x, fx_y))
        fx_x += im.width + 12
    out = Image.new("RGBA", (980, 1060), (30, 34, 52, 255))
    out.alpha_composite(sheet, (0, 0))
    out.alpha_composite(strip, (0, 760))
    out.save(os.path.join(TOOLS, "armory_preview.png"))


def main() -> None:
    os.makedirs(UI, exist_ok=True)
    os.makedirs(GUNS, exist_ok=True)
    make_kit()
    make_guns()
    preview()
    print("armory assets ->", UI, GUNS)


if __name__ == "__main__":
    main()
