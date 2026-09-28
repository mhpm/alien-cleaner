"""Fases 3+ del mutante animadas con un esqueleto hecho de sus piezas sueltas.

python tools/make_infected_rig.py <fase>      (3, 4, ...)
Cada fase (PHASES) trae su hoja de piezas (tools/infected_phase<n>_parts.webp), su
tamaño final (`size`: 64 la fase 3, 100 desde la 4) y, por pieza, el recorte en la hoja,
la escala, la posición en su dibujo completo de referencia y la articulación sobre la
que gira. Cada frame se arma en alta resolución girando las piezas y se reduce al tamaño
final con una paleta común (utilidades de make_infected_phase1/2). Cada pieza se reduce
y contornea por separado y se guarda también como capa: layers/<capa>/<anim>_<i>.png
(las capas `back_*` son la espalda, `spikes` y `fx` los efectos), para armar el
.aseprite con una capa por pieza. Animaciones por fase: idle, run (también caminar
hacia abajo), walk_up (la espalda de la fase 1 con piezas de la fase encima) y
combo_1..3 (4 frames: carga, impacto, estela, recuperación, a 16 fps =
Infected.SLASH_TIME).
Salida: assets/sprites/mutations_player/fase <n>/pixel<size>/<anim>_<i>.png, hojas
<anim>.png, layers/ y frames.json (orden de frames y capas para el .aseprite).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

import make_infected_phase1 as p1
import make_infected_phase2 as p2
from make_infected_phase1 import outline, reduce, apply_palette, fade, shifted

ROOT = p1.ROOT
PAD = 90                     # margen del lienzo grande alrededor del dibujo de referencia
GREEN_WEIGHT = 6
BROOD_PX = 20                # ancho de los sprites de la cría (Infected BROOD BURST)
BACK_IDS = ["007", "005", "008", "006"]   # espalda de la hoja de la fase 1 (walk_up)
ANIMS = ["idle", "run", "walk_up", "combo_1", "combo_2", "combo_3"]
BACK_LAYERS = ["back_claw", "back_body", "back_mass", "back_pauldron", "back_crown"]


def out_dir(n: int, size: int) -> str:
    return os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase %d" % n, "pixel%d" % size)


# ---------------------------------------------------------------- esqueleto

def load_parts(ph: dict) -> dict:
    """Piezas del esqueleto y sueltas (extras): nombre -> (imagen, posición, pivote)."""
    sheet = Image.open(ph["src"]).convert("RGBA")
    out = {}
    for k, ((x, y, w, h), s, pos, piv) in {**ph["parts"], **ph.get("extras", {})}.items():
        a = np.array(sheet.crop((x, y, x + w, y + h)))
        a[a[..., 3] < 128] = 0
        # solo la pieza: fuera las puntas de piezas vecinas que caen en el recorte
        lab, sizes = p1._label(a[..., 3] > 0)
        a[~np.isin(lab, [i for i, n in enumerate(sizes) if i and n >= max(sizes) * 0.08])] = 0
        img = Image.fromarray(a).resize((round(w * s), round(h * s)), Image.LANCZOS)
        out[k] = (img, pos, piv)
    return out


def canvas(ph: dict) -> Image.Image:
    w, h = ph["ref"]
    return Image.new("RGBA", (w + 2 * PAD, h + 2 * PAD), (0, 0, 0, 0))


def place_part(ph: dict, parts: dict, pose: dict, k: str) -> Image.Image:
    """Una pieza del esqueleto en su pose, en el lienzo grande. pose[pieza] = (dx, dy,
    grados); "body" mueve las piezas de arriba (ph["upper"]). Grados + = antihorario."""
    c = canvas(ph)
    bx, by = pose.get("body", (0, 0))
    follow = ph.get("follow", {})
    img, (px, py), (vx, vy) = parts[k]
    dx, dy, rot = pose.get(follow.get(k, k), (0, 0, 0))
    if k in follow:
        rot = pose.get(k, (0, 0, rot))[2]
    if k in ph["upper"]:
        dx, dy = dx + bx, dy + by
    c.alpha_composite(img, (px + PAD, py + PAD))
    if rot:
        c = c.rotate(rot, resample=Image.BICUBIC, center=(vx + PAD, vy + PAD))
    return shifted(c, int(dx), int(dy))


def place_extras(ph: dict, parts: dict, extra: list) -> Image.Image:
    """Piezas sueltas [(pieza, x, y del pie, grados)] en el lienzo grande."""
    c = canvas(ph)
    for k, x, y, rot in extra:
        img = parts[k][0].rotate(rot, resample=Image.BICUBIC, expand=True) if rot else parts[k][0]
        c.alpha_composite(img, (int(x + PAD - img.width / 2), int(y + PAD - img.height)))
    return c


def palette(ph: dict, imgs: list) -> Image.Image:
    px = []
    for i in imgs:
        a = np.array(i)
        px.append(a[..., :3][a[..., 3] > 0])
        px.append(np.repeat(a[..., :3][p2.is_green(a)], GREEN_WEIGHT, axis=0))
    px = np.concatenate(px)
    strip = Image.fromarray(px.reshape(1, -1, 3).astype(np.uint8), "RGB")
    return strip.quantize(ph.get("colors", 46), method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


class Rig:
    """Reduce frames grandes al tamaño final con escala, anclaje y paleta fijos (los del
    reposo) y guarda cada frame como capas."""

    def __init__(self, ph: dict):
        self.ph = ph
        self.size = ph.get("size", 64)
        self.k = self.size / 64.0                     # las medidas de las poses van en px de 64
        self.body_h = round(56 * self.k)
        self.feet = self.size - 2
        self.parts = load_parts(ph)
        self.frames: list = []                        # [(composición, {capa: imagen})]
        rest = self._stack(ph, {})
        x0, y0, x1, y1 = rest.getbbox()
        self.scale = self.body_h / (y1 - y0)
        bx, by = self._boots(reduce(rest, self.scale, crop=False))
        # botas del reposo -> mismo sitio que en todas las fases (centro, pies abajo)
        self.off = (round(self.size / 2 - 4 * self.k - bx), round(self.feet - 2 - by))
        self.backs = self._back_bases()
        self.pal = palette(ph, [self.small(rest)] + self.backs)

    def _stack(self, ph: dict, pose: dict) -> Image.Image:
        c = canvas(ph)
        for k in ph["order"]:
            c.alpha_composite(place_part(ph, self.parts, pose, k))
        return c

    @staticmethod
    def _boots(img: Image.Image) -> tuple:
        a = np.array(img).astype(int)
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        ys, xs = np.nonzero((al > 0) & (b > r + 40) & (b > g + 20))
        low = ys > ys.max() - 6
        return xs[low].mean(), ys.max()

    def _back_bases(self) -> list:
        """Los 4 frames de espalda de la fase 1 a este tamaño (sin paleta aún)."""
        if self.size == 64:
            return [Image.open(p2.BACK % i).convert("RGBA") for i in range(4)]
        srcs = [Image.open(p1.ELEMENTS % i).convert("RGBA") for i in BACK_IDS]
        srcs = [s.crop(s.getbbox()) for s in srcs]
        h = sorted(s.height for s in srcs)[len(srcs) // 2]
        out = []
        for s in srcs:
            small = reduce(s, self.body_h / h)
            cx = p1.head_center_x(s) * small.width / s.width
            c = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
            c.alpha_composite(small, (round(self.size / 2 - cx), self.feet - small.height))
            out.append(c)
        return out

    def small(self, big: Image.Image) -> Image.Image:
        s = reduce(big, self.scale, crop=False)
        c = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
        c.paste(s, self.off, s)
        return c

    def finish(self, img: Image.Image, glow: float = 0.0) -> Image.Image:
        """Paleta, latido de los ojos, limpieza y contorno de una capa."""
        img = apply_palette(img, self.pal)
        return outline(p2.despeckle(p2.eye_glow(img, glow)))

    def commit(self, layers: dict) -> Image.Image:
        """Guarda un frame hecho de capas (en orden) y devuelve su composición."""
        comp = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
        for img in layers.values():
            comp.alpha_composite(img)
        self.frames.append((comp, layers))
        return comp

    def frame(self, pose: dict, glow: float = 0.0, fx: Image.Image = None) -> Image.Image:
        layers = {}
        for k in self.ph["order"]:
            layers[k] = self.finish(self.small(place_part(self.ph, self.parts, pose, k)), glow)
        if pose.get("extra"):
            layers["spikes"] = self.finish(self.small(place_extras(self.ph, self.parts, pose["extra"])))
        if fx is not None:
            layers["fx"] = fx
        return self.commit(layers)

    def to_px(self, x: float, y: float) -> tuple:
        """Coordenadas de la referencia -> lienzo final."""
        return ((x + PAD) * self.scale + self.off[0], (y + PAD) * self.scale + self.off[1])

    def piece(self, k: str, box=None, infection_only: bool = False) -> Image.Image:
        """Una pieza reducida a la escala final (para la espalda)."""
        img = self.parts[k][0]
        if box:
            img = img.crop(box)
        s = img.resize((max(1, round(img.width * self.scale)), max(1, round(img.height * self.scale))),
                       Image.BOX)
        return apply_palette(p2.only_infection(s) if infection_only else s, self.pal)


def arc(rig: Rig, center: tuple, r: float, a0: float, a1: float, w: float) -> Image.Image:
    """Arco de energía; radio y grosor en px de 64 (se escalan al tamaño de la fase)."""
    cx, cy = rig.to_px(*center)
    return p2.draw_arc(rig.size, cx, cy, r * rig.k, a0, a1, w * rig.k)


def shockwave(rig: Rig, center: tuple, rx: float, ry: float, w: float) -> Image.Image:
    """Onda de choque aplastada en el suelo (medidas en px de 64)."""
    cx, cy = rig.to_px(*center)
    rx, ry, w = rx * rig.k, ry * rig.k, w * rig.k
    n = rig.size
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.hypot((xx - cx) / rx, (yy - cy) / ry)
    band = (d <= 1) & (d >= 1 - w / rx)
    kk = np.clip((1 - d) * rx / w, 0, 1)
    cols = np.array(p2.ARC_COLS, np.uint8)
    idx = np.clip((kk * len(cols)).astype(int), 0, len(cols) - 1)
    img = np.zeros((n, n, 4), np.uint8)
    img[band] = cols[idx[band]]
    return Image.fromarray(img, "RGBA")


def combo(rig: Rig, windup: dict, strike: dict, recover: dict, fx, trail: tuple,
          trail_pose: dict = None) -> list:
    tx, ty = round(trail[0] * rig.k), round(trail[1] * rig.k)
    return [rig.frame(windup),
            rig.frame(strike, 0.9, fx),
            rig.frame(trail_pose or recover, 0.4, shifted(fade(fx), tx, ty) if fx is not None else None),
            rig.frame(recover)]


def run_cycle(rig: Rig, extra=None) -> list:
    """Carrera de 8 frames: piernas que giran sobre la cadera, cuerpo inclinado,
    brazos a contrafase. `extra(i, sw)` añade piezas propias de la fase."""
    frames = []
    for i in range(8):
        t = i / 8 * 2 * np.pi
        sw = np.sin(t)
        pose = {
            "body": (6, -abs(np.sin(t)) * 10 + 4),
            "leg_front": (sw * 14, -max(0.0, -np.cos(t)) * 12, -sw * 26),
            "leg_back": (-sw * 14, -max(0.0, np.cos(t)) * 12, sw * 26),
            "head": (4, 2, -4),
            "claw": (sw * 6, 0, -8 + sw * 14),
            "arm": (-sw * 8, 0, -sw * 16),
            "mass": (0, -abs(sw) * 3, sw * 3),
        }
        if extra:
            pose.update(extra(i, sw))
        frames.append(rig.frame(pose, 0.3 if i in (2, 6) else 0.0))
    return frames


def back_view(rig: Rig, layout: list) -> list:
    """walk_up: espalda de la fase 1 (sin su garra) con piezas de la fase encima.
    layout = [(capa, imagen, x, y)] en px de 64; la capa back_claw va detrás del cuerpo
    y todo sigue el rebote de la cabeza."""
    k = rig.k
    frames = []
    ref_top = None
    for i, base in enumerate(rig.backs):
        f = np.array(base)
        f[round(28 * k):, :round(24 * k)] = 0           # la garra de la fase 1
        white = (f[..., 0] > 200) & (f[..., 1] > 200) & (f[..., 2] > 200) & (f[..., 3] > 0)
        top = int(np.nonzero(white.any(1))[0][0])
        ref_top = top if ref_top is None else ref_top
        dy = top - ref_top
        layers = {}
        for name, img, x, y in layout:
            c = Image.new("RGBA", (rig.size, rig.size), (0, 0, 0, 0))
            bob = (i % 2) if name == "back_claw" else 0
            c.paste(img, (round(x * k), round(y * k) + dy + bob), img)
            layers[name] = outline(p2.despeckle(c))
        body = outline(p2.despeckle(apply_palette(Image.fromarray(f, "RGBA"), rig.pal)))
        ordered = {n: layers[n] for n in BACK_LAYERS if n in layers}
        ordered = {**({"back_claw": ordered.pop("back_claw")} if "back_claw" in ordered else {}),
                   "back_body": body, **ordered}
        frames.append(rig.commit(ordered))
    return frames


# ---------------------------------------------------------------- fase 3

def p3_idle(rig: Rig) -> list:
    body = [(0, 4), (0, 7), (0, 10), (0, 10), (0, 7), (0, 4)]
    head = [(0, 0, 0), (2, 0, -2), (4, 2, -4), (2, 3, -3), (0, 1, 0), (-2, 0, 1)]
    claw = [(0, 0, 6), (2, -3, 10), (3, -5, 14), (2, -4, 9), (0, -1, 4), (0, 0, 5)]
    arm = [(0, 0, 0), (-2, 2, -4), (-3, 3, -6), (-2, 2, -4), (0, 0, -1), (0, 0, 0)]
    mass = [(0, 0, 0), (0, -2, 2), (-1, -3, 3), (0, -2, 2), (0, 0, 0), (0, 1, -1)]
    glow = [0.0, 0.3, 0.8, 0.5, 0.2, 0.0]
    return [rig.frame({"body": body[i], "head": head[i], "claw": claw[i], "arm": arm[i],
                       "mass": mass[i], "eyeball": (0, 0, 20 * i)}, glow[i]) for i in range(6)]


def p3_run(rig: Rig) -> list:
    return run_cycle(rig, lambda i, sw: {"eyeball": (0, 0, i * 30)})


def p3_combos(rig: Rig) -> list:
    return [
        # 1: puñetazo del brazo izquierdo — el hombro gira y el puño sale al frente
        combo(rig,
              {"body": (-8, 6), "arm": (-6, 0, -30), "claw": (-4, 0, 15), "head": (-3, 0, 4),
               "leg_front": (-4, 0, 6)},
              {"body": (10, 4), "arm": (38, 12, 72), "claw": (-6, 2, 20), "head": (6, 2, -6),
               "leg_front": (10, 0, -14), "leg_back": (-6, 0, 10)},
              {"body": (5, 5), "arm": (15, -5, 45), "claw": (-2, 0, 10), "head": (3, 1, -3),
               "leg_front": (5, 0, -7)},
              arc(rig, (196, 196), 11, -60, 60, 5), (2, 0)),
        # 2: barrido amplio de la garra — de arriba atrás hasta abajo delante
        combo(rig,
              {"body": (-6, 2), "claw": (-10, -18, 80), "head": (-4, 0, 6), "arm": (0, 0, 10),
               "mass": (0, -3, 4)},
              {"body": (8, 8), "claw": (10, 8, -45), "head": (5, 3, -5), "arm": (-4, 0, -10),
               "leg_front": (8, 0, -10), "leg_back": (-4, 0, 6)},
              {"body": (4, 6), "claw": (6, 5, -25), "head": (2, 2, -3), "leg_front": (4, 0, -5)},
              arc(rig, (160, 185), 22, -120, 70, 6), (2, 1)),
        # 3: salto y golpe al suelo con las dos manos — onda de choque
        combo(rig,
              {"body": (0, -40), "claw": (0, -10, 70), "arm": (0, -6, 60), "head": (0, 0, 5),
               "leg_front": (4, -44, 10), "leg_back": (-4, -40, -10), "hips": (0, -40, 0),
               "mass": (0, -4, 6)},
              {"body": (4, 14), "claw": (8, 10, -50), "arm": (10, 8, -60), "head": (3, 4, -6),
               "leg_front": (-6, 0, 12), "leg_back": (6, 0, -12), "hips": (0, 8, 0)},
              {"body": (2, 8), "claw": (4, 6, -25), "arm": (4, 4, -30), "head": (1, 2, -3),
               "hips": (0, 4, 0)},
              shockwave(rig, (150, 300), 26, 5, 3), (0, 0)),
    ]


def p3_back(rig: Rig) -> list:
    head = rig.parts["head"][0]
    crown = rig.piece("head", (0, 0, head.width, int(head.height * 0.42)), True)
    claw = rig.piece("claw").transpose(Image.FLIP_LEFT_RIGHT)
    return back_view(rig, [("back_claw", claw, 2, 26), ("back_mass", rig.piece("mass"), 26, 22),
                           ("back_crown", crown, 18, 1)])


# ---------------------------------------------------------------- fase 4

def p4_idle(rig: Rig) -> list:
    # guardia más baja y amenazante: la garra levantada tiembla, las hombreras laten
    body = [(0, 6), (0, 9), (0, 12), (0, 12), (0, 9), (0, 6)]
    head = [(0, 0, 0), (3, 1, -3), (5, 3, -5), (3, 4, -4), (0, 2, 0), (-2, 0, 2)]
    claw = [(0, -4, 18), (2, -7, 24), (3, -9, 28), (2, -8, 22), (0, -5, 16), (0, -4, 17)]
    arm = [(0, 0, -6), (-2, 2, -10), (-3, 3, -12), (-2, 2, -9), (0, 0, -6), (0, 0, -5)]
    mass = [(0, 0, 0), (0, -3, 3), (-1, -4, 4), (0, -3, 3), (0, 0, 0), (0, 1, -1)]
    paul = [(0, 0, 0), (1, -2, -2), (1, -3, -3), (1, -2, -2), (0, 0, 0), (0, 1, 1)]
    glow = [0.1, 0.4, 0.9, 0.6, 0.3, 0.1]
    return [rig.frame({"body": body[i], "head": head[i], "claw": claw[i], "arm": arm[i],
                       "mass": mass[i], "pauldron": paul[i], "eyeball": (0, 0, 25 * i)}, glow[i])
            for i in range(6)]


def p4_run(rig: Rig) -> list:
    return run_cycle(rig, lambda i, sw: {"pauldron": (sw * 4, -abs(sw) * 3, -sw * 5),
                                         "claw": (sw * 6, -4, 6 + sw * 14)})


P4_SPIKES = [("spike_a", 250, 352, 0), ("spike_b", 280, 350, -12), ("spike_c", 224, 352, 14)]


def p4_combos(rig: Rig) -> list:
    spikes_up = [(k, x, y, r) for k, x, y, r in P4_SPIKES]
    spikes_low = [(k, x, y + 12, r) for k, x, y, r in P4_SPIKES]
    return [
        # 1: zarpazo ascendente — la garra baja atrás y sube rasgando
        combo(rig,
              {"body": (-6, 8), "claw": (-8, 12, -45), "head": (-3, 3, 5), "pauldron": (-3, 3, 4),
               "arm": (2, 0, -10)},
              {"body": (10, -4), "claw": (8, -16, 100), "head": (5, -2, -7), "pauldron": (5, -5, -8),
               "leg_front": (10, 0, -12), "leg_back": (-6, 0, 8), "arm": (-4, 0, -20)},
              {"body": (5, 0), "claw": (4, -8, 50), "head": (2, 0, -3), "pauldron": (2, -2, -4)},
              arc(rig, (196, 176), 22, 75, -100, 6), (1, -2)),
        # 2: embestida con la hombrera — todo el cuerpo se lanza al frente
        combo(rig,
              {"body": (-14, 4), "pauldron": (-6, 0, 10), "head": (-6, 2, 7), "claw": (-8, 2, 25),
               "arm": (-6, 0, -25), "leg_front": (-6, 0, 10)},
              {"body": (26, 6), "pauldron": (10, 2, -12), "head": (14, 6, -12), "claw": (6, 4, -10),
               "arm": (-10, 0, -35), "leg_front": (20, 0, -22), "leg_back": (-4, 0, 14)},
              {"body": (13, 4), "pauldron": (5, 1, -6), "head": (7, 3, -6), "leg_front": (10, 0, -11)},
              arc(rig, (226, 196), 15, -80, 80, 7), (3, 0)),
        # 3: golpe al suelo con la garra — brotan púas delante
        combo(rig,
              {"body": (0, -8), "claw": (-4, -22, 115), "head": (0, -2, 7), "mass": (0, -4, 5),
               "pauldron": (0, -4, 6), "arm": (0, -2, 15)},
              {"body": (8, 14), "claw": (10, 14, -70), "head": (4, 7, -7), "arm": (4, 6, -22),
               "pauldron": (4, 6, -6), "hips": (0, 6, 0), "extra": spikes_low},
              {"body": (4, 8), "claw": (5, 8, -35), "head": (2, 4, -3), "hips": (0, 3, 0)},
              shockwave(rig, (238, 336), 16, 4, 3), (0, 0),
              trail_pose={"body": (6, 10), "claw": (8, 11, -55), "head": (3, 5, -5), "hips": (0, 4, 0),
                          "extra": spikes_up}),
    ]


def p4_back(rig: Rig) -> list:
    head = rig.parts["head"][0]
    crown = rig.piece("head", (0, 0, head.width, int(head.height * 0.40)), True)
    claw = rig.piece("claw").transpose(Image.FLIP_LEFT_RIGHT)
    return back_view(rig, [("back_claw", claw, 1, 27), ("back_mass", rig.piece("mass"), 22, 18),
                           ("back_pauldron", rig.piece("pauldron"), 44, 22), ("back_crown", crown, 18, 0)])


# ---------------------------------------------------------------- fases

PHASES = {
    3: {
        "src": os.path.join(ROOT, "tools", "infected_phase3_parts.webp"),
        "ref": (275, 316),   # tools/infected_phase3_ref.png
        "size": 64,
        # pieza: (recorte x, y, w, h), escala, posición en la referencia, articulación
        "parts": {
            "mass": ((37, 185, 404, 468), 0.33, (2, 62), (95, 150)),
            "leg_back": ((974, 800, 269, 257), 0.33, (151, 232), (182, 238)),
            "hips": ((574, 791, 349, 202), 0.33, (88, 212), (146, 222)),
            "leg_front": ((237, 795, 269, 257), 0.33, (45, 229), (100, 236)),
            "torso": ((574, 502, 349, 277), 0.34, (87, 150), (146, 200)),
            "claw": ((1022, 294, 395, 496), 0.33, (140, 125), (152, 176)),
            "eyeball": ((943, 603, 177, 186), 0.22, (133, 157), (152, 176)),
            "arm": ((314, 451, 231, 325), 0.35, (24, 153), (82, 162)),
            "head": ((554, 33, 458, 445), 0.37, (73, 2), (150, 150)),
        },
        "order": ["mass", "leg_back", "hips", "leg_front", "torso", "claw", "eyeball", "arm", "head"],
        "upper": {"mass", "torso", "claw", "eyeball", "arm", "head"},
        "follow": {"eyeball": "claw"},       # la bola con ojo es la hombrera de la garra
        "idle": p3_idle, "run": p3_run, "combos": p3_combos, "back": p3_back,
    },
    4: {
        "src": os.path.join(ROOT, "tools", "infected_phase4_parts.webp"),
        "ref": (295, 358),   # tools/mutation_looks/phase_4.png
        "size": 100,
        "colors": 56,
        # posiciones y escalas: las de la primera hoja de la fase 4 (encajada con el
        # dibujo), pasadas a esta hoja manteniendo el centro y el área de cada pieza
        "parts": {
            "mass": ((54, 54, 429, 410), 0.296, (6, 78), (100, 160)),
            "leg_back": ((841, 680, 282, 311), 0.339, (156, 240), (190, 245)),
            "hips": ((573, 752, 250, 136), 0.31, (119, 222), (158, 235)),
            "leg_front": ((252, 680, 301, 311), 0.383, (33, 232), (110, 240)),
            "eyeball": ((1352, 317, 154, 151), 0.205, (181, 249), (196, 265)),
            "torso": ((504, 451, 393, 255), 0.325, (100, 144), (160, 200)),
            "claw": ((949, 448, 350, 389), 0.327, (177, 153), (195, 170)),
            "pauldron": ((1000, 62, 337, 428), 0.239, (160, 106), (195, 165)),
            "arm": ((166, 468, 280, 287), 0.341, (14, 175), (95, 180)),
            "head": ((482, 23, 482, 429), 0.369, (66, 1), (160, 150)),
        },
        # sueltas: bolas con ojo de la cría (BROOD BURST) y púas del golpe al suelo
        "extras": {
            "brood_0": ((1352, 317, 154, 151), 0.5, (0, 0), (0, 0)),
            "brood_1": ((1330, 123, 176, 170), 0.45, (0, 0), (0, 0)),
            "spike_a": ((1330, 496, 102, 134), 0.45, (0, 0), (0, 0)),
            "spike_b": ((1424, 533, 79, 144), 0.42, (0, 0), (0, 0)),
            "spike_c": ((1330, 654, 75, 132), 0.45, (0, 0), (0, 0)),
        },
        "order": ["mass", "leg_back", "eyeball", "hips", "leg_front", "torso", "claw", "pauldron",
                  "arm", "head"],
        "upper": {"mass", "torso", "claw", "pauldron", "arm", "head"},
        "follow": {"eyeball": "leg_back"},   # la bola con ojo va en la rodilla trasera
        "idle": p4_idle, "run": p4_run, "combos": p4_combos, "back": p4_back,
    },
}


def main(n: int) -> None:
    ph = PHASES[n]
    rig = Rig(ph)
    anims = {"idle": ph["idle"](rig), "run": ph["run"](rig), "walk_up": ph["back"](rig)}
    for i, frames in enumerate(ph["combos"](rig)):
        anims["combo_%d" % (i + 1)] = frames
    out = out_dir(n, rig.size)
    os.makedirs(out, exist_ok=True)
    for name in ANIMS:
        for i, f in enumerate(anims[name]):
            f.save(os.path.join(out, f"{name}_{i}.png"))
        sheet = Image.new("RGBA", (rig.size * len(anims[name]), rig.size), (0, 0, 0, 0))
        for i, f in enumerate(anims[name]):
            sheet.alpha_composite(f, (i * rig.size, 0))
        sheet.save(os.path.join(out, f"{name}.png"))
    # capas: una carpeta por pieza con un PNG por frame (vacío si la pieza no sale)
    names = [f"{a}_{i}" for a in ANIMS for i in range(len(anims[a]))]
    order = BACK_LAYERS[:1] + BACK_LAYERS[1:2] + ph["order"] + BACK_LAYERS[2:] + ["spikes", "fx"]
    used = [l for l in order if any(l in ls for _, ls in rig.frames)]
    empty = Image.new("RGBA", (rig.size, rig.size), (0, 0, 0, 0))
    for l in used:
        d = os.path.join(out, "layers", l)
        os.makedirs(d, exist_ok=True)
        for fname, (_, ls) in zip(names, rig.frames):
            ls.get(l, empty).save(os.path.join(d, fname + ".png"))
    counts = {a: len(anims[a]) for a in ANIMS}
    with open(os.path.join(out, "frames.json"), "w") as f:
        json.dump({"size": rig.size, "anims": counts, "layers": used}, f, indent=1)
    # sprites sueltos de la fase (la cría de BROOD BURST) a BROOD_PX de ancho
    for k in [k for k in ph.get("extras", {}) if k.startswith("brood_")]:
        img = rig.parts[k][0]
        s = img.resize((BROOD_PX, round(img.height * BROOD_PX / img.width)), Image.BOX)
        a = np.array(s)
        a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
        outline(apply_palette(Image.fromarray(a, "RGBA"), rig.pal)).save(os.path.join(out, k + ".png"))
    print("fase", n, counts, "size", rig.size, "scale %.3f" % rig.scale, "layers", used)


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 3)
