@tool
extends RefCounted
## Builds / updates the arena TileSet from assets/arena/terrain/terrain.json, so terrain
## art is swapped by editing data, not code:
##   {"tile": 64, "tileset": "res://...tres", "sources": [{"id", "name", "path", "solid"?,
##    "fill"?: tiles used to fill a new floor, "border"?: wall atlas rows}]}
## Source ids are stable: painted arenas keep pointing at the same source after a sync.
## New tiles are created for every non-empty cell of each atlas; "solid" tiles get a
## full-tile collision polygon on physics layer 0 (collision layer 1 = "world").

const CONFIG := "res://assets/arena/terrain/terrain.json"
const WALKABLE := 1  # alternative tile id of a solid tile without its collision


static func config() -> Dictionary:
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return cfg if cfg is Dictionary else {}


static func tileset_path() -> String:
	return str(config().get("tileset", "res://scenes/arena/terrain/arena_terrain.tres"))


## Creates or updates the TileSet and saves it. Returns it (null on error).
static func sync() -> TileSet:
	var cfg := config()
	if cfg.is_empty():
		push_error("Arena Editor: cannot read " + CONFIG)
		return null
	var tile := int(cfg.get("tile", 64))
	var path := str(cfg.get("tileset"))
	var ts: TileSet = load(path) if ResourceLoader.exists(path) else TileSet.new()
	ts.tile_size = Vector2i(tile, tile)
	if ts.get_physics_layers_count() == 0:
		ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	_terrains(ts, cfg.get("terrains", []))
	var h := tile * 0.5
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for src: Dictionary in cfg.get("sources", []):
		var id := int(src.id)
		var tex: Texture2D = load(str(src.path))
		if tex == null:
			push_error("Arena Editor: terrain texture not found: " + str(src.path))
			continue
		var atlas: TileSetAtlasSource
		if ts.has_source(id):
			atlas = ts.get_source(id) as TileSetAtlasSource
		else:
			atlas = TileSetAtlasSource.new()
			ts.add_source(atlas, id)
		atlas.resource_name = display_name(src)
		if atlas.texture != null and atlas.texture.resource_path != tex.resource_path:
			# new art for this id: rebuild its tiles (painted cells keep their coordinates)
			for i in range(atlas.get_tiles_count() - 1, -1, -1):
				atlas.remove_tile(atlas.get_tile_id(i))
		atlas.texture = tex
		atlas.texture_region_size = Vector2i(tile, tile)
		var shapes := {}
		var solid: Variant = src.get("solid", false)
		if solid is String:  # per-tile collision polygons (64 px tile, centred)
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(solid))
			shapes = parsed if parsed is Dictionary else {}
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var cells := atlas.get_atlas_grid_size()
		# tiles the new picture no longer has (smaller or emptier atlas)
		for i in range(atlas.get_tiles_count() - 1, -1, -1):
			var old := atlas.get_tile_id(i)
			if old.x >= cells.x or old.y >= cells.y or img.get_region(Rect2i(old * tile, Vector2i(tile, tile))).is_invisible():
				atlas.remove_tile(old)
		var exclude: Array = src.get("exclude", [])
		for y in cells.y:
			for x in cells.x:
				var c := Vector2i(x, y)
				if exclude.has(y * cells.x + x) or exclude.has(float(y * cells.x + x)):
					if atlas.has_tile(c):
						atlas.remove_tile(c)  # left out of the painter on purpose
					continue
				if not atlas.has_tile(c):
					if img.get_region(Rect2i(c * tile, Vector2i(tile, tile))).is_invisible():
						continue
					atlas.create_tile(c)
				var data := atlas.get_tile_data(c, 0)
				var index := y * cells.x + x
				_terrain_tile(data, index, src.get("terrain", {}))
				var polys: Array = []
				if solid is String:
					for poly: Array in shapes.get(str(index), []):
						var pts := PackedVector2Array()
						for p: Array in poly:
							pts.append(Vector2(float(p[0]), float(p[1])) * (tile / 64.0))
						polys.append(pts)
				elif bool(solid):
					polys = [square]
				if not polys.is_empty():
					data.set_collision_polygons_count(0, polys.size())
					for k in polys.size():
						data.set_collision_polygon_points(0, k, polys[k])
					# alternative 1: the same tile, walkable (bridges switch water to it)
					if not atlas.has_alternative_tile(c, WALKABLE):
						atlas.create_alternative_tile(c, WALKABLE)
					atlas.get_tile_data(c, WALKABLE).set_collision_polygons_count(0, 0)
				else:
					data.set_collision_polygons_count(0, 0)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(ts, path)
	if err != OK:
		push_error("Arena Editor: could not save %s (%s)" % [path, error_string(err)])
		return null
	return ts


## One terrain set (corners): its terrains named and coloured from terrain.json.
static func _terrains(ts: TileSet, list: Array) -> void:
	if list.is_empty():
		return
	if ts.get_terrain_sets_count() == 0:
		ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	while ts.get_terrains_count(0) < list.size():
		ts.add_terrain(0)
	for i in list.size():
		ts.set_terrain_name(0, i, str(list[i].name))
		ts.set_terrain_color(0, i, Color(str(list[i].color)))


const CORNERS := [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]


## Terrain of tile `index`: "all" = every corner that terrain; "wang" = [land, other]:
## the first 16 x "variants" tiles carry their corners in their index bits (index % 16:
## TL 1, TR 2, BL 4, BR 8), any tile after them is `other` all over (a rarer variant:
## "extra_probability").
static func _terrain_tile(data: TileData, index: int, t: Dictionary) -> void:
	if t.is_empty():
		return
	data.terrain_set = 0
	if t.has("all"):
		data.terrain = int(t.all)
		for c in CORNERS:
			data.set_terrain_peering_bit(c, int(t.all))
		var probs: Array = t.get("probabilities", [])
		if index < probs.size():
			data.probability = float(probs[index])
		return
	var pair: Array = t.wang
	var cases := 16 * int(t.get("variants", 1))
	if index >= cases:
		data.terrain = int(pair[1])
		for c in CORNERS:
			data.set_terrain_peering_bit(c, int(pair[1]))
		data.probability = float(t.get("extra_probability", 0.2))
		return
	var others := 0
	var case := index % 16
	for k in 4:
		var bit := (case >> k) & 1
		data.set_terrain_peering_bit(CORNERS[k], int(pair[bit]))
		others += bit
	# the tile "is" the other terrain from two corners up: painting a strip of it then
	# uses straight edge tiles instead of zig-zagging between three-corner ones
	data.terrain = int(pair[1]) if others >= 2 else int(pair[0])


## "Group · Name" (how the TileMap panel lists the source).
static func display_name(src: Dictionary) -> String:
	var n := str(src.get("name", "Source %d" % int(src.id)))
	return "%s · %s" % [src.group, n] if src.has("group") else n


static func source_def(id: int) -> Dictionary:
	for src: Dictionary in config().get("sources", []):
		if int(src.id) == id:
			return src
	return {}


## Sources that can fill a floor: [{id, name}] (those with "fill", or any non-solid one).
static func floor_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for src: Dictionary in config().get("sources", []):
		if src.has("fill"):
			out.append(src)
	return out


## The source with a "border" description (walls), or {}.
static func wall_source() -> Dictionary:
	for src: Dictionary in config().get("sources", []):
		if src.has("border"):
			return src
	return {}
