"""Shared steps that turn a playable character's sprite sheets into game frames.

Used by tools/make_<character>_character.py (the girl, ZED...). A sheet = frames in equal
cells left to right. Every frame of a character goes on ONE shared canvas with the feet
on its horizontal middle (flip_h safe); the scripts then write the CharacterData .tres
(or print the anchor for it).
"""
import os

import numpy as np
from PIL import Image


def cells(path: str, n: int, scale: float, resample=Image.LANCZOS) -> list:
    """The `n` frames of the sheet at `path`, each resized by `scale`."""
    img = Image.open(path).convert("RGBA")
    w = img.width // n
    out = []
    for i in range(n):
        c = img.crop((i * w, 0, (i + 1) * w, img.height))
        out.append(c.resize((round(c.width * scale), round(c.height * scale)), resample))
    return out


def feet_x(frames: list, band: float) -> float:
    """Middle of the boots (the bottom `band` px rows) averaged over a standing sheet."""
    xs = []
    for f in frames:
        a = np.array(f)[..., 3] > 128
        ys, x = np.nonzero(a)
        low = ys > ys.max() - band
        xs.append((x[low].min() + x[low].max() + 1) / 2.0)
    return float(np.mean(xs))


def plan(anims: dict, stand: list, lying: tuple, band: float, keep: dict | None = None) -> dict:
    """anim -> (frames, (feet x, feet y)) for `anims` = {anim: the sheet's frames}. Feet
    y = the bottom of the drawings; feet x = the boots of each standing sheet, or for the
    `lying` ones (hurt / death: no boots to find) the standing sheet's, scaled to their
    cell width. Both are measured on the whole sheet; `keep` = {anim: frame indices} then
    keeps only some of its frames (a still pose taken from a walking sheet)."""
    keep = keep or {}
    out = {}
    for anim, fr in anims.items():
        bottom = max(np.nonzero(np.array(f)[..., 3] > 128)[0].max() for f in fr) + 1
        if anim in lying:
            fx = feet_x(stand, band) * fr[0].width / stand[0].width
        else:
            fx = feet_x(fr, band)
        out[anim] = ([fr[i] for i in keep[anim]] if anim in keep else fr, (fx, bottom))
    return out


def save(out_dir: str, frame_plan: dict, keep=("muzzle_flash.png",)) -> tuple:
    """Writes <anim>_<i>.png on one shared canvas (old frames removed, `keep` files kept).
    Returns (anchor (x, y) = the feet, canvas size)."""
    os.makedirs(out_dir, exist_ok=True)
    half_w = up = down = 0.0
    for frames, (fx, fy) in frame_plan.values():
        for f in frames:
            r = np.nonzero(np.array(f)[..., 3] > 0)
            half_w = max(half_w, fx - r[1].min(), r[1].max() + 1 - fx)
            up = max(up, fy - r[0].min())
            down = max(down, r[0].max() + 1 - fy)
    half_w, up, down = int(np.ceil(half_w)) + 1, int(np.ceil(up)) + 1, int(np.ceil(down))
    size = (half_w * 2, up + down)
    for name in os.listdir(out_dir):
        if name.endswith(".png") and name not in keep:
            os.remove(os.path.join(out_dir, name))
    for anim, (frames, (fx, fy)) in frame_plan.items():
        for i, f in enumerate(frames):
            canvas = Image.new("RGBA", size)
            canvas.alpha_composite(f, (int(round(half_w - fx)), int(up - fy)))
            canvas.save(os.path.join(out_dir, "%s_%d.png" % (anim, i)))
    return (half_w, up), size


def drawn_height(path: str) -> int:
    """Height of the drawing in a frame (the idle one = the CharacterData body_height)."""
    ys = np.nonzero(np.array(Image.open(path))[..., 3] > 128)[0]
    return int(ys.max() + 1 - ys.min())
