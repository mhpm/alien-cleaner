@tool
extends RefCounted
## Creates arena scenes with the standard structure (Arena.LAYERS) and repairs scenes
## that lost a layer. Terrain comes from the TileSet the builder keeps in sync.

const Terrain := preload("terrain_tileset_builder.gd")
const ARENAS := "res://scenes/arenas/"


static func scene_path(world: int, level: int) -> String:
	return ARENAS + "arena_world_%02d_level_%02d.tscn" % [world, level]


## One empty layer node of the standard structure ("Terrain/Floor" style names allowed).
static func make_layer(path: String) -> Node:
	var layer_name := path.get_file()
	if layer_name == Arena.BOUNDS:
		var b := ArenaBounds.new()
		b.name = Arena.BOUNDS
		return b
	if layer_name in Arena.TERRAIN or layer_name == "Walls":
		var tl := TileMapLayer.new()
		tl.name = layer_name
		var ts_path := Terrain.tileset_path()
		if ResourceLoader.exists(ts_path):
			tl.tile_set = load(ts_path)
		tl.scale = Vector2.ONE * Arena.TERRAIN_SCALE
		# same look as the game's arena floor: the 64 px art is drawn at half size
		tl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		return tl
	var node := Node2D.new()
	node.name = layer_name
	node.y_sort_enabled = bool(Arena.LAYERS.get(layer_name, {}).get("y_sort", false))
	return node


## Builds and saves a new arena. cfg: world, level, name, cols, rows (tiles),
## floor (source id, -1 = none), style (wall_styles key; legacy walls: bool), thickness, seed. Returns the scene path or "" on error.
static func create(cfg: Dictionary) -> String:
	var path := scene_path(int(cfg.world), int(cfg.level))
	if FileAccess.file_exists(path):
		push_error("Arena Editor: %s already exists." % path)
		return ""
	if not ResourceLoader.exists(Terrain.tileset_path()):
		Terrain.sync()
	var arena := Arena.new()
	arena.name = "Arena"
	arena.data = new_data(int(cfg.world), int(cfg.level), str(cfg.get("name", "")))
	for layer_name: String in Arena.LAYERS:
		_add(arena, arena, make_layer(layer_name))
	var terrain := arena.get_node("Terrain")
	for layer_name: String in Arena.TERRAIN:
		_add(arena, terrain, make_layer(layer_name))
	var cols := int(cfg.cols)
	var rows := int(cfg.rows)
	var bounds := make_layer(Arena.BOUNDS) as ArenaBounds
	bounds.size = Vector2(cols, rows) * Arena.TILE
	_add(arena, arena, bounds)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	if int(cfg.get("floor", -1)) >= 0:
		fill_floor(arena.get_layer("Floor") as TileMapLayer, int(cfg.floor), Rect2i(0, 0, cols, rows), rng)
	var style := str(cfg.get("style", "border:-1" if bool(cfg.get("walls", false)) else "none"))
	var walls := arena.get_layer("Walls") as TileMapLayer
	if style.begins_with("border:"):
		wall_border(walls, Rect2i(0, 0, cols, rows), int(style.get_slice(":", 1)))
	elif style.begins_with("ring:"):
		wang_band(walls, Rect2i(0, 0, cols, rows), int(style.get_slice(":", 1)), maxi(1, int(cfg.get("thickness", 3))), rng)
	var packed := PackedScene.new()
	var err := packed.pack(arena)
	arena.free()
	if err != OK:
		push_error("Arena Editor: could not pack the arena (%s)." % error_string(err))
		return ""
	DirAccess.make_dir_recursive_absolute(ARENAS)
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Arena Editor: could not save %s (%s)." % [path, error_string(err)])
		return ""
	return path


