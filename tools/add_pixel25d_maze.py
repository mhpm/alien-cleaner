"""Adds the MAZE CHAMBER to the pixel 2.5D prototype arena, in place.

The arena (scenes/arenas/arena_proto_pixel25d.tscn) is retouched by hand in the editor,
so this script never rebuilds it: it only APPENDS to the saved file
  * floor tiles in the empty area right of the corridor (cells that have none),
  * new ext_resources (kit pictures, two scripts),
  * nodes inside "MazeChamber" containers (Obstacles / Decorations / GameplayObjects),
and refuses to run when a MazeChamber is already there.

The chamber (x 768-2880, y 0-896): a 16 x 5 maze of 128 x 163 cells (seeded DFS, one
true route plus a few loops) from the corridor door (bottom left) to the VAULT (top
right: the double specimen tank on its stair platform, a chest). Horizontal walls are
the maze kit's pillar walls, vertical ones the side-wall caps. Security cameras watch
the lanes of the route, two sentry bots sweep long corridors, the dead ends hold loot,
an alien nest and alien rubble.
  python tools/add_pixel25d_maze.py [scene.tscn]
"""
import base64
import os
import random
import re
import struct
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
SCENE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "scenes", "arenas", "arena_proto_pixel25d.tscn")
KIT = "res://assets/decor/pixel_lab/"
KIT_DIR = os.path.join(ROOT, "assets", "decor", "pixel_lab")

SEED = 7
COLS, ROWS = 16, 5
X0, Y0 = 800, 64  # top-left of the maze cells
CW, CH = 128, 163
LEFT, RIGHT = 784, 2864  # side walls (32 wide)
TOP_FEET, BOTTOM_FEET = 51, 896  # outer walls: the cap touches the top edge / feet on the bottom edge
DOOR = (768, 832)  # corridor opening in the left wall
VAULT = [(0, 14), (0, 15)]
ENTRY = (4, 0)

rng = random.Random(SEED)
_uid_seen = set()


def uid():
    while True:
        u = rng.randint(10 ** 8, 2 * 10 ** 9)
        if u not in _uid_seen:
            _uid_seen.add(u)
            return u


def kit_path(name):
    for d in os.listdir(KIT_DIR):
        if os.path.isfile(os.path.join(KIT_DIR, d, name + ".png")):
            return KIT + d + "/" + name + ".png"
    raise SystemExit("missing kit piece " + name)


def size_of(name):
    from PIL import Image
    p = kit_path(name).replace(KIT, "")
    return Image.open(os.path.join(KIT_DIR, p)).size


# ---------------------------------------------------------------- maze
def carve():
    """Walls between cells: True = wall. DFS from the entry, then a few extra openings."""
    h = [[True] * COLS for _ in range(ROWS - 1)]  # h[r][c]: between (r, c) and (r + 1, c)
    v = [[True] * (COLS - 1) for _ in range(ROWS)]  # v[r][c]: between (r, c) and (r, c + 1)
    seen = {ENTRY}
    stack = [ENTRY]
    while stack:
        r, c = stack[-1]
        nxt = [(r + dr, c + dc) for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1))
               if 0 <= r + dr < ROWS and 0 <= c + dc < COLS and (r + dr, c + dc) not in seen]
        if not nxt:
            stack.pop()
            continue
        nr, nc = rng.choice(nxt)
        if nr != r:
            h[min(r, nr)][c] = False
        else:
            v[r][min(c, nc)] = False
        seen.add((nr, nc))
        stack.append((nr, nc))
    v[0][14] = False  # the vault is one room of two cells
    for _ in range(9):  # loops: the maze is not a single corridor
        if rng.random() < 0.5:
            r, c = rng.randrange(ROWS - 1), rng.randrange(COLS)
            if (r, c) not in VAULT and (r + 1, c) not in VAULT:
                h[r][c] = False
        else:
            r, c = rng.randrange(ROWS), rng.randrange(COLS - 1)
            if (r, c) not in VAULT and (r, c + 1) not in VAULT:
                v[r][c] = False
    return h, v


def neighbours(h, v, r, c):
    out = []
    if r > 0 and not h[r - 1][c]:
        out.append((r - 1, c))
    if r < ROWS - 1 and not h[r][c]:
        out.append((r + 1, c))
    if c > 0 and not v[r][c - 1]:
        out.append((r, c - 1))
    if c < COLS - 1 and not v[r][c]:
        out.append((r, c + 1))
    return out


