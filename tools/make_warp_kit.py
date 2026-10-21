"""World 7 WARP NEXUS kit for the Arena Editor (its map is a scene edited by hand).

The user's sheets (tools/w7_walls_ref.webp = A, tools/w7_walls2_ref.webp = B,
tools/w7_props_ref.webp = P) cut into palette pictures (OBJECTS > Warp Nexus > ...):

  assets/decor/warp_nexus/
    walls/run_<n>.png        a straight wall, a striped post at EACH end (runs butt
                             against each other, post to post, like on the sheet): one
                             cell side CW long (the middle rescaled a few % so all match)
    walls/column_<n>.png     a wall going down the map: top of the post above to the base
                             of the one below (the tube rescaled a few %)
    barriers/*.png           wall pieces of other lengths: free-standing cover in halls
    pillars/*.png            single posts and short columns
    junctions/*.png          tees, crosses, L corners, arches (placed by hand)
    gate/ tanks/ machines/ storage/ pipes/ lights/ rocks/ floor/   the props
  assets/arena/terrain/warp_floor.png  the floor world 7 already had (assets/rooms/w7/
                                       build/floor.png) as terrain "Warp floor"

  python tools/make_warp_kit.py
"""
import os

from PIL import Image

from kit_cut import Kit, cut, floor_atlas, owner, piece_at, pieces, split_at_gap, stretch_column, stretch_run

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
FLOOR_ID = 15

CW = 128.0  # one run = one cell side (4 floor tiles)
CH = 128.0  # one column = one cell down
RUN_W = 274  # px a run is brought to (posts kept)
POST = 38  # px of the striped post at each end of a run
RUN_H = 120  # px tall
WALL_K = CW / RUN_W  # world units per wall px
COL_CAP = 78  # px of cap + yellow band kept at each end of a column
COL_H = round((CH + RUN_H * WALL_K) / WALL_K)  # px: far post's top to the near post's base
PROP_K = 0.38
TALL = 45.0

# straight runs of one module (top-left in their sheet); "B2a"/"B2b" = the two halves of B2
RUNS = [("B", (15, 13)), ("B", (311, 13)), ("B", (16, 162)), ("B", (311, 162)), ("A", (12, 294)), ("B2", 0), ("B2", 1)]
SPLIT = {"B2": ("B", (595, 13)), "A0": ("A", (7, 4)), "A6": ("A", (12, 141)), "B9": ("B", (592, 162))}
BARRIERS = {"barrier_vent_a": ("A0", 0), "barrier_vent_b": ("A0", 1), "barrier_screen": ("A6", 0),
            "barrier_fan": ("A6", 1), "barrier_mesh": ("A", (700, 4)), "barrier_fan_long": ("A", (650, 141)),
            "barrier_panel": ("A", (304, 294)), "barrier_fan_short": ("B", (377, 322)),
            "barrier_long_vent": ("B9", 0), "barrier_monitor": ("B9", 1),
            "mini_half": ("A", (23, 884)), "mini_grate": ("A", (143, 884)), "mini_plain": ("A", (292, 884)),
            "mini_plain_b": ("A", (448, 883)), "mini_fan": ("A", (608, 883)), "mini_light": ("B", (16, 872)),
            "mini_screen": ("B", (190, 873)), "mini_vent": ("B", (393, 875)), "mini_grill": ("B", (559, 875)),
            "mini_speaker": ("B", (734, 873))}
COLUMNS = [("A", (17, 464)), ("A", (112, 464)), ("A", (208, 464)), ("A", (304, 495)), ("A", (398, 495)),
           ("A", (496, 495)), ("A", (589, 495)), ("B", (20, 490)), ("B", (103, 489)), ("B", (176, 489)),
           ("B", (259, 493)), ("B", (338, 494)), ("B", (416, 494)), ("B", (508, 494))]
PILLARS = [("A", xy) for xy in [(1275, 5), (1362, 5), (1450, 5), (1381, 149), (1458, 149), (681, 520), (773, 519),
                                (862, 526), (945, 526), (1027, 526), (1106, 526), (1190, 582), (705, 729), (805, 724),
                                (902, 724), (999, 724), (1093, 724), (1185, 724), (799, 883), (903, 883), (999, 883),
                                (1094, 883), (1189, 883), (1452, 881)]] + \
          [("B", xy) for xy in [(1167, 10), (1262, 10), (1358, 12), (1454, 11), (1080, 164), (1168, 195), (1260, 218),
                                (1354, 213), (1452, 238), (586, 497), (656, 492), (1329, 512), (654, 575), (586, 691),
                                (742, 660), (827, 717), (1038, 687), (1130, 717), (926, 742), (1256, 737), (1459, 779),
                                (1356, 782), (927, 877), (1041, 876), (1149, 877), (1257, 880), (1359, 881), (1458, 881)]]
