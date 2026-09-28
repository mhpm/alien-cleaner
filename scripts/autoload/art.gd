extends Node
## Builds every pixel-art texture at runtime (Sweetie-16 based palette).
## Small sprites come from ASCII rows; tiles and bosses are painted procedurally.

const PAL := {
	"k": Color("1a1c2c"), "K": Color("333c57"), "w": Color("f4f4f4"), "g": Color("94b0c2"),
	"G": Color("566c86"), "c": Color("73eff7"), "b": Color("41a6f6"), "B": Color("3b5dc9"),
	"n": Color("29366f"), "l": Color("a7f070"), "L": Color("38b764"), "d": Color("257179"),
	"y": Color("ffcd75"), "o": Color("ef7d57"), "r": Color("b13e53"), "p": Color("5d275d"),
	"M": Color("c75bd6"), "m": Color("f5a3e0"), "P": Color("7a3a8f"),
}

const ROWS := {
	"bot": [
		"..kkkk..",
		".kgccgk.",
		"kgcwwcgk",
		"kgcwwcgk",
		".kgccgk.",
		"..kkkk..",
	],
	"heart": [
		".kk.kk.",
		"krrkrrk",
		"krwrrrk",
		"krrrrrk",
		".krrrk.",
		"..krk..",
		"...k...",
	],
	"coin": [
		"..ooo..",
		".oyyyo.",
		"oyywyyo",
		"oyywyyo",
		"oyyyyyo",
		".oyyyo.",
		"..ooo..",
	],
	# rotating blaster held by the astronaut (points to +x, grip bottom-left)
	"blaster": [
		"...kkkkkkkkk....",
		"..kwwwwwwwgGk...",
		".kwwbbwwbbwgGkkk",
		"kwwwwwwwwwwgGkbc",
		"kgGGbGGbGGGGGkbc",
		".kkkGGkkkkkkkkk.",
		"...kGGk.........",
		"...kkkk.........",
	],
	"crown": [
		".k.....k.....k.",
		"kyk...kyk...kyk",
		"kyyk.kyyyk.kyyk",
		"kyyykyyyyykyyyk",
		"kyyyyyyyyyyyyyk",
		"kyyryyybyyyryyk",
		"koooooooooooook",
		"kkkkkkkkkkkkkkk",
	],
	"skull": [
		"..kkkkk..",
		".kmmmmmk.",
		"kmmmmmmmk",
		"kmkkmkkmk",
		"kmkkmkkmk",
		"kmmmkmmmk",
		".kmmmmmk.",
		"..kmkmk..",
		"..kkkkk..",
	],
	"clock": [
		"..ccccc..",
		".c.....c.",
		"c...w...c",
		"c...w...c",
		"c...www.c",
		"c.......c",
		"c.......c",
		".c.....c.",
		"..ccccc..",
	],
	"alert": [
		"kyk",
		"kyk",
		"kyk",
		"kyk",
		".k.",
		"kyk",
		".k.",
	],
}

const RECOLOR := {}

const SPRITE_DIR := "res://assets/sprites/"

var _cache: Dictionary = {}
var _flash_shader: Shader
var _shot_shader: Shader
var _manifest: Dictionary = {}
var _frames_cache: Dictionary = {}


func _ready() -> void:
	_flash_shader = load("res://assets/shaders/flash.gdshader")
	_shot_shader = load("res://assets/shaders/shot_tint.gdshader")
	var f := FileAccess.open(SPRITE_DIR + "manifest.json", FileAccess.READ)
	if f != null:
		_manifest = JSON.parse_string(f.get_as_text())


# ---------------------------------------------------------------- sliced sprite sheets
# Frames come from tools/slice_sprites.py: every set shares one canvas whose
# anchor (feet or center) sits on the horizontal middle, so flip_h is safe.

func sheet(set_name: String) -> Dictionary:
	return _manifest[set_name]


func body_height(set_name: String) -> float:
	return float(sheet(set_name).body_h)


func anchor_offset(set_name: String) -> Vector2:
	var info := sheet(set_name)
	var size: Array = info.size
	var anchor: Array = info.anchor
	return Vector2(0.0, float(size[1]) * 0.5 - float(anchor[1]))


