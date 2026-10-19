"""Security camera that turns: the user's 8 views (tools/security_cam_8dir_ref.webp, two
rows of four on a transparent background) -> one strip of 8 frames on a common canvas,
anchored on the base of the stand (bottom centre), ordered by the angle the lens faces
(Godot angles, clockwise from the right): E, SE, S, SW, W, NW, N, NE.
  python tools/make_security_cam.py
  -> assets/arena/pixel25d/cam_8dir.png  (indexed PNG, 8 columns)
     assets/arena/pixel25d/cam_8dir.json (lens of each view in frame pixels from the
     feet; SecurityCamera.view_lens takes these numbers)
The lens is the white-hot centre of the red light. Views looking away (N, NW) only show
the rear LED: their lens is set by hand on the hidden front (`HIDDEN`).
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "tools", "security_cam_8dir_ref.webp")
OUT = os.path.join(ROOT, "assets", "arena", "pixel25d")  # not a kit piece: placed as Gameplay > Security Camera
K = 0.085  # sheet px -> world units (about the astronaut's height)

# sheet boxes (reading order) and which one shows each angle
BOXES = [(118, 70, 333, 394), (493, 55, 774, 395), (950, 63, 1280, 394), (1417, 64, 1715, 397),
         (109, 497, 333, 826), (508, 494, 794, 826), (950, 493, 1262, 825), (1424, 488, 1705, 826)]
ORDER = [6, 7, 0, 1, 2, 5, 4, 3]  # E, SE, S, SW, W, NW, N, NE
LENS = {0: (108, 147), 1: (60, 168), 2: (53, 151), 3: (281, 88), 6: (264, 155), 7: (220, 164)}
HIDDEN = {4: (108, 70), 5: (40, 75)}  # back views: the lens is on the far side


def base(alpha):
    rows = np.nonzero(alpha.max(1) > 40)[0]
    bottom = int(rows.max())
    ys, xs = np.nonzero(alpha[bottom - 25:bottom + 1] > 40)
    return float(xs.mean()), bottom + 1


def main():
    sheet = Image.open(SRC).convert("RGBA")
    frames, feet = [], []
    for box in BOXES:
        f = sheet.crop(box)
        frames.append(f)
        feet.append(base(np.array(f)[:, :, 3]))
    left = max(bx for bx, _ in feet)
    right = max(f.width - bx for f, (bx, _) in zip(frames, feet))
    height = max(by for _, by in feet)
    cw, ch = round((left + right) * K), round(height * K)
    strip = Image.new("RGBA", (cw * 8, ch))
    lens = []
    for col, i in enumerate(ORDER):
        f, (bx, by) = frames[i], feet[i]
        canvas = Image.new("RGBA", (round(left + right), round(height)))
        canvas.paste(f, (round(left - bx), round(height - by)))
        small = canvas.resize((cw, ch), Image.Resampling.BOX)
        a = np.array(small)
        a[:, :, 3] = np.where(a[:, :, 3] >= 128, 255, 0)
        strip.paste(Image.fromarray(a), (col * cw, 0))
        lx, ly = LENS.get(i, HIDDEN.get(i))
        lens.append([round((lx - bx) * K, 1), round((ly - by) * K, 1)])
    # indexed PNG: index 0 transparent
    rgba = np.array(strip)
    solid = rgba[:, :, 3] >= 128
    q = Image.fromarray(rgba[:, :, :3]).quantize(47, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    idx = np.array(q).astype(np.uint8) + 1
    idx[~solid] = 0
    out = Image.fromarray(idx, "P")
    out.putpalette([0, 0, 0] + q.getpalette()[:47 * 3])
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, "cam_8dir.png"), optimize=True, transparency=0)
    with open(os.path.join(OUT, "cam_8dir.json"), "w", encoding="utf-8") as fh:
        json.dump({"views": 8, "order": ["E", "SE", "S", "SW", "W", "NW", "N", "NE"],
                   "frame": [cw, ch], "lens": lens}, fh, indent=1)
    print("cam_8dir.png %dx%d (8 x %dx%d), %d bytes; lens %s" % (
        cw * 8, ch, cw, ch, os.path.getsize(os.path.join(OUT, "cam_8dir.png")), lens))


if __name__ == "__main__":
    main()
