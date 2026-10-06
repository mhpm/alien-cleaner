"""Android part collectibles for arena AndroidPart objects (Arena Editor).

Draws the five pieces of the damaged android (head, core, left arm, right arm, leg
module) at 4x and scales them down for smooth edges: gunmetal plating, a dark outline,
a cyan energy glow and scorch marks, so they read as loot on any floor.

    python tools/make_android_parts.py   ->  assets/sprites/android/<part>.png (96x96)
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sprites", "android")
S = 4  # supersampling
W = 96 * S

OUTLINE = (20, 22, 36, 255)
DARK = (51, 60, 87, 255)
MID = (86, 108, 134, 255)
LIGHT = (148, 176, 194, 255)
SHINE = (226, 240, 246, 255)
GLOW = (115, 239, 247, 255)
HOT = (255, 205, 117, 255)
RUST = (177, 62, 83, 255)


def canvas():
    return Image.new("RGBA", (W, W), (0, 0, 0, 0))


def plate(d, box, r, base=MID, light=LIGHT, dark=DARK):
    """A rounded metal plate with an outline, a lit top edge and a shaded bottom."""
    x0, y0, x1, y1 = box
    o = 3 * S
    d.rounded_rectangle((x0 - o, y0 - o, x1 + o, y1 + o), r + o, fill=OUTLINE)
    d.rounded_rectangle(box, r, fill=dark)
    d.rounded_rectangle((x0, y0, x1, y1 - (y1 - y0) * 0.18), r, fill=base)
    d.rounded_rectangle((x0 + 3 * S, y0 + 2 * S, x1 - 3 * S, y0 + (y1 - y0) * 0.3), r, fill=light)


def bolt(d, x, y):
    d.ellipse((x - 3 * S, y - 3 * S, x + 3 * S, y + 3 * S), fill=OUTLINE)
    d.ellipse((x - 2 * S, y - 2 * S, x + 2 * S, y + 2 * S), fill=LIGHT)


def glow_layer(size, shapes, radius=10):
    """Soft cyan halo under the energy parts."""
    g = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    for kind, box in shapes:
        (gd.ellipse if kind == "e" else gd.rectangle)(box, fill=(115, 239, 247, 150))
    return g.filter(ImageFilter.GaussianBlur(radius * S))


def scorch(img, seed, n=5):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img)
    px = img.load()
    for _ in range(n):
        x, y = rnd.randint(W // 4, W * 3 // 4), rnd.randint(W // 4, W * 3 // 4)
        if px[x, y][3] < 200:
            continue
        r = rnd.randint(3, 7) * S
        d.ellipse((x - r, y - r // 2, x + r, y + r // 2), fill=(30, 30, 40, 140))
    for _ in range(3):  # sparks of exposed wiring
        x, y = rnd.randint(W // 3, W * 2 // 3), rnd.randint(W // 3, W * 2 // 3)
        if px[x, y][3] > 200:
            d.line((x, y, x + rnd.randint(-8, 8) * S, y + rnd.randint(-8, 8) * S), fill=HOT, width=2 * S)


def head():
    img = canvas()
    img.alpha_composite(glow_layer(img.size, [("e", (W * .3, W * .38, W * .7, W * .58))]))
    d = ImageDraw.Draw(img)
    plate(d, (W * .2, W * .22, W * .8, W * .78), 26 * S)
    # visor
    d.rounded_rectangle((W * .27, W * .38, W * .73, W * .58), 10 * S, fill=OUTLINE)
    d.rounded_rectangle((W * .29, W * .40, W * .71, W * .56), 8 * S, fill=(18, 60, 80, 255))
    for i, x in enumerate((W * .39, W * .61)):
        d.ellipse((x - 6 * S, W * .44, x + 6 * S, W * .52), fill=GLOW if i == 0 else (60, 120, 130, 255))
    # antenna (bent) and cheek bolts
    d.line((W * .62, W * .22, W * .7, W * .08), fill=OUTLINE, width=6 * S)
    d.line((W * .62, W * .22, W * .7, W * .08), fill=LIGHT, width=3 * S)
    d.ellipse((W * .66, W * .04, W * .74, W * .12), fill=HOT, outline=OUTLINE, width=2 * S)
    bolt(d, W * .26, W * .68)
    bolt(d, W * .74, W * .68)
    d.line((W * .32, W * .68, W * .45, W * .74), fill=RUST, width=3 * S)  # crack
    scorch(img, 1)
    return img


def core():
    img = canvas()
    img.alpha_composite(glow_layer(img.size, [("e", (W * .25, W * .25, W * .75, W * .75))], 14))
    d = ImageDraw.Draw(img)
    plate(d, (W * .18, W * .2, W * .82, W * .8), 14 * S, base=DARK, light=MID, dark=(36, 42, 66, 255))
    for a in range(0, 360, 45):  # cooling fins
        x = W / 2 + math.cos(math.radians(a)) * W * .3
        y = W / 2 + math.sin(math.radians(a)) * W * .3
        bolt(d, x, y)
    d.ellipse((W * .3, W * .3, W * .7, W * .7), fill=OUTLINE)
    d.ellipse((W * .33, W * .33, W * .67, W * .67), fill=(40, 120, 150, 255))
    d.ellipse((W * .38, W * .38, W * .62, W * .62), fill=GLOW)
    d.ellipse((W * .44, W * .4, W * .54, W * .48), fill=SHINE)
    scorch(img, 2, 3)
    return img


def arm(flip):
    img = canvas()
    img.alpha_composite(glow_layer(img.size, [("e", (W * .58, W * .64, W * .8, W * .86))], 8))
    d = ImageDraw.Draw(img)
    plate(d, (W * .18, W * .12, W * .48, W * .42), 14 * S)  # shoulder
    bolt(d, W * .33, W * .27)
    plate(d, (W * .3, W * .36, W * .54, W * .7), 10 * S, base=MID)  # upper arm (tilted look)
    d.ellipse((W * .4, W * .6, W * .62, W * .78), fill=OUTLINE)  # elbow joint
    d.ellipse((W * .43, W * .63, W * .59, W * .75), fill=GLOW)
    plate(d, (W * .52, W * .62, W * .84, W * .82), 10 * S)  # forearm
    for i in range(3):  # fingers
        x = W * (.84 + i * 0.0)
        y = W * (.64 + i * .06)
        d.rounded_rectangle((x - 2 * S, y, x + 9 * S, y + 4 * S), 2 * S, fill=LIGHT, outline=OUTLINE, width=2 * S)
    d.line((W * .55, W * .66, W * .62, W * .78), fill=HOT, width=2 * S)  # torn cable
    scorch(img, 3 if flip else 4)
    return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img


def leg():
    img = canvas()
    img.alpha_composite(glow_layer(img.size, [("e", (W * .36, W * .44, W * .64, W * .6))], 8))
    d = ImageDraw.Draw(img)
    plate(d, (W * .32, W * .08, W * .68, W * .4), 12 * S)  # thigh
    d.ellipse((W * .38, W * .38, W * .62, W * .58), fill=OUTLINE)  # knee
    d.ellipse((W * .41, W * .41, W * .59, W * .55), fill=GLOW)
    plate(d, (W * .35, W * .54, W * .65, W * .8), 10 * S, base=MID)  # shin
    plate(d, (W * .22, W * .78, W * .74, W * .92), 8 * S, base=DARK, light=MID)  # foot
    bolt(d, W * .5, W * .2)
    bolt(d, W * .42, W * .86)
    d.line((W * .36, W * .66, W * .5, W * .7), fill=RUST, width=3 * S)
    scorch(img, 5)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    parts = {"head": head(), "core": core(), "left_arm": arm(False), "right_arm": arm(True), "leg": leg()}
    for name, img in parts.items():
        img.resize((96, 96), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
    print("android parts ->", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
