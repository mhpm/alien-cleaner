"""Builds the title screen layers from the loose art in assets/ui/main/.

Usage: python tools/make_title_assets.py
The stage is 720x1280 (scripts/main_menu.gd ART_SIZE). Writes assets/ui/title/:
  sky.webp        deep-space gradient with faint fixed stars (the moving stuff is live)
  base.png        the centre of assets/ui/main/base.png (the hangar and the planet),
                  with its painted ships and asteroids removed (they fly in code),
                  bottom-aligned on the stage, transparent sky
  bg_full.webp    sky + base in one picture (UiTheme.add_backdrop stretches its edges)
  coin_pill.png   image_041 with the "795" erased (the bank is drawn live)
  astro_0..4.png  the astronaut seen from behind firing up (tools/title_astro_ref.webp, five
                  frames: charge orb, muzzle burst, beam, big beam, fade), all on one
                  canvas with the body centred and the feet on the bottom edge
"""
import os

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "ui", "main")
OUT = os.path.join(HERE, "..", "assets", "ui", "title")
W, H = 720, 1280
CROP_X = 364  # base.png columns CROP_X .. CROP_X+W (door and planet in the middle)
ASTRO_CANVAS = (260, 722)  # frame canvas; the body centre is at x=130, the feet at the bottom


def src(name):
    return Image.open(os.path.join(SRC, name)).convert("RGBA")


def sky():
    y = np.linspace(0.0, 1.0, H)[:, None]
    top = np.array([4, 5, 14], float)
    mid = np.array([14, 16, 44], float)
    low = np.array([30, 22, 60], float)
    k = np.clip(y / 0.55, 0, 1)[..., None]
    col = top * (1 - k) + mid * k
    k2 = np.clip((y - 0.55) / 0.45, 0, 1)[..., None]
    col = col * (1 - k2) + low * k2
    img = np.repeat(col, W, axis=1)
    rng = np.random.default_rng(3)
    # a soft violet nebula band behind the planet
    yy, xx = np.mgrid[0:H, 0:W]
    neb = np.exp(-(((xx - 470) / 260.0) ** 2 + ((yy - 330) / 140.0) ** 2))
    img += neb[..., None] * np.array([40, 16, 60])
    for _ in range(260):
        x, yv = rng.integers(0, W), rng.integers(0, 720)
        b = rng.uniform(50, 170)
        img[yv, x] = (b, b, min(255, b + 40))
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")


def base():
    a = np.asarray(src("base.png")).copy()
    m = (a[:, :, 3] > 20).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    keep = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
    a[(lab != keep) & (lab != 0)] = 0  # painted ships and asteroids
    crop = Image.fromarray(a).crop((CROP_X, 0, CROP_X + W, a.shape[0]))
    out = Image.new("RGBA", (W, H))
    out.paste(crop, (0, H - crop.height))
    return out


def coin_pill():
    a = np.asarray(src("image_041.png")).copy()
    col = a[16:63, 170].copy()
    for x in range(62, 164):
        a[16:63, x] = col
    return Image.fromarray(a)


def astro_frames():
    sheet = Image.open(os.path.join(HERE, "title_astro_ref.webp")).convert("RGBA")
    a = np.asarray(sheet)[:, :, 3]
    xs = np.nonzero((a > 30).any(axis=0))[0]
    runs, start, prev = [], xs[0], xs[0]
    for x in xs[1:]:
        if x - prev > 40:
            runs.append((start, prev))
            start = x
        prev = x
    runs.append((start, prev))
    for i, (x0, x1) in enumerate(runs):
        body = np.nonzero((a[570:740, x0 : x1 + 1] > 30).any(axis=0))[0]  # the suit, below the beam
        cx = x0 + (body.min() + body.max()) // 2
        frame = sheet.crop((cx - ASTRO_CANVAS[0] // 2, 752 - ASTRO_CANVAS[1], cx + ASTRO_CANVAS[0] // 2, 752))
        frame.save(os.path.join(OUT, f"astro_{i}.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    s, b = sky(), base()
    s.convert("RGB").save(os.path.join(OUT, "sky.webp"), quality=90)
    b.save(os.path.join(OUT, "base.png"))
    Image.alpha_composite(s, b).convert("RGB").save(os.path.join(OUT, "bg_full.webp"), quality=90)
    coin_pill().save(os.path.join(OUT, "coin_pill.png"))
    astro_frames()
    print("title assets ->", OUT)


if __name__ == "__main__":
    main()
