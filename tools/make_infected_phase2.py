"""Fase 2 del mutante (64x64): idle agresivo, correr, espalda y 3 golpes nuevos.

python tools/make_infected_phase2.py
Todo sale de tools/infected_phase2_ref.png (vista lateral) con las utilidades de
make_infected_phase1.py (reducción, paleta, contorno, piezas):
- idle / run: piezas animadas (cabeza, torso, garra, puño, piernas); más amplitud y
  ritmo que la fase 1, la garra gira sobre el hombro y el ojo verde late.
- walk_up: la espalda de la fase 1 (pixel64/walk_up_*.png) con las piezas de la fase 2
  encima (garra grande, masa rosa con el ojo, cuerno).
- combo_1..3: estocada, golpe desde arriba y gancho ascendente; la garra rota sobre
  el hombro y el arco de energía se dibuja por código. 4 frames cada uno (carga,
  impacto, estela, recuperación) a 16 fps = Infected.SLASH_TIME.
Salida: assets/sprites/mutations_player/fase 2/pixel64/<anim>_<i>.png + hojas <anim>.png.
"""
import math
import os

import numpy as np
from PIL import Image

import make_infected_phase1 as p1
from make_infected_phase1 import SIZE, FEET_Y, BODY_H, cut, outline, reduce, apply_palette, fade, shifted

ROOT = p1.ROOT
SRC = os.path.join(ROOT, "tools", "infected_phase2_ref.png")
OUT = os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase 2", "pixel64")
BACK = os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase 1", "pixel64", "walk_up_%d.png")
COLORS = 44

# Piezas en coordenadas del sprite base (48x56)
HEAD_Y = 27
HIP_Y = 41
LEG_SPLIT_X = 22
FIST_X = 10
SHOULDER = (32, 31)          # pivote de la garra

# Arco de energía: de fuera a dentro
ARC_COLS = [(120, 10, 110, 255), (214, 30, 190, 255), (255, 80, 230, 255),
            (255, 170, 245, 255), (255, 255, 255, 255)]


def is_green(a: np.ndarray) -> np.ndarray:
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (a[..., 3] > 0) & (g > r + 30) & (g > b + 20)


def palette(imgs: list) -> Image.Image:
    """Paleta común; los píxeles verdes (el ojo) pesan x30 para no perderse."""
    px = []
    for i in imgs:
        a = np.array(i)
        px.append(a[..., :3][a[..., 3] > 0])
        px.append(np.repeat(a[..., :3][is_green(a)], 30, axis=0))
    px = np.concatenate(px)
    strip = Image.fromarray(px.reshape(1, -1, 3).astype(np.uint8), "RGB")
    return strip.quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def parts(base: Image.Image) -> dict:
    claw = lambda x, y: (y >= HEAD_Y) & (y < 51) & (((x >= 31) & (y < HIP_Y)) | (x >= 36))
    fist = lambda x, y: (x < FIST_X) & (y >= HEAD_Y - 1) & (y < 47)
    p = {
        "head": cut(base, lambda x, y: y < HEAD_Y),
        "claw": cut(base, claw),
        "fist": cut(base, fist),
        "torso": cut(base, lambda x, y: (y >= HEAD_Y) & (y < HIP_Y) & (x >= FIST_X) & (x < 31)),
        "leg_front": cut(base, lambda x, y: (y >= HIP_Y) & (x < LEG_SPLIT_X) & ~fist(x, y)),
        "leg_back": cut(base, lambda x, y: (y >= HIP_Y) & (x >= LEG_SPLIT_X) & ~claw(x, y)),
    }
    for k in ("leg_front", "leg_back"):   # muslo de relleno bajo el torso
        a = np.array(p[k])
        for y in range(HIP_Y - 4, HIP_Y):
            a[y] = np.where(a[HIP_Y][..., 3:4] > 0, a[HIP_Y], a[y])
        p[k] = Image.fromarray(a, "RGBA")
    return p


def rotated(part: Image.Image, deg: float, pivot=SHOULDER) -> Image.Image:
    """Gira una pieza alrededor del hombro (pixel art: vecino más cercano). Positivo =
    la garra sube (sentido antihorario en pantalla)."""
    pad = 32
    big = Image.new("RGBA", (part.width + 2 * pad, part.height + 2 * pad), (0, 0, 0, 0))
    big.alpha_composite(part, (pad, pad))
    big = big.rotate(deg, resample=Image.NEAREST, center=(pivot[0] + pad, pivot[1] + pad))
    return big


