"""Splits the mutant's extra sheets into loose frames for tools/slice_sprites.py.

Usage: python tools/split_mutant_extras.py
assets/sprites/mutations_player/fase 1/idle.png (3x3 grid of 128 px cells, 8 frames)
and combo.png (3 strike poses) -> fase 1/extra/idle_<i>.png and combo_<i>.png, scaled
up to the size of the fase 1 sheet frames (K) so they share the "mutant1" set.
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, "..", "assets", "sprites", "mutations_player", "fase 1")
K = 1.5  # these sheets are drawn at 2/3 the size of fase 1.png
COMBO = [(6, 4, 150, 128), (170, 0, 298, 128), (0, 126, 158, 252)]  # x0, y0, x1, y1


def save(img, name):
    img = img.crop(img.getbbox())
    img = img.resize((round(img.width * K), round(img.height * K)), Image.LANCZOS)
    img.save(os.path.join(D, "extra", name))


def main():
    os.makedirs(os.path.join(D, "extra"), exist_ok=True)
    idle = Image.open(os.path.join(D, "idle.png")).convert("RGBA")
    for i in range(8):
        c, r = i % 3, i // 3
        save(idle.crop((c * 128, r * 128, c * 128 + 128, r * 128 + 128)), f"idle_{i}.png")
    combo = Image.open(os.path.join(D, "combo.png")).convert("RGBA")
    for i, box in enumerate(COMBO):
        save(combo.crop(box), f"combo_{i}.png")
    print("ok")


if __name__ == "__main__":
    main()