def route(h, v):
    """Cells of the shortest path from the entry to the vault (BFS)."""
    prev = {ENTRY: None}
    queue = [ENTRY]
    while queue:
        cell = queue.pop(0)
        for n in neighbours(h, v, *cell):
            if n not in prev:
                prev[n] = cell
                queue.append(n)
    assert VAULT[0] in prev, "vault unreachable"
    path, cell = [], VAULT[0]
    while cell is not None:
        path.append(cell)
        cell = prev[cell]
    return path[::-1]


def cell_center(r, c):
    return X0 + c * CW + CW / 2, Y0 + r * CH + CH / 2


# ---------------------------------------------------------------- scene text
class Out:
    def __init__(self):
        self.res = {}  # path -> id
        self.nodes = []

    def tex(self, name):
        path = kit_path(name)
        if path not in self.res:
            self.res[path] = "p25m_" + name
        return self.res[path]

    def scenery(self, parent, name, piece, x, y, foot=None, bullets=False, fade=False,
                flat=False, flip=False, tint=None):
        w, _ = size_of(piece)
        lines = ['[node name="%s" type="Node2D" parent="%s" unique_id=%d]' % (name, parent, uid()),
                 "position = Vector2(%g, %g)" % (x, y),
                 'script = ExtResource("7_rid1u")',
                 'texture = ExtResource("%s")' % self.tex(piece),
                 "width = %.1f" % w]
        if flip:
            lines.append("flip_h = true")
        if tint:
            lines.append("tint = Color(%s)" % tint)
        if foot:
            lines.append("footprint = Vector2(%g, %g)" % foot)
        if bullets:
            lines.append("blocks_bullets = true")
        if flat:
            lines.append("flat = true")
        if fade:
            lines.append("fade_behind = true")
        lines.append("pixel_art = true")
        self.nodes.append("\n".join(lines))

    def raw(self, text):
        self.nodes.append(text)


def build(out, h, v):
    obs, dec, gp = "Obstacles/MazeChamber", "Decorations/MazeChamber", "GameplayObjects/MazeChamber"
    for parent, sort in ((obs, True), (dec, True), (gp, True)):
        out.raw('[node name="MazeChamber" type="Node2D" parent="%s" unique_id=%d]\ny_sort_enabled = true'
                % (parent.split("/")[0], uid()))
    n = [0]

    def nm(base):
        n[0] += 1
        return "%s%d" % (base, n[0])

    wall_w, _ = size_of("m_wall")

    def hwall(x, feet):
        out.scenery(obs, nm("MazeWall"), "m_wall", x, feet, (wall_w, 12), True, True, flip=rng.random() < 0.5)

    def vrun(x, top, bottom, end=True):
        """Side-wall caps from `top` down to `bottom` (feet), the last one with its face."""
        f = top + 32
        while f <= bottom + 0.5:
            last = f + 32 > bottom + 0.5
            out.scenery(obs, nm("MazeSide"), "side_wall_end" if last and end else "side_wall", x, f,
                        (32, 32), True, True)
            f += 32

    # outer walls of the chamber
    for c in range(COLS):
        x = X0 + c * CW + CW / 2
        hwall(x, TOP_FEET)
        hwall(x, BOTTOM_FEET)
    feet = list(range(74, BOTTOM_FEET, 32)) + [BOTTOM_FEET]

    def in_door(f):  # a left piece whose footprint (f - 32 .. f) crosses the opening
        return f > DOOR[0] and f - 32 < DOOR[1]

    for i, f in enumerate(feet):
        last = i == len(feet) - 1
        out.scenery(obs, nm("MazeSide"), "side_wall_end" if last else "side_wall", RIGHT, f, (32, 32), True, True)
        if not in_door(f):
            above_door = not last and in_door(feet[i + 1])
            out.scenery(obs, nm("MazeSide"), "side_wall_end" if last or above_door else "side_wall", LEFT, f,
                        (32, 32), True, True)
    # the corridor: a wall along its top, low rails along its bottom
    hwall(704, DOOR[0])
    rail_w, _ = size_of("m_rail")
    for x in (664, 704, 744):
        out.scenery(obs, nm("CorridorRail"), "m_rail", x, DOOR[1] + 8, (rail_w - 6, 8))
    # inner walls
    for r in range(ROWS - 1):
        for c in range(COLS):
            if h[r][c]:
                hwall(X0 + c * CW + CW / 2, Y0 + (r + 1) * CH)
    for c in range(COLS - 1):
        r = 0
        while r < ROWS:
            if not v[r][c]:
                r += 1
                continue
            r1 = r
            while r1 + 1 < ROWS and v[r1 + 1][c]:
                r1 += 1
            vrun(X0 + (c + 1) * CW, Y0 + r * CH - (12 if r > 0 else 0), Y0 + (r1 + 1) * CH)
            r = r1 + 1
    return nm


