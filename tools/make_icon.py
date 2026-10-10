"""Game icon from the user's art: tools/game_icon_ref.webp -> assets/icon/.

  python tools/make_icon.py

  icon.png           512, the project icon (application/config/icon): art on a deep-space
                     rounded square
  icon_192.png       Android launcher (legacy)
  icon_fg_432.png    Android adaptive foreground: the art inside the 66% safe circle
  icon_bg_432.png    Android adaptive background: the deep-space gradient with a few stars
  icon_mono_432.png  Android 13 themed icon: white silhouette of the foreground
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "game_icon_ref.webp")
OUT = os.path.join(ROOT, "assets", "icon")
TOP = (40, 30, 92)
BOTTOM = (12, 10, 34)


def art() -> Image.Image:
    a = Image.open(SRC).convert("RGBA")
    return a.crop(a.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def space(side: int, seed: int = 7) -> Image.Image:
    bg = Image.new("RGBA", (side, side))
    d = ImageDraw.Draw(bg)
    for y in range(side):
        k = y / (side - 1)
        d.line([(0, y), (side, y)], fill=tuple(round(TOP[i] * (1 - k) + BOTTOM[i] * k) for i in range(3)) + (255,))
    # a soft green glow where the slime is, and a few stars
    glow = Image.new("RGBA", (side, side))
    ImageDraw.Draw(glow).ellipse([side * 0.45, side * 0.35, side * 1.05, side * 0.95], fill=(90, 220, 60, 70))
    bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(side * 0.12)))
    rnd = random.Random(seed)
    for _ in range(side // 9):
        x, y = rnd.random() * side, rnd.random() * side
        r = rnd.choice([1, 1, 1, 2]) * side / 432
        d.ellipse([x - r, y - r, x + r, y + r], fill=(220, 235, 255, rnd.randint(90, 220)))
    return bg


def fit(img: Image.Image, box: int) -> Image.Image:
    k = box / max(img.size)
    return img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)


def on(canvas: Image.Image, img: Image.Image) -> Image.Image:
    canvas.alpha_composite(img, ((canvas.width - img.width) // 2, (canvas.height - img.height) // 2))
    return canvas


def rounded(img: Image.Image, r: float) -> Image.Image:
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.width - 1, img.height - 1], round(img.width * r), fill=255)
    img.putalpha(m)
    return img


def main() -> None:
    a = art()
    big = rounded(on(space(512), fit(a, 468)), 0.18)
    big.save(os.path.join(OUT, "icon.png"))
    rounded(on(space(192), fit(a, 176)), 0.18).save(os.path.join(OUT, "icon_192.png"))
    fg = on(Image.new("RGBA", (432, 432)), fit(a, 300))  # 66% safe zone of 432 = 288 (+ a hair)
    fg.save(os.path.join(OUT, "icon_fg_432.png"))
    space(432).save(os.path.join(OUT, "icon_bg_432.png"))
    mono = Image.new("RGBA", fg.size, (255, 255, 255, 0))
    mono.putalpha(fg.getchannel("A"))
    mono.save(os.path.join(OUT, "icon_mono_432.png"))
    for n in ["icon", "icon_192", "icon_fg_432", "icon_bg_432", "icon_mono_432"]:
        print(n)


if __name__ == "__main__":
    main()
