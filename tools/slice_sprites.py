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
OC = "enemies/octopus3/image_%s.png"
SL = "enemies/slime/%s/image_%s.png"
TP = "enemies/tentacle plant/%s/image_%s.png"
OW = "enemies/octo-wizard/%s/image_%s.png"
U2 = "enemies/ufo2/image_%s.png"
U3 = "enemies/ufo3/%s/image_%s.png"
JP = "enemies/jelly pod/%s/image_%s.png"
SM = "enemies/spike mine/%s/image_%s.png"
W4 = "enemies/%s/%s/image_%02d.png"  # cut by tools/cut_sheet_enemies.py
TA = "enemies/toxic_angler/%s/image_%02d.png"
DB = "enemies/drillback/%s/image_%02d.png"
B3 = "enemies/bosses/boss_3_elements/image_%s.png"
B4 = "enemies/bosses/boss_4_elements/image_%s.png"

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
    # Future worlds: Orbit Warden boss / Orbit Raider horde variant share the art.
    "orbit_warden": {
        "anchor": "feet",
        "anims": {
            "walk": (["enemies/orbit_warden/idle/image_%02d.png" % i for i in (1, 2, 3, 4, 2)], 5, True),
            "fury": (["enemies/orbit_warden/idle/image_%02d.png" % i for i in (5, 6, 7)], 7, True),
            "hurt": (["enemies/orbit_warden/idle/image_08.png"], 1, False),
            "charge": (["enemies/orbit_warden/cast/image_01.png"], 1, True),
            "fire": (["enemies/orbit_warden/cast/image_%02d.png" % i for i in (2, 3, 4)], 8, True),
            "summon": (["enemies/orbit_warden/summon/image_%02d.png" % i for i in (1, 2, 3, 4)], 5, False),
            "splat": (["enemies/orbit_warden/idle/image_09.png"] + ["enemies/orbit_warden/die/image_%02d.png" % i for i in range(1, 8)], 7, False),
        },
        "body": "walk",
    },
    "orbit_spawn": {"anchor": "feet", "anims": {
        "walk": (["enemies/orbit_warden/minion/image_01.png"], 1, True),
    }, "body": "walk"},
    "orbit_plasma": {"anchor": "center", "anims": {"fly": (
        ["enemies/orbit_warden/orb/image_%02d.png" % i for i in (1, 2)], 7, True)}, "body": "fly"},
    "orbit_burst": {"anchor": "center", "anims": {"pop": (
        ["enemies/orbit_warden/burst/image_01.png"], 1, False)}, "body": "pop"},
    "orbit_beam": {"anchor": "bottom", "anims": {"pop": (
        ["enemies/orbit_warden/beam/image_%02d.png" % i for i in (1, 2, 1)], 8, False)}, "body": "pop"},
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
    # Eyeclops (loose frames in assets/sprites/enemies/octopus3, enemies/eyeclops.gd):
    # floating one-eyed octopus (walk), front view with its core glowing (charge), the
    # caterpillar crawl of the lunge / wounded form (crawl) and the melt into a puddle
    # (splat, played by the decal it leaves). orb.png = the bubble cut out of 008.
    "eyeclops": {
        "anchor": "bbox",
        "anims": {
            "walk": ([OC % i for i in ("008", "009", "010", "011", "014", "016")], 8, True),
            "charge": ([OC % i for i in ("053", "054", "055", "056", "057", "058")], 12, True),
            "crawl": ([OC % i for i in ("024", "025", "026", "027", "028", "029")], 12, True),
            "splat": ([OC % i for i in ("031", "040", "042", "043", "045", "049")], 9, False),
        },
        "body": "walk",
    },
    "eyeclops_orb": {"anchor": "center",
                     "anims": {"fly": (["enemies/octopus3/orb.png"], 1, True)}, "body": "fly"},
    # Slime Splitter (loose frames in assets/sprites/enemies/slime/{idle,attack,die},
    # enemies/splitter.gd): wobbling orange goo with eyes (walk), pulls back (wind) and
    # stretches an arm to fling a slimelet (fling), melts into a puddle (splat). The
    # small one-eyed slimes it throws and bursts into are the "splitlet" set.
    "splitter": {
        "anchor": "bbox",
        "anims": {
            "walk": ([SL % ("idle", i) for i in ("080", "083", "084", "085", "086")], 6, True),
            "wind": ([SL % ("attack", "090")], 1, False),
            "fling": ([SL % ("attack", "091")], 1, False),
            "splat": ([SL % ("die", i) for i in ("123", "130", "131", "140")], 9, False),
        },
        "body": "walk",
    },
    "splitlet": {
        "anchor": "bbox",
        "anims": {
            "walk": ([SL % ("attack", i) for i in ("095", "098", "108", "111", "114")], 8, True),
            "splat": ([(SL % ("die", "131"), 0, 999, 0.45)], 1, False),
        },
        "body": "walk",
    },
    # Tentacle Plant (loose frames in assets/sprites/enemies/tentacle plant/{idle,attack,
    # die}, enemies/tentacle_plant.gd): creeps on its tentacles (walk = idle), opens its
    # toothy maw (open), melts into a puddle (splat). attack/068 (maw + tongue) is not
    # used: the tongue is drawn in code (combat/plant_tongue.gd) with the glob (074,
    # "plant_glob") as its tip and as the spit projectile.
    "tentacle_plant": {
        "anchor": "bbox",
        "anims": {
            "walk": ([TP % ("idle", i) for i in ("056", "057", "058", "059", "065")], 6, True),
            "open": ([TP % ("attack", i) for i in ("066", "067")], 4, False),
            "splat": ([TP % ("die", i) for i in ("089", "090", "091", "102")], 8, False),
        },
        "body": "walk",
    },
    "plant_glob": {"anchor": "center", "anims": {"fly": ([TP % ("attack", "074")], 1, True)}, "body": "fly"},
    # Octo-Wizard (loose frames in assets/sprites/enemies/octo-wizard/{idle,attack,die},
    # enemies/octo_wizard.gd): hooded one-eyed octopus mage that floats (walk), holds a
    # glowing orb (orb), raises a hand for a rune (rune), spreads its arms as it blinks
    # (blink) and melts into a puddle (splat). attack/019 holds two poses side by side
    # (arms out | holding the orb): cut by columns. 029/034 = the orb it throws.
    "octo_wizard": {
        "anchor": "bbox",
        "anims": {
            "walk": ([OW % ("idle", i) for i in ("001", "002", "003", "004", "005")], 6, True),
            "blink": ([(OW % ("attack", "019"), 0, 167)], 1, False),
            "orb": ([(OW % ("attack", "019"), 167, 308)], 1, False),
            "rune": ([OW % ("attack", "022")], 1, False),
            "splat": ([OW % ("die", i) for i in ("036", "045", "055", "057", "060")], 8, False),
        },
        "body": "walk",
    },
    "wizard_orb": {"anchor": "center",
                   "anims": {"fly": ([OW % ("attack", "029"), OW % ("attack", "034")], 10, True)}, "body": "fly"},
    # UFO GUNSHIP, world 4 (loose frames in assets/sprites/enemies/ufo2, enemies/ufo_gunship.gd):
    # a big purple saucer with a side cannon. walk = hover with blinking lights, charge =
    # the cannon glowing, fire = the shot leaving the barrel, boost = tilted with its jets
    # blazing (the ram), splat = blows up and leaves a wreck.
    "gunship": {
        "anchor": "bbox",
        "anims": {
            "walk": ([U2 % i for i in ("002", "004", "002", "008")], 6, True),
            "charge": ([U2 % i for i in ("005",)], 1, False),
            "fire": ([U2 % i for i in ("006", "007")], 10, False),
            "boost": ([U2 % i for i in ("011",)], 1, False),
            "splat": ([U2 % i for i in ("010", "014")], 5, False),
        },
        "body": "walk",
    },
    "gunship_shot": {"anchor": "center", "anims": {"fly": ([U2 % "015"], 1, True)}, "body": "fly"},
    # UFO SCOUT, world 4 (loose frames in assets/sprites/enemies/ufo3/{idle,attack,die},
    # enemies/ufo_scout.gd): a small pink saucer that circles you and spits comets.
    # attack = its lights flaring, splat = cracks open and crashes.
    "scout": {
        "anchor": "bbox",
        "anims": {
            "walk": ([U3 % ("idle", i) for i in ("010", "011", "012", "016", "017")], 9, True),
            "attack": ([U3 % ("attack", i) for i in ("024", "025")], 10, True),
            "splat": ([U3 % ("die", i) for i in ("044", "045", "046", "041")], 7, False),
        },
        "body": "walk",
    },
    "scout_shot": {"anchor": "center", "anims": {"fly": ([U3 % ("attack", i) for i in ("035", "036")], 12, True)}, "body": "fly"},
    "scout_comet": {"anchor": "center", "anims": {"fly": ([U3 % ("attack", "028")], 1, True)}, "body": "fly"},
    # JELLY POD, world 4 (loose frames in assets/sprites/enemies/jelly pod/{idle,attack,die},
    # enemies/jelly_pod.gd): a jellyfish in a saucer. walk = drifting with swaying
    # tentacles, attack = tentacles glowing (spores / sting), splat = the dome cracks and
    # it melts into a magenta puddle.
    "jelly_pod": {
        "anchor": "bbox",
        "anims": {
            "walk": ([JP % ("idle", i) for i in ("077", "078", "079", "080", "081")], 7, True),
            "attack": ([JP % ("attack", i) for i in ("087", "088", "089")], 10, True),
            "splat": ([JP % ("die", i) for i in ("117", "118", "120", "132", "133")], 8, False),
        },
        "body": "walk",
    },
    # SPIKE MINE, world 4 (loose frames in assets/sprites/enemies/spike mine/, enemies/spike_mine.gd):
    # a spiked floating mine with a red eye. walk = the eye (it rolls in code), charge =
    # the eye flaring while it arms, splat = cracks, burns and bursts into scrap.
    "spike_mine": {
        "anchor": "bbox",
        "anims": {
            "walk": ([SM % ("edle and attack", "020")], 1, True),
            "charge": ([SM % ("die", "043"), SM % ("edle and attack", "020")], 10, True),
            "splat": ([SM % ("die", i) for i in ("040", "042", "050", "055")], 10, False),
        },
        "body": "walk",
    },
    "mine_shot": {"anchor": "center", "anims": {"fly": ([SM % ("edle and attack", i) for i in ("032", "033")], 10, True)}, "body": "fly"},
    # world 4 sheet enemies (tools/enemies_w4_ref.webp -> tools/cut_sheet_enemies.py):
    # idle / attack poses / "death" = the die row, played once as an effect (it ends in an
    # explosion, so it is not a lasting splat). The attack row's projectile frames are
    # their shots.
    "comet_hopper": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("comet_hopper", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("comet_hopper", "attack", i) for i in (1, 2, 3)], 8, False),
            "death": ([W4 % ("comet_hopper", "die", i) for i in (1, 2, 3, 4, 5)], 10, False),
        },
        "body": "walk",
    },
    "hopper_comet": {"anchor": "center", "anims": {"fly": ([W4 % ("comet_hopper", "attack", 4)], 1, True)}, "body": "fly"},
    "ring_bug": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("ring_bug", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("ring_bug", "attack", i) for i in (1, 2)], 6, False),
            "death": ([W4 % ("ring_bug", "die", i) for i in (1, 2, 3, 4, 5)], 10, False),
        },
        "body": "walk",
    },
    "ring_bug_ring": {"anchor": "center", "anims": {"fly": ([W4 % ("ring_bug", "attack", i) for i in (4, 3)], 10, True)}, "body": "fly"},
    "drill_orbiter": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("drill_orbiter", "idle", i) for i in (1, 2, 3, 4, 5)], 10, True),
            "attack": ([W4 % ("drill_orbiter", "attack", i) for i in (1, 2)], 10, True),
            "fire": ([W4 % ("drill_orbiter", "attack", 3)], 1, False),
            "death": ([W4 % ("drill_orbiter", "die", i) for i in (1, 2, 3, 4, 5)], 10, False),
        },
        "body": "walk",
    },
    "drill_cone": {"anchor": "center", "anims": {"fly": ([W4 % ("drill_orbiter", "attack", i) for i in (4, 5)], 12, True)}, "body": "fly"},
    "nova_puffer": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("nova_puffer", "idle", i) for i in (1, 2, 3, 4, 5)], 7, True),
            "attack": ([W4 % ("nova_puffer", "attack", i) for i in (1, 2)], 6, True),
            "death": ([W4 % ("nova_puffer", "die", i) for i in (1, 2, 3, 4)], 8, False),
        },
        "body": "walk",
    },
    "nova_bubble": {"anchor": "center", "anims": {"fly": ([W4 % ("nova_puffer", "attack", i) for i in (3, 4)], 6, True)}, "body": "fly"},
    # world 4 drones (tools/drones_w4_ref.webp -> tools/cut_sheet_enemies.py); "death" =
    # the die row, played once as an effect.
    "blade_drone": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("blade_drone", "idle", i) for i in (1, 2, 3, 4, 5)], 12, True),
            "attack": ([W4 % ("blade_drone", "attack", i) for i in (1, 2)], 10, True),
            "death": ([W4 % ("blade_drone", "die", i) for i in (1, 2, 3, 4, 5)], 10, False),
        },
        "body": "walk",
    },
    "blade_crescent": {"anchor": "center", "anims": {"fly": ([W4 % ("blade_drone", "attack", i) for i in (3, 4)], 12, True)}, "body": "fly"},
    "tesla_drone": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("tesla_drone", "idle", i) for i in (1, 2, 3, 4, 5)], 9, True),
            "attack": ([W4 % ("tesla_drone", "attack", i) for i in (1, 2, 3)], 10, True),
            "death": ([W4 % ("tesla_drone", "die", i) for i in (1, 2, 3, 4)], 9, False),
        },
        "body": "walk",
    },
    "tesla_orb": {"anchor": "center", "anims": {"fly": ([W4 % ("tesla_drone", "attack", 5)], 1, True)}, "body": "fly"},
    "crab_drone": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("crab_drone", "idle", i) for i in (1, 2, 3, 4, 5)], 9, True),
            "attack": ([W4 % ("crab_drone", "attack", i) for i in (1, 2, 3)], 8, False),
            "death": ([W4 % ("crab_drone", "die", i) for i in (1, 2, 3, 4)], 8, False),
        },
        "body": "walk",
    },
    "crab_rocket": {"anchor": "center", "anims": {"fly": ([W4 % ("crab_drone", "rocket", 2)], 1, True)}, "body": "fly"},
    "prism_drone": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("prism_drone", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("prism_drone", "attack", i) for i in (1, 2)], 10, True),
            "fire": ([W4 % ("prism_drone", "attack", 3)], 1, False),
            "death": ([W4 % ("prism_drone", "die", i) for i in (1, 2, 3, 4)], 9, False),
        },
        "body": "walk",
    },
    "prism_beam": {"anchor": "center", "anims": {"fly": ([W4 % ("prism_drone", "attack", 4)], 1, True)}, "body": "fly"},
    # world 4, second sheet (tools/enemies_w4b_ref.webp -> cut_sheet_enemies.py). The
    # peeper blows up ("death", played once); the others melt into a puddle ("splat", stays).
    "meteor_peeper": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("meteor_peeper", "idle", i) for i in (1, 2, 3, 4, 3, 2)], 7, True),
            "attack": ([W4 % ("meteor_peeper", "attack", i) for i in (1, 2, 3)], 8, False),
            "death": ([W4 % ("meteor_peeper", "die", i) for i in (1, 2, 3, 4)], 8, False),
        },
        "body": "walk",
    },
    "bubble_brain": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("bubble_brain", "idle", i) for i in (1, 2, 3, 4)], 7, True),
            "attack": ([W4 % ("bubble_brain", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("bubble_brain", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "bell_cruiser": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("bell_cruiser", "idle", i) for i in (1, 2, 3, 4, 3, 2)], 6, True),
            "attack": ([W4 % ("bell_cruiser", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("bell_cruiser", "die", i) for i in (1, 2, 3, 4)], 8, False),
        },
        "body": "walk",
    },
    "goo_hopper": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("goo_hopper", "idle", i) for i in (1, 2, 3, 4)], 7, True),
            "attack": ([W4 % ("goo_hopper", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("goo_hopper", "die", i) for i in (1, 2, 3, 4)], 8, False),
        },
        "body": "walk",
    },
    "peeper_meteor": {"anchor": "center", "anims": {"fly": ([W4 % ("meteor_peeper", "shot", 1)], 1, True)}, "body": "fly"},
    "peeper_rock": {"anchor": "center", "anims": {"fly": ([W4 % ("meteor_peeper", "shot", 2)], 1, True)}, "body": "fly"},
    "brain_bubble": {"anchor": "center", "anims": {"fly": ([W4 % ("bubble_brain", "shot", 1)], 1, True)}, "body": "fly"},
    "bell_bubble": {"anchor": "center", "anims": {"fly": ([W4 % ("bell_cruiser", "shot", 1)], 1, True)}, "body": "fly"},
    # world 4, third sheet (tools/enemies_w4c_ref.webp -> cut_sheet_enemies.py)
    "nebula_pod": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("nebula_pod", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("nebula_pod", "attack", i) for i in (1, 2, 3)], 8, False),
            "death": ([W4 % ("nebula_pod", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "ring_eye": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("ring_eye", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("ring_eye", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("ring_eye", "die", i) for i in (1, 2, 3, 4)], 8, False),
        },
        "body": "walk",
    },
    "puddle_radar": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("puddle_radar", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("puddle_radar", "attack", i) for i in (1, 2, 3)], 8, False),
            "splat": ([W4 % ("puddle_radar", "die", i) for i in (1, 2, 3, 4)], 8, False),
        },
        "body": "walk",
    },
    "comet_baby": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("comet_baby", "idle", i) for i in (1, 2, 3, 4, 5)], 10, True),
            "attack": ([W4 % ("comet_baby", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("comet_baby", "die", i) for i in (1, 2, 3, 4)], 8, False),
        },
        "body": "walk",
    },
    "nebula_orb": {"anchor": "center", "anims": {"fly": ([W4 % ("nebula_pod", "shot", 1)], 1, True)}, "body": "fly"},
    "ring_eye_orb": {"anchor": "center", "anims": {"fly": ([W4 % ("ring_eye", "shot", 1)], 1, True)}, "body": "fly"},
    "radar_bubble": {"anchor": "center", "anims": {"fly": ([W4 % ("puddle_radar", "shot", 1)], 1, True)}, "body": "fly"},
    "baby_glob": {"anchor": "center", "anims": {"fly": ([W4 % ("comet_baby", "shot", 1)], 1, True)}, "body": "fly"},
    # world 4, fourth sheet (tools/enemies_w4d_ref.webp -> cut_sheet_enemies.py); all melt ("splat")
    "tadpole_saucer": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("tadpole_saucer", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("tadpole_saucer", "attack", i) for i in (1, 2, 3)], 8, False),
            "splat": ([W4 % ("tadpole_saucer", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "plasma_pupil": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("plasma_pupil", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("plasma_pupil", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("plasma_pupil", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "tentacle_pod": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("tentacle_pod", "idle", i) for i in (1, 2, 3, 4, 5)], 7, True),
            "attack": ([W4 % ("tentacle_pod", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("tentacle_pod", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "pearl_flyer": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("pearl_flyer", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("pearl_flyer", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("pearl_flyer", "die", i) for i in (1, 2, 3, 4)], 8, False),
        },
        "body": "walk",
    },
    "tadpole_bubble": {"anchor": "center", "anims": {"fly": ([W4 % ("tadpole_saucer", "shot", 1)], 1, True)}, "body": "fly"},
    "pupil_plasma": {"anchor": "center", "anims": {"fly": ([W4 % ("plasma_pupil", "shot", 1)], 1, True)}, "body": "fly"},
    "pod_bubble": {"anchor": "center", "anims": {"fly": ([W4 % ("tentacle_pod", "shot", 1)], 1, True)}, "body": "fly"},
    "slime_pearl": {"anchor": "center", "anims": {"fly": ([W4 % ("pearl_flyer", "shot", 1)], 1, True)}, "body": "fly"},
    # world 4, fifth sheet (tools/enemies_w4e_ref.webp -> cut_sheet_enemies.py)
    "martian_scout": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("martian_scout", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("martian_scout", "attack", i) for i in (1, 2, 3)], 8, False),
            "death": ([W4 % ("martian_scout", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "cyclops_pod": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("cyclops_pod", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("cyclops_pod", "attack", i) for i in (1, 2)], 8, False),
            "death": ([W4 % ("cyclops_pod", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "tentacle_orbiter": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("tentacle_orbiter", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("tentacle_orbiter", "attack", i) for i in (1, 2, 3)], 8, False),
            "splat": ([W4 % ("tentacle_orbiter", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "slime_comet": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("slime_comet", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("slime_comet", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("slime_comet", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "martian_orb": {"anchor": "center", "anims": {"fly": ([W4 % ("martian_scout", "shot", 1)], 1, True)}, "body": "fly"},
    "cyclops_orb": {"anchor": "center", "anims": {"fly": ([W4 % ("cyclops_pod", "shot", 1)], 1, True)}, "body": "fly"},
    "orbiter_orb": {"anchor": "center", "anims": {"fly": ([W4 % ("tentacle_orbiter", "shot", 1)], 1, True)}, "body": "fly"},
    "comet_slime": {"anchor": "center", "anims": {"fly": ([W4 % ("slime_comet", "shot", 1)], 1, True)}, "body": "fly"},
    # world 4, sixth sheet (tools/enemies_w4f_ref.webp -> cut_sheet_enemies.py)
    "blink_saucer": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("blink_saucer", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("blink_saucer", "attack", i) for i in (1, 2, 3)], 8, False),
            "death": ([W4 % ("blink_saucer", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "bean_cruiser": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("bean_cruiser", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("bean_cruiser", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("bean_cruiser", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "nugget_ship": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("nugget_ship", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("nugget_ship", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("nugget_ship", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "goo_lantern": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("goo_lantern", "idle", i) for i in (1, 2, 3, 4, 5)], 8, True),
            "attack": ([W4 % ("goo_lantern", "attack", i) for i in (1, 2)], 8, False),
            "splat": ([W4 % ("goo_lantern", "die", i) for i in (1, 2, 3, 4, 5)], 8, False),
        },
        "body": "walk",
    },
    "blink_bubble": {"anchor": "center", "anims": {"fly": ([W4 % ("blink_saucer", "shot", 1)], 1, True)}, "body": "fly"},
    "nugget_orb": {"anchor": "center", "anims": {"fly": ([W4 % ("nugget_ship", "shot", 1)], 1, True)}, "body": "fly"},
    "lantern_bubble": {"anchor": "center", "anims": {"fly": ([W4 % ("goo_lantern", "shot", 1)], 1, True)}, "body": "fly"},
    # MAGMA DRAKE boss (tools/boss_magma_ref.webp -> cut_sheet_enemies.py magma_drake;
    # enemies/boss_magma.gd): idle 01-05 = calm, 06 = blazing (fury), 07 = hurt wince,
    # 08 = dizzy stars; breath / cast / summon poses; death = collapses into a lava pool.
    "magma_drake": {
        "anchor": "bbox",
        "anims": {
            "walk": ([W4 % ("magma_drake", "idle", i) for i in (1, 2, 3, 1, 5, 4)], 5, True),
            "fury": ([W4 % ("magma_drake", "idle", i) for i in (6, 5)], 8, True),
            "hurt": ([W4 % ("magma_drake", "idle", 7)], 1, False),
            "stun": ([W4 % ("magma_drake", "idle", 8)], 1, True),
            "breath": ([W4 % ("magma_drake", "breath", 1)], 1, True),
            "cast": ([W4 % ("magma_drake", "cast", 1)], 1, True),
            "summon": ([W4 % ("magma_drake", "summon", 1)], 1, True),
            "death": ([W4 % ("magma_drake", "die", i) for i in (1, 2, 3, 4, 5, 6, 7, 8)], 6, False),
        },
        "body": "walk",
    },
    "magma_fire": {"anchor": "center", "anims": {"fly": ([W4 % ("magma_drake", "fireball", 1)], 1, True)}, "body": "fly"},
    "magma_meteor": {"anchor": "center", "anims": {"fly": ([W4 % ("magma_drake", "meteor", 1)], 1, True)}, "body": "fly"},
    "magma_crescent": {"anchor": "center", "anims": {"fly": ([W4 % ("magma_drake", "crescent", 1)], 1, True)}, "body": "fly"},
    "magma_ring": {"anchor": "center", "anims": {"pop": ([W4 % ("magma_drake", "ring", 1)], 1, False)}, "body": "pop"},
    "magma_ring_small": {"anchor": "center", "anims": {"pop": ([W4 % ("magma_drake", "ring_small", 1)], 1, False)}, "body": "pop"},
    "magma_mine": {"anchor": "center", "anims": {"fly": ([W4 % ("magma_drake", "mine", 1)], 1, True)}, "body": "fly"},
    "magma_erupt": {"anchor": "center", "anims": {"pop": ([W4 % ("magma_drake", "erupt", 1)], 1, False)}, "body": "pop"},
    # TOXIC ANGLER mini boss (tools/boss_puffer_ref.webp -> cut_sheet_enemies.py toxic_angler;
    # enemies/boss_angler.gd): a toxic lantern pufferfish. idle 1-4 = calm looks, 5-6 = angry,
    # 7 = bloated with an aura (fury), 8 = dizzy, 9 = hurt; attack 1 = bubble in the mouth,
    # 2-3 = spitting; charge = belly glowing; summon = channelling spore mines; wink = the
    # lure's "come here"; dive = sinks in its own rings; ripple = the surface of the goo
    # while it swims below; die = deflates and melts into a puddle of spines.
    "toxic_angler": {
        "anchor": "bbox",
        "anims": {
            "walk": ([TA % ("idle", i) for i in (1, 2, 4, 1, 3, 2)], 5, True),
            "angry": ([TA % ("idle", i) for i in (5, 6)], 6, True),
            "fury": ([TA % ("idle", i) for i in (7, 6)], 8, True),
            "hurt": ([TA % ("idle", 9)], 1, False),
            "stun": ([TA % ("idle", 8)], 1, True),
            "inflate": ([TA % ("attack", 1)], 1, True),
            "spit": ([TA % ("attack", i) for i in (2, 3)], 8, True),
            "charge": ([TA % ("charge", 1)], 1, True),
            "wind": ([TA % ("summon", 1)], 1, True),
            "channel": ([TA % ("summon", i) for i in (2, 3, 4, 3)], 7, True),
            "wink": ([TA % ("wink", 1)], 1, True),
            "sink": ([TA % ("dive", i) for i in (1, 2, 3)], 8, False),
            "ripple": ([TA % ("ripple", 1), TA % ("ripple", 2), TA % ("ripple2", 1), TA % ("ripple", 2)], 8, True),
            "death": ([TA % ("die", i) for i in (1, 2, 3, 4)] + [TA % ("die2", i) for i in (1, 2, 3, 4, 5, 6)], 6, False),
        },
        "body": "walk",
    },
    "angler_bubble": {"anchor": "center", "anims": {"fly": ([TA % ("bubble", 2), TA % ("bubble", 3), TA % ("bubble2", 1)], 3, False)}, "body": "fly"},
    "angler_drop": {"anchor": "center", "anims": {"fly": ([TA % ("bubble", 1), TA % ("bubble", 2)], 6, True)}, "body": "fly"},
    "angler_pop": {"anchor": "center", "anims": {"pop": ([TA % ("bubble2", 2)], 1, False)}, "body": "pop"},
    "angler_mine": {
        "anchor": "center",
        "anims": {
            "fly": ([TA % ("mine", 1)], 1, True),
            "arm": ([TA % ("mine", i) for i in (2, 3, 4, 5)], 4, False),
        },
        "body": "fly",
    },
    "angler_boom": {"anchor": "center", "anims": {"pop": ([TA % ("mine", 6)], 1, False)}, "body": "pop"},
    "angler_geyser": {"anchor": "bottom", "anims": {"pop": ([TA % ("ripple", 3), TA % ("ripple2", 1)], 8, False)}, "body": "pop"},
    "angler_ring": {"anchor": "center", "anims": {"pop": ([TA % ("ripple", 2)], 1, False)}, "body": "pop"},
    # DRILLBACK mini boss (tools/boss_drill_ref.webp -> cut_sheet_enemies.py drillback;
    # enemies/boss_drillback.gd): a rocky armadillo with a drill nose. idle 1-2 calm, 4-5
    # angry, 7 tongue out (winded), 8 dizzy, 9 hurt; attack 1 = crouch, 2-4 = drill spinning
    # up; dash_a-d = the bore (body only, the trail is drawn in code); dive = sinks into a
    # ring of dirt; spike 1-2 = the mound it tunnels under; rear = stands up to throw;
    # die = collapses into a heap of rocks.
    "drillback": {
        "anchor": "bbox",
        "anims": {
            "walk": ([DB % ("idle", i) for i in (1, 2)], 3, True),
            "angry": ([DB % ("idle", i) for i in (4, 5)], 4, True),
            "hurt": ([DB % ("idle", 9)], 1, False),
            "stun": ([DB % ("idle", 8)], 1, True),
            "gasp": ([DB % ("idle", 7)], 1, True),
            "crouch": ([DB % ("attack", 1)], 1, True),
            "spin": ([DB % ("attack", i) for i in (2, 3, 4)], 14, True),
            "dash": ([DB % (r, 1) for r in ("dash_a", "dash_b", "dash_c", "dash_d")], 14, True),
            "sink": ([DB % ("dive", i) for i in (1, 2, 3, 4)], 8, False),
            "mound": ([DB % ("spike", 2), DB % ("spike", 1)], 8, True),
            "rear": ([DB % ("rear", 1)], 1, True),
            "death": ([DB % ("die", i) for i in range(1, 10)], 6, False),
        },
        "body": "walk",
    },
    "drill_rock": {"anchor": "center", "anims": {"fly": ([DB % ("rock", 1)], 1, True)}, "body": "fly"},
    "drill_seed": {
        "anchor": "bottom",
        "anims": {
            "arm": ([DB % ("seed", i) for i in (6, 5, 4, 3, 2, 1)], 5, False),
            "fly": ([DB % ("seed", 6)], 1, True),
        },
        "body": "fly",
    },
    "drill_boom": {"anchor": "bottom", "anims": {"pop": ([DB % ("seed", i) for i in (7, 8, 9)], 10, False)}, "body": "pop"},
    "drill_spike": {"anchor": "bottom", "anims": {"pop": ([DB % ("spike", i) for i in (1, 2, 3, 4)], 12, False)}, "body": "pop"},
    "jelly_spore": {"anchor": "center", "anims": {"fly": ([JP % ("attack", i) for i in ("093", "098")], 6, True)}, "body": "fly"},
    # VOID ARCHMAGE, world 3 final boss (loose frames in assets/sprites/enemies/bosses/
    # boss_3_elements, cut from the sheet; enemies/boss_archmage.gd): a hooded one-eyed
    # octopus mage. walk = idle + blinking, charge = glowing eye, fury = slit eye and aura,
    # cast -> fire = the eye beam windup (024 is cut before the beam: drawn in code),
    # moons = crescent blades circling him, summon = halo + raised hands, stun = X eyes
    # (dizzy: takes more damage), death = slumps and melts into a puddle.
    "archmage": {
        "anchor": "feet",
        "anims": {
            "walk": ([B3 % i for i in ("001", "006", "008", "009", "021", "003", "005", "003")], 5, True),
            "charge": ([B3 % i for i in ("004", "131")], 8, True),
            "fury": ([B3 % i for i in ("002", "004")], 6, True),
            "cast": ([B3 % i for i in ("022", "023", "025")], 9, False),
            "fire": ([(B3 % "024", 0, 175)], 1, False),
            "moons": ([B3 % i for i in ("050", "049", "046")], 9, True),
            "summon": ([B3 % i for i in ("077", "078")], 6, True),
            "stun": ([B3 % "079"], 1, True),
            "death": ([B3 % i for i in ("131", "133", "132", "134", "136", "147", "156", "157", "159", "162")], 6, False),
        },
        "body": "walk",
    },
    # the boss curled into a spiky eye with crescents: whirls and rushes (rotated in code)
    "arch_whirl": {"anchor": "center", "anims": {"spin": ([B3 % "048"], 1, True)}, "body": "spin"},
    "arch_orb": {"anchor": "center", "anims": {"fly": ([B3 % i for i in ("036", "033")], 8, True)}, "body": "fly"},
    "arch_bigorb": {"anchor": "center", "anims": {"fly": ([B3 % i for i in ("029", "027")], 8, True)}, "body": "fly"},
    "arch_blade": {"anchor": "center", "anims": {"fly": ([B3 % i for i in ("059", "061", "062")], 14, True)}, "body": "fly"},
    "arch_ring": {"anchor": "center", "anims": {"pop": ([B3 % "056"], 1, False)}, "body": "pop"},
    "arch_boom": {"anchor": "center", "anims": {"pop": ([B3 % i for i in ("081", "099")], 14, False)}, "body": "pop"},
    # COMMANDER ZORP, world 4 final boss (loose frames in assets/sprites/enemies/bosses/
    # boss_4_elements; enemies/boss_zorp.gd): a cyan alien in a big saucer. walk = idle and
    # winking, angry, charge = an orb growing in the dome, fire = side cannon, fury =
    # electric antennas, stun = dizzy stars, spin = whirling with rings, warp = flattened
    # into its teleport ring, summon = with a drone, splat = cracks, weeps and crashes
    # into a smoking wreck (stays on the floor).
    "zorp": {
        "anchor": "bbox",
        "anims": {
            "walk": ([B4 % i for i in ("005", "006", "005", "007", "005", "008", "011")], 5, True),
            "angry": ([B4 % i for i in ("004", "037", "040", "054")], 6, True),
            "charge": ([B4 % i for i in ("012", "013")], 6, True),
            "fire": ([B4 % "010"], 1, False),
            "fury": ([B4 % i for i in ("001", "002")], 8, True),
            "stun": ([B4 % "003"], 1, True),
            "spin": ([B4 % i for i in ("055", "056", "059")], 14, True),
            "warp": ([B4 % "057"], 1, False),
            "summon": ([B4 % "030"], 1, False),
            "splat": ([B4 % i for i in ("090", "092", "094", "093", "089", "096")], 5, False),
        },
        "body": "walk",
    },
    "zorp_orb": {"anchor": "center", "anims": {"fly": ([B4 % i for i in ("022", "024")], 10, True)}, "body": "fly"},
    "zorp_big": {"anchor": "center", "anims": {"fly": ([B4 % i for i in ("016", "019")], 8, True)}, "body": "fly"},
    "zorp_bolt": {"anchor": "center", "anims": {"fly": ([B4 % i for i in ("015", "017", "018", "023")], 12, True)}, "body": "fly"},
    "zorp_blade": {"anchor": "center", "anims": {"fly": ([B4 % i for i in ("032", "034")], 10, True)}, "body": "fly"},
    "zorp_warp": {"anchor": "center", "anims": {"pop": ([B4 % i for i in ("064", "061", "064")], 6, False)}, "body": "pop"},
    "zorp_pop": {"anchor": "center", "anims": {"pop": ([B4 % i for i in ("038", "041")], 12, False)}, "body": "pop"},
    # the drones Zorp launches (enemies/zorp_drone.gd): orbit, then dash at you and burst
    "zorp_drone": {
        "anchor": "bbox",
        "anims": {
            "walk": ([B4 % i for i in ("028", "029", "031", "033")], 8, True),
            "dash": ([B4 % i for i in ("044", "046", "049")], 12, True),
        },
        "body": "walk",
    },
    # the eyes it summons: float to you and burst (enemies/arcane_eye.gd)
    "arcane_eye": {
        "anchor": "bbox",
        "anims": {"walk": ([B3 % i for i in ("088", "090", "092", "090")], 6, True)},
        "body": "walk",
    },
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