JUNCTIONS = {"arch_a": ("A", (1048, 4)), "arch_b": ("A", (1033, 149)), "corner_post": ("A", (1254, 149)),
             "tee_screen": ("A", (563, 294)), "tee_fan": ("A", (853, 295)), "corner_l": ("A", (1175, 296)),
             "corner_u": ("A", (1360, 296)), "cross_vortex": ("A", (1263, 441)), "cross_plate": ("A", (1260, 688)),
             "bend_a": ("B", (15, 322)), "corner_u_b": ("B", (150, 322)), "tee_fan_b": ("B", (661, 323)),
             "tee_screen_b": ("B", (927, 324)), "bend_b": ("B", (1181, 329)), "arch_c": ("B", (1291, 368)),
             "cross_core": ("B", (803, 466)), "cross_fan": ("B", (1114, 486)), "cross_screen": ("B", (1337, 487))}
# props: name -> (folder, top-left in P); folder "floor" = flat on the floor, "rocks" = loose
PROPS = {
    "warp_gate": ("gate", (12, 8)), "warp_pad": ("gate", (425, 328)), "warp_pad_round": ("gate", (574, 363)),
    "core_tank": ("tanks", (295, 8)), "twin_tanks": ("tanks", (421, 8)), "thin_tank": ("tanks", (658, 11)),
    "specimen_tank": ("tanks", (975, 11)), "canister_tank": ("tanks", (766, 211)), "glass_tank": ("tanks", (843, 212)),
    "twin_canister": ("tanks", (1046, 213)), "small_tank": ("tanks", (639, 286)), "slim_tank": ("tanks", (493, 451)),
    "tiny_tank": ("tanks", (680, 581)),
    "dish": ("machines", (724, 9)), "teleporter": ("machines", (891, 12)), "command_desk": ("machines", (310, 196)),
    "generator_block": ("machines", (915, 216)), "antenna_tower": ("machines", (12, 272)),
    "server_cubes": ("machines", (73, 283)), "reactor_tower": ("machines", (237, 240)),
    "server_rack": ("machines", (334, 324)), "machine_block": ("machines", (326, 448)),
    "door_tall": ("machines", (824, 598)), "blast_door": ("machines", (901, 598)), "door_plain": ("machines", (1024, 598)),
    "locker_cap": ("machines", (745, 581)),
    "crate_stack": ("storage", (522, 199)), "cube_light": ("storage", (641, 206)), "olive_crate": ("storage", (160, 280)),
    "cube_blue": ("storage", (1043, 333)), "olive_box": ("storage", (14, 438)), "shelves": ("storage", (101, 431)),
    "olive_case": ("storage", (243, 451)), "forklift": ("storage", (411, 446)), "cube_glow": ("storage", (553, 447)),
    "battery_pack": ("storage", (15, 523)), "locker_small": ("storage", (592, 517)), "cabinet": ("storage", (831, 499)),
    "hazard_crate": ("storage", (902, 517)), "hazard_locker": ("storage", (1035, 494)), "canisters": ("storage", (94, 553)),
    "mini_cell": ("storage", (18, 602)), "mini_cell_b": ("storage", (19, 667)), "post_box": ("storage", (676, 671)),
    "post_box_b": ("storage", (716, 672)),
    "pipe_short": ("pipes", (102, 371)), "pipe_rack": ("pipes", (987, 379)), "pipe_bar": ("pipes", (634, 456)),
    "pipe_long": ("pipes", (764, 436)), "pipe_mid": ("pipes", (921, 456)), "pipe_bar_b": ("pipes", (676, 516)),
    "tube_light": ("lights", (715, 216)), "beacon_pod": ("lights", (756, 660)),
    "rock_small": ("rocks", (777, 331)), "rock_round": ("rocks", (832, 346)), "rock_long": ("rocks", (885, 344)),
    "pebble": ("rocks", (891, 339)), "rock_a": ("rocks", (677, 360)), "pebble_b": ("rocks", (733, 416)),
    "rock_b": ("rocks", (757, 370)), "pebble_c": ("rocks", (953, 418)),
    "hatch_wheel": ("floor", (168, 542)), "hatch_wheel_b": ("floor", (247, 542)), "plate_blue": ("floor", (327, 544)),
    "plate_glass": ("floor", (407, 545)), "chevron_left": ("floor", (493, 548)), "light_panel": ("floor", (71, 608)),
    "grate": ("floor", (166, 607)), "plate_a": ("floor", (247, 607)), "plate_b": ("floor", (327, 607)),
    "plate_c": ("floor", (407, 607)), "plate_glass_b": ("floor", (493, 607)), "chevron_right": ("floor", (586, 609)),
    "grate_b": ("floor", (77, 673)), "plate_broken": ("floor", (166, 673)), "plate_d": ("floor", (247, 673)),
    "plate_e": ("floor", (327, 673)), "plate_crack": ("floor", (407, 673)), "plate_crack_b": ("floor", (492, 673)),
    "plate_f": ("floor", (586, 672)),
}
FLAT = {"warp_pad", "warp_pad_round"}  # platforms you walk over


