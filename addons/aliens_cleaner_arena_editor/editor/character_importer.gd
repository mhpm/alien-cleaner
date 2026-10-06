@tool
extends RefCounted
## Turns a character sheet (any PNG / WebP / JPG: transparent background, or a plain one
## that is keyed out from the corners) into a CharacterData: finds every drawing
## (connected pixels; specks like stars, sweat drops or muzzle flashes join the nearest
## drawing), groups them into rows (one row = one animation, left to right), and saves
## the frames on one shared canvas with the feet on its horizontal middle.

const MIN_PX := 24  # smaller blobs are noise
const SPECK := 0.2  # blobs under this share of the biggest one join a neighbour
const LINK := 0.035  # ...if they are within this share of the sheet width
const DEFAULT_FPS := {"idle": 5.0, "walk": 9.0, "walk_up": 9.0, "shoot": 12.0, "hurt": 10.0, "death": 8.0}
const LOOPS := ["idle", "walk", "walk_up", "shoot"]
## Default animation of each detected row, in order (the usual sheet layout).
const ROW_ORDER := ["idle", "walk", "shoot", "hurt", "death"]


## Loads `path` (res:// or an absolute file) as RGBA8 with a transparent background.
## tolerance < 0 = from the background: a dark one sits next to dark outlines, so it is
## keyed tightly.
static func load_sheet(path: String, tolerance := -1.0) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var bg := img.get_pixel(0, 0)
	if tolerance < 0.0:
		tolerance = 0.02 if bg.get_luminance() < 0.2 else 0.12
	if bg.a > 0.5:
		_key_background(img, bg, tolerance)
	return img


## Clears the background colour flooding in from the borders (stops at the outlines).
static func _key_background(img: Image, bg: Color, tolerance: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	var r := bg.r8
	var g := bg.g8
	var b := bg.b8
	var tol := int(tolerance * 255.0 * 3.0)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if seen[i] == 1:
			continue
		seen[i] = 1
		var o := i * 4
		if absi(data[o] - r) + absi(data[o + 1] - g) + absi(data[o + 2] - b) > tol:
			continue
		data[o + 3] = 0
		var x := i % w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if i >= w: stack.append(i - w)
		if i < w * (h - 1): stack.append(i + w)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)


## Finds the drawings. Returns {labels: PackedInt32Array (blob id + 1 per pixel),
## sprites: [{rect: Rect2i, blobs: Array[int]}], rows: [[sprite index, ...], ...]}.
static func detect(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var labels := PackedInt32Array()
	labels.resize(w * h)
	var blobs: Array[Dictionary] = []
	var stack := PackedInt32Array()
	for start in w * h:
		if labels[start] != 0 or data[start * 4 + 3] < 24:
			continue
		var id := blobs.size() + 1
		var x0 := w
		var y0 := h
		var x1 := 0
		var y1 := 0
		var count := 0
		stack.append(start)
		labels[start] = id
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
					if labels[n] == 0 and data[n * 4 + 3] >= 24:
						labels[n] = id
						stack.append(n)
		blobs.append({"rect": Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), "count": count})
	var biggest := 1
	for bl in blobs:
		biggest = maxi(biggest, int(bl.count))
	# big blobs are sprites; specks join the nearest sprite within reach
	var sprites: Array[Dictionary] = []
	var specks: Array[int] = []
	for k in blobs.size():
		var c := int(blobs[k].count)
		if c < MIN_PX:
			continue
		if c < biggest * SPECK:
			specks.append(k)
		else:
			sprites.append({"rect": blobs[k].rect, "blobs": [k + 1], "main": blobs[k].rect})
	var reach := w * LINK
	for k in specks:
		var r: Rect2i = blobs[k].rect
		var best := -1
		var best_d := reach
		for s in sprites.size():
			var d := _gap(r, sprites[s].rect)
			if d <= best_d:
				best_d = d
				best = s
		if best >= 0:
			sprites[best].rect = (sprites[best].rect as Rect2i).merge(r)
			sprites[best].blobs.append(k + 1)
	return {"labels": labels, "sprites": sprites, "rows": _rows(sprites)}


