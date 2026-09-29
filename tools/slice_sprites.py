"""Slices the reference sprite sheet into aligned animation frames for Godot.

Usage: python tools/slice_sprites.py <sheet.webp>
Writes assets/sprites/<set>/<anim>_<i>.png and assets/sprites/manifest.json.
Every frame of a set is pasted on a common canvas that is horizontally symmetric
around the anchor (feet), so flip_h works without the body jumping.
A frame is either a (row, x0, x1) range of the sheet or a loose png (relative to
assets/sprites/, e.g. the enemies/<name>/ folders): "path", ("path", x0, x1) to use
only those columns, or ("path", x0, x1, scale) to also resize it.
An anim is (frames, fps, loop) or (frames, fps, loop, True) to mirror its frames.

  python tools/slice_sprites.py <sheet.webp> --only big_red,big_red_ball
re-slices just those sets and keeps the rest of manifest.json as it is.
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

BR = "enemies/big-red/big-red_elements/big-red_%03d.png"
HQ = "enemies/bosses/boss_2_elements/boss_2_%03d.png"

# Infected mode (loose frames in assets/sprites/enviroment/infected player_elements,
# cut from "infected player.png"; frames face right, anchored on the boots)
INF = "enviroment/infected player_elements/infected player_%s.png"


def inf(*ids):
    return [INF % i if isinstance(i, str) else (INF % i[0], *i[1:]) for i in ids]


# The mutant (Infected mode): the astronaut's own frames with the mutated helmet of its
# phase (tools/make_mutant_player.py <n> -> mutations_player/fase <n>/player/). Same
# animations as "player", so it walks, flips and holds the gun like the astronaut.
def mutp(n, anim, k):
    return ["mutations_player/fase %d/player/%s_%d.png" % (n, anim, i) for i in range(k)]


def mutant_set(n):
    return {
        "anchor": "helmet",
        "anims": {
            "idle": (mutp(n, "idle", 4), 5, True),
            "walk": (mutp(n, "walk", 4), 9, True),
            "walk_up": (mutp(n, "walk_up", 4), 9, True),
            "shoot": (mutp(n, "shoot", 2), 14, False),
            "hurt": (mutp(n, "hurt", 2), 10, False),
        },
        "body": "idle",
    }


SETS = {
    "mutant1": mutant_set(1),
    "infected": {
        "anchor": "boots",
        "anims": {
            "idle": (inf("010", "005", "006", "007", "008", "004", "009"), 8, True),
            # drawn facing left in the sheet (the rest face right): mirrored
            "walk": (inf("017", "018", "019", "020", "021", "024", "022", "023"), 13, True, True),
            "walk_up": (inf("016", "027", "028", "029", "030", "025", "026", "031"), 13, True),
            "shoot": (inf("035"), 1, False),
            "slash": (inf("053", "050", "052", "049", "051"), 18, False),
            "dash": (inf(("055", 120, 332)), 1, False),
            "transform": (inf("071", "066", "062", "070", "060", "058", "061"), 9, False),
        },
        "body": "idle",
    },
    "inf_shot": {"anchor": "center", "anims": {"fly": (inf("097", "154"), 12, True)}, "body": "fly"},
    "inf_orb": {"anchor": "center", "anims": {"pulse": (inf("163", "100", "098"), 14, True)}, "body": "pulse"},
    "inf_missile": {"anchor": "center", "anims": {"fly": (inf("111"), 1, True)}, "body": "fly"},
    "inf_burst": {"anchor": "center", "anims": {"pop": (inf("149"), 1, False)}, "body": "pop"},
    "inf_erupt": {"anchor": "bottom", "anims": {"erupt": (inf("150", "141", "115", "136"), 12, False)}, "body": "erupt"},
    "inf_goo": {"anchor": "center", "anims": {"bits": (inf("041", "057", "073", "099", "112", "124", "080", "082"), 1, False)}, "body": "bits"},
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
    # Big Red (loose frames in assets/sprites/enemies/big-red/big-red_elements): the
    # red one-eyed brute and the world 1 boss. 002 and 005 hold two poses side by side,
    # 013 the shooting pose with its fireball (cut off: the fireball is big_red_ball).
    "big_red": {
        "anchor": "bbox",
        "anims": {
            "walk": ([(BR % 1, 0, 244, 0.88), (BR % 5, 200, 398), (BR % 5, 0, 200), BR % 3, (BR % 5, 0, 200), (BR % 5, 200, 398)], 4, True),
            "angry": ([BR % 4, BR % 6, BR % 7, (BR % 2, 0, 196)], 6, True),
            "hurt": ([(BR % 2, 196, 406)], 1, False),
            "fury": ([BR % 8, BR % 9, BR % 11, BR % 9], 10, True),
            "shoot": ([(BR % 13, 0, 174)], 1, False),
            "roar": ([BR % 68], 1, False),
            "death": ([BR % i for i in (68, 69, 71, 78, 80, 82)], 6, False),
            "splat": ([BR % 95], 1, False),
        },
        "body": "walk",
    },
    "big_red_ball": {"anchor": "center",
                     "anims": {"fly": ([BR % i for i in (17, 34, 37, 40)], 12, True)}, "body": "fly"},
    "big_red_blob": {"anchor": "center",
                     "anims": {"fly": ([BR % i for i in (63, 64, 67, 42)], 10, True)}, "body": "fly"},
    "big_red_drop": {"anchor": "center",
                     "anims": {"fly": ([BR % i for i in (72, 75, 81, 84)], 10, True)}, "body": "fly"},
    # HIVE QUEEN, world 2 final boss (loose frames in assets/sprites/enemies/bosses/
    # boss_2_elements, sheet boss_2.png): looks around and blinks, spits acid balls,
    # grows crystals when furious, drools goo eggs, melts into goo and crystals.
    "hive_queen": {
        "anchor": "feet",
        "anims": {
            "walk": ([HQ % i for i in (2, 3, 8, 4, 9, 2, 5)], 5, True),
            "spit": ([HQ % i for i in (11, 13, 12)], 10, False),
            "roar": ([HQ % 7], 1, False),
            "angry": ([HQ % 1], 1, False),
            "crystal": ([HQ % i for i in (49, 50, 54)], 8, True),
            "crystal_spit": ([HQ % 51], 1, False),
            "drool": ([HQ % i for i in (91, 92, 93, 94)], 6, True),
            "death": ([HQ % i for i in (114, 115, 116, 117, 120, 127)], 6, False),
        },
        "body": "walk",
    },
    "hive_acid": {"anchor": "center", "anims": {"fly": ([HQ % 23, HQ % 20], 10, True)}, "body": "fly"},
    "hive_crystal": {"anchor": "center", "anims": {"fly": ([HQ % 64, HQ % 66], 8, True)}, "body": "fly"},
    "hive_shard": {"anchor": "center", "anims": {"fly": ([HQ % 52, HQ % 56], 8, True)}, "body": "fly"},
    "hive_burst": {"anchor": "center", "anims": {"pop": ([HQ % 55], 1, False)}, "body": "pop"},
    "hive_drop": {"anchor": "center", "anims": {"fly": ([HQ % i for i in (97, 101, 102)], 10, True)}, "body": "fly"},
    # goo egg the queen drools: pulses, then hatches greenies (enemies/hive_egg.gd)
    "hive_egg": {
        "anchor": "bbox",
        "anims": {"walk": ([HQ % i for i in (99, 104, 106, 104)], 4, True), "splat": ([HQ % 108], 1, False)},
        "body": "walk",
    },
    # crystal guard that shields the queen (enemies/hive_guard.gd)
    "hive_guard": {"anchor": "feet", "anims": {"walk": ([HQ % 55], 1, True)}, "body": "walk"},
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
    if mode == "boots":
        # the near-black boots at the bottom of the body (energy arcs, dust and
        # tentacles around it would shift a bounding-box anchor)
        rgba = np.asarray(img).astype(int)
        dark = a & (rgba[:, :, 0] < 45) & (rgba[:, :, 1] < 45) & (rgba[:, :, 2] < 90) & (rgba[:, :, 2] >= rgba[:, :, 0])
        dark[: int(h * 0.7)] = False
        ys, xs = np.nonzero(dark)
        low = ys >= ys.max() - 10
        return (float(np.median(xs[low])), float(ys.max() + 1))
    if mode == "boots_blue":
        # the navy boots at the bottom (slash trails reach far to the sides)
        rgba = np.asarray(img).astype(int)
        r, g, b = rgba[:, :, 0], rgba[:, :, 1], rgba[:, :, 2]
        navy = a & (b > 50) & (b > r + 25) & (r < 90) & (g < 110)
        navy[: int(h * 0.7)] = False
        ys, xs = np.nonzero(navy)
        low = ys >= ys.max() - 12
        return (float(np.median(xs[low])), float(ys.max() + 1))
    if mode == "feet":
        # centre of the legs along the bottom rows: a spit or crystals beside the body
        # would shift a bounding-box anchor
        rows = a[int(h * 0.85):]
        xs = np.nonzero(rows.any(axis=0))[0]
        return ((xs.min() + xs.max() + 1) / 2.0, h)
    if mode == "center":
        return (w / 2.0, h / 2.0)
    return (w / 2.0, h)


def main(sheet_path, out_dir, only=None):
    sheet = Image.open(sheet_path).convert("RGBA")
    arr = np.asarray(sheet).copy()
    arr[arr[:, :, 3] < 48] = 0  # drop faint halo pixels
    sheet = Image.fromarray(arr)
    manifest = {}
    if only:
        with open(os.path.join(out_dir, "manifest.json")) as f:
            manifest = json.load(f)
    for set_name, spec in SETS.items():
        if only and set_name not in only:
            continue
        frames = {}
        for anim, (ranges, fps, loop, *mirror) in spec["anims"].items():
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
                if spec.get("flip") or (mirror and mirror[0]):
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
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    main(sys.argv[1], os.path.join(here, "..", "assets", "sprites"), only)
