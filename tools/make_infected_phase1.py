"""Fase 1 del mutante (64x64): idle + walk a partir de tools/infected_phase1_ref.png.

python tools/make_infected_phase1.py [--grid]
Frente/espalda (walk_down/walk_up): frames de la hoja fase 1 del proyecto, misma paleta.
Combo (combo_1..3): poses de fase 1/extra/combo_*.png; el arco rosa se separa del
cuerpo y se anima aparte (carga, impacto, estela, recuperación).
Reduce el arte a pixel art (caja + paleta limitada + contorno), lo separa en piezas
(cabeza, torso, garra, pierna delantera/trasera) y las anima por código.
Salida: assets/sprites/mutations_player/fase 1/pixel64/{idle,walk}_<i>.png,
hojas idle.png/walk.png y infected_phase1.aseprite (tags idle/walk).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "infected_phase1_ref.png")
OUT = os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase 1", "pixel64")
SIZE = 64
BODY_H = 56          # alto del personaje dentro del lienzo
FEET_Y = 62          # fila de las botas en el lienzo (deja 2 px para el rebote)
COLORS = 40
ARC_COLORS = 10     # paleta aparte del arco de energía de los golpes
OUTLINE = (24, 12, 36, 255)


# Frente y espalda: los frames de caminar de la hoja de fase 1 del proyecto (mismo
# personaje), en el orden de SETS["mutant1"] de tools/slice_sprites.py.
ELEMENTS = os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase 1",
                        "fase 1_elements", "fase 1_%s.png")
DIRS = {"walk_down": ["002", "001", "003", "004"], "walk_up": ["007", "005", "008", "006"]}
# Los 3 golpes del combo (puñetazo, gancho, barrido): poses de fase 1/extra/combo_*.png
# (salen de fase 1/combo.png con tools/split_mutant_extras.py).
COMBOS = [os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase 1", "extra",
                       "combo_%d.png" % i) for i in range(3)]
SLASH_MIN_AREA = 400   # manchas rosas más grandes que esto (px de la fuente) = arco
# Por golpe: (retroceso del cuerpo al cargar (dx, dy), avance del arco al desvanecerse)
COMBO_MOTION = [((-2, 0), (2, 0)), ((-1, 1), (1, -2)), ((-2, 1), (2, 1))]
COMBO_MS = [60, 50, 70, 110]   # carga, impacto, estela, recuperación


def reduce(im: Image.Image, scale: float, crop: bool = True) -> Image.Image:
    """Reduce con caja (premultiplicada, para que el fondo no ensucie los bordes) y
    alfa duro. Sin cuantizar: la paleta se reparte después entre todos los frames."""
    im = im.convert("RGBA")
    if crop:
        im = im.crop(im.getbbox())
    W, H = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    a = np.array(im).astype(np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    pm = Image.fromarray((a * 255).astype(np.uint8), "RGBA").resize((W, H), Image.BOX)
    s = np.array(pm).astype(np.float32)
    alpha = s[..., 3]
    rgb = np.where(alpha[..., None] > 0, s[..., :3] * 255.0 / np.maximum(alpha[..., None], 1), 0)
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(alpha > 110, 255, 0)
    return Image.fromarray(out, "RGBA")


def make_palette(imgs: list, colors: int = COLORS) -> Image.Image:
    """Paleta común (mediana) para que todas las direcciones compartan colores.
    Solo cuentan los píxeles opacos."""
    px = np.concatenate([np.array(i)[..., :3][np.array(i)[..., 3] > 0] for i in imgs])
    strip = Image.fromarray(px.reshape(1, -1, 3).astype(np.uint8), "RGB")
    return strip.quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)


def apply_palette(img: Image.Image, pal: Image.Image) -> Image.Image:
    a = np.array(img)
    q = np.array(img.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB"))
    res = np.zeros_like(a)
    res[..., :3] = q
    res[..., 3] = a[..., 3]
    return Image.fromarray(res, "RGBA")


def _label(mask: np.ndarray) -> tuple:
    """Componentes 8-conexas (sin scipy)."""
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    sizes = [0]
    for y0, x0 in zip(*np.nonzero(mask)):
        if lab[y0, x0]:
            continue
        n = len(sizes)
        lab[y0, x0] = n
        stack = [(y0, x0)]
        count = 0
        while stack:
            cy, cx = stack.pop()
            count += 1
            for ny in (cy - 1, cy, cy + 1):
                for nx in (cx - 1, cx, cx + 1):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n
                        stack.append((ny, nx))
        sizes.append(count)
    return lab, sizes


def _grow(m: np.ndarray) -> np.ndarray:
    g = m.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            g |= np.roll(np.roll(m, dy, 0), dx, 1)
    return g


def split_slash(im: Image.Image) -> tuple:
    """Separa el arco de energía rosa (manchas rosas grandes + su brillo y su núcleo
    blanco) del cuerpo. Devuelve (cuerpo, arco) del mismo tamaño que `im`."""
    a = np.array(im.convert("RGBA")).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    hot = (al > 0) & (r > 150) & (b > 100) & (g < 150) & (r > g + 60)
    lab, sizes = _label(hot)
    fx = np.isin(lab, [k for k, s in enumerate(sizes) if k and s >= SLASH_MIN_AREA])
    glow = (al > 0) & ((al < 250) | ((r > g + 40) & (r > 110)))
    for _ in range(4):
        fx |= _grow(fx) & glow
    # Núcleo blanco del arco: huecos rodeados de arco (5+ vecinos de 8).
    for _ in range(3):
        n = sum(np.roll(np.roll(fx, dy, 0), dx, 1).astype(int)
                for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
        fx |= (al > 0) & (n >= 5)
    # Trozos sueltos que no tocan el cuerpo (puntas blancas del arco) también son arco.
    lab, sizes = _label((al > 0) & ~fx)
    keep = max(sizes) * 0.15
    fx |= (al > 0) & ~np.isin(lab, [k for k, s in enumerate(sizes) if k and s >= keep])
    body, arc = a.copy(), a.copy()
    body[fx] = 0
    arc[~fx] = 0
    return (Image.fromarray(body.astype(np.uint8), "RGBA"),
            Image.fromarray(arc.astype(np.uint8), "RGBA"))


def load_sources() -> tuple:
    """Devuelve (base lateral, {anim: [frames reducidos]}, [(cuerpo, arco) por golpe])
    ya con la paleta común."""
    side = Image.open(SRC).convert("RGBA")
    side = side.crop(side.getbbox())
    base = reduce(side, BODY_H / side.height)
    dirs = {}
    for anim, ids in DIRS.items():
        srcs = [Image.open(ELEMENTS % i).convert("RGBA") for i in ids]
        srcs = [s.crop(s.getbbox()) for s in srcs]
        # Escala única por animación (alto mediano = BODY_H) para que no "respire".
        h = sorted(s.height for s in srcs)[len(srcs) // 2]
        dirs[anim] = [(reduce(s, BODY_H / h), s) for s in srcs]
    # Golpes: misma escala que caminar de frente (son de la misma hoja).
    down = [Image.open(ELEMENTS % i).convert("RGBA") for i in DIRS["walk_down"]]
    scale = BODY_H / sorted(s.crop(s.getbbox()).height for s in down)[len(down) // 2]
    combos = []
    for path in COMBOS:
        body, arc = split_slash(Image.open(path).convert("RGBA"))
        combos.append((reduce(body, scale, crop=False), reduce(arc, scale, crop=False)))
    # El cuerpo comparte una paleta; el arco lleva la suya (si no, sus rosas se comen
    # los colores del traje).
    pal = make_palette([base] + [r for fr in dirs.values() for r, _ in fr])
    arc_pal = make_palette([a for _, a in combos if a.getbbox()], ARC_COLORS)
    base = apply_palette(base, pal)
    for anim in dirs:
        dirs[anim] = [(apply_palette(r, pal), s) for r, s in dirs[anim]]
    combos = [(apply_palette(b, pal), apply_palette(a, arc_pal)) for b, a in combos]
    return base, dirs, combos


def head_center_x(src: Image.Image) -> float:
    """Centro horizontal del casco (40 % superior): ancla estable entre frames."""
    a = np.array(src)[..., 3] > 0
    top = a[: int(a.shape[0] * 0.4)]
    xs = np.nonzero(top.any(0))[0]
    return (xs[0] + xs[-1]) / 2.0


def place_dir(frames: list) -> list:
    """Coloca cada frame en 64x64: botas en FEET_Y y casco centrado."""
    out = []
    for small, src in frames:
        cx = head_center_x(src) * small.width / src.width
        c = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        x = round(SIZE / 2 - cx)
        y = FEET_Y - small.height
        c.alpha_composite(small, (max(0, x), max(0, y)))
        out.append(outline(c))
    return out


def outline(img: Image.Image) -> Image.Image:
    a = np.array(img)
    solid = a[..., 3] > 0
    # sin np.roll: lo que toca un borde no debe contornear el borde opuesto
    grow = solid.copy()
    grow[1:] |= solid[:-1]
    grow[:-1] |= solid[1:]
    grow[:, 1:] |= solid[:, :-1]
    grow[:, :-1] |= solid[:, 1:]
    edge = grow & ~solid
    a[edge] = OUTLINE
    return Image.fromarray(a, "RGBA")


def cut(img: Image.Image, mask_fn) -> Image.Image:
    a = np.array(img)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    m = mask_fn(xx, yy)
    b = a.copy()
    b[~m] = 0
    return Image.fromarray(b, "RGBA")


def paste(canvas: Image.Image, part: Image.Image, x: int, y: int) -> None:
    canvas.alpha_composite(part, (x, y))


def grid_preview(img: Image.Image, path: str) -> None:
    k = 12
    big = img.resize((img.width * k, img.height * k), Image.NEAREST).convert("RGBA")
    bg = Image.new("RGBA", big.size, (60, 60, 70, 255))
    bg.alpha_composite(big)
    d = ImageDraw.Draw(bg)
    for x in range(0, img.width, 4):
        d.line([(x * k, 0), (x * k, bg.height)], fill=(0, 255, 0, 120))
        d.text((x * k + 1, 1), str(x), fill=(255, 255, 0, 255))
    for y in range(0, img.height, 4):
        d.line([(0, y * k), (bg.width, y * k)], fill=(0, 255, 0, 120))
        d.text((1, y * k + 1), str(y), fill=(255, 255, 0, 255))
    bg.save(path)


HIP_Y = 40           # en coordenadas del sprite base (49x56)
LEG_SPLIT_X = 22     # pierna delantera (izq.) | trasera (der.)
HEAD_Y = 26
CLAW_X = 34
FIST_X = 10


def parts(base: Image.Image) -> dict:
    p = {
        "head": cut(base, lambda x, y: (y < HEAD_Y) & ~((x >= CLAW_X) & (y >= 24))),
        "claw": cut(base, lambda x, y: (x >= CLAW_X) & (y >= 24) & (y < 50)),
        "fist": cut(base, lambda x, y: (x < FIST_X) & (y >= HEAD_Y) & (y < HIP_Y + 6)),
        "leg_front": cut(base, lambda x, y: (y >= HIP_Y) & (x >= FIST_X) & (x < LEG_SPLIT_X)),
        "leg_back": cut(base, lambda x, y: (y >= HIP_Y) & (x >= LEG_SPLIT_X) & (x < CLAW_X + 4)),
    }
    p["torso"] = cut(base, lambda x, y: (y >= HEAD_Y) & (y < HIP_Y) & (x >= FIST_X) & (x < CLAW_X))
    # Muslo "de relleno": repite la fila de la cadera hacia arriba para que al mover
    # la pierna no se abra un hueco bajo el torso.
    for k in ("leg_front", "leg_back"):
        a = np.array(p[k])
        for y in range(HIP_Y - 4, HIP_Y):
            a[y] = a[HIP_Y]
        p[k] = Image.fromarray(a, "RGBA")
    return p


def frame(p: dict, ox: int, oy: int, *, body=0, head=0, claw=(0, 0), fist=(0, 0),
          front=(0, 0), back=(0, 0)) -> Image.Image:
    c = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    paste(c, p["leg_back"], ox + back[0], oy + back[1])
    paste(c, p["leg_front"], ox + front[0], oy + front[1])
    paste(c, p["fist"], ox + fist[0], oy + body + fist[1])
    paste(c, p["torso"], ox, oy + body)
    paste(c, p["claw"], ox + claw[0], oy + body + claw[1])
    paste(c, p["head"], ox, oy + body + head)
    return outline(c)


def idle(p: dict, ox: int, oy: int) -> list:
    # Respiración de 6 frames: el cuerpo baja 1 px, la cabeza llega un frame tarde,
    # la garra late (se abre y se cierra) a contratiempo.
    body = [0, 0, 1, 1, 1, 0]
    head = [0, 0, 0, 1, 0, 0]
    claw = [(0, 0), (1, 0), (1, 1), (0, 1), (-1, 0), (0, 0)]
    fist = [(0, 0), (0, 0), (0, 1), (0, 1), (0, 0), (0, 0)]
    return [frame(p, ox, oy, body=body[i], head=head[i], claw=claw[i], fist=fist[i])
            for i in range(6)]


def walk(p: dict, ox: int, oy: int) -> list:
    # Ciclo de 8 frames mirando a la derecha: las piernas se alternan adelante/atrás
    # y se levantan al pasar; el cuerpo sube en los pasos cruzados; puño y garra
    # se balancean a contrafase de las piernas.
    stride = [2, 2, 1, -1, -2, -2, -1, 1]      # pierna delantera (la trasera va opuesta)
    lift_f = [0, 0, 0, -1, -2, -1, 0, 0]
    lift_b = [-2, -1, 0, 0, 0, 0, 0, -1]
    body = [0, 1, 0, -1, 0, 1, 0, -1]
    frames = []
    for i in range(8):
        s = stride[i]
        frames.append(frame(
            p, ox, oy, body=body[i], head=1 if body[i] > 0 else 0,
            front=(s, lift_f[i]), back=(-s, lift_b[i]),
            fist=(-int(np.sign(s)), 0), claw=(int(np.sign(s)), 0)))
    return frames


def boots_anchor(img: Image.Image) -> tuple:
    """(x medio, fila más baja) de las botas azules: el punto de apoyo del personaje."""
    a = np.array(img).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    m = (al > 0) & (b > r + 40) & (b > g + 20)
    m[: int(a.shape[0] * 0.7)] = False
    ys, xs = np.nonzero(m)
    return xs.mean(), ys.max()


def fade(img: Image.Image) -> Image.Image:
    """Desvanece a lo pixel art: borra la mitad de los píxeles en damero."""
    a = np.array(img)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    a[(yy + xx) % 2 == 1] = 0
    return Image.fromarray(a, "RGBA")


def shifted(img: Image.Image, dx: int, dy: int) -> Image.Image:
    c = Image.new("RGBA", img.size, (0, 0, 0, 0))
    c.paste(img, (dx, dy), img)   # paste admite desplazamientos negativos (recorta)
    return c


def combo(parts_hit: tuple, target: tuple, motion: tuple) -> list:
    """4 frames de un golpe: carga (cuerpo atrás), impacto (arco completo), estela
    (arco avanzando en damero) y recuperación. Botas en el mismo sitio que el idle."""
    body, arc = parts_hit
    bx, by = boots_anchor(body)
    ox, oy = round(target[0] - bx), round(target[1] - by)
    # Lienzo ancho para colocar y luego recortar a 64 comprimiendo el arco.
    pad = 64
    big = SIZE + 2 * pad

    def place(img: Image.Image, dx: int = 0, dy: int = 0) -> Image.Image:
        c = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        c.alpha_composite(img, (pad + ox + dx, pad + oy + dy))
        return c

    arc_big = place(arc)
    # Encaja el arco en el lienzo 64: la parte que se saldría se comprime hacia dentro
    # (el cuerpo no se toca, así no cambia de tamaño entre animaciones).
    shifted_arc = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bb = arc_big.getbbox()
    if bb:
        x0, y0, x1, y1 = bb
        tx0, ty0 = max(x0 - pad, 0), max(y0 - pad, 0)
        tx1, ty1 = min(x1 - pad, SIZE), min(y1 - pad, SIZE)
        piece = arc_big.crop(bb).resize((tx1 - tx0, ty1 - ty0), Image.NEAREST)
        shifted_arc.alpha_composite(piece, (tx0, ty0))

    def body_at(dx: int, dy: int) -> Image.Image:
        return outline(place(body, dx, dy).crop((pad, pad, pad + SIZE, pad + SIZE)))

    (bdx, bdy), (adx, ady) = motion
    windup = body_at(bdx, bdy)
    strike = body_at(0, 0)
    strike.alpha_composite(shifted_arc)
    trail = body_at(0, 0)
    trail.alpha_composite(shifted(fade(shifted_arc), adx, ady))
    recover = body_at(bdx // 2, 0)
    return [windup, strike, trail, recover]


def sheet(frames: list) -> Image.Image:
    s = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.alpha_composite(f, (i * SIZE, 0))
    return s


if __name__ == "__main__":
    base, dirs, combos = load_sources()
    if "--grid" in sys.argv:
        grid_preview(base, sys.argv[-1])
        print(base.size)
        sys.exit()
    p = parts(base)
    ox = (SIZE - base.width) // 2
    oy = FEET_Y - base.height
    os.makedirs(OUT, exist_ok=True)
    anims = {"idle": idle(p, ox, oy), "walk": walk(p, ox, oy)}
    for anim, frames in dirs.items():
        anims[anim] = place_dir(frames)
    target = boots_anchor(anims["idle"][0])
    for i, hit in enumerate(combos):
        anims["combo_%d" % (i + 1)] = combo(hit, target, COMBO_MOTION[i])
    for name, frames in anims.items():
        for i, f in enumerate(frames):
            f.save(os.path.join(OUT, f"{name}_{i}.png"))
        sheet(frames).save(os.path.join(OUT, f"{name}.png"))
    print("ok", {k: len(v) for k, v in anims.items()})