## Like detect(), but the sheet is a cols x rows grid of equal cells (frames that touch
## each other): each cell's drawing is one sprite, rows of the grid = rows.
static func detect_grid(img: Image, cols: int, rows: int) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var cw := w / maxi(1, cols)
	var ch := h / maxi(1, rows)
	var data := img.get_data()
	var labels := PackedInt32Array()
	labels.resize(w * h)
	var sprites: Array[Dictionary] = []
	var out_rows: Array = []
	for r in rows:
		var row: Array = []
		for c in cols:
			var id := sprites.size() + 1
			var x0 := cw
			var y0 := ch
			var x1 := -1
			var y1 := -1
			for y in range(r * ch, (r + 1) * ch):
				for x in range(c * cw, (c + 1) * cw):
					if data[(y * w + x) * 4 + 3] >= 24:
						labels[y * w + x] = id
						x0 = mini(x0, x - c * cw)
						x1 = maxi(x1, x - c * cw)
						y0 = mini(y0, y - r * ch)
						y1 = maxi(y1, y - r * ch)
			if x1 < 0:
				continue  # an empty cell
			var rect := Rect2i(c * cw + x0, r * ch + y0, x1 - x0 + 1, y1 - y0 + 1)
			row.append(sprites.size())
			sprites.append({"rect": rect, "blobs": [id], "main": rect})
		if not row.is_empty():
			out_rows.append(row)
	return {"labels": labels, "sprites": sprites, "rows": out_rows}


static func _gap(a: Rect2i, b: Rect2i) -> float:
	var dx := maxi(0, maxi(b.position.x - a.end.x, a.position.x - b.end.x))
	var dy := maxi(0, maxi(b.position.y - a.end.y, a.position.y - b.end.y))
	return Vector2(dx, dy).length()


## Sprites whose vertical spans overlap by half the smaller one share a row.
static func _rows(sprites: Array[Dictionary]) -> Array:
	var order := range(sprites.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return (sprites[a].rect as Rect2i).get_center().y < (sprites[b].rect as Rect2i).get_center().y)
	var rows: Array = []
	var span := Vector2i(-1, -1)
	for i: int in order:
		var r: Rect2i = sprites[i].rect
		var overlap := mini(span.y, r.end.y) - maxi(span.x, r.position.y)
		if rows.is_empty() or overlap < mini(span.y - span.x, r.size.y) * 0.5:
			rows.append([i])
			span = Vector2i(r.position.y, r.end.y)
		else:
			rows[-1].append(i)
			span = Vector2i(mini(span.x, r.position.y), maxi(span.y, r.end.y))
	for row: Array in rows:
		row.sort_custom(func(a: int, b: int) -> bool:
			return (sprites[a].rect as Rect2i).position.x < (sprites[b].rect as Rect2i).position.x)
	return rows


## One sprite cut out alone (its own blobs only) as an image of its rect.
static func cut(img: Image, found: Dictionary, s: int) -> Image:
	var sp: Dictionary = found.sprites[s]
	var r: Rect2i = sp.rect
	var out := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	var main: Rect2i = sp.get("main", r)
	out.set_meta("main", Rect2i(main.position - r.position, main.size))
	var labels: PackedInt32Array = found.labels
	var w := img.get_width()
	var keep := {}
	for b: int in sp.blobs:
		keep[b] = true
	for y in r.size.y:
		for x in r.size.x:
			var gx := r.position.x + x
			var gy := r.position.y + y
			if keep.has(labels[gy * w + gx]):
				out.set_pixel(x, y, img.get_pixel(gx, gy))
	return out


## Feet of a cut sprite: bottom row, x = the middle of the top of the head (top 25%: muzzle
## flashes, raised arms or held items rarely reach it), or, when its main drawing (specks
## and flashes aside) is wider than tall = lying down, the middle
## of the drawing when it is lying down (wider than tall).
static func feet(part: Image) -> Vector2:
	var w := part.get_width()
	var h := part.get_height()
	var main: Rect2i = part.get_meta("main", Rect2i(0, 0, w, h))
	if main.size.x > main.size.y * 1.25:
		return Vector2(main.get_center().x, h)
	var sum := 0.0
	var n := 0
	for y in maxi(1, int(h * 0.25)):
		for x in w:
			if part.get_pixel(x, y).a > 0.1:
				sum += x
				n += 1
	return Vector2(sum / n if n > 0 else w * 0.5, h)


