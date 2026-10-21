WARP NEXUS kit (world 7) - palette OBJECTS > Warp Nexus > <folder>

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
