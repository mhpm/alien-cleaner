"""Builds the room + HUD art from tools/room_ref.webp (957x1644).

Room mapping: the walkable interior px (60,330)-(897,1490) is the 10x14-tile room
(160x224 world units, 16 units per tile).  Outputs into assets/room/:
  room_bg.webp         wall frame + door + clean rebuilt floor (no props, no UI)
  prop_<name>.png      crates, barrels, crystals... with the floor keyed out
  hud_<name>.png       HUD panels (values erased), joystick, blast button
"""
import os
import random
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "room")

INTERIOR = (60, 330, 897, 1490)
COLS, ROWS = 10, 14
TILE_W = (INTERIOR[2] - INTERIOR[0]) / COLS
TILE_H = (INTERIOR[3] - INTERIOR[1]) / ROWS

PLATE = (540, 840, 642, 946)  # one clean floor plate (edges included)
LOGO = (352, 632, 606, 824)

# (box, mode): "key" = flood the floor away, "rect" = keep the rectangle, "green" = slime only
PROPS = {
    "crate": ((238, 438, 382, 558), "rect"),
    "barrel": ((760, 1138, 850, 1272), "key"),
    "canister": ((110, 1096, 190, 1240), "key"),
    "planter": ((60, 486, 186, 634), "rect"),
    "locker": ((718, 530, 772, 636), "rect"),
    "vent": ((426, 483, 534, 564), "rect"),
    "grate": ((140, 410, 220, 474), "rect"),
    "splat1": ((232, 545, 310, 645), "green"),
    "splat2": ((600, 1195, 690, 1295), "green"),
    "splat3": ((816, 1030, 897, 1180), "green"),
}

HUD = {
    "hp": (16, 10, 354, 80),
    "room": (356, 10, 600, 80),
    "coins": (646, 10, 840, 80),
    "pause": (866, 8, 940, 82),
    "joystick": (40, 1285, 310, 1555),
    "knob": (112, 1352, 238, 1478),
    "blast": (684, 1314, 918, 1552),
}


def key_out(img, tol=40):
    """Flood the floor away from the crop border (colours close to the border median)."""
    a = np.asarray(img.convert("RGBA")).astype(int)
    h, w = a.shape[:2]
    border = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    bg = np.median(border, axis=0)
    seen = np.zeros((h, w), bool)
    q = deque([(y, x) for x in range(w) for y in (0, h - 1)] + [(y, x) for y in range(h) for x in (0, w - 1)])
    while q:
        y, x = q.popleft()
        if seen[y, x]:
            continue
        if np.abs(a[y, x, :3] - bg).sum() > tol * 3:
            continue
        seen[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx]:
                q.append((ny, nx))
    a[seen, 3] = 0
    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    return out.crop(out.getbbox())


def circle_crop(img, inner_fill=None):
    w, h = img.size
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).ellipse((1, 1, w - 2, h - 2), fill=255)
    out = img.convert("RGBA")
    out.putalpha(m)
    return out


