@tool
extends RefCounted
## Places the armed palette entry where the user clicks in the 2D viewport (grid snap
## or free, whole pixels), into the Arena layer the entry belongs to. Dragging with
## snap on keeps painting one object per new cell. Every placement is one undoable
## action. Esc or right-click disarms. With the dock's Brush on "Area" a drag draws a
## rectangle that fills with random copies of the picked objects (area_brush.gd).

signal disarmed

const AreaBrush := preload("area_brush.gd")
const GHOST := Color(1, 1, 1, 0.55)
const AREA := Color(0.55, 1.0, 0.45)

var plugin: EditorPlugin
var grid  # grid_settings.gd
var entry  # palette_catalog.gd Entry, or null
var hover := Vector2.INF  # arena-local, snapped
var _painting := false
var _last := Vector2.INF
var brush  # dock/brush_panel.gd (null = always one copy per click)
var picked: Callable  # -> Array of the palette entries picked now (the area brush mixes them)
var _drag_from := Vector2.INF
var _drag_rect := Rect2()


func _init(editor_plugin: EditorPlugin, grid_settings: RefCounted) -> void:
	plugin = editor_plugin
	grid = grid_settings


func armed() -> bool:
	return entry != null


func arm(new_entry: RefCounted) -> void:
	entry = new_entry
	_painting = false
	_drag_from = Vector2.INF


func _area_mode() -> bool:
	return brush != null and brush.is_area()


func disarm() -> void:
	if entry == null:
		return
	entry = null
	_painting = false
	_drag_from = Vector2.INF
	hover = Vector2.INF
	disarmed.emit()


func handle_input(event: InputEvent, arena: Arena, xf: Transform2D) -> bool:
	if entry == null:
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		disarm()
		return true
	if _area_mode():
		return _area_input(event, arena, xf)
	if event is InputEventMouseMotion:
		hover = grid.snap_point(xf.affine_inverse() * event.position)
		if _painting and grid.snap and hover != _last:
			_place(arena, hover)
		return false  # the viewport still pans/zooms
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			disarm()
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				hover = grid.snap_point(xf.affine_inverse() * mb.position)
				_place(arena, hover)
				_painting = true
			else:
				_painting = false
			return true
	return false


## Area brush: drag a rectangle, release to fill it.
func _area_input(event: InputEvent, arena: Arena, xf: Transform2D) -> bool:
	var at: Vector2 = grid.snap_line(xf.affine_inverse() * event.position) if event is InputEventMouse else Vector2.ZERO
	if event is InputEventMouseMotion:
		hover = at
		if _drag_from != Vector2.INF:
			_drag_rect = Rect2(_drag_from, Vector2.ZERO).expand(at).abs()
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			disarm()
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_from = at
				_drag_rect = Rect2(at, Vector2.ZERO)
			elif _drag_from != Vector2.INF:
				_drag_rect = Rect2(_drag_from, Vector2.ZERO).expand(at).abs()
				_drag_from = Vector2.INF
				if _drag_rect.size.x > 4.0 and _drag_rect.size.y > 4.0:
					_fill(arena, _drag_rect)
				_drag_rect = Rect2()
			return true
	return false


func _fill(arena: Arena, rect: Rect2) -> void:
	var entries: Array = picked.call() if picked.is_valid() else []
	if entries.is_empty():
		entries = [entry]
	var pairs := AreaBrush.generate(arena, entries, rect, brush.take_config())
	if pairs.is_empty():
		push_warning("Arena Editor: nothing fitted in the area (lower Min dist. or draw a bigger area).")
		return
	var ur := plugin.get_undo_redo()
	ur.create_action("Area brush: %d objects" % pairs.size(), UndoRedo.MERGE_DISABLE, arena)
	for pair: Array in pairs:
		var e = pair[0]
		var node: Node2D = pair[1]
		var parent := arena.get_layer(e.layer)
		if parent == null:
			parent = arena
		node.position = (parent as Node2D).to_local(arena.to_global(node.position)) if parent is Node2D else node.position
		if node.name.is_empty() or node.name.begins_with("@"):
			node.name = e.name.to_pascal_case()
		ur.add_do_method(parent, "add_child", node, true)
		ur.add_do_method(node, "set_owner", arena)
		ur.add_do_reference(node)
		ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()
	print("Arena Editor: area brush placed %d objects." % pairs.size())


