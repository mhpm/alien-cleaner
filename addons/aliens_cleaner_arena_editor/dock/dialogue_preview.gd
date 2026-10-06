@tool
extends Control
## Dialogue Editor > preview: the real game box (DialogueBoxArt) on a little phone
## screen, typing with the line's speed and effect. play_line() / play_all().

signal line_started(index: int)

const BOX_W := 300.0  # same as ArenaDialogue.W
const ZOOM := 2.0  # whole numbers keep the pixel font sharp
const SCREEN := Vector2(316, 210)  # a slice of the game screen around the box

var data: DialogueData
var index := 0
var _t := 0.0
var _shown := 0.0
var _all := false
var _wait := 0.0


func _ready() -> void:
	custom_minimum_size = SCREEN * ZOOM + Vector2(24, 24)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func show_line(i: int) -> void:
	index = i
	_all = false
	_t = 1.0
	_shown = 9999.0
	set_process(false)
	queue_redraw()


func play_line(i: int) -> void:
	index = i
	_all = false
	_restart()


func play_all() -> void:
	index = 0
	_all = true
	_restart()


func stop() -> void:
	_all = false
	_shown = 9999.0
	set_process(false)
	queue_redraw()


func _restart() -> void:
	_t = 0.0
	_shown = 0.0
	_wait = 0.0
	set_process(true)
	line_started.emit(index)


func _info() -> Dictionary:
	if data == null or index < 0 or index >= data.lines.size() or data.lines[index] == null:
		return {}
	return data.line_info(index)


func _process(delta: float) -> void:
	var info := _info()
	if info.is_empty():
		stop()
		return
	_t += delta
	var n := DialogueBoxArt.shown_text(info).length()
	var cps := float(info.speed) * (0.6 if int(info.effect) == DialogueLine.Effect.WHISPER else 1.0)
	if _shown < n:
		_shown = minf(n, _shown + delta * cps)
	else:
		_wait += delta
		var hold := float(info.hold) if float(info.hold) > 0.0 else 1.2
		if _wait >= minf(hold, 2.5):
			if _all and index + 1 < data.lines.size():
				index += 1
				_restart()
			elif not _all and _wait > 4.0:
				set_process(false)
	queue_redraw()


func _draw() -> void:
	var phone := Rect2(Vector2(12, 12), SCREEN * ZOOM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a2a24")
	sb.border_color = Color("0a0d14")
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(14)
	sb.expand_margin_left = 6
	sb.expand_margin_right = 6
	sb.expand_margin_top = 6
	sb.expand_margin_bottom = 6
	draw_style_box(sb, phone)
	# a hint of the arena under the box: grass tiles and the astronaut's spot
	var tile := 16.0 * ZOOM
	var y := phone.position.y
	var row := 0
	while y < phone.end.y - 1.0:
		var x := phone.position.x
		var col := row % 2
		while x < phone.end.x - 1.0:
			var r := Rect2(x, y, minf(tile, phone.end.x - x), minf(tile, phone.end.y - y))
			draw_rect(r, Color("3f7a3a") if (col % 2) == 0 else Color("447f3e"))
			x += tile
			col += 1
		y += tile
		row += 1
	draw_circle(phone.get_center() + Vector2(0, 30), 7.0 * ZOOM, Color(0, 0, 0, 0.25))
	var info := _info()
	if info.is_empty():
		draw_string(get_theme_default_font(), phone.get_center() - Vector2(110, 0), "Add a line to see it here", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
		return
	var sz := DialogueBoxArt.box_size(info, BOX_W)
	var top := bool(info.top)
	var box_y := 14.0 if top else SCREEN.y - sz.y - 14.0
	var origin := phone.position + Vector2((SCREEN.x - BOX_W) * 0.5, box_y) * ZOOM
	var n := DialogueBoxArt.shown_text(info).length()
	DialogueBoxArt.draw(self, info, BOX_W, minf(_shown, n), _t, _shown >= n, bool(info.pause),
		Transform2D(0.0, Vector2(ZOOM, ZOOM), 0.0, origin))
	draw_set_transform(Vector2.ZERO)
	var label := "line %d / %d%s" % [index + 1, data.lines.size(), "  ·  cinematic (tap to continue)" if bool(info.pause) else ""]
	draw_string(get_theme_default_font(), phone.position + Vector2(8, phone.size.y - 8 if top else 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))
