"""Slice the supplied Playground UI sheet into reusable controls.

Run: python -B tools/make_playground_assets.py
Reference coordinates are in the original 1122x1402 sheet. Labels, numbers and
portraits are removed from reusable plates; Godot draws the live catalog on top.
The 941x1672 composition supplies the surrounding circuit art and static heading.
"""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "assets/ui/playground"


def erase(image, box):
    """Interpolate the navy fill between clean pixels beside a baked label."""
    a = np.array(image)
    x0, y0, x1, y1 = box
    k = np.linspace(0, 1, x1 - x0)[None, :, None]
    a[y0:y1, x0:x1] = (
        a[y0:y1, x0 - 1:x0].astype(float) * (1 - k)
        + a[y0:y1, x1:x1 + 1].astype(float) * k
    ).astype(np.uint8)
    return Image.fromarray(a)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(HERE / "playground_elements_ref.png").convert("RGBA")
    reference = Image.open(HERE / "playground_ref.png").convert("RGB")
    bg = np.array(reference)
    # Preserve the title, subtitle and outer circuits; the live body uses its own
    # plates. A subtle navy glow avoids remnants of the painted sample cards.
    yy, xx = np.mgrid[222:1630, 18:924]
    glow = np.exp(-(((xx - 470) / 440) ** 2 + ((yy - 810) / 860) ** 2))
    bg[222:1630, 18:924] = np.stack(
        [2 + 3 * glow, 11 + 13 * glow, 23 + 19 * glow], axis=-1
    ).astype(np.uint8)
    Image.fromarray(bg).save(OUT / "bg.webp", quality=95)

    sheet.crop((99, 45, 238, 181)).save(OUT / "back.png")
    active = sheet.crop((74, 265, 568, 377))
    erase(active, (62, 32, 411, 81)).save(OUT / "tab_active.png")
    idle = sheet.crop((568, 265, 1052, 377))
    erase(idle, (110, 33, 361, 80)).save(OUT / "tab_idle.png")
    search = sheet.crop((73, 379, 1052, 474))
    erase(search, (108, 31, 410, 68)).save(OUT / "search.png")

    card = sheet.crop((73, 476, 1052, 645))
    # Clear the sample +/- counter. Keep the portrait socket at the left.
    card = erase(card, (679, 34, 952, 137))
    card = erase(card, (26, 24, 180, 148))
    card.save(OUT / "card.png")
    sheet.crop((101, 498, 249, 625)).save(OUT / "portrait_frame.png")
    for name, box in {
        "ufo": (110, 646, 301, 804),
        "gunship": (353, 646, 545, 805),
        "scout": (599, 646, 786, 804),
        "zorp_drone": (827, 646, 986, 804),
    }.items():
        portrait = sheet.crop(box)
        portrait.crop(portrait.getbbox()).save(OUT / f"portrait_{name}.png")
    sheet.crop((763, 516, 845, 609)).save(OUT / "minus.png")
    sheet.crop((943, 516, 1026, 609)).save(OUT / "plus.png")
    counter = sheet.crop((851, 516, 938, 609))
    erase(counter, (26, 27, 61, 75)).save(OUT / "counter.png")
    clear = sheet.crop((464, 1172, 725, 1281))
    erase(clear, (65, 34, 192, 72)).save(OUT / "button.png")
    # PLAY's painted label is intentional: it is the same in every state.
    sheet.crop((727, 1168, 1114, 1284)).save(OUT / "play.png")

    toggle = sheet.crop((985, 1084, 1102, 1156))
    toggle.save(OUT / "toggle_off.png")
    # Mirror the supplied switch and recolor its track for the active state.
    a = np.array(toggle.transpose(Image.Transpose.FLIP_LEFT_RIGHT))
    mask = (a[:, :, 3] > 0) & (a[:, :, 0] < 100) & (a[:, :, 2] > a[:, :, 0] * 1.3)
    a[mask, :3] = np.clip(
        a[mask, :3].astype(float) * np.array([0.65, 2.0, 0.6])
        + np.array([8, 22, 3]), 0, 255
    ).astype(np.uint8)
    Image.fromarray(a).save(OUT / "toggle_on.png")
    # The summary plate doubles as a compact switch row, with dynamic text.
    panel = sheet.crop((12, 1178, 462, 1274))
    erase(panel, (42, 26, 413, 70)).save(OUT / "panel.png")
    count = len(list(OUT.glob("*.png"))) + len(list(OUT.glob("*.webp")))
    print(f"Playground: {count} reusable assets in {OUT}")


if __name__ == "__main__":
    main()
