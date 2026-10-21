"""World 8 BIODOME kit for the Arena Editor (its map is a scene edited by hand).

Cuts the user's BIODOME sheets into stand-alone pictures for the palette (OBJECTS >
Biodome > ...):

  tools/w8_walls_ref.webp  greenhouse walls: 5 straight runs, 5 columns, 2 crosses, 3 L
  tools/w8_props_ref.webp  66 props: tanks, planters, plants, consoles, storage, pipes...

  assets/decor/biodome/
    walls/wall_<n>.png       a straight wall between two nodes, a post at each end (the
                             middle resized so every run is as long: they swap freely)
    walls/column_<n>.png     a wall going down the map: top of the far post to the base
                             of the near one
    junctions/*.png          crosses and L corners (placed by hand)
    tanks/ planters/ plants/ machines/ storage/ pipes/ furniture/ floor/   the props
    kit.json                 palette defaults: width, solid footprint, see-through...
    README.txt               how to add more pictures
  assets/arena/terrain/biodome_floor.png  floor tiles as a 64 px terrain atlas
                                          (terrain.json source "Biodome floor")

The wall pictures set the lattice the arena is built on (tools/build_biodome_arena.gd):
CW x CH world units between wall nodes. Entries of kit.json for pictures this script
does not make (added by hand or with the dock) are kept.

  python tools/make_biodome_kit.py
"""
import os

from kit_cut import Kit, cut, floor_atlas, owner, piece_at, pieces, stretch_run

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
SRC = os.path.join(ROOT, "assets", "rooms", "w8", "build")  # the floor tiles
FLOOR_ID = 14

# --- walls (tools/w8_walls_ref.webp) ----------------------------------------------------
CW = 96.0  # between two wall nodes, across (3 terrain tiles): the art's own size
CH = 64.0  # one column module down the map (2 terrain tiles); the arena stacks two a cell
POST = 40  # px: the post at each end of a straight run
RUN_W = 324  # px every straight run is brought to (posts kept, the middle resized)
WALL_K = CW / (RUN_W - POST)  # world units per wall px: post centres land on the nodes
# straight runs, columns, junctions: (left, top, right, bottom) in the sheet
RUNS = [(45, 65, 371, 218), (398, 65, 726, 218), (758, 65, 1061, 219), (1092, 65, 1395, 219), (1425, 63, 1705, 221)]
COLUMNS = [(90, 273, 162, 613), (257, 273, 329, 613), (430, 273, 503, 613), (609, 273, 682, 613), (792, 273, 912, 614)]
JUNCTIONS = {"cross": (973, 273, 1280, 614), "cross_box": (1309, 273, 1664, 614),
             "corner_top_right": (1731, 14, 1966, 249), "corner_top_right_b": (1730, 271, 1966, 505),
             "corner_bottom_left": (1727, 432, 1966, 641)}

# --- props (tools/w8_props_ref.webp) -----------------------------------------------------
PROP_K = 0.3  # world units per prop px
# name: (category, top-left in the sheet). Category "floor" = flat on the floor, no solid.
PROPS = {
    "tank_big": ("tanks", (14, 3)), "tank_tube": ("tanks", (221, 28)), "dome": ("tanks", (303, 11)),
    "planter_flowers": ("planters", (553, 26)), "planter_corner_palm": ("planters", (684, 11)),
    "planter_wide": ("planters", (821, 45)), "planter_low": ("planters", (553, 147)),
    "planter_small": ("planters", (16, 253)), "planter_rail": ("planters", (359, 457)),
    "planter_long": ("planters", (565, 482)),
    "pot_purple": ("plants", (942, 19)), "pot_palm": ("plants", (1027, 19)), "pot_tall": ("plants", (856, 175)),
    "pot_pink": ("plants", (938, 152)), "pot_bush": ("plants", (1029, 151)), "pot_fern": ("plants", (859, 280)),
    "pot_blossom": ("plants", (953, 270)), "pot_leafy": ("plants", (1033, 274)), "pot_small_fern": ("plants", (810, 536)),
    "pot_tiny_purple": ("plants", (616, 563)), "pot_tiny_green": ("plants", (684, 558)),
    "pot_tiny_violet": ("plants", (751, 545)), "pot_hanging": ("plants", (597, 633)), "pot_round": ("plants", (699, 633)),
    "pot_cascade": ("plants", (784, 633)), "palm_box": ("plants", (6, 524)), "bush_box": ("plants", (141, 587)),
    "vine_arch": ("plants", (265, 589)), "purple_box": ("plants", (391, 599)), "vine_pillar": ("plants", (504, 552)),
    "vine_column": ("plants", (877, 451)),
    "console_bank": ("machines", (188, 237)), "console_a": ("machines", (396, 239)), "console_b": ("machines", (478, 238)),
    "console_c": ("machines", (565, 238)), "server_rack": ("machines", (763, 181)), "terminal_vine": ("machines", (645, 245)),
    "terminal": ("machines", (703, 241)), "capsule": ("machines", (120, 249)), "analyzer": ("machines", (606, 351)),
    "canister_vine": ("machines", (703, 347)), "holo_sign": ("machines", (786, 331)), "printer": ("machines", (1046, 382)),
    "camera": ("machines", (698, 457)), "scanner": ("machines", (779, 456)), "hydro_rack": ("machines", (957, 472)),
    "cart": ("machines", (968, 600)),
    "crate": ("storage", (28, 352)), "locker": ("storage", (117, 358)), "locker_narrow": ("storage", (201, 358)),
    "locker_tall": ("storage", (247, 358)), "crate_screen": ("storage", (309, 360)), "medkit": ("storage", (383, 364)),
    "canister": ("storage", (469, 358)), "cylinder": ("storage", (538, 353)),
    "bench": ("furniture", (857, 373)), "lamp": ("furniture", (518, 447)), "bollard": ("furniture", (315, 457)),
    "device": ("furniture", (94, 457)),
    "pipe_arch": ("pipes", (154, 528)), "pipe_stub": ("pipes", (254, 527)), "pipe_long": ("pipes", (294, 526)),
    "pipe_bend": ("pipes", (414, 527)),
    "vent_round": ("floor", (21, 455)), "grate": ("floor", (161, 457)), "fan_vent": ("floor", (238, 457)),
}
TALL = 45.0  # world units: taller props see through when you walk behind them



