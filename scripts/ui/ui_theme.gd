class_name UiTheme
extends RefCounted
## Shared chunky UI style (outlined labels, pixel-ish buttons).
## FONT (Minecraft pixel font, imported with antialiasing/hinting/subpixel off) is the
## default for every Label/Button/draw_string; crispest at multiples of 8.

const FONT: FontFile = preload("res://fonts/minecraft/Minecraft.ttf")

static var _theme: Theme
const SIDE_DIM := Color(0.45, 0.47, 0.55)  # mirrored art beside the stage on wide screens
static var _body: Font


## Smooth (non-pixel) font for descriptions and small body text: the pixel FONT is for
## titles and big important labels only. System sans (Roboto on Android).
static func body_font() -> Font:
	if _body == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Nunito", "Roboto", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
		f.font_weight = 600
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		_body = f
	return _body


## Label in the smooth body font (wraps when given a width).
static func body(text: String, size := 11, color := Color("d6e6ff")) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", body_font())
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return l


static func build() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 16
	th.set_color("font_color", "Label", Color("f4f4f4"))
	th.set_color("font_outline_color", "Label", Color("1a1c2c"))
	th.set_constant("outline_size", "Label", 6)
	var base := Color("3b5dc9")
	th.set_stylebox("normal", "Button", box(base, Color("1a1c2c")))
	th.set_stylebox("hover", "Button", box(base.lightened(0.15), Color("1a1c2c")))
	th.set_stylebox("pressed", "Button", box(base.darkened(0.2), Color("1a1c2c"), true))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("disabled", "Button", box(Color("566c86"), Color("1a1c2c")))
	th.set_color("font_color", "Button", Color("f4f4f4"))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color("f4f4f4"))
	th.set_color("font_disabled_color", "Button", Color("94b0c2"))
	th.set_color("font_outline_color", "Button", Color("1a1c2c"))
	th.set_constant("outline_size", "Button", 6)
	_theme = th
	return th