## Fresh ArenaData: one MAIN objective (clear every wave) and one wave of the "w1" spawners.
static func new_data(world: int, level: int, display_name: String) -> ArenaData:
	var d := ArenaData.new()
	d.world_id = world
	d.level_id = level
	d.arena_id = "w%02d_a%02d" % [world, level]
	d.display_name = display_name
	d.prop_theme = "hive" if world == 2 else "ship"
	var main := ObjectiveData.new()
	main.objective_id = "main"
	main.type = ObjectiveData.Type.CLEAR_WAVES
	d.objectives.append(main)
	var w := WaveData.new()
	w.wave_id = "w1"
	d.waves.append(w)
	return d


static func _add(arena: Arena, parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = arena


## Random plain tiles of a floor source over `cells` (the first "fill" tiles of its atlas).
static func fill_floor(layer: TileMapLayer, source_id: int, cells: Rect2i, rng: RandomNumberGenerator) -> void:
	var src := Terrain.source_def(source_id)
	var atlas := layer.tile_set.get_source(source_id) as TileSetAtlasSource if layer.tile_set != null and layer.tile_set.has_source(source_id) else null
	if src.is_empty() or atlas == null:
		push_warning("Arena Editor: floor source %d is not in the TileSet (TERRAIN > Sync TileSet)." % source_id)
		return
	var acols := atlas.get_atlas_grid_size().x
	var n := mini(int(src.get("fill", 1)), atlas.get_tiles_count())
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var i := rng.randi_range(0, n - 1)
			layer.set_cell(Vector2i(x, y), source_id, Vector2i(i % acols, i / acols))


## Wall strips just outside `cells` (the "border" rows of the wall source) + corners.
static func wall_border(layer: TileMapLayer, cells: Rect2i, source_id := -1) -> void:
	var src := Terrain.wall_source() if source_id < 0 else Terrain.source_def(source_id)
	if src.is_empty() or not src.has("border") or layer.tile_set == null or not layer.tile_set.has_source(int(src.id)):
		push_warning("Arena Editor: no wall source with a \"border\" in terrain.json.")
		return
	var id := int(src.id)
	var b: Dictionary = src.border
	var x0 := cells.position.x
	var y0 := cells.position.y
	var x1 := cells.end.x
	var y1 := cells.end.y
	for x in range(x0, x1):
		layer.set_cell(Vector2i(x, y0 - 1), id, Vector2i((x - x0) % 4, int(b.top)))
		layer.set_cell(Vector2i(x, y1), id, Vector2i((x - x0) % 4, int(b.bottom)))
	for y in range(y0, y1):
		layer.set_cell(Vector2i(x0 - 1, y), id, Vector2i((y - y0) % 4, int(b.left)))
		layer.set_cell(Vector2i(x1, y), id, Vector2i((y - y0) % 4, int(b.right)))
	var c := int(b.corners)
	layer.set_cell(Vector2i(x0 - 1, y0 - 1), id, Vector2i(0, c))
	layer.set_cell(Vector2i(x1, y0 - 1), id, Vector2i(1, c))
	layer.set_cell(Vector2i(x0 - 1, y1), id, Vector2i(2, c))
	layer.set_cell(Vector2i(x1, y1), id, Vector2i(3, c))


## Wall styles for an existing arena: [{key, name}]. "none", "border:<id>" (wall strips of
## a source with "border") and "ring:<id>" (a band of a solid wang autotile, e.g. water).
static func wall_styles() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"key": "none", "name": "None (open: only the bounds stop you)"}]
	var terrains: Array = Terrain.config().get("terrains", [])
	for src: Dictionary in Terrain.config().get("sources", []):
		if src.has("border"):
			out.append({"key": "border:%d" % int(src.id), "name": "Wall strips · " + Terrain.display_name(src)})
		elif src.has("solid") and src.get("terrain", {}).has("wang"):
			var other := int(src.terrain.wang[1])
			var t_name := str(terrains[other].name) if other < terrains.size() else Terrain.display_name(src)
			out.append({"key": "ring:%d" % int(src.id), "name": "%s band (autotile)" % t_name})
	return out


