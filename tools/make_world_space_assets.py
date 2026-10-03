"""World select space backdrop -> assets/ui/world/space/.

  python tools/make_world_space_assets.py

Inputs:
  tools/world_select_space_ref.webp  wide spaceship window (1672x941): sky inside the
                                     window frame, deck floor at the bottom.
  tools/world_select_space_kit.webp  loose pieces on transparency: ships, a space
                                     station, asteroids, belts, planets, sparkles,
                                     galaxy and nebula.
  assets/ui/world/bg.webp            the old portrait art: only its top bar and nav bar
                                     are kept, as UI strips over the new backdrop.

Outputs (assets/ui/world/space/):
  bg.webp        the whole picture (drawn first, covers any screen)
  fg.png         the same picture with the window opening cut out (frame + floor), drawn
                 over the animated pieces so ships and asteroids pass behind the frame
  <piece>.png    each kit piece, cropped (see PIECES)
  top_bar.png / nav_bar.png   the old UI bars, transparent outside their outline
"""
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "tools/world_select_space_ref.webp"
KIT = ROOT / "tools/world_select_space_kit.webp"
OLD = ROOT / "assets/ui/world/bg.webp"
OUT = ROOT / "assets/ui/world/space"

# the window opening (sky) of the ref picture, clockwise from the top-left corner
WINDOW = [
    (92, 170), (180, 82), (360, 82), (370, 58), (728, 58), (734, 66), (946, 66), (952, 58),
    (1300, 58), (1308, 80), (1505, 84), (1590, 172), (1590, 524), (1546, 532), (1546, 640),
    (1440, 642), (1440, 676), (1306, 676), (1284, 701), (396, 701), (370, 676), (236, 676),
    (236, 648), (130, 640), (130, 530), (92, 524),
]

# kit pieces: name -> (x0, y0, x1, y1[, keep only the largest blob])
PIECES = {
    "ship_cruiser": (26, 25, 462, 202, True),
    "ship_fighter": (458, 46, 776, 174, True),
    "ship_dart": (832, 66, 1130, 163, True),
    "ship_hauler": (84, 212, 398, 339, True),
    "ship_gunship": (514, 219, 772, 324, True),
    "ship_scout": (887, 217, 1090, 301, True),
    "station": (1172, 6, 1656, 516, True),
    "rock_0": (26, 330, 252, 528, True),
    "rock_1": (281, 372, 428, 516, True),
    "rock_2": (454, 366, 585, 509, True),
    "rock_3": (614, 384, 723, 503, True),
    "rock_4": (751, 390, 860, 510, True),
    "rock_5": (890, 412, 975, 504, True),
    "rock_6": (1003, 408, 1085, 504, True),
    "rock_7": (1112, 428, 1189, 498, True),
    "rock_8": (1219, 431, 1287, 504, True),
    "rock_9": (1315, 453, 1359, 501, True),
    "belt_0": (786, 516, 1094, 642, False),
    "belt_1": (1102, 524, 1360, 657, False),
    "planet_blue": (26, 530, 332, 830, True),
    "planet_ringed": (332, 519, 894, 828, True),
    "planet_orange": (864, 664, 1029, 828, True),
    "moon": (1061, 704, 1151, 792, True),
    "galaxy": (851, 653, 1480, 937, False),
    "nebula": (1376, 563, 1657, 937, False),
    "star_0": (29, 821, 143, 936, True),
    "star_1": (171, 837, 248, 921, True),
    "star_2": (276, 830, 356, 927, True),
    "star_3": (387, 838, 457, 918, True),
    "star_4": (489, 839, 549, 910, True),
    "star_5": (590, 851, 641, 908, True),
    "star_6": (690, 849, 742, 905, True),
}
# parts of other pieces that fall inside a box (cleared before saving)
CLEAR = {
    "galaxy": [(851, 653, 1030, 830), (1058, 700, 1155, 795), (1378, 722, 1480, 937)],
    "belt_0": [(786, 598, 852, 642)],
    "nebula": [(1376, 563, 1478, 700)],
}

TOP_BAR = [(0, 0), (941, 0), (941, 96), (926, 106), (860, 106), (854, 100), (346, 100),
           (338, 106), (330, 118), (122, 118), (112, 126), (0, 126)]
NAV_BAR = [(0, 1474), (354, 1474), (360, 1460), (586, 1460), (592, 1474), (941, 1474),
           (941, 1672), (0, 1672)]


def poly_mask(size, poly, inside=255, ss=4):
    """Antialiased polygon mask (supersampled)."""
    w, h = size
    m = Image.new("L", (w * ss, h * ss), 0 if inside else 255)
    ImageDraw.Draw(m).polygon([(x * ss, y * ss) for x, y in poly], fill=inside)
    return m.resize(size, Image.LANCZOS)


def largest_blob(img):
    """Keeps only the biggest connected blob (alpha > 12, grown 2 px) of img."""
    a = img.getchannel("A")
    grown = a.point(lambda v: 255 if v > 12 else 0).filter(ImageFilter.MaxFilter(5))
    w, h = img.size
    px = grown.load()
    seen = bytearray(w * h)
    best: list = []
    for y in range(h):
        for x in range(w):
            if px[x, y] and not seen[y * w + x]:
                blob = []
                q = deque([(x, y)])
                seen[y * w + x] = 1
                while q:
                    cx, cy = q.popleft()
                    blob.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and not seen[ny * w + nx]:
                            seen[ny * w + nx] = 1
                            q.append((nx, ny))
                if len(blob) > len(best):
                    best = blob
    keep = Image.new("L", img.size, 0)
    kp = keep.load()
    for x, y in best:
        kp[x, y] = 255
    out = img.copy()
    out.putalpha(Image.composite(a, Image.new("L", img.size, 0), keep))
    return out


def trim(img, pad=2):
    box = img.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    if box is None:
        return img
    x0, y0, x1, y1 = box
    return img.crop((max(0, x0 - pad), max(0, y0 - pad), min(img.width, x1 + pad), min(img.height, y1 + pad)))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ref = Image.open(REF).convert("RGB")
    ref.save(OUT / "bg.webp", quality=92, method=6)
    fg = ref.convert("RGBA")
    fg.putalpha(poly_mask(ref.size, WINDOW, inside=0))
    fg.save(OUT / "fg.png", optimize=True)

    kit = Image.open(KIT).convert("RGBA")
    for name, spec in PIECES.items():
        x0, y0, x1, y1, solo = spec
        piece = kit.crop((x0, y0, x1, y1))
        for cx0, cy0, cx1, cy1 in CLEAR.get(name, []):
            ImageDraw.Draw(piece).rectangle((cx0 - x0, cy0 - y0, cx1 - x0, cy1 - y0), fill=(0, 0, 0, 0))
        if solo:
            piece = largest_blob(piece)
        trim(piece).save(OUT / f"{name}.png", optimize=True)

    old = Image.open(OLD).convert("RGBA")
    for name, poly in (("top_bar", TOP_BAR), ("nav_bar", NAV_BAR)):
        ys = [p[1] for p in poly]
        box = (0, min(ys), old.width, max(ys))
        strip = old.crop(box)
        strip.putalpha(poly_mask(strip.size, [(x, y - box[1]) for x, y in poly]))
        strip.save(OUT / f"{name}.png", optimize=True)
    print("ok ->", OUT)


if __name__ == "__main__":
    main()