def furnish(out, h, v, path, nm):
    obs, dec, gp = "Obstacles/MazeChamber", "Decorations/MazeChamber", "GameplayObjects/MazeChamber"
    on_path = set(path)

    def thing(piece, x, y, shadow="shadow_m"):
        w, _ = size_of(piece)
        out.scenery(obs, nm("MazeProp"), piece, x, y, (max(8, w - 6), min(12, max(6, round(w * 0.3)))), True, True)
        out.scenery(dec, nm("MazeShadow"), shadow, x + 3, y + 3, flat=True)

    def decal(piece, x, y, flip=False):
        out.scenery(dec, nm("MazeDecal"), piece, x, y, flat=True, flip=flip)

    # the vault: double specimen tank on the stair platform, a chest, hazard plates at the door
    vx = X0 + 15 * CW
    vy = Y0
    # (kept clear of the vault's lower wall, whose 3/4 body rises ~50 above its feet)
    decal("m_plate_big", vx - 46, vy + 96)
    decal("m_plate_big", vx + 46, vy + 96)
    thing("m_tank_side", vx - 78, vy + 52, "shadow_l")
    thing("m_tank_double", vx + 62, vy + 70, "shadow_l")
    thing("m_stairs", vx - 4, vy + 98, "shadow_l")
    out.raw('[node name="VaultChest" type="Node2D" parent="%s" unique_id=%d]\nposition = Vector2(%g, %g)\n'
            'texture_filter = 4\nscript = ExtResource("p25m_chest")\nobject_id = "maze_vault"' % (gp, uid(), vx - 4, vy + 124))
    # dead ends (one way in): loot, a nest, rubble
    dead = [(r, c) for r in range(ROWS) for c in range(COLS)
            if len(neighbours(h, v, r, c)) == 1 and (r, c) not in VAULT and (r, c) != ENTRY]
    rng.shuffle(dead)
    loot = [("m_crate_stack", "m_crate_yellow"), ("m_crate_red", "m_crate_hazard"), ("m_desk", None),
            ("m_machine", "m_crate"), ("m_lockers", None), ("m_crate_striped", "m_crate")]
    for i, (r, c) in enumerate(dead):
        cx, cy = cell_center(r, c)
        if i == 0:  # the nest: aliens keep coming out of a dead end
            out.raw('[node name="MazeNest" type="Node2D" parent="%s" unique_id=%d]\nposition = Vector2(%g, %g)\n'
                    'script = ExtResource("p25m_nest")\nobject_id = "maze_nest"\n'
                    'enemies = Array[ExtResource("3_7ogbf")]([SubResource("Resource_07ua1"), SubResource("Resource_oti1y")])'
                    % (gp, uid(), cx, cy + 10))
            decal("m_goo_big", cx - 30, cy + 40)
            decal("goo_b", cx + 34, cy + 30)
            continue
        if i == 1:
            thing("m_rubble_blocks", cx + 30, cy + 44)
            decal("m_rubble", cx - 30, cy + 40)
            continue
        if i - 2 < len(loot):
            a, b = loot[i - 2]
            thing(a, cx - 26, cy + 30)
            if b:
                thing(b, cx + 26, cy + 40)
    # security cameras on the walls above the route, sweeping the lane below them
    cams = [(r, c) for (r, c) in path if r > 0 and h[r - 1][c] and (r, c) not in VAULT]
    rng.shuffle(cams)
    for i, (r, c) in enumerate(sorted(cams[:6])):
        x = X0 + c * CW + CW / 2 + rng.choice((-30, 30))
        out.raw('[node name="MazeCamera%d" type="Node2D" parent="%s" unique_id=%d]\nposition = Vector2(%g, %g)\n'
                'script = ExtResource("57_76sk0")\nmount_height = 30.0\nview_range = 140.0\nsweep_deg = 45.0\n'
                'alarm_squad = Array[ExtResource("3_7ogbf")]([SubResource("Resource_07ua1"), SubResource("Resource_oti1y")])\n'
                'texture = ExtResource("%s")\nwidth = %.1f\npixel_art = true\nobject_id = "maze_cam_%d"'
                % (i + 1, obs, uid(), x, Y0 + r * CH + 1, out.tex("m_cam" if i % 2 else "m_cam_b"),
                   size_of("m_cam")[0], i + 1))
    # sentry bots: cameras on legs in the long corridors, sweeping both ways
    runs = [(r, c) for (r, c) in path if 0 < c < COLS - 1 and not v[r][c - 1] and not v[r][c]
            and (r, c) not in VAULT]
    rng.shuffle(runs)
    for i, (r, c) in enumerate(runs[:2]):
        cx, cy = cell_center(r, c)
        out.raw('[node name="MazeSentry%d" type="Node2D" parent="%s" unique_id=%d]\nposition = Vector2(%g, %g)\n'
                'script = ExtResource("57_76sk0")\nmount_height = 14.0\nview_range = 120.0\nfov_deg = 34.0\n'
                'facing_deg = %g\nsweep_deg = 75.0\nsweep_time = 3.5\n'
                'alarm_squad = Array[ExtResource("3_7ogbf")]([SubResource("Resource_07ua1"), SubResource("Resource_oti1y")])\n'
                'texture = ExtResource("%s")\nwidth = %.1f\nfootprint = Vector2(14, 8)\nblocks_bullets = true\n'
                'pixel_art = true\nobject_id = "maze_sentry_%d"'
                % (i + 1, obs, uid(), cx, cy + 30, 0.0 if i == 0 else 180.0, out.tex("m_sentry"),
                   size_of("m_sentry")[0], i + 1))
    # low barriers that narrow some passages (bodies stop, bullets fly over), floor details
    for r, c in rng.sample([p for p in path if p not in VAULT and p != ENTRY], 5):
        cx, cy = cell_center(r, c)
        side = rng.choice((-1, 1))
        out.scenery(obs, nm("MazeRail"), "m_rail_s", cx + side * 40, cy - 30, (size_of("m_rail_s")[0] - 6, 8))
    for _ in range(26):
        r, c = rng.randrange(ROWS), rng.randrange(COLS)
        if (r, c) in VAULT:
            continue
        cx, cy = cell_center(r, c)
        piece = rng.choice(["m_grate", "m_plate", "m_plate_hazard", "goo_s", "goo_xs", "goo_xs2", "rocks_s", "vent_a"])
        decal(piece, cx + rng.randint(-40, 40), cy + rng.randint(-20, 50), rng.random() < 0.5)


