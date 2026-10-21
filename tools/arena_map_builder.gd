extends Node
## Base of the one-shot tools that turn a world's map into an Arena Editor scene
## (scenes/arenas/arena_world_NN_level_01.tscn) the user then edits by hand. A world's
## builder extends this file and only says what is its own in _configure() (scene path,
## kit, wall lattice, floor terrain, piece lists by role), _data() (ArenaData) and
## _objective() (the world's objective object, e.g. an ArenaSeedTank). See
## tools/build_biodome_arena.gd and the skill arena-world-map.
##
## What it builds: a ForgeMap layout with a fixed seed (halls, corridors, mazes, pits),
## laid on a lattice of wall MODULES (one straight run = mod_w, one column = mod_h; a cell
## side holds mods_x runs / mods_y stacked columns: roomy corridors without stretching the
## art), floor tiles on every area cell, big pieces in the hall corners, pieces along the
## top walls (never in front of a doorway), a centrepiece and garden islands in big halls,
## floor bits, then the Player Spawn, the objective objects, random Chests and Survivors.
##   godot --headless --path . res://tools/<builder>.tscn [-- --force] [-- --seed=N] [-- --out=<res path>]
## It refuses to overwrite an existing scene (the user's) unless --force.

const Terrain := preload("res://addons/aliens_cleaner_arena_editor/editor/terrain_tileset_builder.gd")

# ---- set by the world's _configure() -----------------------------------------------------
var path := ""  # the scene to make
var tag := "ARENA"  # log prefix
var kit_dir := ""  # res://assets/decor/<kit>/
var layout := {}  # ForgeMap.generate config ("set", "maze", "mazes", objective counts...)
var cells := [18, 14]
var seed_value := 1
var mod_w := 96.0  # world units of one straight run between its posts
var mod_h := 64.0  # world units one column goes down
var mods_x := 1
var mods_y := 1
var origin := Vector2(32, 64)  # void round the map (more on top: the walls' top faces)
var floor_src := -1  # terrain.json source of the floor (-1 = no floor painted)
var floor_cols := 1  # tiles a row in its atlas
var floor_tiles := 1  # tiles in its atlas (tile 0 = the plain one)
var plain := 0.7  # share of plain floor tiles
var chests := 8
var survivors := 5
var keep_clear := 64.0  # no decoration this close to the start, objectives, chests, survivors
var runs: Array = []  # kit files by role (relative to kit_dir)
var run_weights: Array = []
var columns: Array = []
var column_weights: Array = []
var corner_big: Array = []  # big machines / tanks pushed into hall corners
var along_wall: Array = []  # under the top wall of halls
var along_side: Array = []  # beside the side walls of halls (empty = none)
var side_share := 0.35  # of the side cells that get one
var pots: Array = []  # small pieces: free posts, wall ends, beside islands
var centrepieces: Array = []  # middle of big halls
var islands: Array = []  # the core of a garden island
var floor_bits: Array = []  # flat on the floor
var lamps: Array = []  # either side of a wide hall's centrepiece

# ---- state -----------------------------------------------------------------------------
var arena: Arena
var rng := RandomNumberGenerator.new()
var fm: ForgeMap
var kit := {}
var run_h := 52.0  # world height of a straight run (its posts span it)
var busy: Array[Vector2] = []  # gameplay spots the decoration keeps away from
var cw := 96.0  # cell size
var ch := 64.0


## Override: set the vars above.
func _configure() -> void:
	pass


## Override: the arena's ArenaData (waves off: the world's WorldData plays the fight).
func _data() -> ArenaData:
	var d := ArenaData.new()
	d.waves_enabled = false
	d.camera_zoom = 1.0
	d.background = ForgeMap.VOID
	return d


## Override: the world's objective object for objective area n (ForgeMap.core_leaves) at
## `at` (the middle of the area), or null. It is added to GameplayObjects.
func _objective(_n: int, _at: Vector2) -> Node2D:
	return null