func frame_tex(set_name: String, anim: String, i: int) -> Texture2D:
	return load("%s%s/%s_%d.png" % [SPRITE_DIR, set_name, anim, i])


func frames(set_name: String) -> SpriteFrames:
	if _frames_cache.has(set_name):
		return _frames_cache[set_name]
	var sf := SpriteFrames.new()
	var anims: Dictionary = sheet(set_name).anims
	for anim: String in anims:
		var a: Dictionary = anims[anim]
		if not sf.has_animation(anim):
			sf.add_animation(anim)
		sf.set_animation_speed(anim, float(a.fps))
		sf.set_animation_loop(anim, bool(a.loop))
		for i in int(a.frames):
			sf.add_frame(anim, frame_tex(set_name, anim, i))
	if sf.has_animation("default") and not anims.has("default"):
		sf.remove_animation("default")
	_frames_cache[set_name] = sf
	return sf


## Blaster image (assets/suits/<variant>_<slot>.png, from tools/make_suit_parts.py) with
## mipmaps, since the high-res parts are drawn heavily scaled down in game.
func suit_tex(variant: String, slot: String) -> Texture2D:
	var key := "suit:%s_%s" % [variant, slot]
	if _cache.has(key):
		return _cache[key]
	var src: Texture2D = load("res://assets/suits/%s_%s.png" % [variant, slot])
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## AnimatedSprite2D whose anchor (feet for characters) sits at the node origin.
func make_anim(set_name: String, s: float) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames(set_name)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.offset = anchor_offset(set_name)
	spr.scale = Vector2.ONE * s
	var names := spr.sprite_frames.get_animation_names()
	if names.size() > 0:
		spr.animation = names[0]
	return spr


## Shared material that recolors a projectile to a blaster's colour.
func shot_material(tint: Color) -> ShaderMaterial:
	var key := "shot:" + tint.to_html()
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = _shot_shader
		m.set_shader_parameter("tint", tint)
		_cache[key] = m
	return _cache[key]


func flash_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _flash_shader
	return m


func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var img: Image
	if ROWS.has(id):
		img = _from_rows(ROWS[id], {})
	elif RECOLOR.has(id):
		var rc: Array = RECOLOR[id]
		img = _from_rows(ROWS[rc[0]], rc[1])
	else:
		img = _procedural(id)
	var t := ImageTexture.create_from_image(img)
	_cache[id] = t
	return t


# ---------------------------------------------------------------- helpers

func _img(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _from_rows(rows: Array, char_map: Dictionary) -> Image:
	var h := rows.size()
	var w := 0
	for i in h:
		var r: String = rows[i]
		w = maxi(w, r.length())
	var img := _img(w, h)
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if char_map.has(ch):
				ch = char_map[ch]
			if PAL.has(ch):
				var c: Color = PAL[ch]
				img.set_pixel(x, y, c)
	return img


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(floori(cy - r - 1), ceili(cy + r + 1) + 1):
		for x in range(floori(cx - r - 1), ceili(cx + r + 1) + 1):
			if Vector2(x - cx, y - cy).length() <= r:
				_px(img, x, y, c)


func _line(img: Image, a: Vector2, b: Vector2, c: Color, thick: int) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(steps))
		for t in thick:
			_px(img, roundi(p.x), roundi(p.y) + t, c)


