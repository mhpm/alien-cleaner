"""ZED (unlockable fox character): frames, his shotgun and his CREW card.

python tools/make_zed_character.py
Sheets in tools/characters/zed/1x/<sheet>.png (pixel art at its own size, frames in
equal cells; tools/characters/zed/animations.json = frame counts and per-frame durations)
-> assets/characters/zed/<anim>_<i>.png at OUT_PX px per art pixel (crisp), on one
shared canvas with the feet at the bottom middle, and assets/characters/zed/zed.tres
(CharacterData: animations with the sheet's own timings, hand points, his ability).
Also: tools/characters/zed/shotgun_ref.png -> assets/guns/zed_shotgun.png (his personal
shotgun, ShotgunAbility) and banner_ref.webp -> assets/ui/crew/card_zed.png (CrewPanel).
His sheets are drawn at one consistent size (same head width and height in every pose):
no per-pose scaling, unlike the girl's.
"""
import json
import os

import numpy as np
from PIL import Image

import character_frames

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "characters", "zed")
OUT = os.path.join(ROOT, "assets", "characters", "zed")
RES = "res://assets/characters/zed/"
OUT_PX = 2  # frame pixels per art pixel (whole number: nearest stays crisp)
CARD_W = 790  # the CREW cards' width (assets/ui/crew/card_kid.png)
FAINT = 10  # banner pixels at or below this alpha are haze, not the card
# anim -> (sheet, frames to keep or None = all, loops)
ANIMS = {
    "idle": ("idle_right", None, True),
    "walk": ("walk_shoot_right", None, True),  # walks holding the arm out (walk_aims)
    "walk_up": ("walk_shoot_up", None, True),  # back view
    "walk_shoot_up": ("walk_shoot_up", None, True),
    "walk_shoot_down": ("walk_shoot_down", None, True),
    "shoot": ("shoot_right", [0, 2], True),  # its middle frame has grey legs (art slip)
    "shoot_down": ("walk_shoot_down", [0], False),
    "shoot_up": ("walk_shoot_up", [0], False),
    "hurt": ("hurt_right", None, False),
    "death": ("death_right", None, False),
}
LYING = ("death",)
BASE_MS = 100.0  # SpriteFrames speed 10 fps; each frame's duration = its ms / BASE_MS
# CharacterData fields (feet-relative frame px, facing right); hands measured on the frames
PROPS = {
    "character_id": '"zed"',
    "display_name": '"ZED"',
    "tagline": '"BLAST draws his SHOTGUN"',
    "accent": "Color(1, 0.48, 0.36, 1)",
    "height": "33.0",
    "hand": "Vector2(30, -40)",
    "aim_pose": "true",
    "shoot_hand": "Vector2(50, -70)",
    "shoot_down_hand": "Vector2(0, -52)",
    "shoot_up_hand": "Vector2(4, -118)",
    "walk_aims": "true",
    "walk_hand": "Vector2(50, -70)",
    "muzzle": "Vector2(62, -72)",
}


def build_frames(meta: dict) -> tuple:
    anims = {}
    keep = {}
    for anim, (sheet, frames, _loop) in ANIMS.items():
        n = int(meta[sheet]["frames"])
        anims[anim] = character_frames.cells(os.path.join(SRC, "1x", sheet + ".png"), n, OUT_PX, Image.NEAREST)
        if frames:
            keep[anim] = frames
    stand = character_frames.cells(os.path.join(SRC, "1x", "idle_right.png"), int(meta["idle_right"]["frames"]), OUT_PX, Image.NEAREST)
    frame_plan = character_frames.plan(anims, stand, LYING, 4 * OUT_PX, keep)
    return character_frames.save(OUT, frame_plan, keep=())


def write_tres(meta: dict, anchor: tuple) -> None:
    ext = []
    blocks = []
    for anim, (sheet, frames, loop) in ANIMS.items():
        ms = meta[sheet]["durations_ms"]
        idx = frames if frames else range(int(meta[sheet]["frames"]))
        fr = []
        for i, k in enumerate(idx):
            rid = "%s_%d" % (anim, i)
            ext.append('[ext_resource type="Texture2D" path="%s%s.png" id="%s"]' % (RES, rid, rid))
            fr.append('{\n"duration": %s,\n"texture": ExtResource("%s")\n}' % (round(ms[k] / BASE_MS, 3), rid))
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (
            ", ".join(fr), "true" if loop else "false", anim, 1000.0 / BASE_MS))
    ext.append('[ext_resource type="Texture2D" path="res://assets/characters/kid_astronaut/muzzle_flash.png" id="flash"]')
    ext.append('[ext_resource type="Script" path="res://scripts/data/character_data.gd" id="script"]')
    ext.append('[ext_resource type="Script" path="res://scripts/abilities/shotgun_ability.gd" id="ability"]')
    body_h = character_frames.drawn_height(os.path.join(OUT, "idle_0.png"))
    props = dict(PROPS, anchor="Vector2(%d, %d)" % anchor, body_height="%.1f" % body_h)
    lines = ['[gd_resource type="Resource" script_class="CharacterData" format=3]', ""]
    lines += ext
    lines += ["", '[sub_resource type="SpriteFrames" id="frames"]', "animations = [%s]" % ", ".join(blocks), ""]
    lines += ["[resource]", 'script = ExtResource("script")']
    lines += ["%s = %s" % (k, v) for k, v in props.items()]
    lines += ['frames = SubResource("frames")', 'muzzle_flash = ExtResource("flash")', 'ability = ExtResource("ability")', ""]
    with open(os.path.join(OUT, "zed.tres"), "w", newline="\n") as f:
        f.write("\n".join(lines))
    print("zed.tres: anchor", anchor, "body_height", body_h)


def shotgun() -> None:
    """His personal shotgun: the user's art, trimmed (grip / tip in ShotgunAbility)."""
    img = Image.open(os.path.join(SRC, "shotgun_ref.png")).convert("RGBA")
    img.crop(img.getbbox()).save(os.path.join(ROOT, "assets", "guns", "zed_shotgun.png"))


def card() -> None:
    """His CREW card: the user's banner cropped and sized like the kit's cards."""
    img = Image.open(os.path.join(SRC, "banner_ref.webp")).convert("RGBA")
    # the banner carries a faint haze (alpha 1-10) around the frame: drop it, crop to the frame
    a = np.array(img)
    a[..., 3] = np.where(a[..., 3] > FAINT, a[..., 3], 0)
    img = Image.fromarray(a)
    img = img.crop(img.getbbox())
    h = round(img.height * CARD_W / img.width)
    img.resize((CARD_W, h), Image.LANCZOS).save(os.path.join(ROOT, "assets", "ui", "crew", "card_zed.png"))
    print("card", (CARD_W, h))


if __name__ == "__main__":
    meta = json.load(open(os.path.join(SRC, "animations.json")))
    anchor, size = build_frames(meta)
    print("canvas", size)
    write_tres(meta, anchor)
    shotgun()
    card()
