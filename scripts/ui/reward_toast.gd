class_name RewardToast
extends Control
## Readable reward cards for the run's pickups that change your build (a chest's perk, a
## rescued crew member's gift): icon, name and what it does, held long enough to read
## (HOLD + a little per character) instead of a floating text that is gone in half a
## second. Several in a row queue up and show one after another (Hud.reward).

const W := 236.0
const H := 50.0
const TOP := 128.0  # below the top bar and the CHESTS / RESCUE panel
const HOLD := 2.6  # seconds on screen, plus READ_K per character of its text
const READ_K := 0.035
const MAX_QUEUE := 6

var _queue: Array[Dictionary] = []
var _card: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5  # over the HUD's labels and panels


## Queues a card: `icon` (may be null), `title` in `color`, `text` under it.
func show_reward(icon: Texture2D, title: String, text: String, color: Color) -> void:
	if _queue.size() >= MAX_QUEUE:
		_queue.pop_front()
	_queue.append({"icon": icon, "title": title, "text": text, "color": color})
	if _card == null:
		_next()


## Drops the queue and the card showing (the run is over: WIPED OUT, victory).
func clear() -> void:
	_queue.clear()
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null


func _next() -> void:
	if _queue.is_empty():
		_card = null
		return
	var r: Dictionary = _queue.pop_front()
	_card = _build(r)
	add_child(_card)
	var x := (size.x - W) * 0.5
	_card.position = Vector2(x, TOP - 30.0)
	_card.modulate.a = 0.0
	var hold := HOLD + READ_K * (str(r.title).length() + str(r.text).length())
	var tw := _card.create_tween()
	tw.tween_property(_card, "position:y", TOP, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_card, "modulate:a", 1.0, 0.18)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_card.queue_free)
	tw.tween_callback(_next)


func _build(r: Dictionary) -> Control:
	var col: Color = r.color
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(W, H)
	card.size = Vector2(W, H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.12, 0.9)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(col, 0.35)
	sb.shadow_size = 6
	sb.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	if r.icon != null:
		var ic := TextureRect.new()
		ic.texture = r.icon
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ic.custom_minimum_size = Vector2(36, 36)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var title := str(r.title)
	var tl := UiTheme.label(title, UiTheme.fit_size(UiTheme.FONT, title, 14, W - 64.0), col.lightened(0.15))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tl.add_theme_constant_override("outline_size", 4)
	tl.add_theme_color_override("font_outline_color", Color("0b1029"))
	v.add_child(tl)
	var dl := UiTheme.body(str(r.text), 12, Color("e8f2ff"))
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(W - 64.0, 0)
	v.add_child(dl)
	return card