func _outline(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.1:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + o.x
				var ny := y + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
					img.set_pixel(x, y, c)
					break


# ---------------------------------------------------------------- procedural

func _procedural(id: String) -> Image:
	match id:
		"shadow":
			var img := _img(12, 5)
			for y in 5:
				for x in 12:
					var nx := (x - 5.5) / 6.0
					var ny := (y - 2.0) / 2.5
					if nx * nx + ny * ny <= 1.0:
						img.set_pixel(x, y, Color(0, 0, 0, 0.35))
			return img
		"glow":
			# soft round light (drawn additively under glowing props)
			var img := _img(32, 32)
			for y in 32:
				for x in 32:
					var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
					if d < 1.0:
						img.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 2.0)))
			return img
		"floor0", "floor1", "floor2":
			return _floor(int(id.substr(5)))
		"vent":
			var img := _floor(0)
			_rect(img, 3, 4, 10, 8, Color("141828"))
			for y in range(5, 12, 2):
				_rect(img, 4, y, 8, 1, Color("333c57"))
			return img
		"wall", "wall_window":
			return _wall(id == "wall_window")
		"wall_side", "wall_side_r":
			var img := _img(16, 16)
			img.fill(Color("222a4f"))
			_rect(img, 14, 0, 1, 16, Color("29366f"))
			_rect(img, 15, 0, 1, 16, Color("566c86"))
			_rect(img, 0, 15, 14, 1, Color("1a1c2c"))
			_px(img, 6, 7, Color("3b5dc9"))
			if id == "wall_side_r":
				img.flip_x()
			return img
		"wall_bottom":
			var img := _img(16, 16)
			img.fill(Color("222a4f"))
			_rect(img, 0, 0, 16, 1, Color("94b0c2"))
			_rect(img, 0, 1, 16, 2, Color("566c86"))
			_rect(img, 15, 3, 1, 13, Color("1a1c2c"))
			return img
		"crate":
			return _crate()
		"barrel":
			return _barrel()
		"terminal":
			return _terminal()
		"toxic":
			return _toxic()
		"electric":
			return _electric()
		"stain":
			return _stain()
		"shield":
			var img := _img(22, 22)
			for y in 22:
				for x in 22:
					var d := Vector2(x - 10.5, y - 10.5).length()
					if d <= 10.5 and d > 9.3:
						img.set_pixel(x, y, Color(0.45, 0.94, 0.97, 0.9))
					elif d <= 9.3:
						img.set_pixel(x, y, Color(0.45, 0.94, 0.97, 0.16))
			_line(img, Vector2(5, 7), Vector2(8, 4), Color(1, 1, 1, 0.9), 1)
			return img
	push_warning("Art: unknown texture " + id)
	return _img(4, 4)


func _floor(v: int) -> Image:
	var img := _img(16, 16)
	var lo := Color("1c2138")
	img.fill(Color("2a3150"))
	_rect(img, 0, 0, 16, 1, Color("38426a"))
	_rect(img, 0, 0, 1, 16, Color("38426a"))
	_rect(img, 0, 15, 16, 1, lo)
	_rect(img, 15, 0, 1, 16, lo)
	for p: Vector2i in [Vector2i(2, 2), Vector2i(13, 2), Vector2i(2, 13), Vector2i(13, 13)]:
		img.set_pixel(p.x, p.y, Color("4a5680"))
	if v == 1:
		for y in range(4, 12, 2):
			_rect(img, 4, y, 8, 1, lo)
	elif v == 2:
		_line(img, Vector2(4, 11), Vector2(9, 6), Color("323b60"), 1)
		_px(img, 10, 9, Color("323b60"))
	return img


func _wall(window: bool) -> Image:
	var img := _img(16, 32)
	img.fill(Color("29366f"))
	_rect(img, 0, 0, 16, 1, Color("94b0c2"))
	_rect(img, 0, 1, 16, 2, Color("566c86"))
	_rect(img, 15, 3, 1, 29, Color("1f2a55"))
	_rect(img, 0, 13, 16, 1, Color("222a4f"))
	_rect(img, 0, 16, 16, 1, Color("41a6f6"))
	_rect(img, 0, 17, 16, 2, Color("73eff7"))
	_rect(img, 0, 19, 16, 1, Color("41a6f6"))
	_rect(img, 0, 22, 16, 9, Color("333c57"))
	_px(img, 2, 24, Color("566c86"))
	_px(img, 13, 24, Color("566c86"))
	_px(img, 2, 29, Color("566c86"))
	_px(img, 13, 29, Color("566c86"))
	_rect(img, 0, 31, 16, 1, Color("1a1c2c"))
	if window:
		_rect(img, 2, 4, 12, 9, Color("94b0c2"))
		_rect(img, 3, 5, 10, 7, Color("0b0e1a"))
		_px(img, 5, 7, Color("f4f4f4"))
		_px(img, 10, 6, Color("73eff7"))
		_px(img, 8, 10, Color("ffcd75"))
		_px(img, 11, 10, Color("f4f4f4"))
	return img