func _place(arena: Arena, at: Vector2) -> void:
	_last = at
	var parent := arena.get_layer(entry.layer)
	if parent == null:
		push_warning("Arena Editor: layer \"%s\" is missing; placing under the arena root (dock: Repair Structure)." % entry.layer)
		parent = arena
	var node: Node2D = entry.instantiate()
	if node == null:
		return
	node.position = (parent as Node2D).to_local(arena.to_global(at)) if parent is Node2D else at
	if node.name.is_empty() or node.name.begins_with("@"):
		node.name = entry.name.to_pascal_case()
	var ur := plugin.get_undo_redo()
	# one Player Spawn per arena: placing another moves the current one and swaps its character
	var spawns := arena.find_children("*", "PlayerSpawn", true, false)
	if node is PlayerSpawn and not spawns.is_empty():
		var sp := spawns[0] as PlayerSpawn
		ur.create_action("Player Spawn: %s" % entry.name, UndoRedo.MERGE_DISABLE, arena)
		ur.add_do_property(sp, "global_position", arena.to_global(at))
		ur.add_undo_property(sp, "global_position", sp.global_position)
		ur.add_do_property(sp, "character", (node as PlayerSpawn).character)
		ur.add_undo_property(sp, "character", sp.character)
		ur.commit_action()
		node.free()
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(sp)
		return
	ur.create_action("Place %s" % entry.name, UndoRedo.MERGE_DISABLE, arena)
	ur.add_do_method(parent, "add_child", node, true)
	ur.add_do_method(node, "set_owner", arena)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()
	# a new Dialogue Trigger: straight to writing its conversation
	if node is ArenaTrigger and (node as ArenaTrigger).action == ArenaTrigger.Action.MESSAGE:
		disarm()
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(node)
		plugin.call_deferred("open_dialogue", node)


## Ghost of the armed entry under the mouse (overlay space).
func draw(overlay: Control, xf: Transform2D) -> void:
	if entry == null or hover == Vector2.INF:
		return
	if _area_mode():
		_draw_area(overlay, xf)
		return
	var p := xf * hover
	var k := xf.get_scale().x
	overlay.draw_circle(p, 3.0, Color(1, 0.9, 0.3, 0.9))
	if entry.icon != null:
		var w := float(entry.width) * k
		var size := Vector2(w, w * entry.icon.get_height() / maxf(1.0, entry.icon.get_width()))
		var origin := p - Vector2(size.x * 0.5, size.y if entry.anchor_feet else size.y * 0.5)
		overlay.draw_texture_rect(entry.icon, Rect2(origin, size), false, GHOST)
	var font := overlay.get_theme_default_font()
	overlay.draw_string(font, p + Vector2(8, 16), entry.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.3))


func _draw_area(overlay: Control, xf: Transform2D) -> void:
	var font := overlay.get_theme_default_font()
	var p := xf * hover
	overlay.draw_line(p - Vector2(8, 0), p + Vector2(8, 0), AREA, 1.5)
	overlay.draw_line(p - Vector2(0, 8), p + Vector2(0, 8), AREA, 1.5)
	if _drag_rect.size == Vector2.ZERO:
		overlay.draw_string(font, p + Vector2(10, 16), "drag to fill: " + entry.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AREA)
		return
	var r := Rect2(xf * _drag_rect.position, xf.basis_xform(_drag_rect.size))
	overlay.draw_rect(r, Color(AREA, 0.07))
	overlay.draw_rect(r, AREA, false, 2.0)
	if brush.is_round():
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(r.get_center() + Vector2(cos(a), sin(a)) * r.size * 0.5)
		overlay.draw_polyline(pts, AREA, 1.5)
	overlay.draw_string(font, r.position + Vector2(4, -4), "%d x %d" % [_drag_rect.size.x, _drag_rect.size.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AREA)
