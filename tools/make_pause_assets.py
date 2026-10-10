"""Pause screen kit: tools/pause_kit_ref.webp -> assets/ui/pause/.

The sheet is a mock-up of the pause modal drawn piece by piece. Cut out:
  panel.png      the tall empty frame (9-slice)
  header.png     PAUSED + "Run temporarily halted" (used as it is)
  stats.png      the stats strip with its labels and values wiped (9-slice)
  banner.png     the section banner with its title wiped (the game writes it)
  crew.png       the pink crew card with portrait and text wiped (9-slice)
  card.png       the upgrade card with icon, name and pips wiped (9-slice)
  ic_gun/alien/clock/coin.png   stat icons
  resume.png, quit.png          the two buttons (text included)
  wing_l/r.png, arrow_*.png, bar_*.png   small ornaments
Interiors are wiped to their own dark fill (median of the dark pixels inside).

Also the GAME OVER kit (tools/gameover_kit_ref.webp): go_header.png (WIPED OUT! in goo
with its subtitle plate), go_info.png (the stats plate, its text wiped), go_again.png and
go_menu.png (PLAY AGAIN / MAIN MENU, text included).

python tools/make_pause_assets.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "pause_kit_ref.webp")
OUT = os.path.join(ROOT, "assets", "ui", "pause")

# (name, box x, y, w, h, wipe rects relative to the piece [(x0, y0, x1, y1)])
PIECES = [
    ("panel", (19, 38, 462, 970), []),
    ("header", (497, 47, 572, 217), []),
    ("stats", (495, 278, 577, 199), [(22, 20, 555, 178)]),
    ("banner", (496, 497, 573, 73), [(98, 12, 472, 58)]),
    ("crew", (503, 576, 559, 164), [(20, 18, 539, 146)]),
    ("card", (503, 842, 276, 241), [(24, 24, 252, 217)]),
    ("ic_gun", (30, 1043, 105, 73), []),
    ("ic_alien", (163, 1042, 78, 81), []),
    ("ic_clock", (275, 1045, 79, 79), []),
    ("ic_coin", (391, 1045, 76, 80), []),
    ("resume", (13, 1160, 550, 128), []),
    ("quit", (574, 1159, 499, 129), []),
    ("bar_l", (197, 1314, 149, 25), []),
    ("bar_mid", (355, 1313, 373, 57), []),
    ("bar_r", (741, 1314, 149, 25), []),
    ("arrow_l", (33, 1320, 48, 76), []),
    ("arrow_r", (124, 1320, 49, 76), []),
    ("wing_l", (225, 1360, 124, 64), []),
    ("wing_r", (738, 1360, 123, 64), []),
]


GO_SRC = os.path.join(ROOT, "tools", "gameover_kit_ref.webp")
GO_PIECES = [
    ("go_header", (878, 13, 643, 346), []),
    ("go_info", (943, 364, 527, 212), [(112, 36, 424, 170)]),
    ("go_again", (1022, 593, 479, 142), []),
    ("go_menu", (1043, 741, 437, 122), []),
]


def wipe(a, r):
    x0, y0, x1, y1 = r
    inner = a[y0:y1, x0:x1].astype(np.float32)
    lum = inner[..., :3].mean(2)
    dark = inner[(lum < np.percentile(lum, 40)) & (inner[..., 3] > 200)][:, :4]
    fill = np.median(dark, 0) if len(dark) else np.array([10, 20, 45, 255])
    # a soft vertical gradient so the wiped area is not dead flat
    h = y1 - y0
    for y in range(h):
        k = 1.08 - 0.16 * y / max(1, h - 1)
        a[y0 + y, x0:x1, :3] = np.clip(fill[:3] * k, 0, 255)
        a[y0 + y, x0:x1, 3] = 255


def main():
    os.makedirs(OUT, exist_ok=True)
    cut(SRC, PIECES)
    cut(GO_SRC, GO_PIECES)


def cut(path, pieces):
    src = np.array(Image.open(path).convert("RGBA"))
    src[src[..., 3] < 40] = 0
    for name, (x, y, w, h), wipes in pieces:
        a = src[y:y + h, x:x + w].copy()
        for r in wipes:
            wipe(a, r)
        Image.fromarray(a).save(os.path.join(OUT, name + ".png"))
        print(name, (w, h))


if __name__ == "__main__":
    main()