## The arena's bounds as a cell rect of `layer`.
static func bounds_cells(arena: Arena, layer: TileMapLayer) -> Rect2i:
	var b := arena.get_bounds()
	var half := Vector2.ONE * Arena.TILE * 0.5
	var a := layer.local_to_map(layer.to_local(b.global_position + half))
	var e := layer.local_to_map(layer.to_local(b.global_position + b.size - half))
	return Rect2i(a, e - a + Vector2i.ONE)


## Resizes the bounds and rebuilds the frame around them. cfg: cols, rows (tiles),
## style (wall_styles key), thickness (band tiles), clear ("frame" = old wall strips and
## bands, "all" = the whole Walls layer, "keep"), floor (-2 keep, else source id that
## fills the empty floor cells inside), trim (erase terrain outside the bounds), seed.
## Edits the live nodes; the caller snapshots them for undo.
static func refit(arena: Arena, cfg: Dictionary) -> void:
	var bounds := arena.get_bounds()
	bounds.size = Vector2(int(cfg.cols), int(cfg.rows)) * Arena.TILE
	var walls := arena.get_layer("Walls") as TileMapLayer
	var floor_layer := arena.get_layer("Floor") as TileMapLayer
	var styles := wall_styles()
	var frame_ids: Array[int] = []
	for s: Dictionary in styles:
		if s.key != "none":
			frame_ids.append(int(str(s.key).get_slice(":", 1)))
	if walls != null:
		match str(cfg.get("clear", "frame")):
			"all":
				walls.clear()
			"frame":
				for c in walls.get_used_cells():
					if walls.get_cell_source_id(c) in frame_ids:
						walls.erase_cell(c)
	if bool(cfg.get("trim", false)):
		for layer_name: String in Arena.TERRAIN:
			var tl := arena.get_layer(layer_name) as TileMapLayer
			if tl == null:
				continue
			var keep := bounds_cells(arena, tl)
			for c in tl.get_used_cells():
				if not keep.has_point(c):
					tl.erase_cell(c)
	if floor_layer != null and int(cfg.get("floor", -2)) >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(cfg.get("seed", 1))
		var inside := bounds_cells(arena, floor_layer)
		var fill := floor_layer.duplicate() as TileMapLayer
		fill_floor(fill, int(cfg.floor), inside, rng)
		for y in range(inside.position.y, inside.end.y):
			for x in range(inside.position.x, inside.end.x):
				var c := Vector2i(x, y)
				if floor_layer.get_cell_source_id(c) == -1 and fill.get_cell_source_id(c) != -1:
					floor_layer.set_cell(c, fill.get_cell_source_id(c), fill.get_cell_atlas_coords(c))
		fill.free()
	if walls == null:
		return
	var style := str(cfg.get("style", "none"))
	var cells := bounds_cells(arena, walls)
	if style.begins_with("border:"):
		wall_border(walls, cells, int(style.get_slice(":", 1)))
	elif style.begins_with("ring:"):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(cfg.get("seed", 1))
		wang_band(walls, cells, int(style.get_slice(":", 1)), maxi(1, int(cfg.get("thickness", 3))), rng)


## A band `thickness` tiles wide of the "other" terrain of wang source `source_id` around
## `cells`, with its shoreline tiles on the cells just inside the edge.
static func wang_band(layer: TileMapLayer, cells: Rect2i, source_id: int, thickness: int, rng: RandomNumberGenerator) -> void:
	var src := Terrain.source_def(source_id)
	var atlas := layer.tile_set.get_source(source_id) as TileSetAtlasSource if layer.tile_set != null and layer.tile_set.has_source(source_id) else null
	if atlas == null or not src.get("terrain", {}).has("wang"):
		push_warning("Arena Editor: source %d is not a wang autotile in the TileSet (Sync TileSet)." % source_id)
		return
	var acols := atlas.get_atlas_grid_size().x
	var variants := int(src.terrain.get("variants", 1))
	var x0 := cells.position.x
	var y0 := cells.position.y
	var x1 := cells.end.x
	var y1 := cells.end.y
	# a corner point is "other" on or outside the edge of the bounds
	var other := func(cx: int, cy: int) -> bool: return cx <= x0 or cx >= x1 or cy <= y0 or cy >= y1
	for y in range(y0 - thickness, y1 + thickness):
		for x in range(x0 - thickness, x1 + thickness):
			var case := (1 if other.call(x, y) else 0) | (2 if other.call(x + 1, y) else 0) \
				| (4 if other.call(x, y + 1) else 0) | (8 if other.call(x + 1, y + 1) else 0)
			if case == 0:
				continue
			var i := rng.randi_range(0, variants - 1) * 16 + case
			var coords := Vector2i(i % acols, i / acols)
			if not atlas.has_tile(coords):
				coords = Vector2i(case % acols, case / acols)
			layer.set_cell(Vector2i(x, y), source_id, coords)


