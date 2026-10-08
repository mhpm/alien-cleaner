@tool
extends RefCounted
## The terrain tile library behind the dock's "Tiles" window: everything terrain.json
## describes, editable without touching the file. Every change saves terrain.json and
## re-syncs the TileSet (terrain_tileset_builder.gd), so painted arenas pick it up.
##   import_sheet   cut a sheet by tile size / margin / separation, scale each tile to the
##                  library's 64 px, optionally make it seamless -> new atlas source
##   import_images  loose pictures, one tile each -> new atlas source
##   make_autotile  16 x 3 corner-transition tiles between two existing tiles (rounded,
##                  wobbly border, rims for water / path / infested), a new terrain type,
##                  and collision polygons that follow the edge when it should block
##   update / remove / set_excluded / add_terrain
## Imported art is copied to assets/arena/terrain/custom/<id>_<name>.png; the original
## file and its cut settings are remembered ("origin") so it can be re-imported.

const Terrain := preload("terrain_tileset_builder.gd")
const T := 64
const CUSTOM := "res://assets/arena/terrain/custom/"


static func load_config() -> Dictionary:
	return Terrain.config()


static func save_config(cfg: Dictionary) -> void:
	var f := FileAccess.open(Terrain.CONFIG, FileAccess.WRITE)
	f.store_string(JSON.stringify(_ints(cfg), "\t", false))
	f.close()


## JSON reads every number as a float: write whole numbers back as ints (ids, indices).
static func _ints(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _ints(x))
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[k] = _ints(v[k])
		return d
	return v


## Saves terrain.json, imports new pictures and rebuilds the TileSet.
static func commit(cfg: Dictionary) -> TileSet:
	save_config(cfg)
	var fs := EditorInterface.get_resource_filesystem()
	var fresh: Array[String] = []
	for src: Dictionary in cfg.get("sources", []):
		if not ResourceLoader.exists(str(src.path)):
			fresh.append(str(src.path))
	if not fresh.is_empty():
		# new pictures must be scanned and imported before the TileSet can use them
		fs.scan()
		var tree := Engine.get_main_loop() as SceneTree
		var until := Time.get_ticks_msec() + 60000  # an unfocused editor runs few frames: wait by time
		while Time.get_ticks_msec() < until and (fs.is_scanning() or not fresh.all(_imported)):
			await tree.process_frame
	return Terrain.sync()


