class_name ForgeMap
extends RefCounted
## World 5 THE FORGE: an EXPLORE map built wall by wall from the forge kit
## (tools/w5_build_kit_ref.webp -> python tools/make_forge_walls.py -> assets/rooms/w5/build/)
## instead of square room paintings. The map is a lattice of CW x CH cells; walls run on
## the cell edges: a POST on every wall node, a horizontal segment (slab + glowing front
## face) between two posts side by side and a column SHAFT between two posts on top of
## each other, so any shape can be drawn.
## Layout: the cells are split BSP-style into areas, some splits leave a 1-cell CORRIDOR
## between both halves; each area becomes a hall, a pillared hall (free-standing posts),
## a ring (a walled lava pit in the middle), a split hall (a wall across with gaps), an
## L-shaped room or a MAZE of 1-cell passages. Every area is joined to its sibling by 1-2
## doorways, `maze` share of the other neighbours get one more (loops), and a repair pass
## makes sure everything is reachable from the start. Hall corners may hold one of the 4
## corner blocks of machinery. Explore reads `leaves`, `solids()`, `spots()`; the drawing
## is split in chunks (floor / walls) so whatever is off screen is culled, and `flow()`
## gives the aliens a way around the walls (Enemy detour).
## Config (survival "explore"): "build": "forge" | "kit", "set": kit (w5 / w6), "cells":
## [w, h], "cores" + "vats" = objective areas, "maze": k, "mazes": n (at least).

## Look of each kit (assets/rooms/<set>/build/ from python tools/make_forge_walls.py <set>):
## glow = colour of the light the walls and hot spots give off, pit = the walled pits in
## the middle of ring halls (lava / bio goo).
const LOOKS := {
	"w5": {"glow": Color(1.0, 0.45, 0.15), "pit": Color("1a0b08"), "pit_in": Color(0.22, 0.05, 0.02)},
	"w6": {"glow": Color(0.95, 0.25, 1.0), "pit": Color("140818"), "pit_in": Color(0.2, 0.04, 0.24)},
	"w7": {"glow": Color(0.25, 0.85, 1.0), "pit": Color("050a1c"), "pit_in": Color(0.03, 0.08, 0.22)},
	"w8": {"glow": Color(0.35, 0.95, 0.85), "pit": Color("0b1a10"), "pit_in": Color(0.06, 0.2, 0.08),
		"sub": 2, "plain": 0.55},  # bigger tiles, often the plain one (tile 0): a calm floor
}
const K := 0.45  # world units per kit px (walls)
const CW := 100.0  # cell size (world units)
const CH := 112.0
const MARGIN := 24.0  # around the outer walls
const CHUNK := Vector2i(6, 5)  # cells per drawing chunk
const FLOOR_SUB := 3  # floor tiles per cell side
const VOID := Color("0a0c13")
const PLAIN := 0.12  # share of wall segments without a feature
## kit pieces (assets/rooms/w5/kit/k_NN.png) for small halls, one or two in the middle
const SMALL_FURNITURE := [25, 26, 29, 30, 32, 44, 50, 53, 31, 21]

var set_id := "w5"  # kit: assets/rooms/<set>/build/
var glow_col := Color(1.0, 0.45, 0.15)
var pit_col := Color("1a0b08")
var pit_in := Color(0.22, 0.05, 0.02)
var extra_sides: Array = []  # corner each extra block is drawn for ("tl" / "tr")
var corner_feet := {}  # atlas name -> solid rects as shares of the picture (from its drawing)
var stud_tex: Texture2D  # drawn at every floor tile crossing (kits with "stud": world 8)
var stud_k := 0.0  # its size as a share of a floor tile
var floor_sub := FLOOR_SUB  # floor tiles per cell side (LOOKS "sub")
var plain_share := 0.0  # share of floor tiles forced to the plain tile 0 (LOOKS "plain")
var w := 18
var h := 14
var origin := Vector2(MARGIN, MARGIN)
var rng: RandomNumberGenerator
var region := PackedInt32Array()  # area index per cell, -1 = void
var blocked := PackedByteArray()  # 1 = not walkable (void, machinery)
var pit := PackedByteArray()  # 1 = void inside an area (ring / L cut): lava pit look
var hwall := PackedByteArray()  # w x (h + 1): wall on the top edge of cell (i, j)
var vwall := PackedByteArray()  # (w + 1) x h: wall on the left edge of cell (i, j)
var hfeat := PackedInt32Array()  # feature per horizontal edge (-1 = plain)
var vshaft := PackedInt32Array()  # shaft variant per vertical edge
var leaves: Array = []  # {rect: Rect2i, type: String}
var splits: Array = []  # [Rect2i, Rect2i] halves to join with doorways
var pillars := {}  # Vector2i node -> true
var machines: Array = []  # [Vector2i cell, "tl" | "tr" | "bl" | "br"]
var start_leaf := 0
var core_leaves: Array[int] = []
var furnish: Array = []  # [leaf, "pattern" | "one"]

var atlas: Texture2D
var floor_tex: Texture2D
var regions := {}  # atlas name -> Rect2
var n_posts := 1
var n_feats := 1
var n_shafts := 1
var n_extra := 0  # extra top-left corner blocks (corner_x<n>)
var _corner_deck := {}
var floor_cols := 1
var floor_rows := 1
var floor_tile := 76.0
var filler_top := 0.0
var glow_tex: Texture2D
var shade_tex: Texture2D  # black, fading downwards (contact shadow under the walls)
var glows: Array = []  # [pos, radius, alpha]
var _redraw: Array[CanvasItem] = []  # drawing nodes (redrawn after clear_circle)


