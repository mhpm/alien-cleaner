@tool
extends RefCounted
## Drag a rectangle in the 2D viewport (DECOR > Draw Area). Snaps to the grid when snap
## is on. The rectangle stays drawn until the arena or the mode changes.

signal area_drawn(rect: Rect2)

const COLOR := Color(1.0, 0.85, 0.3)

var grid  # grid_settings.gd
var drawing := false  # waiting for / doing a drag
var rect := Rect2()
var _start := Vector2.INF


func _init(grid_settings: RefCounted) -> void:
	grid = grid_settings


func begin() -> void:
	drawing = true
	_start = Vector2.INF


func cancel() -> void:
	drawing = false
	_start = Vector2.INF


func handle_input(event: InputEvent, xf: Transform2D) -> bool:
	if not drawing:
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = grid.snap_line(xf.affine_inverse() * event.position)
		if event.pressed:
			_start = p
			rect = Rect2(p, Vector2.ZERO)
		elif _start != Vector2.INF:
			rect = Rect2(_start, Vector2.ZERO).expand(p).abs()
			drawing = false
			_start = Vector2.INF
			if rect.size.x > 4.0 and rect.size.y > 4.0:
				area_drawn.emit(rect)
		return true
	if event is InputEventMouseMotion and _start != Vector2.INF:
		rect = Rect2(_start, Vector2.ZERO).expand(grid.snap_line(xf.affine_inverse() * event.position)).abs()
		return true
	return false


func draw(overlay: Control, xf: Transform2D) -> void:
	if rect.size == Vector2.ZERO:
		return
	var r := Rect2(xf * rect.position, xf.basis_xform(rect.size))
	overlay.draw_rect(r, Color(COLOR, 0.08))
	overlay.draw_rect(r, COLOR, false, 2.0)
	overlay.draw_string(overlay.get_theme_default_font(), r.position + Vector2(4, -4), "DECOR AREA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR)