func _ready() -> void:
	_configure()
	cw = mod_w * mods_x
	ch = mod_h * mods_y
	var args := OS.get_cmdline_user_args()
	var out := path
	for a in args:
		if a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if out == path and ResourceLoader.exists(path) and not args.has("--force"):
		print("%s: %s already exists (it is edited by hand). Use -- --force to rebuild it." % [tag, path])
		get_tree().quit()
		return
	Terrain.sync()
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(kit_dir + "kit.json"))
	for item: Dictionary in cfg.items:
		kit[str(item.file)] = item
	run_h = _height(runs[0])
	rng.seed = seed_value
	seed(seed_value)  # Array.shuffle: the same map for the same seed
	var gen := layout.duplicate()
	gen["cells"] = cells
	fm = ForgeMap.new().generate(gen, rng)

	arena = Arena.new()
	arena.name = "Arena"
	arena.data = _data()
	for layer_name: String in Arena.LAYERS:
		_add(arena, _layer(layer_name))
	for layer_name: String in Arena.TERRAIN:
		_add(arena.get_node("Terrain"), _layer(layer_name))
	var bounds := ArenaBounds.new()
	bounds.name = Arena.BOUNDS
	bounds.size = Vector2(fm.w * cw, fm.h * ch) + origin + Vector2(32, 32)
	_add(arena, bounds)

	_floor()
	_gameplay()
	_walls()
	_corners()
	_decorate()
	_extra()

	var packed := PackedScene.new()
	var err := packed.pack(arena)
	if err == OK:
		err = ResourceSaver.save(packed, out)
	print("%s: %s -> %s (%d objects)" % [tag, error_string(err), out, arena.find_children("*", "ArenaObject", true, false).size()])
	arena.scene_file_path = out
	add_child(arena)
	var report := ArenaValidator.validate(arena)
	print("%s VALIDATION: %s" % [tag, report.summary()])
	for i in report.issues:
		if int(i.severity) > 0:
			print("  ", ["INFO", "WARNING", "ERROR"][i.severity], "  ", i.message)
	get_tree().quit()


## Override: anything else the world adds once the map is dressed.
func _extra() -> void:
	pass


# ------------------------------------------------------------------ scene helpers

func _layer(layer_name: String) -> Node:
	if layer_name in Arena.TERRAIN or layer_name == "Walls":
		var tl := TileMapLayer.new()
		tl.name = layer_name
		tl.tile_set = load(Terrain.tileset_path())
		tl.scale = Vector2.ONE * Arena.TERRAIN_SCALE
		tl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		return tl
	var n := Node2D.new()
	n.name = layer_name
	n.y_sort_enabled = bool(Arena.LAYERS.get(layer_name, {}).get("y_sort", false))
	return n


func _add(parent: Node, node: Node) -> Node:
	parent.add_child(node)
	node.owner = arena
	return node


## A gameplay object (spawn, objective, chest...) in GameplayObjects.
func _place(node: Node2D, at: Vector2) -> Node2D:
	node.position = at.round()
	_add(arena.get_layer("GameplayObjects"), node)
	busy.append(at)
	return node


func node_pos(i: int, j: int) -> Vector2:
	return origin + Vector2(i * cw, j * ch)


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(node_pos(c.x, c.y), Vector2(cw, ch))


func leaf_rect(li: int) -> Rect2:
	var r: Rect2i = fm.leaves[li].rect
	return Rect2(node_pos(r.position.x, r.position.y), Vector2(r.size.x * cw, r.size.y * ch))


## A kit piece standing with its bottom centre at `feet`, with the kit's defaults.
func _piece(file: String, feet: Vector2, flip := false) -> ArenaScenery:
	var item: Dictionary = kit[file]
	var s := ArenaScenery.new()
	s.name = file.get_file().get_basename().to_pascal_case()
	s.texture = load(kit_dir + file)
	s.width = float(item.width)
	s.flip_h = flip
	s.position = feet.round()
	s.fade_behind = bool(item.get("fade", false))
	s.flat = bool(item.get("flat", false))
	s.blocks_bullets = bool(item.get("blocks_bullets", true))
	if item.get("solid") is Array:
		s.footprint = Vector2(float(item.solid[0]), float(item.solid[1]))
	_add(arena.get_layer("Decorations" if s.flat else "Obstacles"), s)
	return s


## Height (world units) of a kit picture drawn at its kit width.
func _height(file: String) -> float:
	var t := load(kit_dir + file) as Texture2D
	return float(kit[file].width) * t.get_height() / t.get_width()