# ---------------------------------------------------------------- generation

func generate(cfg: Dictionary, r: RandomNumberGenerator) -> ForgeMap:
	rng = r
	set_id = str(cfg.get("set", "w5"))
	var look: Dictionary = LOOKS.get(set_id, LOOKS.w5)
	glow_col = look.glow
	pit_col = look.pit
	pit_in = look.pit_in
	floor_sub = int(look.get("sub", FLOOR_SUB))
	plain_share = float(look.get("plain", 0.0))
	var c: Array = cfg.get("cells", [18, 14])
	w = int(c[0])
	h = int(c[1])
	region.resize(w * h)
	region.fill(-1)
	blocked.resize(w * h)
	blocked.fill(1)
	pit.resize(w * h)
	pit.fill(0)
	hwall.resize(w * (h + 1))
	hwall.fill(1)
	vwall.resize((w + 1) * h)
	vwall.fill(1)
	_split(Rect2i(0, 0, w, h))
	start_leaf = _pick_start()
	_pick_cores(int(cfg.get("cores", 0)) + int(cfg.get("vats", 0)) + int(cfg.get("tanks", 0)))  # objective areas
	_pick_specials(int(cfg.get("mazes", 2)))
	for li in leaves.size():
		_carve(li)
	for s: Array in splits:
		_join(s[0], s[1])
	_loops(float(cfg.get("maze", 0.35)))
	_repair()
	_machinery()
	_decorate()
	return self


## The run starts in a roomy area (not a corridor) as close as possible to the bottom
## middle of the map.
func _pick_start() -> int:
	var goal := Vector2(w * 0.5, h)
	var best := 0
	var best_d := INF
	for i in leaves.size():
		var r: Rect2i = leaves[i].rect
		if leaves[i].type == "corridor" or mini(r.size.x, r.size.y) < 2:
			continue
		var d := (Vector2(r.position) + Vector2(r.size) * Vector2(0.5, 1.0)).distance_to(goal)
		if d < best_d:
			best_d = d
			best = i
	return best


## BSP: long areas are cut in two, sometimes with a 1-cell corridor between the halves.
func _split(r: Rect2i) -> void:
	var long_x := r.size.x >= r.size.y
	var size := r.size.x if long_x else r.size.y
	var area := r.size.x * r.size.y
	if size < 5 or (r.size.x <= 5 and r.size.y <= 4 and (area <= 12 or rng.randf() < 0.3)):
		leaves.append({"rect": r, "type": ""})
		return
	var corridor := size >= 8 and rng.randf() < 0.5
	var p := rng.randi_range(3, size - 4) if corridor else rng.randi_range(2, size - 2)
	if not corridor and size >= 6:
		p = rng.randi_range(3, size - 3)
	var gap := 1 if corridor else 0
	var a: Rect2i
	var b: Rect2i
	var cr: Rect2i
	if long_x:
		a = Rect2i(r.position, Vector2i(p, r.size.y))
		cr = Rect2i(r.position + Vector2i(p, 0), Vector2i(1, r.size.y))
		b = Rect2i(r.position + Vector2i(p + gap, 0), Vector2i(r.size.x - p - gap, r.size.y))
	else:
		a = Rect2i(r.position, Vector2i(r.size.x, p))
		cr = Rect2i(r.position + Vector2i(0, p), Vector2i(r.size.x, 1))
		b = Rect2i(r.position + Vector2i(0, p + gap), Vector2i(r.size.x, r.size.y - p - gap))
	_split(a)
	_split(b)
	if corridor:
		leaves.append({"rect": cr, "type": "corridor"})
		splits.append([a, cr])
		splits.append([cr, b])
	else:
		splits.append([a, b])


## At least `n` labyrinths (mid-sized areas), and some small areas left solid: thick
## blocks of wall the corridors wind around.
func _pick_specials(n: int) -> void:
	var cand: Array[int] = []
	for i in leaves.size():
		var r: Rect2i = leaves[i].rect
		var area := r.size.x * r.size.y
		if i == start_leaf or core_leaves.has(i) or leaves[i].type != "":
			continue
		if area >= 8 and area <= 24 and mini(r.size.x, r.size.y) >= 2:
			cand.append(i)
		elif area <= 4 and rng.randf() < 0.45:
			leaves[i].type = "solid"
	cand.shuffle()
	for i in cand.slice(0, n):
		leaves[i].type = "maze"


func _pick_type(li: int) -> String:
	var r: Rect2i = leaves[li].rect
	if li == start_leaf or core_leaves.has(li):
		return "hall"
	var lo := mini(r.size.x, r.size.y)
	var hi := maxi(r.size.x, r.size.y)
	var opts := {"hall": 2.0}
	if lo >= 3:
		opts["pillars"] = 2.0
		opts["ring"] = 1.6
		opts["lshape"] = 1.4
		opts["maze"] = 1.4
		if hi >= 4:
			opts["split"] = 1.4
	elif lo == 2:
		if r.size.x * r.size.y >= 6:
			opts["maze"] = 1.2
		if hi >= 4:
			opts["split"] = 1.0
	var total := 0.0
	for k: String in opts:
		total += float(opts[k])
	var roll := rng.randf() * total
	for k: String in opts:
		roll -= float(opts[k])
		if roll <= 0.0:
			return k
	return "hall"