def main():
    kit = Kit("Warp Nexus", "warp_nexus")
    sheets = {k: pieces(os.path.join(TOOLS, f)) for k, f in
              (("A", "w7_walls_ref.webp"), ("B", "w7_walls2_ref.webp"), ("P", "w7_props_ref.webp"))}

    def pic(sheet, tl):
        img, lab, boxes = sheets[sheet]
        return piece_at(img, lab, boxes, tl)

    halves = {}
    for key, (sheet, tl) in SPLIT.items():
        whole = pic(sheet, tl)
        mid = whole.width // 2
        halves[key] = split_at_gap(whole, mid - 60, mid + 60)

    def get(src):
        a, b = src
        return halves[a][b] if a in halves else pic(a, b)

    run_h = RUN_H * WALL_K
    for n, src in enumerate(RUNS):
        run = stretch_run(get(src), POST, RUN_W)
        w, h = run.size[0] * WALL_K, run.size[1] * WALL_K
        kit.save(run, "walls", "run_%d" % n, Kit.run_entry("Walls", w, h))
    for n, src in enumerate(COLUMNS):
        col = stretch_column(get(src), COL_CAP, COL_H)
        w, h = col.size[0] * WALL_K, col.size[1] * WALL_K
        kit.save(col, "walls", "column_%d" % n, Kit.column_entry("Walls", w, h, run_h))
    for name, src in BARRIERS.items():
        b = get(src)
        w, h = b.size[0] * WALL_K, b.size[1] * WALL_K
        kit.save(b, "barriers", name, Kit.run_entry("Barriers", w, h))
    for n, src in enumerate(PILLARS):
        p = get(src)
        w, h = p.size[0] * WALL_K, p.size[1] * WALL_K
        kit.save(p, "pillars", "pillar_%02d" % n, Kit.entry("Pillars", w, (w + 6.0, min(h * 0.4, 22.0)), fade=h > TALL))
    for name, src in JUNCTIONS.items():
        j = get(src)
        w, h = j.size[0] * WALL_K, j.size[1] * WALL_K
        kit.save(j, "junctions", name, Kit.entry("Junctions", w, (w * 0.9, h * 0.45), fade=True))
    for name, (folder, tl) in PROPS.items():
        p = pic("P", tl)
        w, h = p.size[0] * PROP_K, p.size[1] * PROP_K
        kind = "flat" if folder in ("floor", "rocks") or name in FLAT else "solid"
        kit.save(p, folder, name, Kit.prop_entry(folder.capitalize(), w, h, kind, TALL))

    made, kept = kit.finish(README)
    # the floor world 7 already had (ForgeMap's w7 floor: world 5's plain tiles, tinted)
    floor_atlas(os.path.join(ROOT, "assets", "rooms", "w7", "build", "floor.png"), 76, 6, 3,
                "warp_floor.png", FLOOR_ID, "Warp floor", "Warp Nexus")
    print("warp kit: %d pictures (+%d added by hand), wall %.3f / prop %.2f units per px, column %d px"
          % (made, kept, WALL_K, PROP_K, COL_H))


README = """WARP NEXUS kit (world 7) - palette OBJECTS > Warp Nexus > <folder>

Every PNG in a folder here shows up in the Arena Editor palette under that folder's
name. To add more: drop a PNG (transparent background, feet at the bottom) into one of
the folders, or make a new folder, then press the palette's refresh button. Its size,
solid footprint, see-through and the rest are set in the Inspector of a placed copy
("Apply to all copies" saves them as the defaults in kit.json).

walls/      run_<n> = straight walls, a post at each end, 128 units (4 floor tiles):
            they butt post to post; column_<n> = walls going down, 128 units a cell
barriers/   wall pieces of other lengths: free-standing cover inside halls
pillars/    single posts and short columns
junctions/  tees, crosses, L corners and arches
gate/ tanks/ machines/ storage/ pipes/ lights/ rocks/ floor/   the props
            (rocks and floor pieces are flat: drawn under everything, no collision)

Made by python tools/make_warp_kit.py from tools/w7_walls_ref.webp,
tools/w7_walls2_ref.webp and tools/w7_props_ref.webp (re-running it keeps the pictures
and kit.json entries you add).
"""


if __name__ == "__main__":
    main()
