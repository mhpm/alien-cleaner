"""Arma el .aseprite de una fase del mutante con una capa por pieza.

python tools/build_rig_aseprite.py <fase>
Lee assets/sprites/mutations_player/fase <n>/pixel<size>/frames.json y layers/<capa>/
(de tools/make_infected_rig.py) y crea infected_phase<n>.aseprite: una capa por pieza
(de abajo arriba en el orden de frames.json), un frame por imagen, tags por animación
(idle, run, walk_up, combo_1..3) y la duración de cada frame (FPS, los mismos que
SETS en tools/slice_sprites.py). Usa Aseprite en modo batch con un script Lua.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASEPRITE = os.environ.get("ASEPRITE", r"C:\Program Files\Aseprite\Aseprite.exe")
FPS = {"idle": 9, "run": 14, "walk_up": 12, "combo_1": 16, "combo_2": 16, "combo_3": 16}

LUA = r"""
local data = %s
local spr = Sprite(data.size, data.size, ColorMode.RGB)
for i = 2, #data.frames do spr:newEmptyFrame() end
for i, f in ipairs(data.frames) do spr.frames[i].duration = f.ms / 1000 end
local first = spr.layers[1]
for li, lname in ipairs(data.layers) do
  local layer = (li == 1) and first or spr:newLayer()
  layer.name = lname
  for fi, f in ipairs(data.frames) do
    local img = Image{ fromFile = data.dir .. "/layers/" .. lname .. "/" .. f.name .. ".png" }
    if img and not img:isEmpty() then
      spr:newCel(layer, fi, img, Point(0, 0))
    end
  end
end
for _, t in ipairs(data.tags) do
  local tag = spr:newTag(t.from, t.to)
  tag.name = t.name
end
spr:saveAs(data.out)
"""


def lua_table(v) -> str:
    if isinstance(v, dict):
        return "{" + ", ".join("%s = %s" % (k, lua_table(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "{" + ", ".join(lua_table(x) for x in v) + "}"
    if isinstance(v, str):
        return '"' + v.replace("\\", "/") + '"'
    return str(v)


def main(n: int) -> None:
    base = os.path.join(ROOT, "assets", "sprites", "mutations_player", "fase %d" % n)
    d = next(os.path.join(base, x) for x in sorted(os.listdir(base))
             if x.startswith("pixel") and os.path.exists(os.path.join(base, x, "frames.json")))
    info = json.load(open(os.path.join(d, "frames.json")))
    frames, tags, i = [], [], 1
    for anim, count in info["anims"].items():
        tags.append({"name": anim, "from": i, "to": i + count - 1})
        for k in range(count):
            frames.append({"name": "%s_%d" % (anim, k), "ms": round(1000 / FPS[anim])})
        i += count
    data = {"size": info["size"], "dir": d, "out": os.path.join(d, "infected_phase%d.aseprite" % n),
            "layers": info["layers"], "frames": frames, "tags": tags}
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as f:
        f.write(LUA % lua_table(data))
        script = f.name
    try:
        subprocess.run([ASEPRITE, "-b", "--script", script], check=True)
    finally:
        os.remove(script)
    print("ok", data["out"], len(info["layers"]), "capas", len(frames), "frames")


if __name__ == "__main__":
    main(int(sys.argv[1]))