## Cores go in roomy areas far from the start and from each other.
func _pick_cores(n: int) -> void:
	var cand: Array[int] = []
	for i in leaves.size():
		var r: Rect2i = leaves[i].rect
		if i != start_leaf and leaves[i].type == "" and mini(r.size.x, r.size.y) >= 3:
			cand.append(i)
	var s0 := leaf_rect(start_leaf).get_center()
	for attempt in 40:
		cand.shuffle()
		var got: Array[int] = []
		for i in cand:
			if got.size() >= n:
				break
			var cpos := leaf_rect(i).get_center()
			if cpos.distance_to(s0) < 380.0:
				continue
			var ok := true
			for o in got:
				if leaf_rect(o).get_center().distance_to(cpos) < 480.0:
					ok = false
			if ok:
				got.append(i)
		if got.size() > core_leaves.size():
			core_leaves = got
		if core_leaves.size() >= n:
			break
	for i in cand:  # still short: any roomy area left
		if core_leaves.size() >= n:
			break
		if not core_leaves.has(i):
			core_leaves.append(i)


func _carve(li: int) -> void:
	var L: Dictionary = leaves[li]
	if L.type == "":
		L.type = _pick_type(li)
	var r: Rect2i = L.rect
	if L.type == "solid":
		return  # stays void: walls around it, dark roof
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			region[y * w + x] = li
			blocked[y * w + x] = 0
	match str(L.type):
		"maze":
			_open_all(r, false)
			_maze(r)
		"pillars":
			_open_all(r, true)
			for y in range(r.position.y + 1, r.end.y):
				for x in range(r.position.x + 1, r.end.x):
					if rng.randf() < 0.85:
						pillars[Vector2i(x, y)] = true
		"ring":
			_open_all(r, true)
			var bw := 2 if r.size.x >= 5 else 1
			var bh := 2 if r.size.y >= 5 else 1
			var b := Rect2i(r.position + (r.size - Vector2i(bw, bh)) / 2, Vector2i(bw, bh))
			_cut(b, li)
		"lshape":
			_open_all(r, true)
			var sz := Vector2i(maxi(1, r.size.x / 2), maxi(1, r.size.y / 2))
			var corner := Vector2i(rng.randi() % 2, rng.randi() % 2)
			var at := r.position + Vector2i(corner.x * (r.size.x - sz.x), corner.y * (r.size.y - sz.y))
			_cut(Rect2i(at, sz), li)
		"split":
			_open_all(r, true)
			_split_wall(r)
		_:
			_open_all(r, true)


## Open (or wall) every edge inside rect r.
func _open_all(r: Rect2i, open: bool) -> void:
	var v := 0 if open else 1
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x > r.position.x:
				vwall[y * (w + 1) + x] = v
			if y > r.position.y:
				hwall[y * w + x] = v


## Cells of b become a walled lava pit inside area li.
func _cut(b: Rect2i, _li: int) -> void:
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			region[y * w + x] = -1
			blocked[y * w + x] = 1
			pit[y * w + x] = 1
	for y in range(b.position.y, b.end.y):
		vwall[y * (w + 1) + b.position.x] = 1
		vwall[y * (w + 1) + b.end.x] = 1
	for x in range(b.position.x, b.end.x):
		hwall[b.position.y * w + x] = 1
		hwall[b.end.y * w + x] = 1


func _maze(r: Rect2i) -> void:
	var start := r.position + Vector2i(rng.randi() % r.size.x, rng.randi() % r.size.y)
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var next: Array[Vector2i] = []
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if r.has_point(n) and not seen.has(n):
				next.append(n)
		if next.is_empty():
			stack.pop_back()
			continue
		var n2: Vector2i = next[rng.randi() % next.size()]
		set_open(c, n2, true)
		seen[n2] = true
		stack.append(n2)
	# a few extra openings: loops, so it is a labyrinth and not a dead-end trap
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x > r.position.x and rng.randf() < 0.18:
				vwall[y * (w + 1) + x] = 0
			if y > r.position.y and rng.randf() < 0.18:
				hwall[y * w + x] = 0


## A wall across the area (perpendicular to its long side) with 1-2 gaps.
func _split_wall(r: Rect2i) -> void:
	var across_x := r.size.x >= r.size.y  # wall is vertical, at an x
	var span := r.size.y if across_x else r.size.x
	var at := (r.position.x if across_x else r.position.y) + (r.size.x if across_x else r.size.y) / 2
	var gaps := {rng.randi() % span: true}
	if span >= 4:
		var g2 := rng.randi() % span
		while gaps.has(g2) or gaps.has(g2 - 1) or gaps.has(g2 + 1):
			g2 = rng.randi() % span
		gaps[g2] = true
	for k in span:
		if gaps.has(k):
			continue
		if across_x:
			vwall[(r.position.y + k) * (w + 1) + at] = 1
		else:
			hwall[at * w + r.position.x + k] = 1


## Doorways between two halves of a split (1, or 2 on long boundaries).
func _join(a: Rect2i, b: Rect2i) -> void:
	var cand: Array = []
	if a.end.x == b.position.x:
		for y in range(maxi(a.position.y, b.position.y), mini(a.end.y, b.end.y)):
			cand.append([Vector2i(a.end.x - 1, y), Vector2i(b.position.x, y)])
	else:
		for x in range(maxi(a.position.x, b.position.x), mini(a.end.x, b.end.x)):
			cand.append([Vector2i(x, a.end.y - 1), Vector2i(x, b.position.y)])
	cand = cand.filter(func(p: Array) -> bool: return walkable(p[0]) and walkable(p[1]))
	if cand.is_empty():
		return
	cand.shuffle()
	set_open(cand[0][0], cand[0][1], true)
	if cand.size() >= 5 and rng.randf() < 0.5:
		for p: Array in cand.slice(1):
			var d := absi((p[0] as Vector2i).x - (cand[0][0] as Vector2i).x) + absi((p[0] as Vector2i).y - (cand[0][0] as Vector2i).y)
			if d >= 2:
				set_open(p[0], p[1], true)
				break


