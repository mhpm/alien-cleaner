BIODOME kit (world 8) - palette OBJECTS > Biodome > <folder>

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
