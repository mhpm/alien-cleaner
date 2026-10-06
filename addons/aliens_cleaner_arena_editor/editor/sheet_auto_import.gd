@tool
extends RefCounted
## One picture of mixed ground art (square tiles, path pieces, patches, plants...) ->
## terrain tiles + decoration, sorted on its own:
##   analyze(path)  finds every piece (transparent background, or a plain one keyed out),
##                  guesses the tile size (the commonest full square) and sorts each piece:
##     FLOOR    full squares of one texture          -> tile source "<name> floor"
##                                                      (seamless, even brightness, fills
##                                                      New Arena floors)
##     DETAIL   full squares whose middle differs    -> tile source "<name> tiles"
##     PIECES   big pieces with straight edges       -> flat decoration
##     PATCHES  big organic pieces                   -> flat decoration
##     PLANTS   small green pieces                   -> flat decoration that sways
##     SPOTS    other small pieces                   -> flat decoration
##   apply(...)     writes it all: tiles through tile_library.gd (terrain group), pieces
##                  into assets/decor/<kit>/<section>/<category>/ + kit.json, at the
##                  sheet's scale (one sheet tile = one arena tile, 32 units).
## The Arena dock's "Auto-import" window shows the result first: any piece can be moved
## to another category or skipped.

const Importer := preload("character_importer.gd")
const Library := preload("tile_library.gd")
const DECOR := "res://assets/decor/"
const CATS := ["Floor tiles", "Detail tiles", "Pieces", "Patches", "Plants", "Spots", "Skip"]
enum Cat { FLOOR, DETAIL, PIECES, PATCHES, PLANTS, SPOTS, SKIP }
const MIN_PX := 60  # smaller blobs are noise
const SQUARE := 0.14  # width / height may differ this much for a "square"
const FULL := 0.8  # share of a square's box its pixels fill to count as a tile


class Piece:
	extends RefCounted
	var image: Image
	var rect: Rect2i
	var fill := 1.0
	var cat := Cat.SKIP


## {pieces: Array[Piece] (reading order), tile: int (px of one sheet tile, 0 = none)}.
static func analyze(path: String) -> Dictionary:
	var img := Importer.load_sheet(path)
	if img == null:
		return {}
	var pieces := _pieces(img)
	var tile := _tile_size(pieces)
	for p in pieces:
		p.cat = _classify(p, tile)
	return {"pieces": pieces, "tile": tile}


## Every connected drawing on its own (8-neighbours; no merging of small bits).
static func _pieces(img: Image) -> Array[Piece]:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var labels := PackedInt32Array()
	labels.resize(w * h)
	var found: Array[Dictionary] = []
	var stack := PackedInt32Array()
	for start in w * h:
		if labels[start] != 0 or data[start * 4 + 3] < 40:
			continue
		var id := found.size() + 1
		var x0 := w
		var y0 := h
		var x1 := 0
		var y1 := 0
		var count := 0
		labels[start] = id
		stack.append(start)
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
			var x := i % w
			var y := i / w
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
			for dy in [-1, 0, 1]:
				var ny: int = y + dy
				if ny < 0 or ny >= h:
					continue
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					if nx < 0 or nx >= w:
						continue
					var n := ny * w + nx
					if labels[n] == 0 and data[n * 4 + 3] >= 40:
						labels[n] = id
						stack.append(n)
		found.append({"id": id, "rect": Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), "count": count})
	var out: Array[Piece] = []
	for f in found:
		if int(f.count) < MIN_PX:
			continue
		var r: Rect2i = f.rect
		var cut := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		for y in r.size.y:
			for x in r.size.x:
				var gi := (r.position.y + y) * w + r.position.x + x
				if labels[gi] == int(f.id):
					cut.set_pixel(x, y, img.get_pixel(r.position.x + x, r.position.y + y))
		var p := Piece.new()
		p.image = cut
		p.rect = r
		p.fill = float(f.count) / float(r.size.x * r.size.y)
		out.append(p)
	# reading order: rows of similar top, left to right
	out.sort_custom(func(a: Piece, b: Piece) -> bool:
		var ra := a.rect.position.y / 40
		var rb := b.rect.position.y / 40
		return ra < rb or (ra == rb and a.rect.position.x < b.rect.position.x))
	return out