func _crate() -> Image:
	var img := _img(16, 16)
	var k: Color = PAL["k"]
	_rect(img, 0, 0, 16, 16, k)
	_rect(img, 1, 1, 14, 4, PAL["g"])
	_rect(img, 1, 1, 14, 1, Color("c2d3df"))
	_rect(img, 1, 5, 14, 1, PAL["K"])
	_rect(img, 1, 6, 14, 9, PAL["G"])
	_rect(img, 1, 9, 14, 2, PAL["o"])
	_rect(img, 1, 11, 14, 1, Color("b3563d"))
	for p: Vector2i in [Vector2i(2, 7), Vector2i(13, 7), Vector2i(2, 13), Vector2i(13, 13)]:
		img.set_pixel(p.x, p.y, PAL["g"])
	_rect(img, 6, 2, 4, 2, PAL["G"])
	return img


func _barrel() -> Image:
	var img := _img(12, 16)
	_rect(img, 1, 1, 10, 14, PAL["r"])
	_rect(img, 2, 1, 1, 14, PAL["o"])
	_rect(img, 8, 1, 2, 14, PAL["p"])
	_rect(img, 1, 1, 10, 3, PAL["o"])
	_rect(img, 3, 2, 6, 1, PAL["y"])
	_rect(img, 1, 7, 10, 3, PAL["y"])
	_px(img, 3, 8, PAL["k"])
	_px(img, 5, 8, PAL["k"])
	_px(img, 7, 8, PAL["k"])
	_px(img, 9, 8, PAL["k"])
	_rect(img, 1, 14, 10, 1, PAL["p"])
	_outline(img, PAL["k"])
	return img


func _terminal() -> Image:
	var img := _img(16, 20)
	_rect(img, 1, 1, 14, 18, PAL["G"])
	_rect(img, 1, 1, 14, 4, PAL["g"])
	_rect(img, 1, 5, 14, 1, PAL["K"])
	_rect(img, 3, 7, 10, 6, PAL["d"])
	_rect(img, 4, 8, 6, 1, PAL["c"])
	_rect(img, 4, 10, 4, 1, PAL["c"])
	_px(img, 11, 11, PAL["l"])
	_px(img, 4, 15, PAL["r"])
	_px(img, 6, 15, PAL["y"])
	_px(img, 8, 15, PAL["l"])
	_rect(img, 1, 18, 14, 1, PAL["K"])
	_outline(img, PAL["k"])
	return img


func _toxic() -> Image:
	# flat glossy puddle, slightly wider than tall, bleeding a bit past the tile
	var img := _img(16, 16)
	for y in 16:
		for x in 16:
			var v := Vector2((x - 7.5) / 7.8, (y - 8.0) / 6.6)
			var a := v.angle()
			var r := 1.0 + sin(a * 3.0 + 0.7) * 0.06
			var d := v.length()
			if d > r:
				continue
			var c := Color("4fbf3a")
			if d > r - 0.16:
				c = Color("2f8f4e")
			elif v.y < -0.35 and v.x < 0.3 and d > r - 0.42:
				c = Color("b8f58a")
			elif d < 0.5:
				c = Color("61d148")
			img.set_pixel(x, y, Color(c, 0.85))
	_px(img, 4, 5, PAL["w"])
	_px(img, 5, 5, PAL["w"])
	_disc(img, 10.0, 9.0, 1.0, Color("b8f58a"))
	_px(img, 6, 11, Color("b8f58a"))
	return img


func _electric() -> Image:
	var img := _img(16, 16)
	img.fill(PAL["K"])
	for y in 16:
		for x in 16:
			if x < 2 or y < 2 or x > 13 or y > 13:
				var c: Color = PAL["y"] if ((x + y) % 4) < 2 else PAL["k"]
				img.set_pixel(x, y, c)
	_rect(img, 5, 5, 6, 6, PAL["G"])
	_rect(img, 6, 6, 4, 4, PAL["n"])
	_rect(img, 7, 7, 2, 2, PAL["c"])
	return img


func _stain() -> Image:
	var img := _img(14, 10)
	for y in 10:
		for x in 14:
			var v := Vector2((x - 6.5) / 6.5, (y - 4.5) / 4.5)
			var a := v.angle()
			var r := 0.85 + sin(a * 4.0 + 1.0) * 0.12
			if v.length() <= r:
				img.set_pixel(x, y, Color.WHITE)
	_px(img, 0, 1, Color.WHITE)
	_px(img, 13, 8, Color.WHITE)
	_px(img, 12, 0, Color.WHITE)
	return img