static func box(bg: Color, border: Color, pressed := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	if not pressed:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_offset = Vector2(0, 4)
		sb.shadow_size = 1
	else:
		sb.content_margin_top = 11
	return sb


static func button(text: String, color: Color, font_size := 20, min_size := Vector2(200, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", box(color, Color("1a1c2c")))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.15), Color("1a1c2c")))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.2), Color("1a1c2c"), true))
	b.pressed.connect(func() -> void: Sfx.play("select", 0.0))
	return b


static func label(text: String, size := 16, color := Color("f4f4f4")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Big heading, shrunk (if needed) to fit max_w.
static func title(text: String, size := 40, color := Color("f4f4f4"), max_w := 340.0) -> Label:
	return label(text, fit_size(FONT, text, size, max_w), color)


## Largest size <= size at which text fits in max_w px (one line).
static func fit_size(font: Font, text: String, size: int, max_w: float) -> int:
	while size > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		size -= 1
	return size


static func icon(tex_id: String, px: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Art.tex(tex_id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Part of the screen free of notches, rounded corners and system bars, in viewport
## (canvas) units. On desktop it is the whole viewport.
static func safe_rect(c: Control) -> Rect2:
	var full := Rect2(Vector2.ZERO, c.get_viewport_rect().size)
	if not OS.has_feature("mobile"):
		return full
	var win := Vector2(DisplayServer.window_get_size())
	var area := Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0.0 or win.y <= 0.0 or area.size.x <= 0.0 or area.size.y <= 0.0:
		return full
	area.position -= Vector2(DisplayServer.window_get_position())
	var k := full.size / win
	var r := full.intersection(Rect2(area.position * k, area.size * k))
	return r if r.size.x > 0.0 and r.size.y > 0.0 else full


## Insets (left, top, right, bottom) of the safe area, to use as a full-rect Control's offsets.
static func safe_insets(c: Control) -> Vector4:
	var full := c.get_viewport_rect().size
	var r := safe_rect(c)
	return Vector4(r.position.x, r.position.y, full.x - r.end.x, full.y - r.end.y)


## Responsive layout of a painted screen: `stage` holds the art drawn 1:1 at `art` px and
## is scaled to fit the safe area's width (or its height on wide screens). On phones
## taller than the art the leftover height is NOT left as empty bands: it is shared out
## at the screen's seams (set_seams), horizontal lines of the art where the scene can
## grow, e.g. empty sky. Controls above/below a seam move with their band (top bar pinned
## to the top, nav bar to the bottom) and add_backdrop() paints the opened gaps by folding
## the art's own rows there, so it looks like more of the same scene. Returns the scale.
static func fit_stage(host: Control, stage: Control, art: Vector2, pin_top := false, zoom := 1.0) -> float:
	var safe := safe_rect(host)
	var s := minf(safe.size.x / art.x, safe.size.y / art.y) * zoom
	var x0 := safe.position.x + (safe.size.x - art.x * s) * 0.5
	var extra := maxf(0.0, safe.size.y - art.y * s)
	var seams: Array = stage.get_meta("seams") if stage.has_meta("seams") else []
	if seams.is_empty():
		seams = [[art.y, 1.0, -1]] if pin_top else [[0.0, 1.0, 1], [art.y, 1.0, -1]]
	if not stage.has_meta("bands"):
		_split_bands(host, stage, art, seams)
	var bands: Array = stage.get_meta("bands")
	var total := 0.0
	for sm: Array in seams:
		total += float(sm[1])
	# each band's top edge on screen = safe top + the gaps opened above it
	var gaps: Array = []  # [seam y, screen y where the gap starts, height, dir]
	var y := safe.position.y
	if extra <= 0.0:  # wider than the art (or zoomed): centred vertically
		y += (safe.size.y - art.y * s) * 0.5
	var k := 0
	for b: Dictionary in bands:
		while k < seams.size() and float(seams[k][0]) <= float(b.y0):
			var g := extra * float(seams[k][1]) / total
			gaps.append([float(seams[k][0]), y + float(seams[k][0]) * s, g, int(seams[k][2]), _fold_max(seams[k])])
			y += g
			k += 1
		var node: Control = b.node
		node.scale = Vector2(s, s)
		node.position = Vector2(x0, y)
		b.top = y
	while k < seams.size():  # seams at the very bottom of the art
		var g := extra * float(seams[k][1]) / total
		gaps.append([float(seams[k][0]), y + float(seams[k][0]) * s, g, int(seams[k][2]), _fold_max(seams[k])])
		k += 1
	stage.set_meta("layout", {"s": s, "x0": x0, "gaps": gaps})
	var bd: Variant = stage.get_meta("backdrop") if stage.has_meta("backdrop") else null
	if bd is CanvasItem:
		(bd as CanvasItem).queue_redraw()
	return s


static func _fold_max(seam: Array) -> float:
	return float(seam[3]) if seam.size() > 3 else INF


## Where the screen may grow: [[art y, weight, dir, max fold?], ...]. The extra height is shared by
## weight; the gap at a seam shows the art rows just below it (dir 1) or above it (dir -1),
## folded (out from the seam and back) so both edges join the art seamlessly; with a max
## fold (art px) only that many rows are used, folded back and forth as often as needed. A seam at 0
## or at the art's height opens a gap above / below everything. `home` = which band
## `stage` itself stays as (its non-Control children, e.g. Node2D layers, stay there).
## Call before the first fit_stage, after building the stage.
static func set_seams(stage: Control, seams: Array, home := 0) -> void:
	seams.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	stage.set_meta("seams", seams)
	stage.set_meta("home", home)


## Moves the stage's Controls into one Control per band (by their centre), siblings of it.
static func _split_bands(host: Control, stage: Control, art: Vector2, seams: Array) -> void:
	var cuts: Array[float] = [0.0]
	for sm: Array in seams:
		var sy := float(sm[0])
		if sy > 0.0 and sy < art.y:
			cuts.append(sy)
	cuts.append(art.y)
	var home: int = clampi(int(stage.get_meta("home")) if stage.has_meta("home") else 0, 0, cuts.size() - 2)
	var bands: Array = []
	var at := stage.get_index()
	for i in cuts.size() - 1:
		var node := stage
		if i != home:
			node = Control.new()
			node.name = "%sBand%d" % [stage.name, i]
			node.size = art
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.texture_filter = stage.texture_filter
			host.add_child(node)
		# extra bands go right after stage: drawn and hit above it, so a full-size Control of
		# the home band can't swallow the taps of the top bar's buttons
		if node != stage:
			at += 1
			host.move_child(node, at)
		bands.append({"node": node, "y0": cuts[i], "y1": cuts[i + 1], "top": 0.0})
	var bg: Variant = stage.get_meta("bg") if stage.has_meta("bg") else null
	for c in stage.get_children():
		var cc := c as Control
		if cc == null:
			continue
		if bg != null and cc is TextureRect and (cc as TextureRect).texture == bg:
			cc.visible = false  # the backdrop paints the background band by band
			continue
		var cy := cc.position.y + cc.size.y * 0.5
		var i := 0
		while i < cuts.size() - 2 and cy >= cuts[i + 1]:
			i += 1
		if i != home:
			cc.reparent(bands[i].node, false)
	stage.set_meta("bands", bands)


## The band Control that shows art y (its position/scale map art px to the screen).
static func band_at(stage: Control, art_y: float) -> Control:
	if not stage.has_meta("bands"):
		return stage
	var bands: Array = stage.get_meta("bands")
	for b: Dictionary in bands:
		if art_y < float(b.y1):
			return b.node
	return (bands.back() as Dictionary).node


## Art px -> screen, through the band that shows it.
static func to_screen(stage: Control, art_p: Vector2) -> Vector2:
	var n := band_at(stage, art_p.y)
	return n.position + art_p * n.scale.x


## Screen point -> art px, through the band it falls in.
static func to_art(stage: Control, p: Vector2) -> Vector2:
	if not stage.has_meta("bands"):
		return (p - stage.position) / stage.scale.x
	var bands: Array = stage.get_meta("bands")
	for b: Dictionary in bands:
		var n: Control = b.node
		if (p.y - n.position.y) / n.scale.y < float(b.y1) or b == bands.back():
			return (p - n.position) / n.scale.x
	return p


## Paints the screen behind a fitted stage: the background art band by band, the gaps
## opened at the seams (folded art rows, see set_seams) and whatever is left outside
## (system-bar insets, the sides on wide screens) by mirroring the nearest art.
static func add_backdrop(host: Control, stage: Control, tex: Texture2D) -> Control:
	var bd := Control.new()
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.add_child(bd)
	host.move_child(bd, 0)
	stage.set_meta("backdrop", bd)
	stage.set_meta("bg", tex)
	bd.draw.connect(func() -> void: _paint_backdrop(bd, stage, tex))
	host.resized.connect(bd.queue_redraw)
	return bd


static func _paint_backdrop(bd: Control, stage: Control, tex: Texture2D) -> void:
	if not stage.has_meta("layout"):
		return
	var lay: Dictionary = stage.get_meta("layout")
	var s: float = lay.s
	var x0: float = lay.x0
	var art := stage.size
	var w := art.x * s
	var bands: Array = stage.get_meta("bands")
	for b: Dictionary in bands:
		var y0: float = b.y0
		var y1: float = b.y1
		_strip(bd, tex, art, Rect2(x0, float(b.top) + y0 * s, w, (y1 - y0) * s), y0, y1, 0.0, 1.0)
	var top_y: float = float((bands[0] as Dictionary).top)
	var bot_y: float = float((bands.back() as Dictionary).top) + art.y * s
	for g: Array in lay.gaps:
		var sy: float = g[0]
		var gy: float = g[1]
		var h: float = g[2]
		if sy <= 0.0:
			top_y = minf(top_y, gy)
		elif sy >= art.y:
			bot_y = maxf(bot_y, gy + h)
		elif h > 0.5:
			# an even number of half-folds of at most `max fold` rows each
			var n := maxi(1, ceili(h / s / (2.0 * minf(float(g[4]), art.y))))
			var seg := h / (2.0 * n)
			var far := clampf(sy + float(g[3]) * seg / s, 0.0, art.y)
			for i in 2 * n:
				var r := Rect2(x0, gy + seg * i, w, seg + 0.5)
				if i % 2 == 0:
					_strip(bd, tex, art, r, sy, far, 0.0, 1.0)
				else:
					_strip(bd, tex, art, r, far, sy, 0.0, 1.0)
	# above / below everything (gaps at the art's edges, system-bar insets): mirror outwards
	if top_y > 0.0:
		_strip(bd, tex, art, Rect2(x0, 0.0, w, top_y + 0.5), minf(top_y / s, art.y), 0.0, 0.0, 1.0)
	if bot_y < bd.size.y:
		var h := bd.size.y - bot_y
		_strip(bd, tex, art, Rect2(x0, bot_y - 0.5, w, h + 0.5), art.y, maxf(0.0, art.y - h / s), 0.0, 1.0)
	# sides (screens wider than the art): mirror the edge columns outwards
	if x0 > 0.0:
		var u := minf(x0 / w, 1.0)
		var r := Rect2(0.0, top_y, x0 + 0.5, bot_y - top_y)
		var a := (top_y - float((bands[0] as Dictionary).top)) / s
		var b := a + r.size.y / s
		# dimmed, so mirrored buttons at the art's edges read as scenery, not as UI
		_strip(bd, tex, art, r, a, b, u, 0.0, SIDE_DIM)
		r.position.x = x0 + w - 0.5
		_strip(bd, tex, art, r, a, b, 1.0, 1.0 - u, SIDE_DIM)


## Draws art rows a..b (a = top of dst; b < a flips) and columns u0..u1 (0..1; u1 < u0
## flips) into dst.
static func _strip(ci: CanvasItem, tex: Texture2D, art: Vector2, dst: Rect2, a: float, b: float, u0: float, u1: float, tint := Color.WHITE) -> void:
	var va := a / art.y
	var vb := b / art.y
	var pts := PackedVector2Array([dst.position, Vector2(dst.end.x, dst.position.y), dst.end, Vector2(dst.position.x, dst.end.y)])
	var uvs := PackedVector2Array([Vector2(u0, va), Vector2(u1, va), Vector2(u1, vb), Vector2(u0, vb)])
	ci.draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uvs, tex)
