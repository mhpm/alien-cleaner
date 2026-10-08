"""Animaciones del marciano con pistola: walk_shoot (8), idle (6) y shoot (5).

tools/alien_gunner_ref.png (pose quieta apuntando a la derecha) → separa cuerpo y
piernas, anima cada pierna (giro sobre la cadera + levantamiento) con el ciclo de
tools/walk_shoot_pose_ref.webp (contacto, bajada, paso, subida ×2) y el rebote del
cuerpo, repinta contornos y huecos y deja cuadros de 128×128 en
assets/characters/alien_gunner/<anim>/frame_<n>.png (pies abajo, mismo ancla en todas).
idle = respira y el cañón late; shoot = carga, fogonazo con retroceso y vuelta.
Se juntan en alien_walk_shoot.aseprite (una etiqueta por animación) y se copian a
assets/sprites/enemies/alien_trooper/{walk,idle,attack}/ para el enemigo.

    python tools/make_alien_walk.py
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "alien_gunner_ref.png")
OUT_DIR = os.path.join(ROOT, "assets", "characters", "alien_gunner")
# el enemigo ALIEN TROOPER usa los mismos cuadros (slice_sprites.py set "alien_trooper")
ENEMY_DIR = os.path.join(ROOT, "assets", "sprites", "enemies", "alien_trooper")
ENEMY_ANIMS = {"walk_shoot": "walk", "idle": "idle", "shoot": "attack"}

FRAME = 128
WORK = 160          # lienzo de trabajo a resolución del arte
GROUND = 150        # fila del suelo en el lienzo de trabajo
SCALE = 0.86        # arte (≈140 px de alto) → cuadro de 128
SHIFT_X = -5        # px del cuadro: deja sitio delante al fogonazo

BODY_CUT = 111      # filas <= esto son cuerpo
CROTCH = (37, 51, 119)  # x0, x1, y1: entrepierna del traje que sigue siendo cuerpo
LEG_TOP = 113
LEG_EXT = 8         # filas extra sobre la pierna (quedan tapadas por el cuerpo)
# pierna: columnas permitidas en las filas altas, cadera (pivote)
LEGS = {
    "back": {"x": (0, 36), "hip": (21, 113)},
    "front": {"x": (52, 90), "hip": (66, 113)},
}
# ciclo de una pierna: (ángulo°, levantamiento px); + = el pie va hacia delante
CYCLE = [(18, 0), (8, 0), (-3, 0), (-13, 0), (-20, 1), (-10, 6), (2, 9), (13, 5)]
# rebote del cuerpo por cuadro (+ = abajo), sacado de la cabeza del ejemplo
BOB = [0, 3, 1, -2, 0, 3, 1, -2]
OUTLINE = (14, 10, 24, 255)


def load():
    im = np.array(Image.open(SRC).convert("RGBA")).astype(np.uint8)
    a = im[..., 3]
    # el arte trae el interior al 98%: opaco del todo salvo el borde suave
    im[..., 3] = np.where(a > 160, 255, np.where(a < 40, 0, a))
    return im


def cut_body(im):
    h, w = im.shape[:2]
    body = im.copy()
    yy, xx = np.mgrid[0:h, 0:w]
    keep = yy <= BODY_CUT
    x0, x1, y1 = CROTCH
    keep |= (xx >= x0) & (xx <= x1) & (yy <= y1)
    body[~keep] = 0
    return body


def cut_leg(im, spec):
    h, w = im.shape[:2]
    x0, x1 = spec["x"]
    leg = np.zeros_like(im)
    leg[LEG_TOP:, x0:x1 + 1] = im[LEG_TOP:, x0:x1 + 1]
    # alarga la parte de arriba con un trozo del propio muslo (textura, no rayas)
    src = LEG_TOP + 4
    ext = leg[src:src + LEG_EXT].copy()
    pad = np.zeros((h + LEG_EXT, w, 4), np.uint8)
    pad[:LEG_EXT + LEG_TOP] = 0
    pad[LEG_TOP:LEG_TOP + LEG_EXT] = ext
    pad[LEG_TOP + LEG_EXT:] = leg[LEG_TOP:]
    return Image.fromarray(pad), LEG_EXT


def place(canvas, img, x, y):
    canvas.alpha_composite(img, (int(x), int(y)))


def leg_image(leg_img, ext, hip, angle):
    """Gira la pierna sobre la cadera. Devuelve imagen y posición de la cadera en ella."""
    hx, hy = hip[0], hip[1] + ext
    bbox = leg_img.getbbox()
    crop = leg_img.crop(bbox)
    cx, cy = hx - bbox[0], hy - bbox[1]
    pad = 40
    big = Image.new("RGBA", (crop.width + pad * 2, crop.height + pad * 2))
    big.alpha_composite(crop, (pad, pad))
    cx, cy = cx + pad, cy + pad
    # en pantalla un ángulo positivo de PIL gira a la izquierda: el pie va hacia delante (+x)
    rot = big.rotate(angle, resample=Image.NEAREST, center=(cx, cy))
    return rot, (cx, cy)


def repair(img):
    """Contorno oscuro donde el corte o el giro dejaron borde de color, y tapa agujeros."""
    a = np.array(img).astype(np.int32)
    al = a[..., 3]
    solid = al > 100
    # agujeros de 1 px rodeados de cuerpo → color medio de los vecinos
    for _ in range(2):
        n = sum(np.roll(np.roll(solid, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                if dy or dx)
        hole = (~solid) & (n >= 6)
        if not hole.any():
            break
        acc = np.zeros(a.shape, np.int64)
        cnt = np.zeros(al.shape, np.int64)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy or dx:
                    s = np.roll(np.roll(solid, dy, 0), dx, 1)
                    acc += np.roll(np.roll(a, dy, 0), dx, 1) * s[..., None]
                    cnt += s
        fill = acc[hole] // np.maximum(cnt[hole], 1)[:, None]
        fill[:, 3] = 255
        a[hole] = fill
        solid = a[..., 3] > 100
    # borde: píxeles sólidos que tocan el vacío y son claros → oscurecer al contorno
    lum = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
    empty = ~solid
    touch = np.zeros_like(solid)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        touch |= np.roll(np.roll(empty, dy, 0), dx, 1)
    edge = solid & touch & (lum > 70)
    # contorno de 1 px por fuera de esos bordes claros
    out = np.zeros_like(solid)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        out |= np.roll(np.roll(edge, dy, 0), dx, 1)
    out &= empty
    a[out] = OUTLINE
    return Image.fromarray(a.astype(np.uint8))


# idle: respira (el cuerpo baja y sube sobre las piernas quietas) y el cañón late
IDLE = [
    {"bob": 0, "glow": 1.0},
    {"bob": 0, "glow": 1.08},
    {"bob": 1, "glow": 1.16},
    {"bob": 2, "glow": 1.22},
    {"bob": 2, "glow": 1.14},
    {"bob": 1, "glow": 1.05},
]
IDLE_MS = 140
# shoot: carga, fogonazo con retroceso, se recupera
SHOOT = [
    {"bob": 0, "glow": 1.45, "flash": 0.5},
    {"bob": -1, "dx": -4, "glow": 1.6, "flash": 1.0},
    {"bob": 0, "dx": -3, "glow": 1.3, "flash": 0.7},
    {"bob": 1, "dx": -1, "glow": 1.1},
    {"bob": 0, "glow": 1.0},
]
SHOOT_MS = [70, 60, 60, 80, 110]
MUZZLE = (105, 95)  # boca del cañón en el arte
GUN = (64, 76, 106, 112)  # caja del cañón (para el brillo)


def glow_gun(body, k):
    """Aclara los rosas del cañón hacia blanco (k = 1 sin cambio)."""
    if k == 1.0:
        return body
    a = np.array(body).astype(np.float32)
    x0, y0, x1, y1 = GUN
    sub = a[y0:y1, x0:x1]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    pink = (r > 150) & (b > 140) & (g < 150) & (sub[..., 3] > 0)
    t = min(1.0, (k - 1.0) * 1.2)
    for c in range(3):
        ch = sub[..., c]
        ch[pink] = ch[pink] * (1 - t * 0.5) + 255 * t * 0.5 + (ch[pink] * (k - 1) * 0.3)
    a[y0:y1, x0:x1] = sub
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def flash_image(size):
    """Fogonazo rosa: halo redondo, núcleo blanco, chorro hacia delante y destellos."""
    R = 28
    yy, xx = np.mgrid[-R:R + 1, -R:R + 1].astype(np.float32)
    x, y = xx / size, yy / size
    d = np.hypot(x, y)
    ang = np.abs(np.arctan2(y, x))
    jet = (x > 0) & (np.abs(y) < 3.2 * (1 - x / 17)) & (x < 17)          # chorro delante
    diag = (np.abs(np.abs(y) - x * 0.75) < 1.4) & (x > 0) & (d < 13)    # destellos 37°
    vert = (np.abs(x) < 1.3) & (np.abs(y) < 12)                          # cruz vertical
    halo = d < 9.5
    mid = (d < 7) | (jet & (x < 14))
    core = (d < 4) | (jet & (np.abs(y) < 1.2) & (x < 10))
    shape = halo | jet | diag | vert
    img = np.zeros(xx.shape + (4,), np.uint8)
    img[shape] = (205, 40, 200, 255)
    img[mid | ((jet | diag | vert) & (d < 9))] = (255, 95, 240, 255)
    img[core] = (255, 245, 255, 255)
    # borde exterior oscuro para que se lea sobre cualquier suelo
    edge = np.zeros_like(shape)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        edge |= np.roll(np.roll(shape, dy, 0), dx, 1)
    img[edge & ~shape] = (120, 10, 110, 255)
    del ang
    return Image.fromarray(img), (R, R)


def compose(parts, ox, oy, pose, legs_pose):
    body, legs = parts
    canvas = Image.new("RGBA", (WORK, WORK))
    b = pose.get("bob", 0)
    dx = pose.get("dx", 0)
    for name in ("back", "front"):
        angle, lift = legs_pose[name]
        img, ext = legs[name]
        hip = LEGS[name]["hip"]
        rot, (cx, cy) = leg_image(img, ext, hip, angle)
        # cadera pegada al cuerpo; el pie apoyado toca el suelo
        hx, hy = hip[0] + ox, hip[1] + oy + b
        low = np.where(np.array(rot)[..., 3] > 100)[0].max()
        y = GROUND - lift - low
        # la cadera no puede quedar por debajo del cuerpo (se vería el corte)
        y = min(y, hy - cy + 3)
        place(canvas, rot, hx - cx, y)
    place(canvas, glow_gun(body, pose.get("glow", 1.0)), ox + dx, oy + b)
    out = repair(canvas)
    if pose.get("flash"):
        fl, (fx, fy) = flash_image(pose["flash"])
        out.alpha_composite(fl, (MUZZLE[0] + ox + dx - fx + 3, MUZZLE[1] + oy + b - fy))
    return out


def build():
    im = load()
    parts = (Image.fromarray(cut_body(im)), {k: cut_leg(im, v) for k, v in LEGS.items()})
    ground_src = int(np.where(im[..., 3] > 100)[0].max())  # pie más bajo del arte

    # desplazamiento arte → lienzo: pies en GROUND, cuerpo centrado
    bb = Image.fromarray(im).getbbox()
    ox = (WORK - (bb[2] - bb[0])) // 2 - bb[0]
    oy = GROUND - ground_src

    rest = {"back": (0, 0), "front": (0, 0)}
    anims = {
        "walk_shoot": [compose(parts, ox, oy, {"bob": BOB[f]},
                               {"back": CYCLE[(f + 4) % 8], "front": CYCLE[f]})
                       for f in range(8)],
        "idle": [compose(parts, ox, oy, p, rest) for p in IDLE],
        "shoot": [compose(parts, ox, oy, p, rest) for p in SHOOT],
    }

    # el encuadre de la caminata vale para todas → mismo ancla en todas las animaciones
    boxes = [fr.getbbox() for fr in anims["walk_shoot"]]
    x0 = min(bx[0] for bx in boxes)
    x1 = max(bx[2] for bx in boxes)
    y1 = max(bx[3] for bx in boxes)
    sx0, sx1, sy1 = x0 * SCALE, x1 * SCALE, y1 * SCALE
    dx = round((FRAME - (sx1 - sx0)) / 2 - sx0) + SHIFT_X
    dy = round(FRAME - 2 - sy1)
    w = round(WORK * SCALE)
    for name, frames in anims.items():
        folder = os.path.join(OUT_DIR, name)
        os.makedirs(folder, exist_ok=True)
        for i, fr in enumerate(frames):
            small = fr.resize((w, w), Image.LANCZOS)
            a = np.array(small)
            al = a[..., 3].astype(np.int32)
            a[..., 3] = np.where(al > 150, 255, np.where(al < 60, 0, al)).astype(np.uint8)
            small = Image.fromarray(a)
            out = Image.new("RGBA", (FRAME, FRAME))
            out.paste(small, (dx, dy), small)
            if small.getbbox()[2] + dx > FRAME:
                print("aviso: %s %d se sale del cuadro" % (name, i + 1))
            out.save(os.path.join(folder, "frame_%d.png" % (i + 1)))
            enemy = os.path.join(ENEMY_DIR, ENEMY_ANIMS[name])
            os.makedirs(enemy, exist_ok=True)
            out.save(os.path.join(enemy, "image_%02d.png" % (i + 1)))
    print("ok", OUT_DIR)


if __name__ == "__main__":
    build()
