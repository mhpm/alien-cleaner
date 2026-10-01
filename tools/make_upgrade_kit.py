"""Builds the level-up modal kit from the loose upgrade elements.

  python tools/make_upgrade_kit.py

Sources (loose PNGs cut from the level-up mock-up):
  assets/ui/upgrades/upgrade_elements/elements_NNN.png   frames, header, NEW, shield strip
  assets/ui/upgrades/marciano_elements/marciano_NNN.png  Martian UFO, its shots, level boxes
  tools/overdrive_ref.webp   OVERDRIVE: 5 framed level cards, their 5 shot pictures, portrait

Output: assets/ui/upgrades/kit/
  header.png            "LEVEL UP / Choose an upgrade" plate
  card.png              empty card frame (elements_013 with its picture/text erased), 9-slice
  cell.png              level box frame (empty), shared by every upgrade
  num_<n>.png           level number tag, blue; num_<n>_on.png the gold one (level being taken)
  new.png               NEW tag
  <id>.png              portrait picture (no frame: the modal puts it in cell.png)
  <id>_<n>.png          level n picture, transparent, drawn inside cell.png
  martian_beam.png      Martian UFO with its abduction beam (unused for now)
  martian_shot.png      its plasma shot (head pointing right)
  face_<mood>.png       Martian emotes: surprise, angry, neutral, happy, wink
  shield_dome_<n>.png   shield dome in the colour of n charges: blue, green, purple, orange, RED
  shield_bubble_<n>.png the same dome hollowed out (bright rim, see-through middle): the
                        one drawn around the astronaut in play

New upgrades: add their portrait + 5 transparent level pictures here (<id>.png, <id>_<n>.png);
frame, number tags and animations come from the shared kit.
"""
import colorsys
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.join(HERE, "..", "assets", "ui", "upgrades")
EL = os.path.join(UP, "upgrade_elements")
MA = os.path.join(UP, "marciano_elements")
OUT = os.path.join(UP, "kit")

# OVERDRIVE (tools/overdrive_ref.webp): the loose shot pictures of levels 1-5 under the
# framed cards, and the portrait (gun icon with a shot) at the bottom
OVERDRIVE_LEVELS = [(20, 570, 290, 715), (300, 540, 550, 740), (565, 505, 825, 785),
                    (825, 560, 1113, 745), (1108, 450, 1440, 800)]
OVERDRIVE_PORTRAIT = (606, 824, 858, 1038)

# shield strength colours, weakest -> strongest (red is always the strongest)
SHIELD_HUES = [None, 135.0, 275.0, 32.0, 356.0]  # None = keep the art's blue
SHIELD_SAT = [1.0, 1.0, 1.0, 1.1, 1.25]


def el(n: int) -> Image.Image:
    return Image.open(os.path.join(EL, "elements_%03d.png" % n)).convert("RGBA")


def ma(n: int) -> Image.Image:
    return Image.open(os.path.join(MA, "marciano_%03d.png" % n)).convert("RGBA")


def trim(img: Image.Image) -> Image.Image:
    bb = img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    return img.crop(bb) if bb else img


def square(img: Image.Image, pad: int = 2) -> Image.Image:
    img = trim(img)
    s = max(img.size) + pad * 2
    out = Image.new("RGBA", (s, s))
    out.alpha_composite(img, ((s - img.width) // 2, (s - img.height) // 2))
    return out


def fit(img: Image.Image, side: int) -> Image.Image:
    if max(img.size) <= side:
        return img
    k = side / max(img.size)
    return img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)


def save(img: Image.Image, name: str) -> None:
    img.save(os.path.join(OUT, name))
    print("  ", name, img.size)


def header() -> Image.Image:
    """elements_001 is the plate plus a UFO whose outline touches it: cut the UFO off."""
    img = el(1)
    px = img.load()
    for y in range(img.height):
        edge = 687 if y < 126 else (660 if y > 160 else round(684 - (y - 126) * 19 / 34))
        for x in range(edge, img.width):
            px[x, y] = (0, 0, 0, 0)
    return keep_part(img, (300, 100))


def keep_part(img: Image.Image, seed: tuple) -> Image.Image:
    """Only the opaque blob connected to seed."""
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    stack = [seed]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x] or px[x, y][3] <= 8:
            continue
        seen[y * w + x] = 1
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    out = Image.new("RGBA", img.size)
    op = out.load()
    for y in range(h):
        for x in range(w):
            if seen[y * w + x]:
                op[x, y] = px[x, y]
    return trim(out)


def clean_card() -> Image.Image:
    """elements_013 without its picture box, title, text and level boxes."""
    a = el(13)
    px = a.load()
    col = [px[600 if y < 60 else 722, y] for y in range(a.height)]  # clean interior gradient
    x0, x1, y0, y1, c = 20, 727, 11, 206, 26
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if min(x - x0, x1 - x) + min(y - y0, y1 - y) < c:
                continue  # leave the chamfered corners alone
            px[x, y] = col[y]
    return trim(a)


def recolor_digit(img: Image.Image, to_gold: bool) -> Image.Image:
    """Number tag: repaint the digit (not the frame) blue <-> gold."""
    img = img.copy()
    px = img.load()
    w, h = img.size
    for y in range(22, h - 22):
        for x in range(26, w - 26):
            r, g, b, a = px[x, y]
            if to_gold and r > 60 and b > 200:  # light-blue digit
                t = min(1.0, max(0.0, (r - 80) / 70.0))
                px[x, y] = (round(240 + 15 * t), round(168 + 50 * t), round(0 + 50 * t), a)
            elif not to_gold and r > 200 and b < 90:  # yellow digit
                t = min(1.0, max(0.0, (g - 188) / 18.0))
                px[x, y] = (round(81 + 66 * t), round(188 + 35 * t), round(249 + 6 * t), a)
    return img


