"""CREW panel (world select > CREW tile) and its nav tile, from the user's art.

python tools/make_crew_assets.py
tools/crew_kit_ref.webp (transparent kit) -> assets/ui/crew/<piece>.png
tools/crew_tile_ref.webp (the CREW nav tile)  -> assets/ui/world/nav/crew.png
tools/crew_ref.webp is the mock-up the panel follows (scripts/ui/crew_panel.gd).
Each piece keeps only its biggest drawing (glow of a neighbour cut away).
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui", "crew")
NAV = os.path.join(HERE, "..", "assets", "ui", "world", "nav")
# name: (x0, y0, x1, y1) in the kit
PIECES = {
    "header": (30, 12, 815, 292),      # kid + girl around the title plate
    "frame": (834, 13, 1312, 195),     # big blue frame (9-slice: the panel)
    "bar": (826, 204, 1258, 285),      # subtitle plate
    "card_kid": (33, 302, 823, 551),   # blue card, the kid shooting
    "card_girl": (33, 551, 823, 803),  # pink card, the girl shooting
    "btn_back": (49, 808, 344, 904),   # blue button with the arrow
    "btn_gray": (363, 809, 677, 904),
    "btn_green": (690, 808, 1014, 904),
    "bracket_l": (962, 915, 1054, 1008),
    "bracket_r": (1059, 915, 1167, 1013),
}
# the BACK button has its arrow painted in the middle: it moves to the left so the
# word BACK fits beside it (the gap is filled with the button's own plain column)
ARROW_BOX = (114, 22, 186, 74)  # in btn_back.png
ARROW_X = 34
PLAIN_X = 80  # a column of btn_back.png with nothing but the button's blue
TILE = (114, 88, 1138, 1160)  # the CREW tile inside its picture
TILE_SIZE = (166, 185)        # nav tiles on the world-select stage (BUTTONS)


def biggest(img: Image.Image) -> Image.Image:
    a = np.array(img)
    lab, n = ndimage.label(a[..., 3] > 40)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = ndimage.binary_dilation(lab == int(np.argmax(sizes)) + 1, iterations=3)
        a[..., 3] = np.where(keep, a[..., 3], 0)
    out = Image.fromarray(a)
    return out.crop(out.getbbox())


def arrow_left(btn: Image.Image) -> Image.Image:
    a = np.array(btn)
    x0, y0, x1, y1 = ARROW_BOX
    arrow = a[y0:y1, x0:x1].copy()
    a[y0:y1, x0:x1] = a[y0:y1, PLAIN_X:PLAIN_X + 1]
    a[y0:y1, ARROW_X:ARROW_X + (x1 - x0)] = arrow
    return Image.fromarray(a)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    kit = Image.open(os.path.join(HERE, "crew_kit_ref.webp")).convert("RGBA")
    for name, box in PIECES.items():
        p = biggest(kit.crop(box))
        if name == "btn_back":
            p = arrow_left(p)
        p.save(os.path.join(OUT, name + ".png"))
        print(name, p.size)
    tile = Image.open(os.path.join(HERE, "crew_tile_ref.webp")).convert("RGBA").crop(TILE)
    w = TILE_SIZE[0]
    h = round(tile.height * w / tile.width)
    canvas = Image.new("RGBA", TILE_SIZE)
    canvas.alpha_composite(tile.resize((w, h), Image.LANCZOS), (0, TILE_SIZE[1] - h))
    canvas.save(os.path.join(NAV, "crew.png"))
    print("tile", TILE_SIZE, "drawn", (w, h))


if __name__ == "__main__":
    main()