func _width(file: String) -> float:
	return float(kit[file].width)


## Depth of a piece's solid footprint (0 = none).
func _depth(file: String) -> float:
	var s: Variant = kit[file].get("solid")
	return float(s[1]) if s is Array else 0.0


func _pick(list: Array, weights: Array = []) -> String:
	if weights.is_empty() or weights.size() != list.size():
		return list[rng.randi() % list.size()]
	return list[rng.rand_weighted(PackedFloat32Array(weights))]


func _clear_of_busy(p: Vector2) -> bool:
	return busy.all(func(q: Vector2) -> bool: return q.distance_to(p) > keep_clear)


# ------------------------------------------------------------------ the map

## Floor tiles on every cell of an area; voids and pits stay empty.
func _floor() -> void:
	if floor_src < 0:
		return
	var fl := arena.get_layer("Floor") as TileMapLayer
	for j in fm.h:
		for i in fm.w:
			if fm.is_void(Vector2i(i, j)):
				continue
			var t0 := Vector2i(roundi(node_pos(i, j).x / Arena.TILE), roundi(node_pos(i, j).y / Arena.TILE))
			for ty in roundi(ch / Arena.TILE):
				for tx in roundi(cw / Arena.TILE):
					var k := 0
					if rng.randf() >= plain:
						k = rng.randi() % floor_tiles
						if k % 3 == 0:  # cracked / vent tiles less often
							k = rng.randi() % floor_tiles
					fl.set_cell(t0 + Vector2i(tx, ty), floor_src, Vector2i(k % floor_cols, k / floor_cols))


## The walls: columns down every drawn vertical edge (each from the post above to the
## next one down), then straight runs on every drawn horizontal edge (posts on the nodes,
## drawing centred on the node line; they sort over the column ends they meet). Free
## posts of pillared halls get a small piece.
func _walls() -> void:
	for j in fm.h:
		for i in fm.w + 1:
			if fm._vdrawn(i, j):
				var a := node_pos(i, j)
				for k in mods_y:
					_piece(_pick(columns, column_weights), Vector2(a.x, a.y + mod_h * (k + 1) + run_h * 0.5))
	for j in fm.h + 1:
		for i in fm.w:
			if fm._hdrawn(i, j):
				var a := node_pos(i, j)
				for k in mods_x:
					_piece(_pick(runs, run_weights), Vector2(a.x + mod_w * (k + 0.5), a.y + run_h * 0.5), rng.randf() < 0.5)
	if pots.is_empty():
		return
	for n: Vector2i in fm.pillars:
		if not _wall_at_node(n.x, n.y):
			_piece(_pick(pots), node_pos(n.x, n.y) + Vector2(0, 10))


func _wall_at_node(i: int, j: int) -> bool:
	return (i < fm.w and fm._hdrawn(i, j)) or (i > 0 and fm._hdrawn(i - 1, j)) \
		or (j < fm.h and fm._vdrawn(i, j)) or (j > 0 and fm._vdrawn(i, j - 1))


## The hall corners ForgeMap kept for machinery: a big piece pushed into each.
func _corners() -> void:
	if corner_big.is_empty():
		return
	for m: Array in fm.machines:
		var c: Vector2i = m[0]
		var kind: String = m[1]
		var cr := cell_rect(c)
		var file := _pick(corner_big)
		var w := _width(file)
		var x := cr.position.x + 18.0 + w * 0.5 if kind[1] == "l" else cr.end.x - 18.0 - w * 0.5
		var y := cr.position.y + run_h * 0.5 + _depth(file) + 4.0
		if kind[0] == "b":
			y = cr.end.y - run_h * 0.5 - 2.0
		if _clear_of_busy(Vector2(x, y)):
			_piece(file, Vector2(x, y), kind[1] == "r" and rng.randf() < 0.5)