## Neighbouring areas not joined yet get a doorway with chance k (loops in the map).
func _loops(k: float) -> void:
	var pairs := {}  # "a,b" -> [[cell, cell], ...]
	var joined := {}
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var n := c + d
				if n.x >= w or n.y >= h or not walkable(c) or not walkable(n):
					continue
				var ra := region[y * w + x]
				var rb := region[n.y * w + n.x]
				if ra == rb:
					continue
				var key := "%d,%d" % [mini(ra, rb), maxi(ra, rb)]
				if is_open(c, n):
					joined[key] = true
				if not pairs.has(key):
					pairs[key] = []
				(pairs[key] as Array).append([c, n])
	for key: String in pairs:
		if joined.has(key) or rng.randf() >= k:
			continue
		var list: Array = pairs[key]
		var p: Array = list[rng.randi() % list.size()]
		set_open(p[0], p[1], true)


## Whatever the doorways missed (voids in the way) gets opened to the reachable part.
func _repair() -> void:
	var s := start_cell()
	for guard in 200:
		var seen := reach(s)
		var fixed := false
		for y in h:
			for x in w:
				var c := Vector2i(x, y)
				if not walkable(c) or seen.has(c):
					continue
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if seen.has(c + d):
						set_open(c, c + d, true)
						fixed = true
						break
				if fixed:
					break
			if fixed:
				break
		if not fixed:
			return


## Corner blocks of machinery in some hall corners (never on a doorway, never cutting
## the map in two).
func _machinery() -> void:
	var s := start_cell()
	var total := reach(s).size()
	for li in leaves.size():
		var L: Dictionary = leaves[li]
		var r: Rect2i = L.rect
		if li == start_leaf or core_leaves.has(li) or mini(r.size.x, r.size.y) < 3:
			continue
		if not str(L.type) in ["hall", "pillars", "ring", "split"]:
			continue
		var placed := 0
		var corners := [["tl", r.position], ["tr", Vector2i(r.end.x - 1, r.position.y)],
				["bl", Vector2i(r.position.x, r.end.y - 1)], ["br", r.end - Vector2i.ONE]]
		corners.shuffle()
		for it: Array in corners:
			var c: Vector2i = it[1]
			var kind: String = it[0]
			if placed >= 2 or rng.randf() > (0.6 if kind[0] == "t" else 0.4):
				continue
			if not walkable(c) or not _has_corner_art(kind):
				continue
			var up := kind[0] == "t"
			var left := kind[1] == "l"
			# its two outer sides must be walls (no doorway into the machinery)
			if is_open(c, c + (Vector2i.UP if up else Vector2i.DOWN)) or is_open(c, c + (Vector2i.LEFT if left else Vector2i.RIGHT)):
				continue
			blocked[c.y * w + c.x] = 1
			if reach(s).size() < total - 1:
				blocked[c.y * w + c.x] = 0
				continue
			total -= 1
			var piece: Array = _deal_corner(kind)
			machines.append([c, kind, piece[0], piece[1]])
			pillars.erase(Vector2i(c.x + (1 if left else 0), c.y + (1 if up else 0)))
			placed += 1


## Corner blocks that fit corner `kind`, dealt out shuffled so a map rarely shows the same
## one twice: [atlas name, mirrored]. Top corners also get the 10 extra blocks
## (tools/w5_corners_ref.webp, drawn for the top-left: mirrored on the top-right); the
## originals can swap sides mirrored too.
## Is there any picture for corner `kind` (world 8 brings only top corners)?
func _has_corner_art(kind: String) -> bool:
	_load()
	if kind[0] == "t" and n_extra > 0:
		return true
	var other := {"tl": "tr", "tr": "tl", "bl": "br", "br": "bl"}
	return regions.has("corner_" + kind) or regions.has("corner_" + str(other[kind]))


func _deal_corner(kind: String) -> Array:
	if not _corner_deck.has(kind) or (_corner_deck[kind] as Array).is_empty():
		_load()
		var other := {"tl": "tr", "tr": "tl", "bl": "br", "br": "bl"}
		var deck: Array = []
		for it: Array in [["corner_" + kind, false], ["corner_" + str(other[kind]), true]]:
			if regions.has(it[0]):  # kits may come without some of the 4 base corners
				deck.append(it)
		if kind[0] == "t":
			for i in n_extra:
				var side := str(extra_sides[i]) if i < extra_sides.size() else "tl"
				deck.append(["corner_x%d" % i, side != kind])  # mirrored onto the other top corner
		deck.shuffle()
		_corner_deck[kind] = deck
	return (_corner_deck[kind] as Array).pop_back()


