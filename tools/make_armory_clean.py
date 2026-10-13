"""Clean ARMORY look: a plain dark space background and the holo pedestal of the UI kit.

Usage: python tools/make_armory_clean.py
  tools/armory_ui_kit_ref.webp (UI kit sheet) -> assets/ui/armory/pedestal_holo.png
  assets/ui/armory/bg_clean.webp (941x1672: dark navy gradient, soft blue glow behind
  the pedestal, faint stars). Used by scripts/armory_screen.gd.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.join(HERE, "..", "assets", "ui", "armory")
W, H = 941, 1672
GLOW_AT = (255, 760)  # behind the pedestal


def main():
    kit = Image.open(os.path.join(HERE, "armory_ui_kit_ref.webp")).convert("RGBA")
    ped = kit.crop((20, 60, 510, 470))
    ped = ped.crop(ped.getbbox())
    ped.resize((430, round(430 * ped.height / ped.width)), Image.LANCZOS).save(os.path.join(UI, "pedestal_holo.png"))

    y = np.linspace(0, 1, H)[:, None, None]
    top = np.array([10, 20, 48], np.float32)
    bot = np.array([4, 9, 24], np.float32)
    img = top * (1 - y) + bot * y
    img = np.broadcast_to(img, (H, W, 3)).copy()
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.hypot((xx - GLOW_AT[0]) / 380.0, (yy - GLOW_AT[1]) / 300.0)
    glow = np.clip(1 - d, 0, 1) ** 2
    img += glow[..., None] * np.array([10, 55, 110], np.float32)
    rng = np.random.default_rng(3)
    for _ in range(90):
        sx, sy = rng.integers(0, W), rng.integers(120, 1200)
        b = rng.uniform(60, 150)
        img[sy, sx] = (b, b, min(255, b + 40))
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(UI, "bg_clean.webp"), quality=92)
    print("ok", ped.size)


if __name__ == "__main__":
    main()
