class_name RescuePanel
extends Control
## HUD panel of the EXPLORE maps: astronaut portrait, RESCUE plate, "n/m" counter and one
## figure per crew member to save (lit when rescued). Art: assets/ui/rescue/ from
## tools/make_rescue_hud.py. set_count(rescued, total) refreshes it; pop() bounces the
## newly lit figure.

const DIR := "res://assets/ui/rescue/"
const H := 30.0  # panel height (HUD px)
const PIP := 13.0  # figure height

var frame: NinePatchRect
var count: Label
var pips: Array[TextureRect] = []
var total := 0
var lit := 0


func setup(n: int) -> RescuePanel:
	total = n
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 5.0
	var icon := _img("icon.png", Rect2(x, 3, H - 6, H - 6))
	x += icon.size.x + 3.0
	var label := _img("label.png", Rect2(x, 7, 46, 16))
	x += label.size.x + 2.0
	var cnt := _img("count.png", Rect2(x, 7, 32, 16))
	count = UiTheme.label("", 8, Color("e8eefc"))
	count.position = cnt.position
	count.size = cnt.size
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_constant_override("outline_size", 3)
	add_child(count)
	x += cnt.size.x + 5.0
	var pw := PIP * 104.0 / 125.0
	for i in n:
		pips.append(_img("pip_off.png", Rect2(x + i * (pw + 2.0), (H - PIP) * 0.5, pw, PIP)))
	x += n * (pw + 2.0) + 4.0
	size = Vector2(x, H)
	frame = NinePatchRect.new()
	frame.texture = load(DIR + "frame.png")
	frame.patch_margin_left = 40
	frame.patch_margin_right = 40
	frame.patch_margin_top = 40
	frame.patch_margin_bottom = 40
	frame.size = size * 4.0  # drawn at 1/4 so its border stays thin
	frame.scale = Vector2(0.25, 0.25)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	move_child(frame, 0)
	set_count(0)
	return self


func _img(file: String, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = load(DIR + file)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = r.position
	t.size = r.size
	add_child(t)
	return t


func set_count(n: int) -> void:
	lit = n
	count.text = "%d/%d" % [n, total]
	for i in pips.size():
		pips[i].texture = load(DIR + ("pip_on.png" if i < n else "pip_off.png"))


## The figure just lit jumps and flashes; the counter bumps.
func pop() -> void:
	if lit <= 0 or lit > pips.size():
		return
	var p := pips[lit - 1]
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(1.8, 1.8)
	p.modulate = Color(2.0, 2.0, 2.0)
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate", Color.WHITE, 0.4)
	count.pivot_offset = count.size * 0.5
	var t2 := count.create_tween()
	t2.tween_property(count, "scale", Vector2(1.4, 1.4), 0.1)
	t2.tween_property(count, "scale", Vector2.ONE, 0.2)