func _decorate() -> void:
	hfeat.resize(w * (h + 1))
	for i in hfeat.size():
		hfeat[i] = -1 if rng.randf() < PLAIN else rng.randi() % maxi(1, _count("feat_"))
	vshaft.resize((w + 1) * h)
	for i in vshaft.size():
		vshaft[i] = rng.randi() % maxi(1, _count("shaft_"))
	for li in leaves.size():
		var r: Rect2i = leaves[li].rect
		if li == start_leaf or core_leaves.has(li) or str(leaves[li].type) != "hall":
			continue
		if r.size.x >= 5 and r.size.y >= 4:
			furnish.append([li, "pattern"])
		elif mini(r.size.x, r.size.y) >= 2 and rng.randf() < 0.7:
			furnish.append([li, "one"])


func _count(prefix: String) -> int:
	_load()
	match prefix:
		"feat_":
			return n_feats
		"shaft_":
			return n_shafts
	return n_posts


# ---------------------------------------------------------------- queries

func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func walkable(c: Vector2i) -> bool:
	return inside(c) and blocked[idx(c)] == 0


func is_void(c: Vector2i) -> bool:
	return not inside(c) or region[idx(c)] < 0


## Is there no wall between neighbouring cells a and b?
func is_open(a: Vector2i, b: Vector2i) -> bool:
	if not inside(a) or not inside(b):
		return false
	if b.x != a.x:
		return vwall[a.y * (w + 1) + maxi(a.x, b.x)] == 0
	return hwall[maxi(a.y, b.y) * w + a.x] == 0


func set_open(a: Vector2i, b: Vector2i, open: bool) -> void:
	if b.x != a.x:
		vwall[a.y * (w + 1) + maxi(a.x, b.x)] = 0 if open else 1
	else:
		hwall[maxi(a.y, b.y) * w + a.x] = 0 if open else 1


## Walking distance (in cells) from c to every reachable cell.
func distances(c: Vector2i) -> Dictionary:
	var dist := {c: 0}
	var q: Array[Vector2i] = [c]
	var i := 0
	while i < q.size():
		var p := q[i]
		i += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := p + d
			if walkable(n) and not dist.has(n) and is_open(p, n):
				dist[n] = int(dist[p]) + 1
				q.append(n)
	return dist


## Cells reachable from c (walking through open edges).
func reach(c: Vector2i) -> Dictionary:
	var seen := {c: true}
	var q: Array[Vector2i] = [c]
	var i := 0
	while i < q.size():
		var p := q[i]
		i += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := p + d
			if walkable(n) and not seen.has(n) and is_open(p, n):
				seen[n] = true
				q.append(n)
	return seen


func start_cell() -> Vector2i:
	var r: Rect2i = leaves[start_leaf].rect
	return Vector2i(r.position.x + r.size.x / 2, r.end.y - 1)


func size() -> Vector2:
	return Vector2(w * CW, h * CH) + Vector2.ONE * MARGIN * 2.0


func node_pos(i: int, j: int) -> Vector2:
	return origin + Vector2(i * CW, j * CH)


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(node_pos(c.x, c.y), Vector2(CW, CH))


func leaf_rect(li: int) -> Rect2:
	var r: Rect2i = leaves[li].rect
	return Rect2(node_pos(r.position.x, r.position.y), Vector2(r.size.x * CW, r.size.y * CH))


func cell_at(p: Vector2) -> int:
	var q := (p - origin) / Vector2(CW, CH)
	var c := Vector2i(floori(q.x), floori(q.y))
	return idx(c) if inside(c) else -1


## Free spots of area li (local to its rect) for chests and survivors: cell centres clear
## of machinery, away from a reactor core or furniture in the middle.
func spots(li: int) -> Array:
	var r: Rect2i = leaves[li].rect
	var lr := leaf_rect(li)
	var busy := core_leaves.has(li)
	for f: Array in furnish:
		if int(f[0]) == li:
			busy = true
	var out: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if not walkable(c):
				continue
			var p := cell_rect(c).get_center() + Vector2(0, 10)
			if busy and p.distance_to(lr.get_center()) < 110.0:
				continue
			out.append(p - lr.position)
	return out


## Half thickness of the walls (world units).
func post_half() -> Vector2:
	_load()
	var ps: Vector2 = regions.get("post_0", Rect2(0, 0, 37, 90)).size
	return ps * K * 0.5


## Every solid rect: walls (merged runs), voids, pillars, machinery, the frame margin.
func solids() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var hp := post_half()
	# horizontal runs
	for j in h + 1:
		var run := -1
		for i in w + 1:
			var on := i < w and _hdrawn(i, j)
			if on and run < 0:
				run = i
			elif not on and run >= 0:
				var a := node_pos(run, j)
				var b := node_pos(i, j)
				out.append(Rect2(a.x - hp.x, a.y - hp.y, b.x - a.x + hp.x * 2.0, hp.y * 2.0))
				run = -1
	# vertical runs
	for i in w + 1:
		var run := -1
		for j in h + 1:
			var on := j < h and _vdrawn(i, j)
			if on and run < 0:
				run = j
			elif not on and run >= 0:
				var a := node_pos(i, run)
				var b := node_pos(i, j)
				out.append(Rect2(a.x - hp.x, a.y - hp.y, hp.x * 2.0, b.y - a.y + hp.y * 2.0))
				run = -1
	# corner machinery: solid where its picture stands (the foot of what is drawn, measured
	# by make_forge_walls.py), mirrored with it; the open floor it leaves is walkable
	var mach := {}
	for m: Array in machines:
		mach[m[0]] = true
		var box := machine_box(m)
		var flip := bool(m[3])
		for f: Array in corner_feet.get(str(m[2]), [[0.0, 0.0, 1.0, 1.0]]):
			var fx := float(f[0])
			if flip:
				fx = 1.0 - fx - float(f[2])
			out.append(Rect2(box.position + box.size * Vector2(fx, float(f[1])), box.size * Vector2(float(f[2]), float(f[3]))))
	# blocked cells, merged along rows
	for j in h:
		var run := -1
		for i in w + 1:
			var on := i < w and blocked[j * w + i] == 1 and not mach.has(Vector2i(i, j))
			if on and run < 0:
				run = i
			elif not on and run >= 0:
				out.append(Rect2(node_pos(run, j), Vector2((i - run) * CW, CH)))
				run = -1
	for n: Vector2i in pillars:
		var p := node_pos(n.x, n.y)
		out.append(Rect2(p - hp, hp * 2.0))
	var sz := size()
	out.append(Rect2(0, 0, sz.x, MARGIN))
	out.append(Rect2(0, sz.y - MARGIN, sz.x, MARGIN))
	out.append(Rect2(0, 0, MARGIN, sz.y))
	out.append(Rect2(sz.x - MARGIN, 0, MARGIN, sz.y))
	return out