## Halls get dressed: pieces against the top wall (pots at its ends), a centrepiece and
## lamps in big halls without an objective, garden islands in their open middle, floor
## bits. Nothing goes in front of a doorway or next to the gameplay spots.
func _decorate() -> void:
	var corners := {}
	for m: Array in fm.machines:
		corners[m[0]] = true
	for li in fm.leaves.size():
		var leaf: Dictionary = fm.leaves[li]
		var type := str(leaf.type)
		var r: Rect2i = leaf.rect
		if type == "solid":
			continue
		var roomy := type not in ["maze", "corridor"]
		if roomy and not along_wall.is_empty():
			var j := r.position.y
			for i in range(r.position.x, r.end.x):
				var c := Vector2i(i, j)
				if corners.has(c) or not fm.walkable(c) or not fm._hdrawn(i, j) or not _inner(c, li):
					continue
				var cr := cell_rect(c)
				for k in mods_x:  # a slot under each wall module
					if rng.randf() > 0.6:
						continue
					var left_wall := k == 0 and fm._vdrawn(i, j)
					var right_wall := k == mods_x - 1 and fm._vdrawn(i + 1, j)
					var x0 := cr.position.x + mod_w * k
					var file: String
					var x := x0 + mod_w * 0.5
					if (left_wall or right_wall) and not pots.is_empty():
						file = _pick(pots)
						x = x0 + 18.0 + _width(file) * 0.5 if left_wall else x0 + mod_w - 18.0 - _width(file) * 0.5
					else:
						file = _pick(along_wall)
						if _width(file) > mod_w - 24.0:
							continue
					var y := cr.position.y + run_h * 0.5 + maxf(_depth(file), 6.0) + 3.0
					if _clear_of_busy(Vector2(x, y)):
						_piece(file, Vector2(x, y), rng.randf() < 0.5)
		if roomy and not along_side.is_empty():
			_side_pieces(li, r)
		if roomy and not centrepieces.is_empty() and r.size.x >= 2 and r.size.y >= 2 and li != fm.start_leaf \
				and not fm.core_leaves.has(li) and rng.randf() < 0.75:
			var mid := leaf_rect(li).get_center() + Vector2(0, 14)
			var file := _pick(centrepieces)
			if _clear_of_busy(mid) and _width(file) < r.size.x * cw - 120.0:
				_piece(file, mid)
			if not lamps.is_empty() and r.size.x >= 3 and rng.randf() < 0.6:
				for side in [-1.0, 1.0]:
					var lp: Vector2 = mid + Vector2(side * cw * 0.9, 22)
					if _clear_of_busy(lp):
						_piece(lamps[0], lp)
		if roomy and not islands.is_empty() and r.size.x >= 3 and r.size.y >= 3:
			for y in range(r.position.y + 1, r.end.y - 1):
				for x in range(r.position.x + 1, r.end.x - 1):
					var c := Vector2i(x, y)
					if not fm.walkable(c) or (x + y) % 2 == 1 or rng.randf() > 0.45:
						continue
					var p := cell_rect(c).get_center() + Vector2(0, 16)
					if not _clear_of_busy(p) or p.distance_to(leaf_rect(li).get_center() + Vector2(0, 14)) < 120.0:
						continue
					_island(p)
		if floor_bits.is_empty():
			continue
		var n_bits := rng.randi_range(0, 2) if roomy else 0
		for k in n_bits:
			var c := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
			if not fm.walkable(c):
				continue
			var p := cell_rect(c).get_center() + Vector2(rng.randf_range(-60, 60), rng.randf_range(-20, 30))
			_piece(_pick(floor_bits), p)


## Pieces against the side walls of hall li: in its left / right column cells (below the
## top row) whose outer edge is a wall, at the cell's middle, never next to a doorway.
func _side_pieces(li: int, r: Rect2i) -> void:
	for y in range(r.position.y + 1, r.end.y):
		for side in [0, 1]:
			var x: int = r.position.x if side == 0 else r.end.x - 1
			var c := Vector2i(x, y)
			var walled := fm._vdrawn(x, y) if side == 0 else fm._vdrawn(x + 1, y)
			if not walled or not fm.walkable(c) or fm.region[fm.idx(c)] != li or rng.randf() > side_share:
				continue
			var below := c + Vector2i.DOWN
			if not fm._hdrawn(c.x, c.y + 1) and (not fm.inside(below) or fm.region[fm.idx(below)] != li):
				continue  # a doorway under it
			var file := _pick(along_side)
			var cr := cell_rect(c)
			var w := _width(file)
			var px: float = cr.position.x + 22.0 + w * 0.5 if side == 0 else cr.end.x - 22.0 - w * 0.5
			var p := Vector2(px, cr.get_center().y + 10.0)
			if _clear_of_busy(p):
				_piece(file, p, side == 1)


