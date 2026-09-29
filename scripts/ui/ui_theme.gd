class_name UiTheme
extends RefCounted
## Shared chunky UI style (outlined labels, pixel-ish buttons).
## FONT (Minecraft pixel font, imported with antialiasing/hinting/subpixel off) is the
## default for every Label/Button/draw_string; crispest at multiples of 8.

const FONT: FontFile = preload("res://fonts/minecraft/Minecraft.ttf")

static var _theme: Theme
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


## Scales `stage` (painted art drawn 1:1 at `art` px) so all of it fits inside the safe
## area, centred (or pinned to its top). Screens more elongated than the art get bands,
## filled by add_backdrop(). Returns the scale.
static func fit_stage(host: Control, stage: Control, art: Vector2, pin_top := false, zoom := 1.0) -> float:
	var safe := safe_rect(host)
	var s := minf(safe.size.x / art.x, safe.size.y / art.y) * zoom
	stage.scale = Vector2(s, s)
	stage.position = safe.position + (safe.size - art * s) * 0.5
	if pin_top:
		stage.position.y = safe.position.y
	var bd: Variant = stage.get_meta("backdrop") if stage.has_meta("backdrop") else null
	if bd is CanvasItem:
		(bd as CanvasItem).queue_redraw()
	return s


## Fills the screen around a fitted stage by stretching the edge rows/columns of its
## background art into the leftover bands, so the art seems to continue to the screen edge.
static func add_backdrop(host: Control, stage: Control, tex: Texture2D) -> Control:
	var bd := Control.new()
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.add_child(bd)
	host.move_child(bd, 0)
	stage.set_meta("backdrop", bd)
	bd.draw.connect(func() -> void:
		var ts := tex.get_size()
		var r := Rect2(stage.position, stage.size * stage.scale)
		var e := 4.0  # source strip thickness (texture px)
		var full := bd.size
		if r.position.x > 0.0:
			bd.draw_texture_rect_region(tex, Rect2(0, r.position.y, r.position.x + 1.0, r.size.y), Rect2(0, 0, e, ts.y))
		if r.end.x < full.x:
			bd.draw_texture_rect_region(tex, Rect2(r.end.x - 1.0, r.position.y, full.x - r.end.x + 1.0, r.size.y), Rect2(ts.x - e, 0, e, ts.y))
		if r.position.y > 0.0:
			bd.draw_texture_rect_region(tex, Rect2(0, 0, full.x, r.position.y + 1.0), Rect2(0, 0, ts.x, e))
		if r.end.y < full.y:
			bd.draw_texture_rect_region(tex, Rect2(0, r.end.y - 1.0, full.x, full.y - r.end.y + 1.0), Rect2(0, ts.y - e, ts.x, e)))
	host.resized.connect(bd.queue_redraw)
	return bd