## Builds the character `id` from `rows` = [{anim, parts: Array[Image]}] and saves it.
## Returns the saved CharacterData (or null). Its textures are references by path: the
## editor imports the new PNGs in the scan this starts; reload the .tres after
## EditorFileSystem.filesystem_changed to see them.
static func build(id: String, display_name: String, rows: Array, height := 25.5) -> CharacterData:
	var dir := CharacterData.DIR + id + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	# one canvas for every frame: feet at the bottom middle
	var half_w := 1.0
	var up := 1.0
	var feet_of := {}
	for row: Dictionary in rows:
		for part: Image in row.parts:
			var f := feet(part)
			feet_of[part] = f
			half_w = maxf(half_w, maxf(f.x, part.get_width() - f.x))
			up = maxf(up, f.y)
	var size := Vector2i(ceili(half_w) * 2 + 2, ceili(up) + 1)
	var anchor := Vector2(size.x * 0.5, up)
	var paths: Array[String] = []
	var plan: Array = []  # [anim, [paths]]
	for row: Dictionary in rows:
		var list: Array[String] = []
		for i in row.parts.size():
			var part: Image = row.parts[i]
			var f: Vector2 = feet_of[part]
			var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			canvas.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i((anchor - f).round()))
			var p := dir + "%s_%d.png" % [row.anim, i]
			canvas.save_png(ProjectSettings.globalize_path(p))
			list.append(p)
			paths.append(p)
		plan.append([row.anim, list])
	var c := CharacterData.new()
	c.character_id = id
	c.display_name = display_name
	c.anchor = anchor
	c.height = height
	c.frames = SpriteFrames.new()
	c.frames.remove_animation("default")
	var idle_h := 0.0
	for step: Array in plan:
		var anim: String = step[0]
		if not c.frames.has_animation(anim):
			c.frames.add_animation(anim)
			c.frames.set_animation_speed(anim, float(DEFAULT_FPS.get(anim, 8.0)))
			c.frames.set_animation_loop(anim, anim in LOOPS)
		for p: String in step[1]:
			c.frames.add_frame(anim, _ref(p))
	for row: Dictionary in rows:
		if row.anim == "idle":
			for part: Image in row.parts:
				idle_h = maxf(idle_h, part.get_height())
	if idle_h <= 0.0:
		idle_h = up
	c.body_height = idle_h
	c.hand = Vector2(idle_h * 0.1, -idle_h * 0.38).round()
	c.weapon = CharacterData.Weapon.HELD
	for row: Dictionary in rows:
		if row.anim == "shoot" and not row.parts.is_empty():
			c.weapon = CharacterData.Weapon.IN_SPRITE
			c.muzzle = _muzzle(row.parts[0], feet_of[row.parts[0]])
	return c if save(c) else null


## Saves the character and starts the scan that imports its new / changed PNGs. Then
## reload the .tres with CACHE_MODE_REPLACE_DEEP after EditorFileSystem.filesystem_changed:
## that also replaces the empty stand-in textures (_ref) left in the cache.
static func save(c: CharacterData) -> bool:
	var path := CharacterData.path_of(c.character_id)
	var err := ResourceSaver.save(c, path)
	if err != OK:
		push_error("Players: could not save %s (%s)" % [path, error_string(err)])
		return false
	EditorInterface.get_resource_filesystem().scan.call_deferred()
	return true


## One loose picture as a single drawing: background keyed out, cropped to it.
static func load_part(path: String) -> Image:
	var img := load_sheet(path)
	if img == null:
		return null
	var r := img.get_used_rect()
	return img.get_region(r) if r.has_area() else null


## `part` resized so its drawing is `target_h` px tall (smooth: the frames are painted art).
static func fit_height(part: Image, target_h: float) -> Image:
	var k := target_h / float(part.get_height())
	if absf(k - 1.0) < 0.01:
		return part
	var out := part.duplicate() as Image
	# enlarging small pixel art: keep its pixels crisp; shrinking big paintings: smooth
	out.resize(maxi(1, roundi(part.get_width() * k)), maxi(1, roundi(target_h)),
		Image.INTERPOLATE_NEAREST if k > 1.4 else Image.INTERPOLATE_LANCZOS)
	return out


## Average drawn height of `anim`'s frames (0 = none): new frames are sized to match.
static func drawn_height(c: CharacterData, anim: String) -> float:
	if c.frames == null or not c.frames.has_animation(anim) or c.frames.get_frame_count(anim) == 0:
		return 0.0
	var sum := 0.0
	var n := c.frames.get_frame_count(anim)
	for k in n:
		var img := Image.load_from_file(ProjectSettings.globalize_path(c.frames.get_frame_texture(anim, k).resource_path))
		sum += img.get_used_rect().size.y if img != null else 0.0
	return sum / n


