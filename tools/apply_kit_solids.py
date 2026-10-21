"""Gives the pieces already placed in an arena scene the solid footprint their kit.json
now says (after a kit's collision changed), touching nothing else: only the `footprint`
lines of ArenaScenery nodes whose picture is in the kit are rewritten (scaled with the
piece's own width), so positions, pieces added or moved by hand, UIDs and the rest of
the file stay exactly as the editor saved them.

  python tools/apply_kit_solids.py scenes/arenas/arena_world_08_level_01.tscn biodome [walls/]
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    scene = os.path.join(ROOT, sys.argv[1])
    kit_name = sys.argv[2]
    only = sys.argv[3] if len(sys.argv) > 3 else ""
    kit_dir = "res://assets/decor/%s/" % kit_name
    kit = json.load(open(os.path.join(ROOT, "assets", "decor", kit_name, "kit.json"), encoding="utf-8"))
    items = {kit_dir + it["file"]: it for it in kit["items"]
             if it["file"].startswith(only) and isinstance(it.get("solid"), list)}
    text = open(scene, encoding="utf-8", newline="").read()
    ext = {m.group(2): m.group(1) for m in
           re.finditer(r'\[ext_resource type="Texture2D"[^\]]*path="([^"]+)" id="([^"]+)"\]', text)}
    blocks = re.split(r'(?=\n\[node )', text)
    changed = 0
    for i, b in enumerate(blocks):
        m = re.search(r'\ntexture = ExtResource\("([^"]+)"\)', b)
        it = items.get(ext.get(m.group(1))) if m else None
        if it is None or not re.search(r'\nfootprint = Vector2\([^)]*\)', b):
            continue
        wm = re.search(r'\nwidth = ([0-9.]+)', b)
        k = float(wm.group(1)) / float(it["width"]) if wm else 1.0
        fp = "footprint = Vector2(%s, %s)" % (round(it["solid"][0] * k, 2), round(it["solid"][1] * k, 2))
        nb = re.sub(r'\nfootprint = Vector2\([^)]*\)', "\n" + fp, b)
        if nb != b:
            blocks[i] = nb
            changed += 1
    open(scene, "w", encoding="utf-8", newline="").write("".join(blocks))
    print("apply kit solids: %d pieces updated in %s" % (changed, sys.argv[1]))


if __name__ == "__main__":
    main()
