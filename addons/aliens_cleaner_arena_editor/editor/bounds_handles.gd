@tool
extends RefCounted
## Drag handles on the ArenaBounds rectangle while it is selected: corners and edge
## midpoints resize it (edges snap to grid lines when snap is on). The whole drag is
## one undoable action.

const GRAB := 9.0  # px around a handle that picks it
const COLOR := Color(0.45, 1.0, 0.55)

var plugin: EditorPlugin
var grid  # grid_settings.gd
var _drag := Vector2i.ZERO  # handle side: x/y in -1, 0, 1 (ZERO = not dragging)
var _start := Rect2()


func _init(editor_plugin: EditorPlugin, grid_settings: RefCounted) -> void:
	plugin = editor_plugin
	grid = grid_settings


func _target(arena: Arena) -> ArenaBounds:
	var bounds := arena.get_bounds()
	if bounds == null or not EditorInterface.get_selection().get_selected_nodes().has(bounds):
		return null
	return bounds


## Handles in arena space: side -> point.
static func _handles(r: Rect2) -> Dictionary:
	var out := {}
	for sx in [-1, 0, 1]:
		for sy in [-1, 0, 1]:
			if sx == 0 and sy == 0:
				continue
			out[Vector2i(sx, sy)] = r.get_center() + Vector2(sx, sy) * r.size * 0.5
	return out


static func _rect(b: ArenaBounds) -> Rect2:
	return Rect2(b.position, b.size)


func handle_input(event: InputEvent, arena: Arena, xf: Transform2D) -> bool:
	var bounds := _target(arena)
	if bounds == null:
		_drag = Vector2i.ZERO
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var hs := _handles(_rect(bounds))
			for side: Vector2i in hs:
				if (xf * (hs[side] as Vector2)).distance_to(mb.position) <= GRAB:
					_drag = side
					_start = _rect(bounds)
					return true
			return false
		if _drag != Vector2i.ZERO:
			_commit(bounds)
			_drag = Vector2i.ZERO
			return true
	if event is InputEventMouseMotion and _drag != Vector2i.ZERO:
		var p: Vector2 = grid.snap_line(xf.affine_inverse() * event.position)
		var r := _start
		var left := r.position.x
		var top := r.position.y
		var right := r.end.x
		var bottom := r.end.y
		if _drag.x < 0:
			left = minf(p.x, right - ArenaBounds.MIN_SIZE.x)
		elif _drag.x > 0:
			right = maxf(p.x, left + ArenaBounds.MIN_SIZE.x)
		if _drag.y < 0:
			top = minf(p.y, bottom - ArenaBounds.MIN_SIZE.y)
		elif _drag.y > 0:
			bottom = maxf(p.y, top + ArenaBounds.MIN_SIZE.y)
		bounds.position = Vector2(left, top).round()
		bounds.size = Vector2(right - left, bottom - top)
		return true
	return false


func _commit(bounds: ArenaBounds) -> void:
	var now := _rect(bounds)
	if now == _start:
		return
	var ur := plugin.get_undo_redo()
	ur.create_action("Resize Arena Bounds", UndoRedo.MERGE_DISABLE, bounds)
	ur.add_do_property(bounds, "position", now.position)
	ur.add_do_property(bounds, "size", now.size)
	ur.add_undo_property(bounds, "position", _start.position)
	ur.add_undo_property(bounds, "size", _start.size)
	ur.commit_action()


func draw(overlay: Control, xf: Transform2D, arena: Arena) -> void:
	var bounds := _target(arena)
	if bounds == null:
		return
	var hs := _handles(_rect(bounds))
	for side: Vector2i in hs:
		var p := xf * (hs[side] as Vector2)
		var box := Rect2(p - Vector2(5, 5), Vector2(10, 10))
		overlay.draw_rect(box, Color.WHITE if side == _drag else COLOR)
		overlay.draw_rect(box, Color(0, 0, 0, 0.8), false, 1.0)
