"""Fases del mutante armadas con una biblioteca de poses de sus piezas (100x100, por capas).

python tools/make_infected_poses.py <fase> [--rest]
La fase trae una carpeta de piezas sueltas (p. ej. fase 3/fase 3 sheet_elements/, sacadas
de "fase 3 sheet.png": cabeza de lado y de espaldas, masa de púas, 5 torsos girados,
puños y garras, pierna delantera e trasera en 6 poses, pelvis, pies y púas). Cada pieza
tiene una articulación en el esqueleto (JOINTS, en px de la hoja) y cada frame elige
qué sprite usa cada pieza (variante), cuánto se desplaza y cuánto gira sobre su
articulación. Cada sprite encaja su propio punto de unión (arriba al centro para
piernas y brazos, centro para el resto) en la articulación. Se arma en alta resolución,
se reduce a 100x100 con paleta común y cada pieza se guarda también como capa
(layers/<capa>/<anim>_<i>.png + frames.json) para tools/build_rig_aseprite.py.
--rest guarda solo la pose de reposo ampliada (para ajustar JOINTS).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

import make_infected_phase1 as p1
import make_infected_phase2 as p2
from make_infected_phase1 import outline, reduce, apply_palette, fade, shifted
from make_infected_rig import arc, shockwave, ANIMS

ROOT = p1.ROOT
SIZE = 100
CANVAS = (760, 760)          # lienzo de trabajo (px de la hoja)
GROUND = 660                 # suelo en el lienzo de trabajo
GREEN_WEIGHT = 6


def out_dir(n: int) -> str:
    return os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase %d" % n, "pixel%d" % SIZE)


def load(folder: str, prefix: str, ids: set) -> dict:
    out = {}
    for i in ids:
        a = np.array(Image.open(os.path.join(folder, "%s_%s.png" % (prefix, i))).convert("RGBA"))
        a[a[..., 3] < 128] = 0
        out[i] = Image.fromarray(a)
    return out


def split_pair(img: Image.Image) -> list:
    """Un PNG con dos piezas juntas (p. ej. 2 garras) -> las dos por separado."""
    a = np.array(img)
    lab, sizes = p1._label(a[..., 3] > 0)
    big = sorted(range(1, len(sizes)), key=lambda k: -sizes[k])[:2]
    out = []
    for k in sorted(big, key=lambda k: np.nonzero(lab == k)[1].mean()):
        b = a.copy()
        b[lab != k] = 0
        im = Image.fromarray(b)
        out.append(im.crop(im.getbbox()))
    return out


def joint_of(img: Image.Image, mode: str) -> tuple:
    """Punto de unión de un sprite: "top" = centro de sus filas de arriba (cadera,
    hombro), "center" = centro de la caja."""
    a = np.array(img)[..., 3] > 0
    if mode == "top":
        ys, xs = np.nonzero(a)
        top = ys < ys.min() + max(6, int(a.shape[0] * 0.14))
        return float(xs[top].mean()), float(ys.min() + 4)
    return img.width / 2.0, img.height / 2.0


def palette(imgs: list, colors: int) -> Image.Image:
    px = []
    for i in imgs:
        a = np.array(i)
        px.append(a[..., :3][a[..., 3] > 0])
        px.append(np.repeat(a[..., :3][p2.is_green(a)], GREEN_WEIGHT, axis=0))
    px = np.concatenate(px)
    strip = Image.fromarray(px.reshape(1, -1, 3).astype(np.uint8), "RGB")
    return strip.quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


class PoseRig:
    def __init__(self, ph: dict):
        self.ph = ph
        self.size = SIZE
        self.k = SIZE / 64.0
        self.body_h = round(56 * self.k)
        ids = {v for p in ph["parts"].values() for v in p["variants"]} | set(ph.get("extras", {}).values())
        self.src = load(ph["dir"], ph["prefix"], {i.split(":")[0] for i in ids})
        for i in list(ids):
            if ":" in i:                              # "021:0" = primera pieza de un PNG doble
                base, n = i.split(":")
                self.src[i] = split_pair(self.src[base])[int(n)]
        self.frames: list = []
        rest = self.assemble(ph["rest"])
        x0, y0, x1, y1 = rest.getbbox()
        self.scale = self.body_h / (y1 - y0)
        small = reduce(rest, self.scale, crop=False)
        bx, by = self._boots(small)
        self.off = (round(SIZE / 2 - 4 * self.k - bx), round(SIZE - 4 - by))
        backs = [self.assemble(p) for p in ph.get("palette_poses", [])]
        self.pal = palette([self.small(rest)] + [self.small(b) for b in backs], ph.get("colors", 56))

    @staticmethod
    def _boots(img: Image.Image) -> tuple:
        a = np.array(img).astype(int)
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        ys, xs = np.nonzero((al > 0) & (b > r + 40) & (b > g + 20))
        low = ys > ys.max() - 6
        return xs[low].mean(), ys.max()

    # --------------------------------------------------------- armado

    def place(self, part: str, spec) -> Image.Image:
        """spec = variante o (variante, dx, dy, grados[, espejo])."""
        p = self.ph["parts"][part]
        if isinstance(spec, str):
            spec = (spec, 0, 0, 0)
        v, dx, dy, rot = spec[:4]
        img = self.src[v]
        if len(spec) > 4 and spec[4]:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        jx, jy = joint_of(img, p["joint"])
        ax, ay = p["at"]
        c = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        x, y = round(ax - jx), round(ay - jy)
        c.alpha_composite(img, (x, y)) if x >= 0 and y >= 0 else c.paste(img, (x, y), img)
        if rot:
            c = c.rotate(rot, resample=Image.BICUBIC, center=(ax, ay))
        return shifted(c, int(dx), int(dy))

    def layers_big(self, pose: dict) -> dict:
        """pose: pieza -> spec; "body" = (dx, dy) que mueve las piezas de arriba;
        "extra" = [(sprite, x, y del pie, grados)] sueltos (capa spikes)."""
        bx, by = pose.get("body", (0, 0))
        out = {}
        for part in self.ph["order"]:
            spec = pose.get(part, self.ph["rest"].get(part))
            if spec is None:
                continue
            if isinstance(spec, str):
                spec = (spec, 0, 0, 0)
            if part in self.ph["upper"]:
                spec = (spec[0], spec[1] + bx, spec[2] + by, *spec[3:])
            out[part] = self.place(part, spec)
        if pose.get("extra"):
            c = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
            for v, x, y, rot in pose["extra"]:
                img = self.src[v].rotate(rot, resample=Image.BICUBIC, expand=True) if rot else self.src[v]
                c.alpha_composite(img, (int(x - img.width / 2), int(y - img.height)))
            out["spikes"] = c
        return out

    def assemble(self, pose: dict) -> Image.Image:
        c = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        for img in self.layers_big(pose).values():
            c.alpha_composite(img)
        return c

    def small(self, big: Image.Image) -> Image.Image:
        s = reduce(big, self.scale, crop=False)
        c = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        c.paste(s, self.off, s)
        return c

    def finish(self, img: Image.Image, glow: float = 0.0) -> Image.Image:
        img = apply_palette(img, self.pal)
        return outline(p2.despeckle(p2.eye_glow(img, glow)))

    def frame(self, pose: dict, glow: float = 0.0, fx: Image.Image = None) -> Image.Image:
        layers = {k: self.finish(self.small(v), glow) for k, v in self.layers_big(pose).items()}
        if fx is not None:
            layers["fx"] = fx
        comp = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        for img in layers.values():
            comp.alpha_composite(img)
        self.frames.append((comp, layers))
        return comp

    def to_px(self, x: float, y: float) -> tuple:
        """Lienzo de trabajo -> lienzo final (lo usan arc/shockwave)."""
        return (x * self.scale + self.off[0], y * self.scale + self.off[1])


def combo(rig: PoseRig, windup: dict, strike: dict, recover: dict, fx, trail: tuple,
          trail_pose: dict = None) -> list:
    tx, ty = round(trail[0] * rig.k), round(trail[1] * rig.k)
    return [rig.frame(windup),
            rig.frame(strike, 0.9, fx),
            rig.frame(trail_pose or recover, 0.4, shifted(fade(fx), tx, ty) if fx is not None else None),
            rig.frame(recover)]


# ---------------------------------------------------------------- fase 3

P3_DIR = os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase 3", "fase 3 sheet_elements")


def p3_idle(rig: PoseRig) -> list:
    body = [(0, 4), (0, 8), (0, 12), (0, 12), (0, 8), (0, 4)]
    head = [0, -2, -4, -3, -1, 1]
    claw = [6, 10, 14, 10, 5, 4]
    arm = [0, -3, -5, -4, -1, 0]
    mass = [0, 2, 4, 3, 1, -1]
    glow = [0.0, 0.3, 0.8, 0.5, 0.2, 0.0]
    frames = []
    for i in range(6):
        b = body[i]
        frames.append(rig.frame({
            "body": b, "pelvis": ("045", 0, b[1] // 2, 0),
            "head": ("001", 2 if i in (2, 3) else 0, 2 if i == 3 else 0, head[i]),
            "claw": ("022", 0, -claw[i] // 3, claw[i]),
            "arm": ("020", 0, 0, arm[i]),
            "mass": ("002", 0, -mass[i], mass[i]),
        }, glow[i]))
    return frames


# ciclo de 8 pasos: (pierna delantera, dx), (pierna trasera, dx), torso
P3_RUN = [
    (("032", 16), ("059", -10), "015"),
    (("033", 12), ("055", -6), "015"),
    (("029", 4), ("058", 0), "016"),
    (("028", -6), ("062", 6), "016"),
    (("031", -12), ("061", 12), "015"),
    (("030", -4), ("056", 8), "015"),
    (("030", 6), ("058", 0), "016"),
    (("032", 12), ("055", -8), "016"),
]


def p3_run(rig: PoseRig) -> list:
    frames = []
    for i, ((fl, fdx), (bl, bdx), torso) in enumerate(P3_RUN):
        sw = np.sin(i / 8 * 2 * np.pi)
        lift_f = -18 if fl == "030" else (-8 if fl == "032" else 0)
        lift_b = -14 if bl == "059" else 0
        bob = -abs(sw) * 10 + 6
        frames.append(rig.frame({
            "body": (8, bob),
            "leg_front": (fl, fdx, lift_f, 0),
            "leg_back": (bl, bdx, lift_b, 0),
            "pelvis": ("045", 4, bob // 2, 0),
            "torso": torso,
            "head": ("001", 4, 2, -4),
            "claw": ("022", sw * 8, 0, -8 + sw * 16),
            "arm": ("020", -sw * 10, 0, -sw * 18),
            "mass": ("002", 0, -abs(sw) * 4, sw * 4),
        }, 0.3 if i in (2, 6) else 0.0))
    return frames


def p3_back(rig: PoseRig) -> list:
    """walk_up: la cabeza de espaldas (003), la masa de púas sobre la espalda, garra a la
    izquierda y puño a la derecha (espejados), piernas rectas y dobladas alternas."""
    legs = [("029", "061"), ("058", "029"), ("062", "029"), ("029", "058")]
    lifts = [(0, -10), (0, 0), (-10, 0), (0, 0)]
    frames = []
    for i in range(4):
        bob = [0, 6, 0, 6][i]
        fl, bl = legs[i]
        frames.append(rig.frame({
            "body": (0, bob),
            "leg_front": (fl, 0, lifts[i][0], 0),
            "leg_back": (bl, 0, lifts[i][1], 0),
            "pelvis": ("064", 0, bob // 2, 0),
            "torso": ("019", 0, 0, 0),
            "head": ("003", 0, 0, 0),
            "mass": ("002", 0, -4, 0),
            "claw": ("022", -20, 0, 8 if i % 2 else -4, True),
            "arm": ("020", 20, 0, -4 if i % 2 else 6, True),
        }, 0.0))
    return frames


P3_SPIKES = [("004", 470, 668, -8), ("006", 520, 668, 4), ("010", 570, 668, 14)]


def p3_combos(rig: PoseRig) -> list:
    spikes_low = [(v, x, y + 30, r) for v, x, y, r in P3_SPIKES]
    return [
        # 1: puñetazo — el torso gira (017) y el puño sale al frente
        combo(rig,
              {"body": (-10, 6), "torso": "018", "arm": ("020", -8, 0, 25), "claw": ("022", -6, 0, 15),
               "head": ("001", -4, 0, 4), "leg_front": ("028", -4, 0, 0)},
              {"body": (14, 4), "torso": "017", "arm": ("020", 230, -10, 60, True), "claw": ("022", -30, 18, 30),
               "head": ("001", 8, 2, -6), "leg_front": ("033", 14, 0, 0), "leg_back": ("055", -8, 0, 0)},
              {"body": (6, 5), "torso": "016", "arm": ("020", 150, -5, 40, True), "claw": ("022", -14, 8, 18),
               "head": ("001", 3, 1, -3), "leg_front": ("033", 6, 0, 0)},
              arc(rig, (575, 405), 12, -60, 60, 5), (2, 0)),
        # 2: barrido de garra — de arriba atrás hasta abajo delante
        combo(rig,
              {"body": (-8, 2), "torso": "018", "claw": ("026", -14, -30, 80), "head": ("001", -5, 0, 6),
               "arm": ("020", 0, 0, 10), "mass": ("002", 0, -4, 5)},
              {"body": (12, 10), "torso": "017", "claw": ("026", 16, 12, -45), "head": ("001", 6, 4, -5),
               "arm": ("020", -6, 0, -10), "leg_front": ("032", 10, 0, 0), "leg_back": ("062", -6, 0, 0)},
              {"body": (6, 8), "torso": "016", "claw": ("026", 8, 6, -25), "head": ("001", 3, 2, -3),
               "leg_front": ("033", 6, 0, 0)},
              arc(rig, (520, 390), 22, -120, 70, 6), (2, 1)),
        # 3: salto y golpe al suelo — púas que brotan y onda de choque
        combo(rig,
              {"body": (0, -60), "claw": ("022", 0, -14, 70), "arm": ("020", 0, -10, 60),
               "head": ("001", 0, 0, 5), "leg_front": ("030", 6, -66, 0), "leg_back": ("059", -6, -60, 0),
               "pelvis": ("045", 0, -60, 0), "mass": ("002", 0, -6, 8)},
              {"body": (6, 20), "torso": "017", "claw": ("026", 14, 16, -55), "arm": ("024", 14, 12, -30),
               "head": ("001", 4, 6, -6), "leg_front": ("028", 12, 0, 0), "leg_back": ("055", -12, 0, 0),
               "pelvis": ("045", 0, 12, 0), "extra": spikes_low},
              {"body": (3, 12), "claw": ("026", 6, 8, -25), "arm": ("020", 6, 6, -20),
               "head": ("001", 2, 3, -3), "pelvis": ("045", 0, 6, 0)},
              shockwave(rig, (500, 650), 26, 5, 3), (0, 0),
              trail_pose={"body": (4, 16), "claw": ("026", 10, 12, -40), "arm": ("024", 10, 9, -25),
                          "head": ("001", 3, 4, -4), "leg_front": ("028", 10, 0, 0),
                          "leg_back": ("055", -10, 0, 0), "pelvis": ("045", 0, 9, 0),
                          "extra": P3_SPIKES}),
    ]


PHASES = {
    3: {
        "dir": P3_DIR, "prefix": "fase 3 sheet", "colors": 80,
        # joint: punto de unión de cada sprite ("top" = arriba al centro); at = articulación
        "parts": {
            "leg_back": {"variants": ["055", "056", "058", "059", "061", "062"], "joint": "top", "at": (315, 515)},
            "leg_front": {"variants": ["028", "029", "030", "031", "032", "033"], "joint": "top", "at": (440, 515)},
            "pelvis": {"variants": ["045", "064"], "joint": "center", "at": (380, 505)},
            "mass": {"variants": ["002"], "joint": "center", "at": (275, 325)},
            "torso": {"variants": ["015", "016", "017", "018", "019"], "joint": "center", "at": (385, 410)},
            "claw": {"variants": ["022", "026"], "joint": "top", "at": (500, 370)},
            "arm": {"variants": ["020", "023", "024"], "joint": "top", "at": (280, 385)},
            "head": {"variants": ["001", "003"], "joint": "center", "at": (400, 230)},
        },
        "extras": {"a": "004", "b": "006", "c": "010"},
        "order": ["mass", "leg_back", "pelvis", "leg_front", "torso", "claw", "arm", "head"],
        "upper": {"mass", "torso", "claw", "arm", "head"},
        "rest": {"leg_back": "055", "leg_front": "033", "pelvis": "045", "mass": "002",
                 "torso": "015", "claw": "022", "arm": "020", "head": "001"},
        "palette_poses": [{"head": "003", "torso": "019", "pelvis": "064"}],
        "idle": p3_idle, "run": p3_run, "combos": p3_combos, "back": p3_back,
    },
}


def main(n: int, rest_only: bool = False) -> None:
    ph = PHASES[n]
    rig = PoseRig(ph)
    if rest_only:
        big = rig.assemble(ph["rest"])
        bg = Image.new("RGBA", CANVAS, (70, 80, 100, 255))
        bg.alpha_composite(big)
        path = os.path.join(out_dir(n), "_rest_big.png")
        os.makedirs(out_dir(n), exist_ok=True)
        bg.save(path)
        f = rig.frame(ph["rest"])
        f.save(os.path.join(out_dir(n), "_rest.png"))
        print(path)
        return
    anims = {"idle": ph["idle"](rig), "run": ph["run"](rig), "walk_up": ph["back"](rig)}
    for i, frames in enumerate(ph["combos"](rig)):
        anims["combo_%d" % (i + 1)] = frames
    out = out_dir(n)
    os.makedirs(out, exist_ok=True)
    for name in ANIMS:
        for i, f in enumerate(anims[name]):
            f.save(os.path.join(out, f"{name}_{i}.png"))
        sheet = Image.new("RGBA", (SIZE * len(anims[name]), SIZE), (0, 0, 0, 0))
        for i, f in enumerate(anims[name]):
            sheet.alpha_composite(f, (i * SIZE, 0))
        sheet.save(os.path.join(out, f"{name}.png"))
    names = [f"{a}_{i}" for a in ANIMS for i in range(len(anims[a]))]
    order = ph["order"] + ["spikes", "fx"]
    used = [l for l in order if any(l in ls for _, ls in rig.frames)]
    empty = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for l in used:
        d = os.path.join(out, "layers", l)
        os.makedirs(d, exist_ok=True)
        for fname, (_, ls) in zip(names, rig.frames):
            ls.get(l, empty).save(os.path.join(d, fname + ".png"))
    counts = {a: len(anims[a]) for a in ANIMS}
    with open(os.path.join(out, "frames.json"), "w") as f:
        json.dump({"size": SIZE, "anims": counts, "layers": used}, f, indent=1)
    print("fase", n, counts, "scale %.3f" % rig.scale, "layers", used)


if __name__ == "__main__":
    main(int(sys.argv[1]), "--rest" in sys.argv)
