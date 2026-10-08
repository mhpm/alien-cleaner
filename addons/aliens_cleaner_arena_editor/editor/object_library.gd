@tool
extends RefCounted
## Decoration objects of the palette (assets/decor/<kit>/<category>/*.png + kit.json),
## managed from the dock (OBJECTS > Import / Delete):
##   import_objects  ready PNGs (one object each), or pictures holding several objects
##                   that are cut apart by their transparent gaps ("split"); copied into
##                   the kit with their settings (width, solid footprint, wind, fade, flat,
##                   shadow) written to kit.json
##   delete_object   removes a picture and its kit.json entry
## Arena objects already placed with a deleted picture lose it (Validate lists them).

const DECOR := "res://assets/decor/"
const MIN_PIECE := 64  # pixels: smaller specks of a split picture are dropped


static func kits() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(DECOR)
	if dir != null:
		for k in dir.get_directories():
			out.append(k)
	if out.is_empty():
		out.append("earth")
	return out


static func categories(kit: String) -> Array[String]:
	var out: Array[String] = []
	for item: Dictionary in _kit(kit).get("items", []):
		var c := str(item.get("category", "Misc"))
		if not out.has(c):
			out.append(c)
	return out


static func _kit(kit: String) -> Dictionary:
	var path := DECOR + kit + "/kit.json"
	if not FileAccess.file_exists(path):
		return {"name": kit.capitalize(), "items": []}
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return cfg if cfg is Dictionary else {"name": kit.capitalize(), "items": []}


static func _save_kit(kit: String, cfg: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(DECOR + kit)
	var f := FileAccess.open(DECOR + kit + "/kit.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(cfg, " ", false))
	f.close()


## opts: kit, category, split (bool), scale (world units per picture pixel; 0 = use
## width), width (world units, when scale is 0), solid (bool), sway, fade, flat, shadow.
## Returns the new pictures' paths (the dock waits for Godot to import them).
static func import_objects(files: PackedStringArray, opts: Dictionary) -> Array[String]:
	var kit := str(opts.get("kit", "earth")).to_snake_case()
	var category := str(opts.get("category", "Misc"))
	var folder := DECOR + kit + "/" + category.to_snake_case() + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	var cfg := _kit(kit)
	var added: Array[String] = []
	for file in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path(file) if file.begins_with("res://") else file)
		if img == null or img.is_empty():
			push_error("Object import: cannot read " + file)
			continue
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var anim: Dictionary = opts.get("anim", {})
		var pieces: Array[Image] = []
		if not anim.is_empty():
			pieces.append(img)  # a spritesheet stays whole: its frames are cut while playing
		elif bool(opts.get("split", false)):
			pieces = split_pieces(img)
		else:
			pieces.append(_trim(img))
		var base := file.get_file().get_basename().to_snake_case()
		for i in pieces.size():
			var piece := pieces[i]
			var name := base if pieces.size() == 1 else "%s_%02d" % [base, i + 1]
			var path := folder + name + ".png"
			var n := 2
			while FileAccess.file_exists(path):
				path = folder + "%s_%d.png" % [name, n]
				n += 1
			piece.save_png(path)
			var frame := Vector2(piece.get_size())
			var anim_entry := {}
			if not anim.is_empty():
				var fsz: Vector2i = anim.get("frame", piece.get_size())
				var cols := maxi(1, piece.get_width() / maxi(1, fsz.x))
				var rws := maxi(1, piece.get_height() / maxi(1, fsz.y))
				frame = Vector2(piece.get_width() / float(cols), piece.get_height() / float(rws))
				# frames chosen in the dialog win; otherwise detect the empty trailing cells
				var count := int(anim.get("count", 0))
				count = clampi(count, 1, cols * rws) if count > 0 else used_frames(piece, cols, rws)
				anim_entry = {"columns": cols, "rows": rws, "count": count,
					"fps": float(anim.get("fps", 8.0)), "loop": bool(anim.get("loop", true))}
			var k := float(opts.get("scale", 0.5))
			var width := frame.x * k if k > 0.0 else float(opts.get("width", 40.0))
			var height := width * frame.y / frame.x
			var solid: Variant = null
			if bool(opts.get("solid", false)):
				solid = [snappedf(width * 0.8, 0.5), snappedf(maxf(3.0, height * 0.18), 0.5)]
			cfg.items.append({"file": path.trim_prefix(DECOR + kit + "/"), "category": category,
				"width": snappedf(width, 0.5), "solid": solid, "sway": bool(opts.get("sway", false)),
				"fade": bool(opts.get("fade", false)), "flat": bool(opts.get("flat", false)),
				"shadow": bool(opts.get("shadow", false))})
			if not anim_entry.is_empty():
				cfg.items.back()["anim"] = anim_entry
			added.append(path)
	_save_kit(kit, cfg)
	EditorInterface.get_resource_filesystem().scan()
	return added


## Frames of a sheet up to the last one that has something in it (a half-empty last row).
## Tolerant on purpose: near-invisible alpha noise or a solid background colour (common in
## exported/generated sheets) does not count as a frame.
static func used_frames(sheet: Image, cols: int, rws: int) -> int:
	var img := sheet
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var fw := img.get_width() / maxi(1, cols)
	var fh := img.get_height() / maxi(1, rws)
	var bg := img.get_pixel(0, 0)
	var opaque_bg := bg.a > 0.5
	var last := 0
	for i in cols * rws:
		if _cell_has_content(img, Rect2i((i % cols) * fw, (i / cols) * fh, fw, fh), bg, opaque_bg):
			last = i + 1
	return maxi(1, last)


static func _cell_has_content(img: Image, r: Rect2i, bg: Color, opaque_bg: bool) -> bool:
	const ALPHA_MIN := 0.1  # fainter pixels are compression/AI noise, not drawing
	const COLOR_TOL := 0.08
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := img.get_pixel(x, y)
			if opaque_bg:
				if absf(p.r - bg.r) > COLOR_TOL or absf(p.g - bg.g) > COLOR_TOL \
						or absf(p.b - bg.b) > COLOR_TOL or absf(p.a - bg.a) > COLOR_TOL:
					return true
			elif p.a > ALPHA_MIN:
				return true
	return false


## The picture without its transparent margins.
static func _trim(img: Image) -> Image:
	var r := img.get_used_rect()
	return img.get_region(r) if r.size.x > 0 and r.size.y > 0 else img


## Every separate shape of a picture (islands of opaque pixels), each trimmed.
static func split_pieces(img: Image) -> Array[Image]:
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, 0.1)
	var out: Array[Image] = []
	var rects: Array[Rect2i] = []
	for poly: PackedVector2Array in bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), 2.0):
		var r := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			r = r.expand(p)
		var ri := Rect2i(r.position.floor(), r.size.ceil()).grow(1).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if ri.size.x * ri.size.y < MIN_PIECE:
			continue
		# a shape inside another one's box (a hole, a detail) belongs to it
		if rects.any(func(o: Rect2i) -> bool: return o.encloses(ri)):
			continue
		rects = rects.filter(func(o: Rect2i) -> bool: return not ri.encloses(o))
		rects.append(ri)
	rects.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.position.y < b.position.y if absi(a.position.y - b.position.y) > 40 else a.position.x < b.position.x)
	for r in rects:
		out.append(_trim(img.get_region(r)))
	return out


