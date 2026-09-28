"""Cuts the upgrade art out of the three design sheets.

  python tools/make_upgrade_icons.py

tools/upgrades_sheet1..3.webp (1122x1402): six rows per sheet, each with the upgrade's
icon on the left and its L1..L5 level pictures on the right. Outputs, per upgrade id
(the ids of scripts/data/upgrade_data.gd):
  assets/ui/upgrades/<id>.png      the icon (square)
  assets/ui/upgrades/<id>_<n>.png  level n picture, n = 1..5 (square)
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "ui", "upgrades")

ROWS = {
    1: ["blaster", "double_shot", "spread_shot", "ricochet", "piercing", "freeze"],
    2: ["electric", "rapid", "power", "crit", "speed", "vitality"],
    3: ["orbiters", "slime_explode", "air_cannon", "shield", "magnet", "snack"],
}
# top edge of each row's outer frame
TOPS = {1: [129, 331, 529, 733, 938, 1143], 2: [129, 331, 531, 735, 940, 1145], 3: [129, 332, 532, 732, 934, 1135]}
# level cells: [x0, x1] between their frame lines; icon box left/right
CELLS = {
    1: [(405, 524), (536, 657), (669, 799), (811, 943), (955, 1101)],
    2: [(405, 524), (536, 657), (669, 799), (811, 943), (955, 1101)],
    3: [(414, 536), (546, 670), (681, 814), (824, 959), (970, 1102)],
}
ICON_X = {1: (31, 153), 2: (31, 153), 3: (31, 157)}
CELL_Y = (40, 168)  # below the "Ln" tag, above the bottom frame line (from the row top)
CELL_Y_NAMED = (44, 150)  # blaster row: leave out the tier names under the pictures
LEVEL_SIZE = 96
ICON_SIZE = 96
INSET = 5


def square(img: Image.Image, size: int) -> Image.Image:
    w, h = img.size
    s = min(w, h)
    img = img.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for n, ids in ROWS.items():
        sheet = Image.open(os.path.join(HERE, "upgrades_sheet%d.webp" % n)).convert("RGB")
        for r, uid in enumerate(ids):
            top = TOPS[n][r]
            ix0, ix1 = ICON_X[n]
            icon = sheet.crop((ix0 + INSET, top + 36, ix1 - INSET, top + 36 + (ix1 - ix0) - 2 * INSET))
            square(icon, ICON_SIZE).save(os.path.join(OUT, "%s.png" % uid))
            for lv, (x0, x1) in enumerate(CELLS[n]):
                cy = CELL_Y_NAMED if uid == "blaster" else CELL_Y
                cell = sheet.crop((x0 + INSET, top + cy[0], x1 - INSET - 2, top + cy[1]))
                square(cell, LEVEL_SIZE).save(os.path.join(OUT, "%s_%d.png" % (uid, lv + 1)))
    print("upgrade art ->", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