def main():
    kit = Kit("Biodome", "biodome")

    # walls
    img, lab, boxes = pieces(os.path.join(TOOLS, "w8_walls_ref.webp"))
    for n, box in enumerate(RUNS):
        ids, b = owner(boxes, box)
        run = stretch_run(cut(img, lab, b, ids), POST, RUN_W)
        w, h = run.size[0] * WALL_K, run.size[1] * WALL_K
        kit.save(run, "walls", "wall_%d" % n, Kit.run_entry("Walls", w, h))
    run_h = 153 * WALL_K
    for n, box in enumerate(COLUMNS):
        ids, b = owner(boxes, box)
        col = cut(img, lab, b, ids)
        w, h = col.size[0] * WALL_K, col.size[1] * WALL_K
        kit.save(col, "walls", "column_%d" % n, Kit.column_entry("Walls", w, h, run_h))
    for name, box in JUNCTIONS.items():
        ids, b = owner(boxes, box)
        j = cut(img, lab, b, ids)
        w, h = j.size[0] * WALL_K, j.size[1] * WALL_K
        kit.save(j, "junctions", name, Kit.entry("Junctions", w, (w * 0.9, h * 0.45), fade=True))

    # props
    img, lab, boxes = pieces(os.path.join(TOOLS, "w8_props_ref.webp"))
    for name, (cat, tl) in PROPS.items():
        pic = piece_at(img, lab, boxes, tl)
        w, h = pic.size[0] * PROP_K, pic.size[1] * PROP_K
        kind = "flat" if cat == "floor" else ("walk_under" if name == "vine_arch" else ("post" if name in ("lamp", "bollard") else "solid"))
        kit.save(pic, cat, name, Kit.prop_entry(cat.capitalize(), w, h, kind, TALL))

    made, kept = kit.finish(README)
    # the floor tiles as a 64 px terrain atlas (tile 0 = the plain one)
    floor_atlas(os.path.join(SRC, "floor.png"), 76, 12, 2, "biodome_floor.png", FLOOR_ID, "Biodome floor", "Biodome")
    print("biodome kit: %d pictures (+%d added by hand), wall %.3f / prop %.2f units per px" % (made, kept, WALL_K, PROP_K))


README = """BIODOME kit (world 8) - palette OBJECTS > Biodome > <folder>

Every PNG in a folder here shows up in the Arena Editor palette under that folder's
name. To add more: drop a PNG (transparent background, feet at the bottom) into one of
the folders, or make a new folder, then press the palette's refresh button. Its size,
solid footprint, see-through and the rest are set in the Inspector of a placed copy
("Apply to all copies" saves them as the defaults in kit.json).

walls/      wall_<n> = straight runs between two posts (96 units = 3 floor tiles)
            column_<n> = walls going down the map (64 units = 2 floor tiles; the
            Biodome stacks two in each cell for roomy corridors)
junctions/  crosses and L corners
tanks/ planters/ plants/ machines/ storage/ pipes/ furniture/ floor/   the props

Made by python tools/make_biodome_kit.py from tools/w8_walls_ref.webp and
tools/w8_props_ref.webp (re-running it keeps the pictures and kit.json entries you add).
"""


if __name__ == "__main__":
    main()