# ---------------------------------------------------------------- floor
def add_floor(text):
    """Appends drawn floor cells (source 0) to the Floor layer where there are none."""
    m = re.search(r'(\[node name="Floor" type="TileMapLayer"[^\n]*\n(?:[^\n\[]*\n)*?tile_map_data = PackedByteArray\(")([A-Za-z0-9+/=]*)("\))', text)
    data = base64.b64decode(m.group(2))
    assert (len(data) - 2) % 12 == 0, "unexpected TileMapLayer data size"
    version = struct.unpack_from("<H", data, 0)[0]
    assert version == 0, "unknown TileMapLayer data format %d" % version
    used = set()
    for i in range(2, len(data), 12):
        x, y = struct.unpack_from("<hh", data, i)
        used.add((x, y))
    fr = random.Random(SEED + 1)
    extra = bytearray()
    for y in range(28):
        for x in range(24, 90):
            if (x, y) in used:
                continue
            t = (0, 0) if fr.random() < 0.55 else (1, 0)
            r = fr.random()
            if r < 0.012:
                t = (2, 0)
            elif r < 0.035:
                t = (0, 1)
            elif r < 0.07:
                t = (2, 1)
            extra += struct.pack("<hhHHHH", x, y, 0, t[0], t[1], 0)
    new = base64.b64encode(data + bytes(extra)).decode()
    return text[:m.start(2)] + new + text[m.end(2):], len(extra) // 12


def main():
    text = open(SCENE, encoding="utf-8", newline="").read()
    if "MazeChamber" in text:
        sys.exit("The maze chamber is already in the scene: nothing done.")
    nl = "\r\n" if "\r\n" in text else "\n"
    h, v = carve()
    path = route(h, v)
    out = Out()
    nm = build(out, h, v)
    furnish(out, h, v, path, nm)
    text, cells = add_floor(text)
    # new ext_resources after the last one
    res = ['[ext_resource type="Texture2D" path="%s" id="%s"]' % (p, i) for p, i in out.res.items()]
    res.append('[ext_resource type="Script" path="res://scripts/arena/components/arena_chest.gd" id="p25m_chest"]')
    res.append('[ext_resource type="Script" path="res://scripts/arena/components/alien_nest.gd" id="p25m_nest"]')
    last = list(re.finditer(r"^\[ext_resource [^\n]*\]$", text, re.M))[-1]
    text = text[:last.end()] + nl + nl.join(res) + text[last.end():]
    text = text.rstrip() + nl + nl + (nl + nl).join(t.replace("\n", nl) for t in out.nodes) + nl
    open(SCENE, "w", encoding="utf-8", newline="").write(text)
    print("maze chamber added: %d nodes, %d floor cells, route %d cells" % (len(out.nodes), cells, len(path)))


if __name__ == "__main__":
    main()