## Copies the arena scene `src_path` to world/level: its own deep copy of ArenaData with
## a new id, the same objects and terrain. Returns [new path or "", android parts copied]
## (android part ids must stay unique: the caller warns, validation flags them).
static func duplicate_arena(src_path: String, world: int, level: int) -> Array:
	var path := scene_path(world, level)
	if FileAccess.file_exists(path):
		push_error("Arena Editor: %s already exists." % path)
		return ["", 0]
	var src := load(src_path) as PackedScene
	if src == null:
		return ["", 0]
	var arena := src.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Arena
	_unshare(arena)
	var data: ArenaData = arena.data if arena.data != null else new_data(world, level, "")
	data.world_id = world
	data.level_id = level
	data.arena_id = "w%02d_a%02d" % [world, level]
	if not data.display_name.is_empty():
		data.display_name += " II"
	arena.data = data
	var parts := arena.objects("AndroidPart").size()
	var packed := PackedScene.new()
	var err := packed.pack(arena)
	arena.free()
	if err == OK:
		err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Arena Editor: could not duplicate to %s (%s)." % [path, error_string(err)])
		return ["", 0]
	return [path, parts]


## Gives every node of the copy its own copies of the resources embedded in the source
## scene (ArenaData, SpawnEntry lists, rewards...), so editing one arena never edits the
## other. Shared files (textures, the TileSet) stay shared.
static func _unshare(root: Node) -> void:
	for node in [root] + root.find_children("*", "", true, false):
		for prop in node.get_property_list():
			if not prop.usage & PROPERTY_USAGE_STORAGE:
				continue
			var v: Variant = node.get(prop.name)
			if v is Resource and _embedded(v):
				node.set(prop.name, (v as Resource).duplicate_deep(Resource.DEEP_DUPLICATE_ALL))
			elif v is Array and (v as Array).any(func(x: Variant) -> bool: return x is Resource and _embedded(x)):
				var copy := (v as Array).duplicate()
				for i in copy.size():
					if copy[i] is Resource and _embedded(copy[i]):
						copy[i] = (copy[i] as Resource).duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
				node.set(prop.name, copy)


static func _embedded(r: Resource) -> bool:
	return r.resource_path.is_empty() or r.resource_path.contains("::")


## Adds every missing layer as one undoable action. Returns how many were added.
static func repair(arena: Arena, ur: EditorUndoRedoManager) -> int:
	var missing := arena.missing_layers()
	var added := missing.size()
	if added == 0:
		return 0
	ur.create_action("Repair Arena Structure", UndoRedo.MERGE_DISABLE, arena)
	var terrain := arena.get_node_or_null("Terrain")
	# Terrain itself first, so its children have a parent when the action runs
	if missing.has("Terrain"):
		terrain = make_layer("Terrain")
		_undoable_add(ur, arena, arena, terrain)
		missing.erase("Terrain")
	for path in missing:
		var parent: Node = terrain if path.begins_with("Terrain/") else arena
		_undoable_add(ur, arena, parent, make_layer(path))
	ur.commit_action()
	return added


static func _undoable_add(ur: EditorUndoRedoManager, arena: Arena, parent: Node, node: Node) -> void:
	ur.add_do_method(parent, "add_child", node, true)
	ur.add_do_method(node, "set_owner", arena)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
