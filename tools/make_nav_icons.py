"""Cuts the bottom-nav tiles of the world-select screen from tools/nav_icons_ref.webp
(SHOP, ARMORY, BATTLE, TALENTS, LAB, each with its own frame and painted label).

Usage: python tools/make_nav_icons.py
-> assets/ui/world/nav/<id>.png (scaled to the size they have on the 941x1672 stage;
   sizes mirrored in scripts/world_select.gd BUTTONS), nav/bar.png (plain strip behind
   them) and lock.png (the padlock of TALENTS, used by the locked-world veil).
ARMORY's tile is empty on purpose: world_select.gd draws the equipped weapon in it.
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui", "world")

# id: (x0, y0, x1, y1 in the sheet, width, height on the stage)
TILES = {
    "shop": ((16, 324, 317, 661), (166, 185)),
    "gear": ((329, 324, 629, 661), (166, 185)),
    "battle": ((633, 270, 1039, 700), (203, 215)),
    "talents": ((1043, 324, 1343, 661), (166, 185)),
    "lab": ((1356, 324, 1656, 661), (166, 185)),
}
LOCK = (1128, 392, 1258, 540)  # the padlock inside TALENTS
BAR = (941, 212)


def main():
    os.makedirs(os.path.join(OUT, "nav"), exist_ok=True)
    sheet = Image.open(os.path.join(HERE, "nav_icons_ref.webp")).convert("RGBA")
    for name, (box, size) in TILES.items():
        sheet.crop(box).resize(size, Image.LANCZOS).save(os.path.join(OUT, "nav", f"{name}.png"))
    sheet.crop(LOCK).save(os.path.join(OUT, "lock.png"))
    w, h = BAR
    bar = Image.new("RGBA", BAR)
    d = ImageDraw.Draw(bar)
    for y in range(h):
        k = y / (h - 1)
        c = (round(14 - 8 * k), round(22 - 12 * k), round(52 - 26 * k), 245)
        d.line([(0, y), (w, y)], fill=c)
    d.rectangle([0, 0, w, 3], fill=(58, 96, 190, 255))
    d.rectangle([0, 4, w, 5], fill=(115, 239, 247, 90))
    bar.save(os.path.join(OUT, "nav", "bar.png"))
    print("ok", list(TILES))


if __name__ == "__main__":
    main()
