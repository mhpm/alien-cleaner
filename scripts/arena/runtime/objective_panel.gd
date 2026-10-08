class_name ObjectivePanel
extends Control
## The arena's objective list on the HUD (top-left, under the wave line). One row per
## objective: a box (check / cross when done or failed), its text, progress and a thin
## bar. MAIN rows are cyan, SIDE ones gold. Progress makes a row flash; finishing one
## draws a strike that sweeps across it. Drawn by hand (one canvas item, cheap).

const W := 178.0
const ROW := 15.0
const MAIN := Color("73eff7")
const SIDE := Color("ffcd75")
const DONE := Color("a7f070")
const FAIL := Color("ff5566")

var states: Array = []
var _flash: Dictionary = {}  # state -> seconds
var _strike: Dictionary = {}  # state -> 0..1
var _last := ""


func setup(objective_states: Array) -> void:
	states = objective_states
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, 6.0 + ROW * states.size())
	visible = not states.is_empty()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func bump(s: Object) -> void:
	_flash[s] = 0.35


func complete(s: Object) -> void:
	_flash[s] = 0.6
	_strike[s] = 0.0


func refresh() -> void:
	var key := ""
	for s in states:
		key += "%d|%d|%d|%d;" % [int(s.progress), int(s.done), int(s.failed), int(s.time_left)]
	if key != _last or not _flash.is_empty() or _strike.values().any(func(v: float) -> bool: return v < 1.0):
		_last = key
		queue_redraw()


func _process(delta: float) -> void:
	for s in _flash.keys():
		_flash[s] -= delta
		if _flash[s] <= 0.0:
			_flash.erase(s)
	for s in _strike.keys():
		_strike[s] = minf(1.0, _strike[s] + delta * 2.5)


func _draw() -> void:
	var font := UiTheme.FONT
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.05, 0.1, 0.62)
	box.border_color = Color(MAIN, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	for i in states.size():
		var s = states[i]
		var y := 3.0 + i * ROW
		var col: Color = SIDE if s.data.optional else MAIN
		if s.done:
			col = DONE
		elif s.failed:
			col = FAIL
		if _flash.has(s):
			draw_rect(Rect2(2, y, W - 4, ROW - 1), Color(col, 0.25 * _flash[s] / 0.35))
		# check box
		var b := Rect2(5, y + 3, 8, 8)
		draw_rect(b, Color(0, 0, 0, 0.5))
		draw_rect(b, col, false, 1.0)
		if s.done:
			FastDraw.polyline(self, PackedVector2Array([b.position + Vector2(1.5, 4), b.position + Vector2(3.5, 6.5), b.position + Vector2(7, 1.5)]), DONE, 1.5)
		elif s.failed:
			draw_line(b.position + Vector2(1.5, 1.5), b.end - Vector2(1.5, 1.5), FAIL, 1.5)
			draw_line(Vector2(b.end.x - 1.5, b.position.y + 1.5), Vector2(b.position.x + 1.5, b.end.y - 1.5), FAIL, 1.5)
		var label: String = s.data.label(s.target)
		if s.data.optional:
			label = "+ " + label
		var right := ""
		if s.data.is_timed():
			right = "%ds" % ceili(maxf(0.0, s.target - s.progress))
		elif s.target > 1:
			right = "%d/%d" % [mini(int(s.progress), s.target), s.target]
		if s.data.time_limit > 0.0 and not s.done and not s.failed:
			right = "%ds" % ceili(maxf(0.0, s.time_left))
		var rw := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var text_w := W - 22.0 - rw - 6.0
		draw_string_outline(font, Vector2(17, y + 10), label, HORIZONTAL_ALIGNMENT_LEFT, text_w, 8, 2, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(17, y + 10), label, HORIZONTAL_ALIGNMENT_LEFT, text_w, 8, col if not s.done else Color(DONE, 0.8))
		if not right.is_empty():
			draw_string(font, Vector2(W - 5.0 - rw, y + 10), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		# progress line
		if not s.done and not s.failed:
			draw_rect(Rect2(17, y + 12, W - 22, 1), Color(1, 1, 1, 0.12))
			draw_rect(Rect2(17, y + 12, (W - 22) * s.ratio(), 1), col)
		if _strike.has(s):
			var k: float = _strike[s]
			draw_line(Vector2(16, y + 7), Vector2(16 + (W - 20) * k, y + 7), Color(col, 0.75), 1.0)