## Adds `parts` (single drawings, already sized) to `anim` (replace = instead of its
## frames). The shared canvas grows when a part does not fit: every frame is padded so
## the feet stay put (hand / muzzle points do not move).
static func add_frames(c: CharacterData, anim: String, parts: Array[Image], replace: bool) -> bool:
	var dir := CharacterData.DIR + c.character_id + "/"
	var size := c.frame_size()
	var anchor := c.anchor
	var half_w := maxf(anchor.x, size.x - anchor.x)
	var up := anchor.y
	var down := size.y - anchor.y
	var feet_of := {}
	for part in parts:
		var f := feet(part)
		feet_of[part] = f
		half_w = maxf(half_w, maxf(f.x, part.get_width() - f.x))
		up = maxf(up, f.y)
	var new_anchor := Vector2(ceilf(half_w), ceilf(up))
	var new_size := Vector2i(int(new_anchor.x) * 2, int(new_anchor.y + ceilf(down)))
	if new_size != Vector2i(size) or new_anchor != anchor:
		var shift := Vector2i((new_anchor - anchor).round())
		for a in c.frames.get_animation_names():
			if replace and a == anim:
				continue
			for k in c.frames.get_frame_count(a):
				var p := c.frames.get_frame_texture(a, k).resource_path
				var old := Image.load_from_file(ProjectSettings.globalize_path(p))
				var canvas := Image.create(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
				canvas.blit_rect(old, Rect2i(Vector2i.ZERO, old.get_size()), shift)
				canvas.save_png(ProjectSettings.globalize_path(p))
		c.anchor = new_anchor
	var start := 0 if replace or not c.frames.has_animation(anim) else c.frames.get_frame_count(anim)
	if replace or not c.frames.has_animation(anim):
		var fps := c.frames.get_animation_speed(anim) if c.frames.has_animation(anim) else float(DEFAULT_FPS.get(anim, 8.0))
		var loop := c.frames.get_animation_loop(anim) if c.frames.has_animation(anim) else anim in LOOPS
		if c.frames.has_animation(anim):
			c.frames.remove_animation(anim)
		c.frames.add_animation(anim)
		c.frames.set_animation_speed(anim, fps)
		c.frames.set_animation_loop(anim, loop)
		for f in DirAccess.get_files_at(dir):
			if f.begins_with(anim + "_") and f.trim_prefix(anim + "_").get_basename().is_valid_int():
				DirAccess.remove_absolute(dir + f)
	for i in parts.size():
		var part := parts[i]
		var canvas := Image.create(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i((new_anchor - (feet_of[part] as Vector2)).round()))
		var p := dir + "%s_%d.png" % [anim, start + i]
		canvas.save_png(ProjectSettings.globalize_path(p))
		c.frames.add_frame(anim, _ref(p))
	compact(c)
	return save(c)


## Shrinks the shared canvas to what the frames still use (replacing big frames with
## smaller ones would leave it oversized), keeping the feet on its middle.
static func compact(c: CharacterData) -> void:
	var anchor := c.anchor
	var half_w := 1.0
	var up := 1.0
	var down := 1.0
	var images := {}
	for a in c.frames.get_animation_names():
		for k in c.frames.get_frame_count(a):
			var p := c.frames.get_frame_texture(a, k).resource_path
			var img := Image.load_from_file(ProjectSettings.globalize_path(p))
			if img == null:
				return
			images[p] = img
			var r := img.get_used_rect()
			if not r.has_area():
				continue
			half_w = maxf(half_w, maxf(anchor.x - r.position.x, r.end.x - anchor.x))
			up = maxf(up, anchor.y - r.position.y)
			down = maxf(down, r.end.y - anchor.y)
	var new_anchor := Vector2(ceilf(half_w), ceilf(up))
	var new_size := Vector2i(int(new_anchor.x) * 2, int(new_anchor.y + ceilf(down)))
	var same := new_anchor == anchor
	for p: String in images:
		same = same and (images[p] as Image).get_size() == new_size
	if same:
		return
	var shift := Vector2i((new_anchor - anchor).round())
	for p: String in images:
		var old: Image = images[p]
		var canvas := Image.create(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(old, Rect2i(Vector2i.ZERO, old.get_size()), shift)
		canvas.save_png(ProjectSettings.globalize_path(p))
	c.anchor = new_anchor


## The muzzle flash of `c` from a picture (background keyed, cropped); null clears it.
static func set_flash(c: CharacterData, path: String) -> bool:
	if path.is_empty():
		c.muzzle_flash = null
		return save(c)
	var part := load_part(path)
	if part == null:
		return false
	var p := CharacterData.DIR + c.character_id + "/muzzle_flash.png"
	part.save_png(ProjectSettings.globalize_path(p))
	c.muzzle_flash = _ref(p)
	return save(c)


## The tip of the gun in a shooting frame: the furthest opaque pixel in front of the body
## (between knee and head height), relative to the feet.
static func _muzzle(part: Image, f: Vector2) -> Vector2:
	var h := part.get_height()
	for x in range(part.get_width() - 1, int(f.x), -1):
		for y in range(int(h * 0.25), int(h * 0.75)):
			if part.get_pixel(x, y).a > 0.5:
				return (Vector2(x, y) - f).round()
	return Vector2(h * 0.3, -h * 0.45).round()


## A texture saved as a reference to the PNG at `p` (imported or not yet): the .tres
## stores only the path, so nothing waits for the import.
static func _ref(p: String) -> Texture2D:
	if ResourceLoader.has_cached(p):
		return ResourceLoader.get_cached_ref(p) as Texture2D
	var t := CompressedTexture2D.new()
	t.take_over_path(p)
	return t


## Safe folder / id from a display name.
static func make_id(display_name: String) -> String:
	var s := display_name.strip_edges().to_lower()
	var out := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif not out.ends_with("_"):
			out += "_"
	out = out.trim_prefix("_").trim_suffix("_")
	return out if out != "" else "character"