def color_to_alpha(img: Image.Image, bg: tuple, floor: float = 0.14) -> Image.Image:
    """GIMP-style colour-to-alpha: glow painted on a flat background -> transparent glow."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a0 = px[x, y]
            c = (r, g, b)
            a = 0.0
            for i in range(3):
                if c[i] > bg[i]:
                    a = max(a, (c[i] - bg[i]) / (255.0 - bg[i]))
                elif c[i] < bg[i]:
                    a = max(a, (bg[i] - c[i]) / float(bg[i]))
            if a < 0.02:
                px[x, y] = (0, 0, 0, 0)
                continue
            f = [min(255, max(0, round((c[i] - (1 - a) * bg[i]) / a))) for i in range(3)]
            a2 = max(0.0, (a - floor) / (1.0 - floor))  # drop the box's faint vignette
            px[x, y] = (f[0], f[1], f[2], round(a2 * a0))
    return out


def hue_shift(img: Image.Image, hue: float, sat: float) -> Image.Image:
    """Repaint the blue art in another hue; near-white highlights stay white-hot."""
    if hue is None:
        return img
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            nr, ng, nb = colorsys.hsv_to_rgb(hue / 360.0, min(1.0, s * sat), v)
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return out


def hollow(img: Image.Image, inner: float = 0.42, outer: float = 0.9, keep: float = 0.1) -> Image.Image:
    """See-through middle: alpha fades from the rim (full) to `keep` at the centre."""
    out = img.copy()
    px = out.load()
    cx, cy = (out.width - 1) / 2.0, (out.height - 1) / 2.0
    rad = min(out.width, out.height) / 2.0
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / rad
            t = min(1.0, max(0.0, (d - inner) / (outer - inner)))
            t = t * t * (3 - 2 * t)
            px[x, y] = (r, g, b, round(a * (keep + (1 - keep) * t)))
    return out


def five_shot() -> Image.Image:
    """Level 5 picture: the 5-shot fan (marciano_024) bursting out of the UFO."""
    fan = trim(ma(24))
    ufo = fit(trim(ma(2)), round(fan.width * 0.5))
    w = fan.width
    h = round(fan.height * 0.78) + ufo.height
    out = Image.new("RGBA", (w, h))
    out.alpha_composite(fan, (0, 0))
    out.alpha_composite(ufo, ((w - ufo.width) // 2, h - ufo.height))
    return out


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    save(header(), "header.png")
    save(clean_card(), "card.png")
    save(trim(ma(18)), "cell.png")
    save(trim(el(8)), "new.png")

    # number tags: 019 has a gold "1", 020..023 blue "2".."5"
    tags = {1: ma(19), 2: ma(20), 3: ma(21), 4: ma(22), 5: ma(23)}
    for n, img in tags.items():
        img = trim(img)
        if n == 1:
            save(img, "num_1_on.png")
            save(recolor_digit(img, False), "num_1.png")
        else:
            save(img, "num_%d.png" % n)
            save(recolor_digit(img, True), "num_%d_on.png" % n)

    # --- Martian UFO
    save(fit(trim(ma(2)), 200), "martian.png")
    beam = ma(5)
    beam = trim(beam.crop((0, 280, beam.width, beam.height)))
    save(beam, "martian_beam.png")
    save(fit(trim(ma(10)), 128), "martian_shot.png")
    levels = [ma(10), ma(9), ma(11), ma(8), five_shot()]
    for i, img in enumerate(levels):
        save(fit(square(img), 128), "martian_%d.png" % (i + 1))
    for mood, n in {"surprise": 2, "angry": 3, "neutral": 4, "happy": 5, "wink": 6}.items():
        save(fit(trim(el(n)), 96), "face_%s.png" % mood)

    # --- Shield: the strip's 5 pictures, glow lifted off their box, recoloured up to red
    strip = el(23)
    cells = [(11, 89), (103, 183), (196, 275), (288, 369), (382, 462)]
    for i, (x0, x1) in enumerate(cells):
        cell = strip.crop((x0 + 6, 17, x1 - 6, 87))
        bg = cell.getpixel((2, 2))[:3]
        pic = color_to_alpha(cell, bg)
        pic = hue_shift(pic, SHIELD_HUES[i], SHIELD_SAT[i])
        save(square(pic, 4).resize((128, 128), Image.LANCZOS), "shield_%d.png" % (i + 1))
    dome = trim(el(22))
    for i in range(5):
        tinted = hue_shift(dome, SHIELD_HUES[i], SHIELD_SAT[i])
        save(tinted, "shield_dome_%d.png" % (i + 1))
        save(hollow(tinted), "shield_bubble_%d.png" % (i + 1))
    save(fit(dome, 160), "shield.png")

    # --- OVERDRIVE (boosts whatever ARMORY weapon is equipped)
    ref = Image.open(os.path.join(HERE, "overdrive_ref.webp")).convert("RGBA")
    for i, box in enumerate(OVERDRIVE_LEVELS):
        save(fit(square(trim(ref.crop(box))), 128), "overdrive_%d.png" % (i + 1))
    save(fit(trim(ref.crop(OVERDRIVE_PORTRAIT)), 200), "overdrive.png")


if __name__ == "__main__":
    main()