static func _squareish(p: Piece) -> bool:
	var s := p.rect.size
	return absf(s.x - s.y) <= SQUARE * maxf(s.x, s.y) and p.fill >= FULL and mini(s.x, s.y) >= 24


## The commonest size among full squares (at least 2 alike), or 0.
static func _tile_size(pieces: Array[Piece]) -> int:
	var sizes: Array[float] = []
	for p in pieces:
		if _squareish(p):
			sizes.append((p.rect.size.x + p.rect.size.y) * 0.5)
	var best := 0.0
	var best_n := 1
	for s in sizes:
		var near := sizes.filter(func(o: float) -> bool: return absf(o - s) <= s * 0.15)
		if near.size() > best_n:
			best_n = near.size()
			var sum := 0.0
			for o: float in near:
				sum += o
			best = sum / near.size()
	return roundi(best)


static func _classify(p: Piece, tile: int) -> Cat:
	var s := p.rect.size
	if tile > 0 and _squareish(p) and absf((s.x + s.y) * 0.5 - tile) <= tile * 0.15:
		return Cat.DETAIL if _middle_differs(p.image) else Cat.FLOOR
	var big := float(tile) * 0.6 if tile > 0 else 64.0
	if maxi(s.x, s.y) >= big:
		return Cat.PIECES if p.fill >= 0.7 else Cat.PATCHES
	return Cat.PLANTS if _greenish(p.image) else Cat.SPOTS


static func _mean(img: Image, r: Rect2i) -> Color:
	var sum := Vector3.ZERO
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	sum /= maxf(1.0, n)
	return Color(sum.x, sum.y, sum.z)


