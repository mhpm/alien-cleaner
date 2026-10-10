"""First-run intro cinematic: the user's 9 scenes tools/intro/scene_<n>.webp (stickers on a
transparent background) -> assets/ui/intro/panel_<n>.png, trimmed and capped at MAX px.
Order = the story (IntroScreen.PANELS).

  python tools/make_intro_assets.py
"""
import glob
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "intro")
OUT = os.path.join(ROOT, "assets", "ui", "intro")
MAX = 900


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in glob.glob(os.path.join(OUT, "panel_*.png*")):
        os.remove(old)
    n = 1
    while os.path.exists(os.path.join(SRC, "scene_%d.webp" % n)):
        img = Image.open(os.path.join(SRC, "scene_%d.webp" % n)).convert("RGBA")
        a = img.getchannel("A").point(lambda v: 255 if v > 8 else 0)
        img = img.crop(a.getbbox())
        img.putalpha(img.getchannel("A").point(lambda v: 0 if v <= 8 else v))
        if max(img.size) > MAX:
            k = MAX / max(img.size)
            img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
        img.save(os.path.join(OUT, "panel_%d.png" % n))
        print("panel_%d" % n, img.size)
        n += 1


if __name__ == "__main__":
    main()