## Godot has fully imported `path` (its .import file points at a texture that exists).
static func _imported(path: String) -> bool:
	if not FileAccess.file_exists(path + ".import"):
		return false
	for line in FileAccess.get_file_as_string(path + ".import").split("
"):
		if line.begins_with("path=") or line.begins_with("path.s3tc=") or line.begins_with("path.etc2="):
			return FileAccess.file_exists(line.get_slice("\"", 1))
	return false


static func next_id(cfg: Dictionary) -> int:
	var top := -1
	for src: Dictionary in cfg.get("sources", []):
		top = maxi(top, int(src.id))
	return top + 1


static func groups(cfg: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for src: Dictionary in cfg.get("sources", []):
		var g := str(src.get("group", "General"))
		if not out.has(g):
			out.append(g)
	return out


static func find(cfg: Dictionary, id: int) -> Dictionary:
	for src: Dictionary in cfg.get("sources", []):
		if int(src.id) == id:
			return src
	return {}


# ---------------------------------------------------------------- importing

## opts: name, group, tile (Vector2i), margin (Vector2i), separation (Vector2i),
## skip_empty, seamless, solid. Returns the new source's id (-1 on error).
static func import_sheet(file: String, opts: Dictionary) -> int:
	var img := _load(file)
	if img == null:
		return -1
	var tile: Vector2i = opts.get("tile", Vector2i(T, T))
	var margin: Vector2i = opts.get("margin", Vector2i.ZERO)
	var sep: Vector2i = opts.get("separation", Vector2i.ZERO)
	var tiles: Array[Image] = []
	var y := margin.y
	while y + tile.y <= img.get_height():
		var x := margin.x
		while x + tile.x <= img.get_width():
			var t := img.get_region(Rect2i(Vector2i(x, y), tile))
			if not (bool(opts.get("skip_empty", true)) and t.is_invisible()):
				tiles.append(_fit(t, bool(opts.get("seamless", false))))
			x += tile.x + sep.x
		y += tile.y + sep.y
	return await _add_source(tiles, file, opts, {"tile": [tile.x, tile.y], "margin": [margin.x, margin.y], "separation": [sep.x, sep.y]})


## Each picture becomes one tile (scaled to 64 px). Returns the new id (-1 on error).
static func import_images(files: PackedStringArray, opts: Dictionary) -> int:
	var tiles: Array[Image] = []
	for file in files:
		var img := _load(file)
		if img != null:
			tiles.append(_fit(img, bool(opts.get("seamless", false))))
	return await _add_source(tiles, files[0] if not files.is_empty() else "", opts, {"images": Array(files)})


static func _load(file: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(file) if file.begins_with("res://") else file)
	if img == null or img.is_empty():
		push_error("Tile library: cannot read " + file)
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _fit(t: Image, make_seamless: bool) -> Image:
	t = t.duplicate()
	if t.get_size() != Vector2i(T, T):
		t.resize(T, T, Image.INTERPOLATE_LANCZOS)
	return seamless(t) if make_seamless else t


static func _add_source(tiles: Array[Image], origin_file: String, opts: Dictionary, origin: Dictionary) -> int:
	if tiles.is_empty():
		push_error("Tile library: no tiles found (check the tile size and margins).")
		return -1
	var cfg := load_config()
	var id := next_id(cfg)
	var name := str(opts.get("name", "Tiles %d" % id))
	var path := CUSTOM + "%d_%s.png" % [id, name.to_snake_case()]
	DirAccess.make_dir_recursive_absolute(CUSTOM)
	pack(tiles).save_png(path)
	origin["from"] = origin_file
	origin["seamless"] = bool(opts.get("seamless", false))
	var src := {"id": id, "name": name, "group": str(opts.get("group", "Custom")), "path": path, "origin": origin}
	if bool(opts.get("solid", false)):
		src["solid"] = true
	cfg.sources.append(src)
	await commit(cfg)
	return id


## Tiles side by side, 8 per row.
static func pack(tiles: Array[Image]) -> Image:
	var cols := mini(8, tiles.size())
	var rows := ceili(tiles.size() / float(cols))
	var atlas := Image.create(cols * T, rows * T, false, Image.FORMAT_RGBA8)
	for i in tiles.size():
		atlas.blit_rect(tiles[i], Rect2i(0, 0, T, T), Vector2i((i % cols) * T, (i / cols) * T))
	return atlas


## A tile that repeats without a visible joint: its middle, cross-faded at the borders
## with itself shifted by half a tile.
static func seamless(t: Image) -> Image:
	var out := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var h := T / 2
	for y in T:
		for x in T:
			var d := minf(minf(x, T - 1 - x), minf(y, T - 1 - y)) / float(h)
			var w := clampf(d * 1.7 - 0.1, 0.0, 1.0)
			var a := t.get_pixel(x, y)
			var b := t.get_pixel((x + h) % T, (y + h) % T)
			out.set_pixel(x, y, b.lerp(a, w))
	return out


# ---------------------------------------------------------------- editing

## Changes name / group / solid / fill / terrain of a source.
static func update(id: int, values: Dictionary) -> void:
	var cfg := load_config()
	var src := find(cfg, id)
	if src.is_empty():
		return
	for k: String in values:
		if values[k] == null:
			src.erase(k)
		else:
			src[k] = values[k]
	await commit(cfg)


## Collision of single tiles (atlas reading order): "solid" = they block, "walk" = they
## never block, "reset" = whatever their source says. Kept in terrain.json, so a sync
## (which rebuilds every tile's collision) does not lose it.
static func set_tile_collision(id: int, indices: Array, mode: String) -> void:
	var src := find(load_config(), id)
	if src.is_empty():
		return
	var solid_list: Array = Array(src.get("solid_tiles", [])).map(func(v: Variant) -> int: return int(v))
	var walk_list: Array = Array(src.get("walk_tiles", [])).map(func(v: Variant) -> int: return int(v))
	for v: Variant in indices:
		var i := int(v)
		solid_list.erase(i)
		walk_list.erase(i)
		if mode == "solid":
			solid_list.append(i)
		elif mode == "walk":
			walk_list.append(i)
	solid_list.sort()
	walk_list.sort()
	await update(id, {"solid_tiles": solid_list if not solid_list.is_empty() else null,
		"walk_tiles": walk_list if not walk_list.is_empty() else null})


## Tiles of a source the painter should not offer (atlas reading order, 0-based).
static func set_excluded(id: int, indices: Array) -> void:
	await update(id, {"exclude": indices if not indices.is_empty() else null})


## Deletes single tiles of a source: they leave the painter (and the TileSet). Pictures
## imported into custom/ also get those squares erased; built-in art is left untouched
## (its tiles are just hidden, see restore_tiles). Cells painted with them go blank.
static func delete_tiles(id: int, indices: Array) -> void:
	var cfg := load_config()
	var src := find(cfg, id)
	if src.is_empty() or indices.is_empty():
		return
	var path := str(src.path)
	if path.begins_with(CUSTOM):
		var img := _load(path)
		var cols := img.get_width() / T
		for i: int in indices:
			img.fill_rect(Rect2i((i % cols) * T, (i / cols) * T, T, T), Color(0, 0, 0, 0))
		img.save_png(path)
		EditorInterface.get_resource_filesystem().reimport_files(PackedStringArray([path]))
	var hidden: Array = Array(src.get("exclude", [])).map(func(v: Variant) -> int: return int(v))
	for i: int in indices:
		if not hidden.has(i):
			hidden.append(i)
	hidden.sort()
	src["exclude"] = hidden
	await commit(cfg)


## Brings back the hidden tiles of built-in art (erased custom tiles stay erased).
static func restore_tiles(id: int) -> void:
	await update(id, {"exclude": null})


## Removes a source from the library and the TileSet (cells painted with it go blank).
## Copied art in custom/ is deleted; built-in art stays.
static func remove(id: int) -> void:
	var cfg := load_config()
	var src := find(cfg, id)
	if src.is_empty():
		return
	cfg.sources.erase(src)
	save_config(cfg)
	var ts: TileSet = load(Terrain.tileset_path())
	if ts != null and ts.has_source(id):
		ts.remove_source(id)
		ResourceSaver.save(ts, Terrain.tileset_path())
	var path := str(src.path)
	if path.begins_with(CUSTOM):
		for f in [path, path + ".import", path.get_basename() + ".json"]:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	EditorInterface.get_resource_filesystem().scan()


static func add_terrain(name: String, color: Color) -> int:
	var cfg := load_config()
	if not cfg.has("terrains"):
		cfg.terrains = []
	cfg.terrains.append({"name": name, "color": "#" + color.to_html(false)})
	await commit(cfg)
	return cfg.terrains.size() - 1


static func rename_terrain(index: int, name: String, color: Color) -> void:
	var cfg := load_config()
	if index < cfg.get("terrains", []).size():
		cfg.terrains[index] = {"name": name, "color": "#" + color.to_html(false)}
		await commit(cfg)


## The picture of one tile of a source (64 px).
static func tile_image(id: int, index: int) -> Image:
	var src := find(load_config(), id)
	if src.is_empty():
		return null
	var img := _load(str(src.path))
	if img == null:
		return null
	var cols := img.get_width() / T
	return img.get_region(Rect2i((index % cols) * T, (index / cols) * T, T, T))


# ---------------------------------------------------------------- autotiles

## Corner autotile from `land` to `other` (64 px tiles, seamless works best). opts:
## name, group, style ("water" | "path" | "infested" | "plain"), land_terrain,
## other_terrain (existing index, or -1 + new_terrain_name / new_terrain_color),
## solid (the other side blocks, with polygons that follow the edge), seed.
static func make_autotile(land: Image, other: Image, opts: Dictionary) -> int:
	var cfg := load_config()
	var other_terrain := int(opts.get("other_terrain", -1))
	if other_terrain < 0:
		if not cfg.has("terrains"):
			cfg.terrains = []
		cfg.terrains.append({"name": str(opts.get("new_terrain_name", "New terrain")),
			"color": "#" + (opts.get("new_terrain_color", Color.MAGENTA) as Color).to_html(false)})
		other_terrain = cfg.terrains.size() - 1
	var style := str(opts.get("style", "plain"))
	var seed_v := int(opts.get("seed", 1))
	var rim := _rim_color(style)
	var tiles: Array[Image] = []
	var shapes := {}
	var noise_a := FastNoiseLite.new()
	noise_a.frequency = 0.035
	var noise_b := FastNoiseLite.new()
	noise_b.frequency = 0.12
	for n in 48:
		var i := n % 16
		noise_a.seed = seed_v + n * 7
		noise_b.seed = seed_v + n * 7 + 50
		var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
		var mask := Image.create(T, T, false, Image.FORMAT_LA8)
		var tl := float(i & 1)
		var tr := float((i >> 1) & 1)
		var bl := float((i >> 2) & 1)
		var br := float((i >> 3) & 1)
		for y in T:
			for x in T:
				var u := x / float(T - 1)
				var v := y / float(T - 1)
				var f := tl * (1 - u) * (1 - v) + tr * u * (1 - v) + bl * (1 - u) * v + br * u * v
				var env := sin(PI * u) * sin(PI * v)
				f += (noise_a.get_noise_2d(x, y) * 0.07 + noise_b.get_noise_2d(x, y) * 0.04) * env
				var c := other.get_pixel(x, y) if f > 0.5 else land.get_pixel(x, y)
				match style:
					"water":
						if f > 0.38 and f <= 0.5:
							c = c.lerp(rim, 0.75) if f <= 0.46 else c.lerp(rim, 0.75).darkened(0.28)
						elif f > 0.5 and f <= 0.555:
							c = c.lerp(Color(0.92, 0.98, 1.0), 0.55)
						elif f > 0.5:
							c = c.darkened(clampf((f - 0.5) * 3.0, 0.0, 1.0) * 0.22)
					"path":
						if f > 0.44 and f <= 0.52:
							c = c.darkened(0.15)
					"infested":
						if f > 0.42 and f <= 0.5:
							c = c.darkened(0.4).lerp(Color(0.35, 0.08, 0.43), 0.4)
				img.set_pixel(x, y, c)
				mask.set_pixel(x, y, Color(1, 1, 1, 1) if f > 0.53 else Color(0, 0, 0, 0))
		tiles.append(img)
		if bool(opts.get("solid", false)):
			shapes[str(n)] = _polygons(mask)
	var id := next_id(cfg)
	var name := str(opts.get("name", "Autotile %d" % id))
	var path := CUSTOM + "%d_%s.png" % [id, name.to_snake_case()]
	DirAccess.make_dir_recursive_absolute(CUSTOM)
	pack(tiles).save_png(path)
	var src := {"id": id, "name": name, "group": str(opts.get("group", "Custom")), "path": path,
		"terrain": {"wang": [int(opts.get("land_terrain", 0)), other_terrain], "variants": 3},
		"origin": {"autotile": style}}
	if bool(opts.get("solid", false)):
		var shape_path := path.get_basename() + ".json"
		var f := FileAccess.open(shape_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(shapes))
		f.close()
		src["solid"] = shape_path
	cfg.sources.append(src)
	await commit(cfg)
	return id


static func _rim_color(style: String) -> Color:
	match style:
		"water":
			return Color(0.83, 0.68, 0.43)
	return Color(0.4, 0.3, 0.2)


## Collision polygons of a mask (tile-centred), [] when empty, one square when full.
static func _polygons(mask: Image) -> Array:
	var bm := BitMap.new()
	bm.create_from_image_alpha(mask, 0.5)
	var filled := bm.get_true_bit_count()
	if filled == 0:
		return []
	if filled == T * T:
		return [[[-32, -32], [32, -32], [32, 32], [-32, 32]]]
	var out := []
	for poly: PackedVector2Array in bm.opaque_to_polygons(Rect2i(0, 0, T, T), 1.2):
		if poly.size() >= 3:
			out.append(Array(poly).map(func(p: Vector2) -> Array: return [p.x - 32.0, p.y - 32.0]))
	return out
