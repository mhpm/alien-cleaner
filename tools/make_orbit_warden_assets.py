"""Rebuild Orbit Warden assets from the supplied transparent sheet.

python tools/make_orbit_warden_assets.py
Only updates this creature's sprite sets; preserves all other manifest entries.
"""
from pathlib import Path
from PIL import Image
import slice_sprites as slicer
from cut_sheet_enemies import clean, main_piece

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools/orbit_warden_ref.png"
OUT = ROOT / "assets/sprites"


def main():
    sheet = Image.open(SOURCE).convert("RGBA")
    if sheet.size != (1672, 941):
        raise ValueError("Expected the original 1672 x 941 reference sheet")
    rows = {
        "idle": (0, 201, [0, 200, 392, 582, 774, 965, 1155, 1344, 1506, 1672]),
        "cast": (210, 407, [0, 196, 393, 586, 774]),
        "orb": (272, 386, [775, 866, 951]),
        "burst": (205, 425, [1421, 1672]),
        "beam": (427, 625, [855, 1051, 1257]),
        "summon": (611, 786, [0, 204, 440, 650, 892]),
        "die": (792, 941, [0, 200, 440, 665, 980, 1290, 1465, 1672]),
    }
    for row, (y0, y1, cuts) in rows.items():
        folder = OUT / "enemies/orbit_warden" / row
        folder.mkdir(parents=True, exist_ok=True)
        for i, (x0, x1) in enumerate(zip(cuts, cuts[1:]), 1):
            frame = clean(sheet.crop((x0, y0, x1, y1)))
            if row == "orb" or (row == "die" and i == 1):
                frame = main_piece(frame)
            frame.crop(frame.getbbox()).save(folder / f"image_{i:02}.png")
    # One unobstructed small invader, isolated from the summoning row.
    folder = OUT / "enemies/orbit_warden/minion"
    folder.mkdir(parents=True, exist_ok=True)
    frame = main_piece(sheet.crop((975, 644, 1080, 742)))
    frame.crop(frame.getbbox()).save(folder / "image_01.png")
    slicer.main(str(SOURCE), str(OUT), {
        "orbit_warden", "orbit_spawn", "orbit_plasma", "orbit_burst", "orbit_beam",
    })


if __name__ == "__main__":
    main()
