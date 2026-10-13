"""The girl astronaut (unlockable character): frames from her sheets.

python tools/make_girl_character.py
Sheets in tools/characters/girl/<sheet>.png (transparent, pixel art drawn 5x, frames
in equal cells left to right) -> assets/characters/girl/<anim>_<i>.png at OUT_PX px per
art pixel, all on one shared canvas with the feet on its horizontal middle (flip_h safe),
plus the pink PULSE BLASTER shot (assets/guns/shot_pulse_pink.png, hit_pulse_pink.png),
her muzzle flash and the HEART SHOT heart (assets/guns/shot_heart.png, from the pickup heart).
Prints the anchor and the canvas size for assets/characters/girl/girl.tres.
"""
import colorsys
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "characters", "girl")
OUT = os.path.join(ROOT, "assets", "characters", "girl")
GUNS = os.path.join(ROOT, "assets", "guns")
PICKUP_HEART = os.path.join(ROOT, "assets", "sprites", "enviroment", "collectibles_elements",
                            "ChatGPT Image Sep 27, 2026, 04_45_58 PM_015.png")
PX = 5  # sheet pixels per art pixel
OUT_PX = 2.0  # frame pixels per art pixel
# each sheet is drawn at its own size: these scales give every pose the face of the
# idle one (measured face width), so she does not shrink when she starts shooting
GROW = {"walk_shoot": 1.23, "walk_shoot_up": 1.2, "walk_shoot_down": 1.2}
GROW_OTHERS = 1.12  # idle, hurt, death
# anim -> (sheet, frames in the sheet, which frames to keep)
ANIMS = {
    "idle": ("idle", 8, None),
    "walk": ("walk_shoot", 8, None),       # walks holding the arm out (walk_aims)
    "walk_up": ("walk_shoot_up", 8, None),  # back view
    "shoot": ("walk_shoot", 8, [0]),
    "shoot_down": ("walk_shoot_down", 8, [0]),
    "shoot_up": ("walk_shoot_up", 8, [0]),
    "hurt": ("hurt", 2, None),
    "death": ("death", 4, None),
}
PINK_HUE = 0.92  # hue of her pink shots (0..1)


def cells(sheet: str, n: int) -> list:
    img = Image.open(os.path.join(SRC, sheet + ".png")).convert("RGBA")
    w = img.width // n
    out = []
    for i in range(n):
        c = img.crop((i * w, 0, (i + 1) * w, img.height))
        k = OUT_PX / PX * GROW.get(sheet, GROW_OTHERS)
        out.append(c.resize((round(c.width * k), round(c.height * k)), Image.LANCZOS))
    return out


def feet_x(frames: list) -> float:
    """Middle of the boots (bottom rows) averaged over a standing sheet."""
    xs = []
    for f in frames:
        a = np.array(f)[..., 3] > 128
        ys, x = np.nonzero(a)
        low = ys > ys.max() - 6 * OUT_PX
        xs.append((x[low].min() + x[low].max() + 1) / 2.0)
    return float(np.mean(xs))


def build() -> None:
    os.makedirs(OUT, exist_ok=True)
    stand = cells("idle", 8)
    plan = {}
    for anim, (sheet, n, keep) in ANIMS.items():
        fr = cells(sheet, n)
        # feet: bottom of the drawings; x from the boots of the standing sheets, the idle
        # one for the lying-down ones (hurt / death keep their cell placement)
        bottom = max(np.nonzero(np.array(f)[..., 3] > 128)[0].max() for f in fr) + 1
        fx = feet_x(stand) * fr[0].width / stand[0].width if anim in ("hurt", "death") else feet_x(fr)
        plan[anim] = ([fr[k] for k in keep] if keep else fr, (fx, bottom))
    half_w = up = down = 0.0
    for frames, (fx, fy) in plan.values():
        for f in frames:
            r = np.nonzero(np.array(f)[..., 3] > 0)
            half_w = max(half_w, fx - r[1].min(), r[1].max() + 1 - fx)
            up = max(up, fy - r[0].min())
            down = max(down, r[0].max() + 1 - fy)
    half_w, up, down = int(np.ceil(half_w)) + 1, int(np.ceil(up)) + 1, int(np.ceil(down))
    size = (half_w * 2, up + down)
    for name in os.listdir(OUT):
        if name.endswith(".png") and name != "muzzle_flash.png":
            os.remove(os.path.join(OUT, name))
    for anim, (frames, (fx, fy)) in plan.items():
        for i, f in enumerate(frames):
            canvas = Image.new("RGBA", size)
            canvas.alpha_composite(f, (int(round(half_w - fx)), int(up - fy)))
            canvas.save(os.path.join(OUT, "%s_%d.png" % (anim, i)))
    print("anchor", (half_w, up), "canvas", size)
    idle = np.array(Image.open(os.path.join(OUT, "idle_0.png")))[..., 3] > 128
    ys = np.nonzero(idle)[0]
    print("idle height", ys.max() + 1 - ys.min())


def pinkify(src: str, out: str) -> None:
    """`src` recoloured to her pink (same brightness and alpha) saved as `out`."""
    a = np.array(Image.open(src).convert("RGBA")).astype(np.float32) / 255.0
    flat = a.reshape(-1, 4)
    for p in flat:
        if p[3] > 0.0:
            h, l, s = colorsys.rgb_to_hls(p[0], p[1], p[2])
            p[0], p[1], p[2] = colorsys.hls_to_rgb(PINK_HUE, l, s)
    Image.fromarray((flat.reshape(a.shape) * 255).round().astype(np.uint8)).save(out)


if __name__ == "__main__":
    build()
    pinkify(os.path.join(GUNS, "shot_pulse.png"), os.path.join(GUNS, "shot_pulse_pink.png"))
    pinkify(os.path.join(GUNS, "hit_pulse.png"), os.path.join(GUNS, "hit_pulse_pink.png"))
    pinkify(os.path.join(ROOT, "assets", "characters", "kid_astronaut", "muzzle_flash.png"),
            os.path.join(OUT, "muzzle_flash.png"))
    pinkify(PICKUP_HEART, os.path.join(GUNS, "shot_heart.png"))