## Deletes one object picture (res:// path) from its kit.
static func delete_object(texture_path: String) -> bool:
	if not texture_path.begins_with(DECOR):
		return false
	var kit := texture_path.trim_prefix(DECOR).get_slice("/", 0)
	var rel := texture_path.trim_prefix(DECOR + kit + "/")
	var cfg := _kit(kit)
	cfg.items = cfg.get("items", []).filter(func(i: Dictionary) -> bool: return str(i.get("file", "")) != rel and str(i.get("file", "")) != rel.get_file())
	_save_kit(kit, cfg)
	for f in [texture_path, texture_path + ".import"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	EditorInterface.get_resource_filesystem().call_deferred("scan")  # once per batch, not per file
	return true


## The kit.json settings of an object picture (res:// path), or {}.
static func settings(texture_path: String) -> Dictionary:
	if not texture_path.begins_with(DECOR):
		return {}
	var kit := texture_path.trim_prefix(DECOR).get_slice("/", 0)
	var rel := texture_path.trim_prefix(DECOR + kit + "/")
	for item: Dictionary in _kit(kit).get("items", []):
		if str(item.get("file", "")) == rel or str(item.get("file", "")) == rel.get_file():
			return item
	# a picture dropped in without a kit.json entry: its defaults
	return {"file": rel, "category": rel.get_base_dir().capitalize() if rel.contains("/") else "Misc"}


## Changes the kit.json settings of several pictures at once. `values` holds only what
## changes: category, width, solid (true/false: footprint from the width, or an exact
## [w, h] footprint), sway, fade,
## flat, shadow. The pictures stay where they are (arenas keep pointing at them).
static func update_objects(texture_paths: Array, values: Dictionary) -> void:
	var by_kit := {}
	for path: String in texture_paths:
		if path.begins_with(DECOR):
			var kit := path.trim_prefix(DECOR).get_slice("/", 0)
			if not by_kit.has(kit):
				by_kit[kit] = []
			by_kit[kit].append(path)
	for kit: String in by_kit:
		var cfg := _kit(kit)
		for path: String in by_kit[kit]:
			var rel := path.trim_prefix(DECOR + kit + "/")
			var item: Dictionary = {}
			for it: Dictionary in cfg.items:
				if str(it.get("file", "")) == rel or str(it.get("file", "")) == rel.get_file():
					item = it
			if item.is_empty():
				item = settings(path)
				cfg.items.append(item)
			var old_width := float(item.get("width", 40.0))
			var old_solid: Variant = item.get("solid")
			for k: String in values:
				if k == "anim":
					var a: Dictionary = item.get("anim", {}).duplicate()
					a.merge(values.anim, true)
					item["anim"] = a
				elif k != "solid":
					item[k] = values[k]
			var width := float(item.get("width", 40.0))
			if values.get("solid") is Array:  # an exact footprint (copied from a placed piece)
				var fp: Array = values.solid
				item["solid"] = [snappedf(float(fp[0]), 0.5), snappedf(float(fp[1]), 0.5)] if float(fp[0]) > 0.0 and float(fp[1]) > 0.0 else null
				continue
			var want := bool(values.solid) if values.has("solid") else old_solid != null
			if not want:
				item["solid"] = null
			elif old_solid is Array and (old_solid as Array).size() == 2:
				# keep its footprint, scaled with the new size
				var k2 := width / maxf(old_width, 0.1)
				item["solid"] = [snappedf(float(old_solid[0]) * k2, 0.5), snappedf(float(old_solid[1]) * k2, 0.5)]
			else:
				var tex: Texture2D = load(path)
				var an: Dictionary = item.get("anim", {})
				var fw := tex.get_width() / float(int(an.get("columns", 1))) if tex != null else 1.0
				var fh := tex.get_height() / float(int(an.get("rows", 1))) if tex != null else 1.0
				var height := width * fh / fw
				var tree := bool(item.get("shadow", false))  # trees: only the trunk blocks
				item["solid"] = [snappedf(width * (0.2 if tree else 0.8), 0.5), snappedf(maxf(3.0, height * (0.08 if tree else 0.18)), 0.5)]
		_save_kit(kit, cfg)
