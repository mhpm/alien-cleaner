class_name TouchControls
extends Control
## Floating virtual joystick (touch anywhere) + Air Blast button bottom-right.
## Works with mouse via "emulate touch from mouse". With Infected mode the button wears
## a magenta ring: the infection meter, "MUTATE!" when full, the mutation time left.

signal ability_pressed

const JOY_R := 40.0  # knob travel
const BASE_D := 103.0  # painted joystick ring diameter (screen px)
const KNOB_D := 48.0
const BTN_R := 44.0
## centres of the painted controls relative to the screen centre (room art framing)
const JOY_OFFSET := Vector2(-116.0, 228.7)
const BTN_OFFSET := Vector2(123.0, 233.6)

var tex_base: Texture2D = load("res://assets/room/hud_joystick.png")
var tex_knob: Texture2D = load("res://assets/room/hud_knob.png")
var tex_btn: Texture2D = load("res://assets/room/hud_blast.png")

var enabled := true:
	set(v):
		enabled = v
		if not v:
			joy_touch = -1
			output = Vector2.ZERO
var output := Vector2.ZERO
var cooldown := 0.0  # 0 = is_ready, 1 = just used
var infect_state := 0  # 0 locked, 1 charging, 2 ready to mutate, 3 mutated
var infect := 0.0  # meter (charging) or mutation time left (mutated), 0..1
var joy_touch := -1
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO
var btn_flash := 0.0
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rest_center() -> Vector2:
	return size * 0.5 + JOY_OFFSET


func _btn_center() -> Vector2:
	return size * 0.5 + BTN_OFFSET


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	event = make_input_local(event)  # we sit inside the HUD's safe area, not at the screen origin
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			if te.position.distance_to(_btn_center()) <= BTN_R + 12.0:
				if cooldown <= 0.0:
					btn_flash = 1.0
				ability_pressed.emit()
				get_viewport().set_input_as_handled()
				return
			if joy_touch == -1 and te.position.y > 56.0:
				joy_touch = te.index
				joy_center = te.position
				joy_knob = te.position
				output = Vector2.ZERO
		elif te.index == joy_touch:
			joy_touch = -1
			output = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		if de.index != joy_touch:
			return
		var off := de.position - joy_center
		if off.length() > JOY_R:
			joy_center += off.normalized() * (off.length() - JOY_R)
		joy_knob = de.position
		var v := (joy_knob - joy_center) / JOY_R
		output = v.limit_length(1.0) if v.length() > 0.15 else Vector2.ZERO


func _process(delta: float) -> void:
	t += delta
	btn_flash = maxf(0.0, btn_flash - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# joystick: painted ring (floats to the thumb while active) + knob
	var active := joy_touch != -1
	var c := joy_center if active else _rest_center()
	var k := joy_knob if active else c
	if active:
		k = c + (joy_knob - joy_center).limit_length(JOY_R)
	var a := 0.95 if active else 0.8
	draw_texture_rect(tex_base, Rect2(c - Vector2.ONE * BASE_D * 0.5, Vector2.ONE * BASE_D), false, Color(1, 1, 1, a))
	draw_texture_rect(tex_knob, Rect2(k - Vector2.ONE * KNOB_D * 0.5, Vector2.ONE * KNOB_D), false, Color(1, 1, 1, a))
	# blast button + cooldown sweep
	var b := _btn_center()
	var is_ready := cooldown <= 0.0
	var pulse := (0.5 + 0.5 * sin(t * 5.0)) if is_ready else 0.0
	var tint := Color.WHITE if is_ready else Color(0.55, 0.6, 0.75)
	if infect_state == 3:
		tint = Color(1.0, 0.5, 1.0) if is_ready else Color(0.6, 0.35, 0.7)
	elif infect_state == 2:
		tint = Color(1.0, 0.6 + pulse * 0.3, 1.0)
	var d := BTN_R * 2.0 * (1.0 + pulse * 0.03)
	draw_texture_rect(tex_btn, Rect2(b - Vector2.ONE * d * 0.5, Vector2.ONE * d), false, tint)
	if not is_ready:
		var pts := PackedVector2Array([b])
		var start := -PI * 0.5
		var end_a := start + TAU * cooldown
		for i in 33:
			pts.append(b + Vector2.from_angle(lerpf(start, end_a, i / 32.0)) * (BTN_R - 5.0))
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.02, 0.04, 0.12, 0.6))
	if btn_flash > 0.0:
		FastDraw.disc(self, b, BTN_R + 10.0 * (1.0 - btn_flash), Color(1, 1, 1, btn_flash * 0.5))
	if infect_state > 0:
		_draw_infection(b)


func _draw_infection(b: Vector2) -> void:
	const MAG := Color("ff3df0")
	var r := BTN_R + 5.0
	FastDraw.ring(self, b, r, Color(0.15, 0.03, 0.2, 0.75), 5.0)
	if infect > 0.0:
		FastDraw.arc(self, b, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(infect, 0.0, 1.0), MAG, 4.0)
	if infect_state == 2:
		var p := 0.5 + 0.5 * sin(t * 8.0)
		FastDraw.ring(self, b, r + 4.0 + p * 4.0, Color(MAG, 0.5 - p * 0.3), 3.0)
		_label(b + Vector2(0, -r - 10.0), "MUTATE!", MAG.lerp(Color.WHITE, p * 0.5))
	elif infect_state == 3:
		_label(b + Vector2(0, -r - 10.0), "ROLL", MAG)


func _label(pos: Vector2, text: String, col: Color) -> void:
	var f := get_theme_default_font()
	var at := pos - Vector2(60.0, -5.0)
	draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 12, 4, Color("1a1c2c"))
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 12, col)