def interp_rows(a, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        left = a[y, x0 - 1].astype(float)
        right = a[y, x1].astype(float)
        for x in range(x0, x1):
            k = (x - x0) / float(x1 - x0)
            a[y, x] = (left * (1 - k) + right * k).astype(np.uint8)


def glow_only(img: Image.Image, floor: float = 120.0) -> Image.Image:
    """Keep only the glowing lines of a touch control (neon ring, arrows, knob rim, comet)
    and turn the painted room behind them into a faint translucent tint."""
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    bright = np.maximum(g, b)
    blueish = np.clip((b - r - 20.0) / 50.0, 0.0, 1.0)
    glow = np.clip((bright - floor) / 70.0, 0.0, 1.0) * np.maximum(blueish, np.clip((r + g + b - 600.0) / 90.0, 0.0, 1.0))
    base = np.array([20.0, 60.0, 90.0])  # the translucent fill
    out = np.empty_like(a)
    out[..., :3] = rgb * glow[..., None] + base * (1.0 - glow[..., None])
    out[..., 3] = np.where(alpha > 0, np.maximum(glow * 255.0, 60.0), 0.0) * (alpha / 255.0)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    random.seed(11)
    src = Image.open(os.path.join(HERE, "room_ref.webp")).convert("RGB")
    a = np.asarray(src).copy()

    # ---- props / HUD crops from the untouched art
    for name, (box, mode) in PROPS.items():
        crop = src.crop(box)
        if mode == "key":
            img = key_out(crop, 30)
        elif mode == "green":
            ga = np.asarray(crop.convert("RGBA")).copy().astype(int)
            g = (ga[:, :, 1] > ga[:, :, 0] + 35) & (ga[:, :, 1] > ga[:, :, 2] + 25)
            ga[~g, 3] = 0
            img = Image.fromarray(ga.astype(np.uint8), "RGBA")
            img = img.crop(img.getbbox())
        else:
            img = crop.convert("RGBA")
        img.save(os.path.join(OUT, f"prop_{name}.png"))
    for name, box in HUD.items():
        crop = src.crop(box)
        ca = np.asarray(crop).copy()
        if name == "hp":
            ca[18:52, 72:327] = (26, 14, 24)  # empty bar trough (filled live)
        elif name == "room":
            interp_rows(ca, (22, 14, 222, 56))
        elif name == "coins":
            interp_rows(ca, (66, 14, 184, 56))
        crop = Image.fromarray(ca)
        if name in ("joystick", "blast", "knob"):
            img = circle_crop(crop)
            if name == "joystick":  # remove the baked knob, keep the ring + arrows
                ja = np.asarray(img).copy()
                cx, cy, r = 135, 130, 66
                yy, xx = np.mgrid[0:ja.shape[0], 0:ja.shape[1]]
                knob = (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r
                ja[knob, :3] = (18, 44, 66)
                ja[knob, 3] = 150
                img = Image.fromarray(ja, "RGBA")
            img = glow_only(img, 175.0 if name == "blast" else 120.0)
            if name == "knob":  # a clean glassy disc inside the bright rim
                ka = np.asarray(img).copy()
                h, w = ka.shape[:2]
                yy, xx = np.mgrid[0:h, 0:w]
                inner = (xx - w / 2) ** 2 + (yy - h / 2) ** 2 <= (w * 0.40) ** 2
                ka[inner] = (60, 170, 200, 90)
                img = Image.fromarray(ka, "RGBA")
            img.save(os.path.join(OUT, f"hud_{name}.png"))
        else:
            crop.save(os.path.join(OUT, f"hud_{name}.png"))

    # ---- rebuild the floor on the 10x14 grid from clean plates
    base = np.asarray(src.crop(PLATE)).copy()
    # the plate's bottom-left corner touches the astronaut's aura: patch it from the top-left
    qh, qw = base.shape[0] // 2, base.shape[1] // 2
    base[qh:, :qw] = base[:qh, :qw][::-1][: base.shape[0] - qh]
    size = (int(round(TILE_W)) + 1, int(round(TILE_H)) + 1)
    plates = []
    for flip_x in (False, True):
        for flip_y in (False, True):
            p = base[:, ::-1] if flip_x else base
            p = p[::-1] if flip_y else p
            plates.append(np.asarray(Image.fromarray(np.ascontiguousarray(p)).resize(size, Image.LANCZOS)))
    logo = src.crop(LOGO)
    for r in range(1, ROWS):
        for c in range(COLS):
            x = int(round(INTERIOR[0] + c * TILE_W))
            y = int(round(INTERIOR[1] + r * TILE_H))
            p = plates[random.randrange(4)].astype(float) * random.uniform(0.93, 1.05)
            p = np.clip(p, 0, 255).astype(np.uint8)
            h = min(p.shape[0], INTERIOR[3] - y)
            w = min(p.shape[1], INTERIOR[2] - x)
            a[y:y + h, x:x + w] = p[:h, :w]
    img = Image.fromarray(a)
    # faint planet emblem in the middle, feathered in
    m = Image.new("L", logo.size, 0)
    ImageDraw.Draw(m).ellipse((10, 10, logo.width - 10, logo.height - 10), fill=180)
    m = m.filter(ImageFilter.GaussianBlur(10))
    cx = (INTERIOR[0] + INTERIOR[2]) // 2 - logo.width // 2
    cy = int(INTERIOR[1] + 7 * TILE_H) - logo.height // 2
    img.paste(logo, (cx, cy), m)
    a = np.asarray(img).copy()

    # ---- side walls hidden behind the baked joystick / blast button: copy from above
    a[1290:1490, 0:60] = a[1090:1290, 0:60]
    a[1318:1490, 897:957] = a[1118:1290, 897:957]
    # bottom wall corners under the controls: mirrored top-wall cap + clean lower wall
    cap_l = a[88:168, 0:312][::-1]
    cap_r = a[88:168, 645:957][::-1]
    a[1484:1564, 0:312] = cap_l
    a[1484:1564, 645:957] = cap_r
    # HUD strip -> plain dark (the live HUD is drawn there)
    a[0:86] = (10, 13, 26)
    Image.fromarray(a).save(os.path.join(OUT, "room_bg.webp"), quality=92)
    print("ok", TILE_W, TILE_H)


if __name__ == "__main__":
    main()
