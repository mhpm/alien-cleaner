"""Cuts the frames of a character sheet (transparent background, one row per animation)
into loose PNGs: assets/sprites/enemies/<name>/<row>/image_NN.png.

Usage: python tools/cut_sheet_enemies.py [enemy,enemy...]
SHEETS lists, per sheet, each enemy's rows as (row name, y0, y1, x0, x1, cuts): the
frames in a row touch each other, so `cuts` are rough x positions between frames and
each is moved to the emptiest column within SNAP px. Frames are trimmed to their
content. `cuts` = None instead splits the area into its separate pieces (connected
components of the alpha, as in scripts/split_items.py), biggest first: for loose shots
or bits drawn together (the crab's rockets). slice_sprites.py then builds the sprite sets from these files.
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sprites", "enemies")
SNAP = 12

SHEETS = {
    # world 4: Comet Hopper, Saturn Ring Bug, Drill Nose Orbiter, Nova Puffer Saucer
    "enemies_w4_ref.webp": {
        "comet_hopper": [
            ("idle", 89, 195, 66, 562, [157, 259, 357, 455]),
            ("attack", 207, 311, 66, 568, [163, 258, 357, 435, 488, 536]),
            ("die", 331, 440, 66, 566, [152, 252, 358, 466]),
        ],
        "ring_bug": [
            ("idle", 89, 198, 632, 1120, [732, 832, 930, 1025]),
            ("attack", 215, 313, 645, 1125, [748, 853, 912, 1003]),
            ("die", 335, 440, 632, 1116, [741, 848, 945, 1032]),
        ],
        "drill_orbiter": [
            ("idle", 521, 613, 72, 570, [169, 271, 372, 473]),
            ("attack", 624, 716, 78, 565, [177, 278, 408, 492, 542]),
            ("die", 724, 833, 72, 565, [175, 273, 372, 468]),
        ],
        "nova_puffer": [
            ("idle", 518, 622, 640, 1120, [738, 834, 930, 1024]),
            ("attack", 623, 720, 640, 1120, [738, 838, 935, 1012, 1070]),
            ("die", 721, 834, 632, 1120, [740, 862, 992]),
        ],
    },
    # world 4 drones: Cyclone Blade, Tesla Orb, Cargo Crab, Prism Satellite
    "drones_w4_ref.webp": {
        "blade_drone": [
            ("idle", 86, 177, 74, 548, [166, 260, 355, 450]),
            ("attack", 192, 288, 74, 545, [193, 350, 412, 465, 508]),
            ("die", 303, 418, 74, 560, [168, 305, 383, 470]),
        ],
        "tesla_drone": [
            ("idle", 84, 178, 634, 1106, [730, 821, 914, 1009]),
            ("attack", 192, 292, 634, 1120, [728, 820, 915, 1060]),
            ("die", 300, 418, 634, 1112, [752, 871, 1000]),
        ],
        "crab_drone": [
            ("idle", 491, 580, 74, 556, [163, 261, 358, 455]),
            ("attack", 586, 683, 74, 377, [180, 281]),
            ("rocket", 586, 683, 377, 565, None),
            ("die", 691, 802, 74, 558, [176, 309, 470]),
        ],
        "prism_drone": [
            ("idle", 486, 578, 634, 1104, [728, 821, 915, 1009]),
            ("attack", 580, 683, 634, 1118, [731, 827, 915]),
            ("die", 693, 808, 634, 1116, [727, 820, 915]),
        ],
    },
    # world 4, second sheet: Meteor Peeper, Bubble Brain, Tentacle Bell, Goo Seed Hopper
    "enemies_w4b_ref.webp": {
        "meteor_peeper": [
            ("idle", 53, 165, 52, 532, [170, 288, 407]),
            ("attack", 171, 281, 60, 405, [174, 292]),
            ("shot", 171, 281, 405, 565, None),
            ("die", 301, 412, 52, 550, [165, 280, 402]),
        ],
        "bubble_brain": [
            ("idle", 50, 166, 634, 1108, [748, 864, 986]),
            ("attack", 170, 289, 630, 866, [740]),
            ("shot", 170, 289, 1024, 1115, None),
            ("die", 289, 410, 625, 1116, [728, 834, 912, 1015]),
        ],
        "bell_cruiser": [
            ("idle", 464, 598, 52, 544, [170, 295, 420]),
            ("attack", 598, 718, 60, 296, [180]),
            ("shot", 598, 718, 458, 560, None),
            ("die", 721, 828, 52, 558, [168, 289, 428]),
        ],
        "goo_hopper": [
            ("idle", 464, 603, 630, 1118, [757, 885, 1004]),
            ("attack", 603, 721, 630, 864, [748]),
            ("shot", 603, 721, 864, 957, None),
            ("die", 722, 833, 622, 1112, [738, 868, 988]),
        ],
    },
    # world 4, third sheet: Nebula Scout Pod, Ring-Eye Shuttle, Puddle Radar, Comet Baby Skiff
    "enemies_w4c_ref.webp": {
        "nebula_pod": [
            ("idle", 54, 163, 58, 545, [151, 250, 346, 444]),
            ("attack", 177, 282, 58, 362, [160, 260]),
            ("shot", 177, 282, 362, 455, None),
            ("die", 292, 412, 58, 566, [148, 247, 346, 446]),
        ],
        "ring_eye": [
            ("idle", 52, 162, 614, 1121, [718, 822, 925, 1017]),
            ("attack", 183, 289, 624, 830, [724]),
            ("shot", 183, 289, 964, 1110, None),
            ("die", 307, 418, 614, 1112, [721, 840, 970]),
        ],
        "puddle_radar": [
            ("idle", 471, 601, 58, 542, [152, 253, 347, 444]),
            ("attack", 603, 720, 63, 345, [158, 258]),
            ("shot", 603, 720, 436, 556, None),
            ("die", 720, 835, 58, 566, [156, 265, 415]),
        ],
        "comet_baby": [
            ("idle", 468, 599, 612, 1123, [737, 840, 943, 1032]),
            ("attack", 601, 719, 605, 845, [733]),
            ("shot", 601, 719, 945, 1048, None),
            ("die", 725, 836, 612, 1119, [740, 855, 973]),
        ],
    },
    # world 4, fourth sheet: Orbit Tadpole, Plasma Pupil, Bubble Tentacle Pod, Slime Pearl Flyer
    "enemies_w4d_ref.webp": {
        "tadpole_saucer": [
            ("idle", 51, 164, 58, 562, [155, 255, 357, 460]),
            ("attack", 170, 285, 64, 352, [161, 258]),
            ("shot", 170, 285, 440, 565, None),
            ("die", 298, 411, 58, 562, [146, 245, 342, 447]),
        ],
        "plasma_pupil": [
            ("idle", 46, 166, 634, 1112, [734, 829, 922, 1016]),
            ("attack", 167, 288, 638, 840, [742]),
            ("shot", 167, 288, 980, 1115, None),
            ("die", 299, 417, 622, 1116, [718, 822, 924, 1020]),
        ],
        "tentacle_pod": [
            ("idle", 461, 606, 58, 552, [159, 255, 354, 454]),
            ("attack", 606, 712, 64, 266, [166]),
            ("shot", 606, 712, 470, 566, None),
            ("die", 712, 834, 58, 570, [158, 258, 362, 465]),
        ],
        "pearl_flyer": [
            ("idle", 464, 588, 626, 1112, [729, 827, 922, 1018]),
            ("attack", 588, 709, 633, 842, [731]),
            ("shot", 588, 709, 1030, 1112, None),
            ("die", 709, 836, 618, 1112, [729, 840, 977]),
        ],
    },
    # world 4, fifth sheet: Martian Scout Saucer, Cyclops Ray Pod, Tentacle Orbiter, Slime Comet Ship
    "enemies_w4e_ref.webp": {
        "martian_scout": [
            ("idle", 60, 180, 72, 545, [168, 261, 352, 449]),
            ("attack", 186, 298, 78, 395, [181, 287]),
            ("shot", 186, 298, 470, 545, None),
            ("die", 310, 430, 72, 552, [168, 266, 363, 461]),
        ],
        "cyclops_pod": [
            ("idle", 60, 182, 632, 1108, [726, 821, 916, 1010]),
            ("attack", 184, 304, 644, 812, [729]),
            ("shot", 184, 304, 1015, 1110, None),
            ("die", 310, 430, 634, 1115, [729, 823, 920, 1016]),
        ],
        "tentacle_orbiter": [
            ("idle", 484, 610, 72, 552, [168, 262, 355, 451]),
            ("attack", 610, 723, 80, 393, [186, 292]),
            ("shot", 610, 723, 478, 548, None),
            ("die", 724, 832, 72, 562, [158, 255, 379, 478]),
        ],
        "slime_comet": [
            ("idle", 495, 607, 632, 1112, [732, 828, 926, 1020]),
            ("attack", 612, 722, 640, 868, [751]),
            ("shot", 612, 722, 1022, 1106, None),
            ("die", 727, 834, 630, 1110, [735, 830, 933, 1020]),
        ],
    },
    # world 4, sixth sheet: Astro Blink, Martian Bean Cruiser, Ray-Eye Nugget, Goo Lantern
    "enemies_w4f_ref.webp": {
        "blink_saucer": [
            ("idle", 50, 172, 58, 556, [153, 253, 352, 453]),
            ("attack", 178, 298, 63, 375, [160, 265]),
            ("shot", 178, 298, 495, 560, None),
            ("die", 305, 428, 58, 562, [155, 270, 385, 470]),
        ],
        "bean_cruiser": [
            ("idle", 45, 173, 626, 1122, [730, 829, 926, 1025]),
            ("attack", 174, 300, 620, 844, [738]),
            ("shot", 174, 300, 1020, 1105, None),
            ("die", 302, 428, 626, 1115, [722, 824, 912, 1010]),
        ],
        "nugget_ship": [
            ("idle", 478, 601, 58, 554, [156, 252, 351, 451]),
            ("attack", 605, 724, 58, 260, [166]),
            ("shot", 605, 724, 486, 556, None),
            ("die", 724, 838, 58, 562, [157, 270, 380, 430]),
        ],
        "goo_lantern": [
            ("idle", 476, 610, 620, 1121, [724, 825, 923, 1022]),
            ("attack", 610, 733, 637, 871, [744]),
            ("shot", 610, 733, 1005, 1114, None),
            ("die", 733, 840, 622, 1112, [728, 829, 937, 1034]),
        ],
    },
    # MAGMA DRAKE boss (enemies/boss_magma.gd): one row per pose; the projectiles drawn in
    # the rows are cut as single frames (cuts = [] keeps the whole box as one frame)
    "boss_magma_ref.webp": {
        "magma_drake": [
            ("idle", 22, 163, 0, 1125, [147, 289, 431, 571, 708, 851, 994]),
            ("breath", 165, 302, 0, 148, []),
            ("cast", 302, 415, 0, 155, []),
            ("summon", 415, 522, 0, 158, []),
            ("die", 523, 626, 0, 1125, [138, 275, 432, 597, 755, 874, 995]),
            ("fireball", 165, 302, 340, 432, []),
            ("meteor", 165, 302, 860, 1120, []),
            ("crescent", 302, 415, 490, 590, []),
            ("ring", 302, 415, 990, 1122, []),
            ("ring_small", 302, 415, 592, 732, []),
            ("mine", 415, 522, 245, 320, []),
            ("erupt", 415, 522, 870, 1012, []),
        ],
    },
    # TOXIC ANGLER boss (enemies/boss_angler.gd): one sheet, one row per pose / effect
    "boss_puffer_ref.webp": {
        "toxic_angler": [
            ("idle", 5, 142, 0, 1125, [133, 260, 388, 513, 643, 770, 902, 1016]),
            ("attack", 143, 277, 0, 405, [127, 266]),
            ("spit", 143, 282, 405, 465, []),
            ("charge", 143, 282, 465, 553, []),
            ("bubble", 143, 283, 553, 826, [647, 722]),
            ("bubble2", 143, 297, 826, 1125, [950]),
            ("summon", 279, 405, 0, 662, [131, 300, 490]),
            ("mine", 298, 422, 662, 1125, [707, 768, 833, 902, 995]),
            ("wink", 402, 526, 0, 134, []),
            ("dive", 411, 528, 134, 603, [300, 458]),
            ("ripple", 402, 536, 603, 998, [700, 848]),
            ("ripple2", 422, 536, 998, 1125, []),
            ("die", 526, 626, 0, 502, [108, 234, 366]),
            ("die2", 534, 626, 502, 1125, [615, 720, 806, 869, 991]),
        ],
    },
    # DRILLBACK boss (enemies/boss_drillback.gd): one sheet, one row per pose / effect. The
    # dash rows keep only the body of each frame (the long plasma trail is drawn in code)
    "boss_drill_ref.webp": {
        "drillback": [
            ("idle", 30, 170, 0, 1500, [171, 340, 512, 688, 855, 1026, 1190, 1350]),
            ("attack", 195, 363, 0, 662, [166, 308, 460]),
            ("dash_a", 195, 363, 664, 822, []),
            ("dash_b", 195, 363, 880, 1030, []),
            ("dash_c", 195, 363, 1135, 1300, []),
            ("dash_d", 195, 363, 1360, 1500, []),
            ("dive", 362, 526, 0, 745, [177, 366, 556]),
            ("spike", 362, 526, 745, 1500, [903, 1088, 1281]),
            ("rear", 526, 690, 0, 190, []),
            ("rock", 540, 617, 168, 240, []),
            ("seed", 526, 690, 240, 1500, [360, 528, 690, 822, 928, 1006, 1165, 1328]),
            ("die", 698, 838, 0, 1500, [172, 348, 532, 730, 855, 1002, 1195, 1315]),
        ],
    },
}


def clean(fr):
    """Drops slivers of the neighbouring frames: small bits touching the cut edges."""
    a = np.asarray(fr).copy()
    m = cv2.dilate((a[:, :, 3] > 20).astype(np.uint8), np.ones((3, 3), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    if n <= 2:
        return fr
    big = st[1:, cv2.CC_STAT_AREA].max()
    w = a.shape[1]
    for k in range(1, n):
        x, _, bw, _, area = st[k]
        if (x <= 1 or x + bw >= w - 1) and area < big * 0.12:
            a[lab == k] = 0
    return Image.fromarray(a)


def main_piece(fr):
    """Only the biggest piece of a frame (drops stray drips of the rows around it)."""
    a = np.asarray(fr).copy()
    m = cv2.dilate((a[:, :, 3] > 20).astype(np.uint8), np.ones((5, 5), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    if n < 2:
        return fr
    keep = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
    a[lab != keep] = 0
    return Image.fromarray(a)


# rows whose first N frames keep only their biggest piece (TOXIC ANGLER's spore mine)
MAIN_ONLY = {"mine": 5, "rear": 1, "rock": 1}
# rows whose left edge fades out over N px (a long trail cut off by the frame box)
FADE_LEFT = {"dash_b": 50, "dash_c": 70, "dash_d": 60}


def _fresh(d):
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        if f.endswith(".png"):
            os.remove(os.path.join(d, f))


def pieces(img, name, row, box, min_area=150):
    """Each separate piece in `box` as its own frame, biggest first."""
    a = np.asarray(img.crop(box)).copy()
    m = (a[:, :, 3] > 24).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(cv2.dilate(m, np.ones((3, 3), np.uint8)))
    order = sorted(range(1, n), key=lambda k: -st[k, cv2.CC_STAT_AREA])
    d = os.path.join(OUT, name, row)
    _fresh(d)
    k = 0
    for c in order:
        if st[c, cv2.CC_STAT_AREA] < min_area:
            continue
        b = a.copy()
        b[lab != c] = 0
        fr = Image.fromarray(b)
        k += 1
        fr.crop(fr.getbbox()).save(os.path.join(d, "image_%02d.png" % k))
    print(name, row, k, "pieces")


def main(only=None):
    for sheet, enemies in SHEETS.items():
        img = Image.open(os.path.join(HERE, sheet)).convert("RGBA")
        alpha = np.asarray(img)[:, :, 3]
        for name, rows in enemies.items():
            if only and name not in only:
                continue
            for row, y0, y1, x0, x1, cuts in rows:
                if cuts is None:
                    pieces(img, name, row, (x0, y0, x1, y1))
                    continue
                prof = (alpha[y0:y1] > 40).sum(axis=0)
                xs = [x0]
                for c in cuts:
                    lo, hi = max(x0 + 1, c - SNAP), min(x1 - 1, c + SNAP)
                    xs.append(lo + int(np.argmin(prof[lo:hi + 1])))
                xs.append(x1)
                d = os.path.join(OUT, name, row)
                _fresh(d)
                for i in range(len(xs) - 1):
                    fr = clean(img.crop((xs[i], y0, xs[i + 1], y1)))
                    if i < MAIN_ONLY.get(row, 0):
                        fr = main_piece(fr)
                    if row in FADE_LEFT:
                        fa = np.asarray(fr).copy()
                        ramp = np.clip(np.arange(fa.shape[1]) / FADE_LEFT[row], 0.0, 1.0)
                        fa[:, :, 3] = (fa[:, :, 3] * ramp[None, :]).astype(np.uint8)
                        fr = Image.fromarray(fa)
                    fr = fr.crop(fr.getbbox())
                    fr.save(os.path.join(d, "image_%02d.png" % (i + 1)))
                print(name, row, len(xs) - 1, "frames", xs)


if __name__ == "__main__":
    # python tools/cut_sheet_enemies.py [name,name...]  (all enemies when omitted)
    main(set(sys.argv[1].split(",")) if len(sys.argv) > 1 else None)