## A wall on the top edge of cell (i, j) that is drawn: there is floor on one side.
func _hdrawn(i: int, j: int) -> bool:
	if hwall[j * w + i] == 0:
		return false
	return not is_void(Vector2i(i, j - 1)) or not is_void(Vector2i(i, j))


func _vdrawn(i: int, j: int) -> bool:
	if vwall[j * (w + 1) + i] == 0:
		return false
	return not is_void(Vector2i(i - 1, j)) or not is_void(Vector2i(i, j))


## Does node (i, j) get a post: any wall drawn next to it, or a pillar.
func _has_post(i: int, j: int) -> bool:
	if pillars.has(Vector2i(i, j)):
		return true
	if i < w and _hdrawn(i, j):
		return true
	if i > 0 and _hdrawn(i - 1, j):
		return true
	if j < h and _vdrawn(i, j):
		return true
	if j > 0 and _vdrawn(i, j - 1):
		return true
	return false


# ---------------------------------------------------------------- aliens' way around walls

## For every cell, the point to head for to get one cell closer to cell `goal` (a little
## past the doorway). Vector2.ZERO = unreachable.
func flow(goal: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(w * h)
	if goal < 0:
		return out
	var g := Vector2i(goal % w, goal / w)
	var q: Array[Vector2i] = [g]
	var seen := {g: true}
	var i := 0
	while i < q.size():
		var p := q[i]
		i += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := p + d
			if walkable(n) and not seen.has(n) and is_open(p, n):
				seen[n] = true
				q.append(n)
				# n walks towards p: the middle of their shared edge, then a step into p
				var mid := (cell_rect(n).get_center() + cell_rect(p).get_center()) * 0.5
				out[idx(n)] = mid - Vector2(d) * 22.0
	return out


# ---------------------------------------------------------------- drawing

func _load() -> void:
	if atlas != null:
		return
	var dir := "res://assets/rooms/%s/build/" % set_id
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "build.json"))
	for k: String in data.regions:
		var a: Array = data.regions[k]
		regions[k] = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	n_posts = int(data.posts)
	n_feats = int(data.feats)
	n_shafts = int(data.shafts)
	n_extra = int(data.get("extra_corners", 0))
	filler_top = float(data.filler_top)
	floor_cols = int(data.floor.cols)
	floor_rows = int(data.floor.rows)
	floor_tile = float(data.floor.tile)
	atlas = _mip(dir + "atlas.png")
	floor_tex = _mip(dir + "floor.png")
	extra_sides = data.get("extra_sides", [])
	stud_k = float(data.floor.get("stud", 0.0))
	if stud_k > 0.0 and ResourceLoader.exists(dir + "stud.png"):
		stud_tex = _mip(dir + "stud.png")
	corner_feet = data.get("corner_feet", {})
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	glow_tex = gt
	var sg := Gradient.new()
	sg.set_color(0, Color(0, 0, 0, 0.55))
	sg.set_color(1, Color(0, 0, 0, 0))
	var st := GradientTexture2D.new()
	st.gradient = sg
	st.fill_from = Vector2(0, 0)
	st.fill_to = Vector2(0, 1)
	st.width = 4
	st.height = 32
	shade_tex = st


