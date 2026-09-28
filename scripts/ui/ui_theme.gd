class_name UiTheme
extends RefCounted
## Shared chunky UI style (outlined labels, pixel-ish buttons).
## FONT (Minecraft pixel font, imported with antialiasing/hinting/subpixel off) is the
## default for every Label/Button/draw_string; crispest at multiples of 8.

const FONT: FontFile = preload("res://fonts/minecraft/Minecraft.ttf")

static var _theme: Theme


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