## An island: a core piece in the middle, small pieces either side.
func _island(p: Vector2) -> void:
	var core := _pick(islands)
	_piece(core, p)
	if pots.is_empty():
		return
	var half := _width(core) * 0.5
	for side in [-1.0, 1.0]:
		if rng.randf() < 0.7:
			var pot := _pick(pots)
			_piece(pot, p + Vector2(side * (half + _width(pot) * 0.5 + 4.0), rng.randf_range(-4, 6)))


## Inside hall li away from its doorways: the cells beside and below are the same hall
## (or a wall stands between).
func _inner(c: Vector2i, li: int) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var n := c + d
		var walled := (d == Vector2i.LEFT and fm._vdrawn(c.x, c.y)) or (d == Vector2i.RIGHT and fm._vdrawn(c.x + 1, c.y)) \
			or (d == Vector2i.DOWN and fm._hdrawn(c.x, c.y + 1))
		if walled:
			continue
		if not fm.inside(n) or fm.region[fm.idx(n)] != li:
			return false
	return true


## Player spawn, the objective objects in the middle of their halls, one random chest a
## hall (none in the start hall) and survivors on other halls' free spots, away from chests.
func _gameplay() -> void:
	var start := cell_rect(fm.start_cell()).get_center() + Vector2(0, 8)
	var ps := PlayerSpawn.new()
	ps.name = "PlayerSpawn"
	_place(ps, start)
	var n_obj := 0
	for li in fm.core_leaves:
		var at := leaf_rect(li).get_center() + Vector2(0, 16)
		var o := _objective(n_obj, at)
		if o != null:
			_place(o, at)
			busy.append(at + Vector2(0, -40))
			n_obj += 1
	var spots: Array = []  # [hall, spot]
	var halls: Array[int] = []
	for li in fm.leaves.size():
		if fm.leaves[li].type == "solid" or li == fm.start_leaf:
			continue
		var list := _spots(li)
		if list.is_empty():
			continue
		list.shuffle()
		halls.append(li)
		for p: Vector2 in list:
			spots.append([li, p])
	halls.shuffle()
	var chest_at: Array[Vector2] = []
	for li in halls:
		if chest_at.size() >= chests:
			break
		for s: Array in spots:
			if int(s[0]) == li:
				chest_at.append(s[1])
				break
	for i in chest_at.size():
		var c := ArenaChest.new()
		c.name = "Chest%d" % (i + 1)
		c.object_id = "chest_%d" % (i + 1)
		c.random_kind = true
		_place(c, chest_at[i])
	var crew: Array = range(SurvivorData.CREW.size())
	crew.shuffle()
	var used := {}
	var placed := 0
	spots.shuffle()
	for s: Array in spots:
		if placed >= survivors:
			break
		var p: Vector2 = s[1]
		if used.has(s[0]) or chest_at.any(func(q: Vector2) -> bool: return q.distance_to(p) < 70.0):
			continue
		used[s[0]] = true
		var sv := ArenaSurvivor.new()
		sv.name = "Survivor%d" % (placed + 1)
		sv.object_id = "survivor_%d" % (placed + 1)
		sv.crew = int(crew[placed % crew.size()])
		_place(sv, p)
		placed += 1
	print("%s: %d halls, %d objectives, %d chests, %d survivors" % [tag, fm.leaves.size(), n_obj, chest_at.size(), placed])


## Free spots of hall li: walkable cell middles (below the top wall's solid band), away
## from the hall corners' machines and an objective in the middle.
func _spots(li: int) -> Array:
	var r: Rect2i = fm.leaves[li].rect
	var mid := leaf_rect(li).get_center()
	var obj := fm.core_leaves.has(li)
	var out: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if not fm.walkable(c) or fm.machines.any(func(m: Array) -> bool: return m[0] == c):
				continue
			var p := cell_rect(c).get_center() + Vector2(0, 8)
			if obj and p.distance_to(mid) < 110.0:
				continue
			out.append(p)
	return out