## The inner half has another colour than the rim (a patch, a hole, an object).
static func _middle_differs(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	var inner := _mean(img, Rect2i(w / 4, h / 4, w / 2, h / 2))
	var rim := _mean(img, Rect2i(0, 0, w, maxi(1, h / 8)))
	var d := Vector3(inner.r - rim.r, inner.g - rim.g, inner.b - rim.b).length()
	return d > 0.12


static func _greenish(img: Image) -> bool:
	var c := _mean(img, Rect2i(Vector2i.ZERO, img.get_size()))
	return c.g > c.r * 1.05 and c.g > c.b * 1.1


# ---------------------------------------------------------------- writing

## opts: name (terrain group and tile names), kit (decor folder id), section (sub-folder
## and category prefix), tile (px of one sheet tile), source (original file).
## Returns a short report. A coroutine (the tile library imports and re-syncs).
static func apply(pieces: Array[Piece], opts: Dictionary) -> String:
	var name := str(opts.get("name", "Ground"))
	var tile := maxi(8, int(opts.get("tile", 64)))
	var by := {}
	for p in pieces:
		if not by.has(p.cat):
			by[p.cat] = [] as Array[Piece]
		(by[p.cat] as Array[Piece]).append(p)
	var report: Array[String] = []
	if by.has(Cat.FLOOR):
		var imgs := _floor_tiles(by[Cat.FLOOR], tile)
		var id: int = await Library._add_source(imgs, str(opts.get("source", "")),
			{"name": name + " floor", "group": name}, {"auto": true})
		if id >= 0:
			await Library.update(id, {"fill": imgs.size()})
			report.append("%d floor tiles (\"%s floor\")" % [imgs.size(), name])
	if by.has(Cat.DETAIL):
		var imgs: Array[Image] = []
		for p: Piece in by[Cat.DETAIL]:
			var t := p.image.duplicate() as Image
			t.resize(Library.T, Library.T, Image.INTERPOLATE_LANCZOS)
			imgs.append(t)
		var id: int = await Library._add_source(imgs, str(opts.get("source", "")),
			{"name": name + " tiles", "group": name}, {"auto": true})
		if id >= 0:
			report.append("%d detail tiles (\"%s tiles\")" % [imgs.size(), name])
	var decor := _write_decor(by, opts, tile)
	if decor > 0:
		report.append("%d decoration pieces (OBJECTS > %s · %s · …)" % [decor,
			str(opts.get("kit", "kit")).capitalize(), str(opts.get("section", "Ground"))])
	EditorInterface.get_resource_filesystem().scan()
	return ", ".join(report) if not report.is_empty() else "Nothing imported."


## Full squares made into a floor: the rounded rim cut off, scaled to the library's tile,
## seamless, one shared brightness and soft borders, so a field of them shows no grid.
static func _floor_tiles(list: Array, tile: int) -> Array[Image]:
	var inset := maxi(1, roundi(tile * 0.065))
	var out: Array[Image] = []
	var sum := Vector3.ZERO
	for p: Piece in list:
		var r := Rect2i(Vector2i(inset, inset), p.image.get_size() - Vector2i(inset, inset) * 2)
		var t := p.image.get_region(r)
		t.resize(Library.T, Library.T, Image.INTERPOLATE_LANCZOS)
		t = Library.seamless(t)
		out.append(t)
		var m := _mean(t, Rect2i(0, 0, Library.T, Library.T))
		sum += Vector3(m.r, m.g, m.b)
	var target := sum / maxf(1.0, out.size())
	for t in out:
		var m := _mean(t, Rect2i(0, 0, Library.T, Library.T))
		var k := Vector3(target.x / maxf(m.r, 0.01), target.y / maxf(m.g, 0.01), target.z / maxf(m.b, 0.01))
		for y in Library.T:
			for x in Library.T:
				var c := t.get_pixel(x, y)
				var v := Vector3(c.r * k.x, c.g * k.y, c.b * k.z)
				var edge := mini(mini(x, Library.T - 1 - x), mini(y, Library.T - 1 - y))
				if edge < 3:
					v = v.lerp(target, 0.45 * (1.0 - edge / 3.0))
				t.set_pixel(x, y, Color(clampf(v.x, 0, 1), clampf(v.y, 0, 1), clampf(v.z, 0, 1), c.a))
	return out


## Decoration pieces -> PNGs + kit.json items. Returns how many.
static func _write_decor(by: Dictionary, opts: Dictionary, tile: int) -> int:
	var kit := str(opts.get("kit", "custom")).to_snake_case()
	var section := str(opts.get("section", "Ground"))
	var sub := section.to_snake_case()
	var units := 32.0 / float(tile)
	var dir := DECOR + kit + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	var cfg := {"name": kit.capitalize(), "items": []}
	if FileAccess.file_exists(dir + "kit.json"):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "kit.json"))
		if old is Dictionary:
			cfg = old
	var items: Array = (cfg.get("items", []) as Array).filter(func(it: Dictionary) -> bool:
		return not str(it.get("file", "")).begins_with(sub + "/"))
	var total := 0
	for cat: int in [Cat.PIECES, Cat.PATCHES, Cat.PLANTS, Cat.SPOTS]:
		if not by.has(cat):
			continue
		var label: String = CATS[cat]
		var folder := "%s/%s" % [sub, label.to_snake_case()]
		DirAccess.make_dir_recursive_absolute(dir + folder)
		for f in DirAccess.get_files_at(dir + folder):
			DirAccess.remove_absolute(dir + folder + "/" + f)
		var k := 0
		for p: Piece in by[cat]:
			k += 1
			var file := "%s/%s_%02d.png" % [folder, label.to_snake_case().trim_suffix("s"), k]
			p.image.save_png(ProjectSettings.globalize_path(dir + file))
			items.append({"file": file, "category": "%s · %s" % [section, label],
				"width": snappedf(p.image.get_width() * units, 0.1), "solid": null,
				"sway": cat == Cat.PLANTS, "fade": false, "flat": true, "shadow": false})
			total += 1
	cfg["items"] = items
	var f := FileAccess.open(dir + "kit.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(cfg, " "))
	f.close()
	return total