def eye_glow(img: Image.Image, k: float) -> Image.Image:
    """Aclara el ojo verde (k 0..1): latido agresivo."""
    if k <= 0:
        return img
    a = np.array(img).astype(np.float32)
    m = is_green(a.astype(np.uint8))
    a[m, :3] = a[m, :3] + (np.array([200, 255, 170]) - a[m, :3]) * k
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def compose(p: dict, ox: int, oy: int, *, body=(0, 0), head=(0, 0), claw_rot=0.0,
            claw=(0, 0), fist=(0, 0), front=(0, 0), back=(0, 0), glow=0.0) -> Image.Image:
    c = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bx, by = body

    def put(img: Image.Image, dx: int, dy: int, pad: int = 0) -> None:
        c.paste(img, (ox + dx - pad, oy + dy - pad), img)

    put(p["leg_back"], back[0], back[1])
    put(p["leg_front"], front[0], front[1])
    put(p["fist"], bx + fist[0], by + fist[1])
    put(p["torso"], bx, by)
    put(eye_glow(p["head"], glow), bx + head[0], by + head[1])
    put(rotated(p["claw"], claw_rot), bx + claw[0], by + claw[1], pad=32)
    return outline(despeckle(c))


def despeckle(img: Image.Image, min_px: int = 6) -> Image.Image:
    """Quita píxeles sueltos (restos de los cortes y giros) antes del contorno: islas
    pequeñas, también las de color unidas al cuerpo solo por píxeles casi negros, y
    las colas de 1 px que quedan."""
    a = np.array(img)
    solid = a[..., 3] > 0
    lab, sizes = p1._label(solid)
    a[np.isin(lab, [k for k, n in enumerate(sizes) if k and n < min_px])] = 0
    r, g, b = (a[..., k].astype(int) for k in range(3))
    dark = (r < 45) & (g < 35) & (b < 60)
    lab, sizes = p1._label((a[..., 3] > 0) & ~dark)
    a[np.isin(lab, [k for k, n in enumerate(sizes) if k and n < 4])] = 0
    for _ in range(2):
        solid = a[..., 3] > 0
        n = sum(np.roll(np.roll(solid, dy, 0), dx, 1).astype(int)
                for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
        a[solid & (n <= 1)] = 0
    return Image.fromarray(a, "RGBA")


# ---------------------------------------------------------------- animaciones

def idle(p: dict, ox: int, oy: int) -> list:
    # Guardia agachada: respira fuerte, la garra se abre y cierra levantada, la cabeza
    # da un tirón y el ojo late.
    body = [(0, 1), (0, 1), (0, 2), (0, 2), (0, 1), (0, 1)]
    head = [(0, 0), (1, 0), (1, 1), (0, 1), (0, 0), (-1, 0)]
    rot = [8, 14, 18, 12, 6, 4]
    claw = [(0, -1), (0, -2), (1, -2), (1, -1), (0, 0), (0, -1)]
    fist = [(0, 0), (-1, 0), (-1, 1), (0, 1), (0, 0), (0, 0)]
    glow = [0.0, 0.3, 0.7, 0.4, 0.1, 0.0]
    return [compose(p, ox, oy, body=body[i], head=head[i], claw_rot=rot[i], claw=claw[i],
                    fist=fist[i], glow=glow[i]) for i in range(6)]


def run(p: dict, ox: int, oy: int) -> list:
    # Carrera inclinada hacia delante: zancadas de ±3 px, piernas que se levantan hasta
    # 3 px, rebote de 2 px y la garra bombeando.
    stride = [3, 3, 1, -2, -3, -3, -1, 2]
    lift_f = [0, 0, -1, -2, -3, -2, 0, 0]
    lift_b = [-3, -2, 0, 0, 0, 0, -1, -2]
    bob = [0, 1, 0, -2, 0, 1, 0, -2]
    frames = []
    for i in range(8):
        s = stride[i]
        frames.append(compose(
            p, ox, oy, body=(1, bob[i]), head=(1, 1 if bob[i] > 0 else 0),
            front=(s, lift_f[i]), back=(-s, lift_b[i]),
            claw_rot=-10 + 4 * s, claw=(int(np.sign(s)), 0), fist=(-int(np.sign(s)) * 2, 0),
            glow=0.3 if i in (3, 7) else 0.0))
    return frames


def draw_arc(size: int, cx: float, cy: float, r: float, a0: float, a1: float, width: float,
             ox: int = 0, oy: int = 0) -> Image.Image:
    """Media luna de energía: ángulos en grados (0 = derecha, 90 = abajo); se afina en
    los extremos y va de magenta oscuro por fuera a blanco por dentro."""
    img = np.zeros((size, size, 4), np.uint8)
    yy, xx = np.mgrid[0:size, 0:size]
    dx, dy = xx - (cx + ox), yy - (cy + oy)
    d = np.hypot(dx, dy)
    ang = np.degrees(np.arctan2(dy, dx))
    lo, hi = min(a0, a1), max(a0, a1)
    ang = np.where(ang < lo - 180, ang + 360, ang)
    ang = np.where(ang > hi + 180, ang - 360, ang)
    t = (ang - lo) / max(hi - lo, 1e-6)
    inside = (t >= 0) & (t <= 1)
    # grosor máximo hacia el extremo de llegada (a1): la estela se afila atrás
    head_t = t if a1 >= a0 else 1 - t
    w = np.maximum(1.0, width * np.sin(np.clip(head_t, 0, 1) * math.pi * 0.8 + 0.2))
    band = inside & (d <= r) & (d >= r - w)
    k = np.clip((r - d) / np.maximum(w, 1e-6), 0, 1)          # 0 fuera .. 1 dentro
    idx = np.clip((k * len(ARC_COLS)).astype(int), 0, len(ARC_COLS) - 1)
    cols = np.array(ARC_COLS, np.uint8)
    img[band] = cols[idx[band]]
    return Image.fromarray(img, "RGBA")


# Cada golpe: poses (carga, impacto, recuperación) + arco (centro relativo al hombro,
# radio, ángulos, grosor) + avance de la estela.
COMBOS = [
    {   # 1: estocada — la garra sale disparada al frente
        "windup": dict(body=(-2, 1), head=(-1, 0), claw_rot=20, claw=(-4, 1), fist=(1, 0),
                       front=(-1, 0), back=(1, 0)),
        "strike": dict(body=(2, 1), head=(2, 1), claw_rot=-6, claw=(6, 0), fist=(-3, 1),
                       front=(3, 0), back=(-2, 0), glow=0.8),
        "recover": dict(body=(1, 1), head=(1, 1), claw_rot=0, claw=(3, 0), fist=(-1, 0),
                        front=(2, 0), back=(-1, 0)),
        "arc": (2, 0, 18, -55, 55, 6), "trail": (2, 0),
    },
    {   # 2: golpe desde arriba — la garra sube por encima de la cabeza y cae
        "windup": dict(body=(-1, -1), head=(-1, -1), claw_rot=95, claw=(-3, -6), fist=(1, -1),
                       front=(0, 0), back=(0, 0)),
        "strike": dict(body=(2, 3), head=(2, 3), claw_rot=-40, claw=(3, 4), fist=(-2, 2),
                       front=(2, 0), back=(-2, 0), glow=0.8),
        "recover": dict(body=(1, 2), head=(1, 2), claw_rot=-20, claw=(2, 3), fist=(-1, 1),
                        front=(1, 0), back=(-1, 0)),
        "arc": (0, 0, 20, -110, 35, 6), "trail": (1, 2),
    },
    {   # 3: gancho ascendente — se agacha y barre hacia arriba
        "windup": dict(body=(-1, 3), head=(-1, 3), claw_rot=-45, claw=(-2, 6), fist=(1, 2),
                       front=(-1, 0), back=(1, 0)),
        "strike": dict(body=(1, -2), head=(1, -2), claw_rot=60, claw=(3, -5), fist=(-2, -1),
                       front=(2, -1), back=(-1, 0), glow=0.8),
        "recover": dict(body=(0, 0), head=(0, 0), claw_rot=25, claw=(1, -2), fist=(-1, 0),
                        front=(1, 0), back=(0, 0)),
        "arc": (0, 0, 18, 75, -75, 6), "trail": (1, -2),
    },
]


def combo(p: dict, ox: int, oy: int, spec: dict) -> list:
    windup = compose(p, ox, oy, **spec["windup"])
    strike = compose(p, ox, oy, **spec["strike"])
    ax, ay, r, a0, a1, w = spec["arc"]
    bx, by = spec["strike"]["body"]
    cx, cy = ox + SHOULDER[0] + bx + ax, oy + SHOULDER[1] + by + ay
    arc = draw_arc(SIZE, cx, cy, r, a0, a1, w)
    strike.alpha_composite(arc)
    trail = compose(p, ox, oy, **spec["recover"])
    trail.alpha_composite(shifted(fade(arc), *spec["trail"]))
    recover = compose(p, ox, oy, **{**spec["recover"], "glow": 0.0})
    return [windup, strike, trail, recover]


# ---------------------------------------------------------------- espalda

def back_view(p: dict, base: Image.Image) -> list:
    """walk_up: espalda de la fase 1 + piezas de la fase 2 (espejadas: de espaldas el
    brazo de la garra queda a la izquierda)."""
    head = p["head"]
    growth = only_infection(head.crop((1, 6, 17, 31)))     # masa rosa con el ojo
    horn = only_infection(head.crop((26, 0, 38, 11)))      # cuerno de arriba
    claw = p["claw"].crop((31, 26, 48, 52)).transpose(Image.FLIP_LEFT_RIGHT)
    shoulder = p["fist"].crop((0, 25, 13, 37)).transpose(Image.FLIP_LEFT_RIGHT)
    frames = []
    ref_top = None
    for i in range(4):
        f = np.array(Image.open(BACK % i).convert("RGBA"))
        # borra la garra de la fase 1 (lado izquierdo, rosa) para poner la grande
        r, g, b, al = (f[..., k].astype(int) for k in range(4))
        region = np.zeros(al.shape, bool)
        region[28:, :24] = True                            # la garra vieja vive aquí
        ys, xs = np.nonzero(region & (al > 0) & (r > g + 40) & (b > g + 20))
        cyx = (ys.mean(), xs.mean()) if len(ys) else (42.0, 17.0)
        f[region] = 0
        img = Image.fromarray(f, "RGBA")
        # la cabeza de la espalda sube y baja: sigue su borde superior
        white = (f[..., 0] > 200) & (f[..., 1] > 200) & (f[..., 2] > 200) & (f[..., 3] > 0)
        top = int(np.nonzero(white.any(1))[0][0])
        ref_top = top if ref_top is None else ref_top
        dy = top - ref_top
        c = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        c.paste(claw, (int(cyx[1]) - claw.width // 2 - 1, int(cyx[0]) - claw.height // 2 - 1), claw)
        c.alpha_composite(img)
        c.paste(growth, (26, 9 + dy), growth)              # en la nuca
        c.paste(horn, (40, 1 + dy), horn)
        c.paste(shoulder, (45, 27 + dy), shoulder)
        frames.append(outline(despeckle(c)))
    return frames


def only_infection(img: Image.Image) -> Image.Image:
    """Deja solo lo rosa/oscuro/verde de la infección (fuera el casco blanco y naranja)."""
    a = np.array(img)
    r, g, b = (a[..., k].astype(int) for k in range(3))
    suit = ((r > 170) & (g > 150)) | ((r > 180) & (g > 70) & (b < 90))
    a[suit & ~is_green(a)] = 0
    return Image.fromarray(a, "RGBA")


def sheet(frames: list) -> Image.Image:
    s = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.alpha_composite(f, (i * SIZE, 0))
    return s


def main() -> None:
    side = Image.open(SRC).convert("RGBA")
    side = side.crop(side.getbbox())
    raw = reduce(side, BODY_H / side.height)
    backs = [Image.open(BACK % i).convert("RGBA") for i in range(4)]
    pal = palette([raw] + backs)
    base = apply_palette(raw, pal)
    p = parts(base)
    ox = (SIZE - base.width) // 2
    oy = FEET_Y - base.height
    anims = {"idle": idle(p, ox, oy), "run": run(p, ox, oy), "walk_up": back_view(p, base)}
    for i, spec in enumerate(COMBOS):
        anims["combo_%d" % (i + 1)] = combo(p, ox, oy, spec)
    os.makedirs(OUT, exist_ok=True)
    for name, frames in anims.items():
        for i, f in enumerate(frames):
            f.save(os.path.join(OUT, f"{name}_{i}.png"))
        sheet(frames).save(os.path.join(OUT, f"{name}.png"))
    print("ok", {k: len(v) for k, v in anims.items()})


if __name__ == "__main__":
    main()