static func _mip(path: String) -> Texture2D:
	var img := (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _hash(a: int, b: int, c := 0) -> int:
	var x := a * 73856093 ^ b * 19349663 ^ c * 83492791
	x = (x ^ (x >> 13)) * 1274126177
	return absi(x ^ (x >> 16))


## Builds the drawing nodes under `parent`: floor chunks, the glow layer, wall chunks and
## the machinery on top.
func make_nodes(parent: Node2D) -> void:
	_load()
	_place_glows()
	var floor_root := Node2D.new()
	floor_root.name = "ForgeFloor"
	parent.add_child(floor_root)
	var glow := Glows.new()
	glow.map = self
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	var wall_root := Node2D.new()
	wall_root.name = "ForgeWalls"
	for cy in range(0, h, CHUNK.y):
		for cx in range(0, w, CHUNK.x):
			var r := Rect2i(cx, cy, mini(CHUNK.x, w - cx), mini(CHUNK.y, h - cy))
			var f := Chunk.new()
			f.map = self
			f.cells = r
			f.walls = false
			floor_root.add_child(f)
			_redraw.append(f)
			var wl := Chunk.new()
			wl.map = self
			wl.cells = r
			wl.walls = true
			wall_root.add_child(wl)
			_redraw.append(wl)
	parent.add_child(glow)
	_redraw.append(glow)
	parent.add_child(wall_root)
	var top := Machinery.new()
	top.map = self
	parent.add_child(top)
	_redraw.append(top)


## The final boss fight: every cell the circle (c, r) touches becomes open floor, its walls,
## pits, pillars and machinery gone; walls stay only between the ring and solid cells
## around it. Then the drawing is redone (solids() gives the new collision).
func clear_circle(c: Vector2, r: float) -> void:
	var clear := {}
	# the walls left round the ring are this thick: clear that much further
	var reach := r + post_half().y + 4.0
	for j in h:
		for i in w:
			var cr := cell_rect(Vector2i(i, j))
			if (c.clamp(cr.position, cr.end) - c).length() < reach:
				clear[Vector2i(i, j)] = true
	var keep_region := region[idx(start_cell())]
	for cell: Vector2i in clear:
		var k := idx(cell)
		if region[k] < 0:
			region[k] = keep_region
		blocked[k] = 0
		pit[k] = 0
	for cell: Vector2i in clear:
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := cell + d
			if not inside(n):
				continue
			set_open(cell, n, clear.has(n) or walkable(n))
	for n: Vector2i in pillars.keys():
		if node_pos(n.x, n.y).distance_to(c) < r + CW * 0.5:
			pillars.erase(n)
	machines = machines.filter(func(m: Array) -> bool: return not clear.has(m[0]))
	_place_glows()
	for ci in _redraw:
		if is_instance_valid(ci):
			ci.queue_redraw()


func _place_glows() -> void:
	glows.clear()
	var hp := post_half()
	# lava light spilling from the glowing faces of the walls
	for j in h + 1:
		for i in w:
			if not _hdrawn(i, j) or hfeat[j * w + i] < 0 or is_void(Vector2i(i, j)):
				continue
			var a := node_pos(i, j)
			glows.append([a + Vector2(CW * 0.5, hp.y + 4.0), 46.0, 0.22])
	# hot spots in the floor (tile corners), like the reference floor
	for j in h:
		for i in w:
			var c := Vector2i(i, j)
			if not walkable(c) or _hash(i, j, 5) % 100 > 9:
				continue
			var k := _hash(i, j, 6) % (floor_sub * floor_sub)
			var p := cell_rect(c).position + Vector2(CW, CH) / floor_sub * Vector2(k % floor_sub + 1, k / floor_sub + 1)
			glows.append([p, 26.0, 0.32])
			glows.append([p, 7.0, 0.85])
	# lava pits and machinery
	for j in h:
		for i in w:
			if pit[j * w + i] == 1:
				var pc := cell_rect(Vector2i(i, j)).get_center()
				glows.append([pc, 64.0, 0.95])
				glows.append([pc + Vector2(-14, 8), 30.0, 0.9])
				glows.append([pc + Vector2(16, -6), 24.0, 0.9])
	for m: Array in machines:
		glows.append([cell_rect(m[0]).get_center(), 80.0, 0.35])


func draw_floor(ci: CanvasItem, cells: Rect2i) -> void:
	var t := Vector2(CW, CH) / floor_sub
	var n := floor_cols * floor_rows
	for j in range(cells.position.y, cells.end.y):
		for i in range(cells.position.x, cells.end.x):
			var c := Vector2i(i, j)
			var cr := cell_rect(c)
			if is_void(c):
				ci.draw_rect(cr, pit_col if pit[idx(c)] == 1 else VOID)
				if pit[idx(c)] == 1:  # lava far below: the Glows layer lights it up
					ci.draw_rect(cr.grow(-10.0), pit_in)
				continue
			for ty in floor_sub:
				for tx in floor_sub:
					var gx := i * floor_sub + tx
					var gy := j * floor_sub + ty
					var k := _hash(gx, gy) % n
					# plain tiles more often than cracked ones: half the picks re-roll
					if k % 3 == 0:
						k = _hash(gx, gy, 1) % n
					if plain_share > 0.0 and _hash(gx, gy, 3) % 100 < int(plain_share * 100.0):
						k = 0
					var src := Rect2(Vector2(k % floor_cols, k / floor_cols) * floor_tile, Vector2.ONE * floor_tile)
					ci.draw_texture_rect_region(floor_tex, Rect2(cr.position + t * Vector2(tx, ty), t), src)
	if stud_tex != null:  # one stud per tile crossing (the tiles carry none of their own)
		var ss := t.x * stud_k * 0.75
		for j in range(cells.position.y, cells.end.y):
			for i in range(cells.position.x, cells.end.x):
				var c := Vector2i(i, j)
				if is_void(c):
					continue
				var o := cell_rect(c).position
				for ty in floor_sub:
					for tx in floor_sub:
						var p := o + t * Vector2(tx, ty)
						ci.draw_texture_rect(stud_tex, Rect2(p - Vector2(ss, ss) * 0.5, Vector2(ss, ss)), false)
	# contact shadows: under the horizontal walls, along the sides of the columns
	var hp := post_half()
	for j in range(cells.position.y, cells.end.y):
		for i in range(cells.position.x, cells.end.x):
			var c := Vector2i(i, j)
			if is_void(c):
				continue
			var cr := cell_rect(c)
			if _hdrawn(i, j):
				ci.draw_texture_rect(shade_tex, Rect2(cr.position.x - hp.x, cr.position.y + hp.y - 2.0, CW + hp.x * 2.0, 18.0), false)
			if _vdrawn(i, j):
				ci.draw_texture_rect(shade_tex, Rect2(cr.position.x + hp.x - 1.0, cr.position.y, 7.0, CH), false, Color(1, 1, 1, 0.5))
			if _vdrawn(i + 1, j):
				ci.draw_texture_rect(shade_tex, Rect2(cr.end.x - hp.x - 6.0, cr.position.y, 7.0, CH), false, Color(1, 1, 1, 0.5))


func _blit(ci: CanvasItem, name: String, pos: Vector2, scale := Vector2(K, K)) -> void:
	var r: Rect2 = regions[name]
	ci.draw_texture_rect_region(atlas, Rect2(pos, r.size * scale), r)


## Walls of the nodes owned by chunk `cells`, row by row: the shafts coming down to the
## row, its horizontal segments, then its posts (on top of the segment ends).
func draw_walls(ci: CanvasItem, cells: Rect2i) -> void:
	var hp := post_half()
	var i1 := cells.end.x + (1 if cells.end.x == w else 0)
	var j1 := cells.end.y + (1 if cells.end.y == h else 0)
	for j in range(cells.position.y, j1):
		if j > 0:
			for i in range(cells.position.x, i1):
				if _vdrawn(i, j - 1):
					_draw_shaft(ci, i, j - 1, hp)
		for i in range(cells.position.x, mini(i1, w)):
			if _hdrawn(i, j):
				_draw_segment(ci, i, j, hp)
		for i in range(cells.position.x, i1):
			if _has_post(i, j):
				var p := node_pos(i, j)
				var v := _hash(i, j, 2) % n_posts
				var south := j < h and _vdrawn(i, j)
				_blit(ci, ("cap_%d" if south else "post_%d") % v, p - hp)


func _draw_segment(ci: CanvasItem, i: int, j: int, hp: Vector2) -> void:
	var a := node_pos(i, j)
	var x0 := a.x + hp.x
	var span := CW - hp.x * 2.0
	var top := a.y - hp.y
	# plain slab + face, tiled
	var fr: Rect2 = regions.filler
	var fy := top + filler_top * K
	var x := x0
	var fw := fr.size.x * K
	while x < x0 + span - 0.01:
		var ww := minf(fw, x0 + span - x)
		ci.draw_texture_rect_region(atlas, Rect2(x, fy, ww, fr.size.y * K), Rect2(fr.position, Vector2(ww / K, fr.size.y)))
		x += ww
	var f := hfeat[j * w + i]
	if f < 0:
		return
	var r: Rect2 = regions["feat_%d" % f]
	var s := minf(K, span / r.size.x)
	var sz := r.size * Vector2(s, K)
	ci.draw_texture_rect_region(atlas, Rect2(Vector2(x0 + (span - sz.x) * 0.5, top), sz), r)


func _draw_shaft(ci: CanvasItem, i: int, j: int, hp: Vector2) -> void:
	var a := node_pos(i, j)
	var cap: Rect2 = regions.cap_0
	var y0 := a.y - hp.y + cap.size.y * K - 2.0
	var y1 := a.y + CH - hp.y + 2.0
	var r: Rect2 = regions["shaft_%d" % vshaft[j * (w + 1) + i]]
	var sh := r.size.y * K
	var y := y0
	while y < y1 - 0.01:
		var hh := minf(sh, y1 - y)
		ci.draw_texture_rect_region(atlas, Rect2(a.x - hp.x, y, hp.x * 2.0, hh), Rect2(r.position, Vector2(r.size.x, hh / K)))
		y += hh


## Where corner block m is drawn (world rect): fitted from the outer face of its corner
## posts across the cell.
func machine_box(m: Array) -> Rect2:
	_load()
	var hp := post_half()
	var c: Vector2i = m[0]
	var kind: String = m[1]
	var r: Rect2 = regions[str(m[2])]
	var target := Vector2(CW + hp.x * 2.0, CH + hp.y * 2.0)
	var s := minf(target.x / r.size.x, target.y / r.size.y)
	var sz := r.size * s
	var cr := cell_rect(c)
	return Rect2(Vector2(cr.position.x - hp.x if kind[1] == "l" else cr.end.x + hp.x - sz.x,
			cr.position.y - hp.y if kind[0] == "t" else cr.end.y + hp.y - sz.y), sz)


func draw_machinery(ci: CanvasItem) -> void:
	for m: Array in machines:
		var r: Rect2 = regions[str(m[2])]
		var box := machine_box(m)
		var pos := box.position
		var sz := box.size
		if bool(m[3]):  # mirrored
			ci.draw_set_transform(pos + Vector2(sz.x, 0.0), 0.0, Vector2(-1.0, 1.0))
			ci.draw_texture_rect_region(atlas, Rect2(Vector2.ZERO, sz), r)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			ci.draw_texture_rect_region(atlas, Rect2(pos, sz), r)


class Chunk:
	extends Node2D
	var map: ForgeMap
	var cells: Rect2i
	var walls := false

	func _draw() -> void:
		if walls:
			map.draw_walls(self, cells)
		else:
			map.draw_floor(self, cells)


class Glows:
	extends Node2D
	var map: ForgeMap

	func _draw() -> void:
		for g: Array in map.glows:
			var r: float = g[1]
			draw_texture_rect(map.glow_tex, Rect2((g[0] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0), false,
					Color(map.glow_col, float(g[2])))


class Machinery:
	extends Node2D
	var map: ForgeMap

	func _draw() -> void:
		map.draw_machinery(self)
