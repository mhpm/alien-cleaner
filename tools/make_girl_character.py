"""The girl astronaut (unlockable character): frames from her sheets.

python tools/make_girl_character.py
Sheets in tools/characters/girl/<sheet>.png (transparent, pixel art drawn 5x, frames
in equal cells left to right) -> assets/characters/girl/<anim>_<i>.png at OUT_PX px per
art pixel, all on one shared canvas with the feet on its horizontal middle (flip_h safe),
plus the pink PULSE BLASTER shot (assets/guns/shot_pulse_pink.png, hit_pulse_pink.png),
her muzzle flash and the HEART SHOT heart (assets/guns/shot_heart.png, from the user's
tools/characters/girl/heart_ref.webp: cropped and shrunk to HEART_W px, crisp).
Prints the anchor and the canvas size for assets/characters/girl/girl.tres.
"""
import colorsys
import os

import numpy as np
from PIL import Image

import character_frames

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "characters", "girl")
OUT = os.path.join(ROOT, "assets", "characters", "girl")
GUNS = os.path.join(ROOT, "assets", "guns")
HEART_REF = os.path.join(SRC, "heart_ref.webp")
HEART_W = 64  # px wide (its pixel art is ~24 cells across: crisp at this size)
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
    "walk_shoot_down": ("walk_shoot_down", 8, None),  # walking while aiming down
    "walk_shoot_up": ("walk_shoot_up", 8, None),  # walking while aiming up (back view)
    "hurt": ("hurt", 2, None),
    "death": ("death", 4, None),
}
PINK_HUE = 0.92  # hue of her pink shots (0..1)


def build() -> None:
    k = OUT_PX / PX
    anims = {}
    keep = {}
    for anim, (sheet, n, frames) in ANIMS.items():
        anims[anim] = character_frames.cells(os.path.join(SRC, sheet + ".png"), n, k * GROW.get(sheet, GROW_OTHERS))
        if frames:
            keep[anim] = frames
    stand = character_frames.cells(os.path.join(SRC, "idle.png"), 8, k * GROW_OTHERS)
    frame_plan = character_frames.plan(anims, stand, ("hurt", "death"), 6 * OUT_PX, keep)
    anchor, size = character_frames.save(OUT, frame_plan)
    print("anchor", anchor, "canvas", size)
    print("idle height", character_frames.drawn_height(os.path.join(OUT, "idle_0.png")))


def heart() -> None:
    """Her heart (projectile, particles, button icon): the user's pixel heart, cropped."""
    img = Image.open(HEART_REF).convert("RGBA")
    img = img.crop(img.getbbox())
    h = round(img.height * HEART_W / img.width)
    img.resize((HEART_W, h), Image.LANCZOS).save(os.path.join(GUNS, "shot_heart.png"))


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
    heart()
