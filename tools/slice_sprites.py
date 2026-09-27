"""Slices the reference sprite sheet into aligned animation frames for Godot.

Usage: python tools/slice_sprites.py <sheet.webp>
Writes assets/sprites/<set>/<anim>_<i>.png and assets/sprites/manifest.json.
Every frame of a set is pasted on a common canvas that is horizontally symmetric
around the anchor (feet), so flip_h works without the body jumping.
A frame is either a (row, x0, x1) range of the sheet or a loose png (relative to
assets/sprites/, e.g. the enemies/<name>/ folders): "path", ("path", x0, x1) to use
only those columns, or ("path", x0, x1, scale) to also resize it.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROWS = {0: (17, 92), 1: (109, 178), 2: (194, 268), 3: (286, 367),
        4: (384, 445), 5: (468, 551), 6: (561, 641), 7: (649, 732)}

# (row, x0, x1) source ranges
F = {
    "p_idle": [(0, 18, 68), (0, 81, 130), (0, 143, 191), (0, 202, 252)],
    "p_walk": [(0, 278, 328), (0, 339, 386), (0, 401, 448), (0, 460, 510)],
    "p_up": [(0, 561, 609), (0, 620, 667), (0, 681, 728), (0, 743, 790)],
    "p_shoot": [(2, 95, 167), (2, 177, 248)],
    "p_hurt": [(3, 86, 166), (3, 175, 256)],
    "p_death": [(3, 468, 534), (3, 551, 614), (3, 627, 690)],
}

GREEN = [(5, 14, 94), (5, 113, 189), (5, 201, 279), (5, 294, 368), (5, 381, 446), (5, 464, 538), (5, 550, 624), (5, 634, 707)]
PINK = [(6, 23, 96), (6, 112, 188), (6, 202, 276), (6, 298, 372), (6, 382, 458), (6, 466, 538), (6, 550, 625), (6, 637, 710)]
BLUE = [(7, 18, 84), (7, 106, 170), (7, 193, 258), (7, 281, 346), (7, 371, 437), (7, 458, 522), (7, 545, 607), (7, 626, 694)]

SETS = {
    "player": {
        "anchor": "helmet",
        "anims": {
            "idle": (F["p_idle"], 5, True),
            "walk": (F["p_walk"], 9, True),
            "walk_up": (F["p_up"], 9, True),
            "shoot": (F["p_shoot"], 14, False),
            "hurt": (F["p_hurt"], 10, False),
            "death": (F["p_death"], 8, False),
        },
        "body": "idle",
    },
    "green": {
        "anchor": "bbox",
        "anims": {
            "walk": (GREEN, 10, True),
            "hurt": ([(5, 381, 446)], 1, False),
            "splat": ([(5, 816, 909), (5, 920, 1012), (5, 1025, 1103)], 12, False),
        },
        "body": "walk",
    },
    "pink": {
        "anchor": "bbox",
        "anims": {
            "walk": (PINK, 10, True),
            "splat": ([(6, 730, 807), (6, 824, 905), (6, 927, 1004), (6, 1025, 1104)], 12, False),
        },
        "body": "walk",
    },
    "blue": {
        "anchor": "bbox",
        "anims": {"walk": (BLUE, 10, True)},
        "body": "walk",
    },
    "bullet": {
        "anchor": "center",
        "anims": {"fly": ([(4, 62, 118), (4, 139, 185), (4, 202, 260)], 14, True)},
        "body": "fly",
    },
    "impact": {
        "anchor": "center",
        "anims": {"pop": ([(4, 278, 340), (4, 364, 420), (4, 435, 496)], 20, False)},
        "body": "pop",
    },
    "dust": {
        "anchor": "bottom",
        "anims": {"puff": ([(4, 690, 782), (4, 809, 865), (4, 874, 981), (4, 982, 1073), (4, 1077, 1103)], 14, False)},
        "body": "puff",
    },
    # blaster power tiers (all normalised to fly towards +x)
    "shot1": {"anchor": "center", "anims": {"fly": ([(4, 139, 185)], 1, True)}, "body": "fly"},
    "shot2": {"anchor": "center", "anims": {"fly": ([(4, 62, 118), (4, 202, 260)], 12, True)}, "body": "fly"},
    "shot3": {"anchor": "center", "anims": {"fly": ([(4, 278, 340)], 1, True)}, "body": "fly"},
    "shot4": {"anchor": "center", "flip": True, "anims": {"fly": ([(4, 364, 420), (4, 435, 496)], 12, True)}, "body": "fly"},
    "shot5": {"anchor": "center", "flip": True, "anims": {"fly": ([(4, 518, 577), (4, 603, 656)], 10, True)}, "body": "fly"},
    "muzzle": {"anchor": "center", "anims": {"flash": ([(4, 25, 46)], 16, False)}, "body": "flash"},
    # Droid (loose frames in assets/sprites/enemies/droid01): hovering eye robot
    "droid": {
        "anchor": "bbox",
        "anims": {
            "walk": ([f"enemies/droid01/enemies_00{i}.png" for i in (4, 5, 6, 7, 8)], 10, True),
            "charge": (["enemies/droid01/enemies_001.png"], 1, False),
        },
        "body": "walk",
    },
    "droid_shot": {"anchor": "center", "flip": True,
                   "anims": {"fly": (["enemies/droid01/enemies_012.png"], 1, True)}, "body": "fly"},
    "droid_pop": {"anchor": "center",
                  "anims": {"pop": (["enemies/droid01/enemies_010.png"], 1, False)}, "body": "pop"},
    # UFO (loose frames in assets/sprites/enemies/ufo01). 090 holds the firing UFO,
    # its laser and a portal side by side: cut by columns.
    "ufo": {
        "anchor": "bbox",
        "anims": {
            "walk": ([f"enemies/ufo01/enemies_0{i}.png" for i in (91, 93, 97, 98)], 8, True),
            "attack": ([("enemies/ufo01/enemies_090.png", 0, 86, 1.1)], 1, False),
        },
        "body": "walk",
    },
    "ufo_shot": {"anchor": "center",
                 "anims": {"fly": ([("enemies/ufo01/enemies_090.png", 86, 148)], 1, True)}, "body": "fly"},
    "ufo_portal": {"anchor": "center",
                   "anims": {"open": ([("enemies/ufo01/enemies_090.png", 148, 211)], 1, False)}, "body": "open"},
    "ufo_alien": {"anchor": "bbox",
                  "anims": {"walk": (["enemies/ufo01/enemies_099.png"], 1, True)}, "body": "walk"},
    # Octopus (loose frames in assets/sprites/enemies/octopus01). attack.png holds the
    # octopus and its orb side by side; die.png is the puddle it leaves (splat).
    "octopus": {
        "anchor": "bbox",
        "anims": {
            "walk": ([f"enemies/octopus01/enemies_04{i}.png" for i in (2, 3, 4, 3)], 7, True),
            "attack": ([("enemies/octopus01/attack.png", 0, 78)], 1, False),
            "splat": (["enemies/octopus01/die.png"], 1, False),
        },
        "body": "walk",
    },
    "octopus_shot": {"anchor": "center",
                     "anims": {"fly": ([("enemies/octopus01/attack.png", 78, 146)], 1, True)}, "body": "fly"},
    "octopus_pop": {"anchor": "center",
                    "anims": {"pop": (["enemies/octopus01/enemies_051.png"], 1, False)}, "body": "pop"},
    "glob": {
        "anchor": "center",
        "anims": {"fly": ([(7, 709, 782)], 1, True)},
        "body": "fly",
    },
    "glob_pop": {
        "anchor": "center",
        "anims": {"pop": ([(7, 802, 891), (7, 912, 986), (7, 992, 1104)], 16, False)},
        "body": "pop",
    },
}


def trim(img):
    a = np.asarray(img)
    ys, xs = np.nonzero(a[:, :, 3] > 0)
    return img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def anchor_of(img, mode):
    a = np.asarray(img)[:, :, 3] > 0
    h, w = a.shape
    if mode == "helmet":
        top = a[: int(h * 0.4)]
        xs = np.nonzero(top.any(axis=0))[0]
        return ((xs.min() + xs.max() + 1) / 2.0, h)
    if mode == "center":
        return (w / 2.0, h / 2.0)
    return (w / 2.0, h)


def main(sheet_path, out_dir):
    sheet = Image.open(sheet_path).convert("RGBA")
    arr = np.asarray(sheet).copy()
    arr[arr[:, :, 3] < 48] = 0  # drop faint halo pixels
    sheet = Image.fromarray(arr)
    manifest = {}
    for set_name, spec in SETS.items():
        frames = {}
        for anim, (ranges, fps, loop) in spec["anims"].items():
            lst = []
            for r in ranges:
                if isinstance(r, str) or isinstance(r[0], str):
                    path, *cols = (r,) if isinstance(r, str) else r
                    img = Image.open(os.path.join(out_dir, path)).convert("RGBA")
                    if cols:
                        img = img.crop((cols[0], 0, cols[1], img.height))
                    if len(cols) > 2:
                        img = img.resize((round(img.width * cols[2]), round(img.height * cols[2])), Image.LANCZOS)
                    a = np.asarray(img).copy()
                    a[a[:, :, 3] < 48] = 0
                    img = trim(Image.fromarray(a))
                else:
                    row, x0, x1 = r
                    y0, y1 = ROWS[row]
                    img = trim(sheet.crop((x0, y0 - 2, x1, y1 + 2)))
                if spec.get("flip"):
                    img = img.transpose(Image.FLIP_LEFT_RIGHT)
                lst.append((img, anchor_of(img, spec["anchor"])))
            frames[anim] = (lst, fps, loop)
        left = right = up = down = 0.0
        for lst, _, _ in frames.values():
            for img, (ax, ay) in lst:
                left, right = max(left, ax), max(right, img.width - ax)
                up, down = max(up, ay), max(down, img.height - ay)
        half = int(np.ceil(max(left, right)))
        W, H = half * 2, int(np.ceil(up + down))
        d = os.path.join(out_dir, set_name)
        os.makedirs(d, exist_ok=True)
        anims = {}
        for anim, (lst, fps, loop) in frames.items():
            for i, (img, (ax, ay)) in enumerate(lst):
                canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                canvas.alpha_composite(img, (int(round(half - ax)), int(round(up - ay))))
                canvas.save(os.path.join(d, f"{anim}_{i}.png"))
            anims[anim] = {"frames": len(lst), "fps": fps, "loop": loop}
        body = frames[spec["body"]][0]
        body_h = float(np.median([img.height for img, _ in body]))
        manifest[set_name] = {"size": [W, H], "anchor": [half, round(up, 1)], "body_h": body_h, "anims": anims}
        print(set_name, W, H, body_h, list(anims))
    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1], os.path.join(here, "..", "assets", "sprites"))
