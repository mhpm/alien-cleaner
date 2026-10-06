@tool
extends RefCounted
## Picking arena objects by what they look like. Godot's own 2D select only grabs a
## custom-drawn node near its origin, which is hopeless in a forest of hundreds; this
## knows every component's real bounds (the picture of a tree, the zone of a trigger...):
##   click        select the object under the mouse (Shift: add / remove)
##   drag         move it, or every selected object together (grid snap if on)
##   R            rotate 90 degrees (Shift+R: 15)
##   F / V        flip horizontally / vertically
##   + / -        bigger / smaller (10%)
##   D            duplicate (next to the original, selected)
##   Supr / Del   delete
## Every change is one undoable action (Ctrl+Z).
##   hover        outline + name of what a click would take
## Clicks on empty floor go to Godot (box selection). Never active while a TileMapLayer
## is selected (terrain painting) or another tool is armed.

const HOVER := Color(1, 1, 1, 0.55)
const SELECTED := Color(1.0, 0.85, 0.3)

var plugin: EditorPlugin
var grid  # grid_settings.gd
var hover: ArenaObject
var _drag: ArenaObject  # the object under the mouse when the drag began
var _group: Array[ArenaObject] = []  # everything moving with it
var _from: Array[Vector2] = []
var _offset := Vector2.ZERO
var _moved := false


func _init(editor_plugin: EditorPlugin, grid_settings: RefCounted) -> void:
	plugin = editor_plugin
	grid = grid_settings


## Painting terrain: the TileMap panel owns the clicks.
static func painting() -> bool:
	return EditorInterface.get_selection().get_selected_nodes().any(func(n: Node) -> bool: return n is TileMapLayer)


## What an object covers on screen (global), roughly its picture or its zone.
static func bounds(o: ArenaObject) -> Rect2:
	var p := o.global_position
	if o is ArenaScenery:
		return (o as ArenaScenery).cover_rect()
	if o is ArenaTrigger:
		return Rect2(p - (o as ArenaTrigger).size * 0.5, (o as ArenaTrigger).size)
	if o is HazardArea:
		return Rect2(p - (o as HazardArea).size * 0.5, (o as HazardArea).size)
	if o is BossTrigger:
		return Rect2(p - (o as BossTrigger).trigger_size * 0.5, (o as BossTrigger).trigger_size)
	if o is ArenaDoor:
		var s := (o as ArenaDoor).size
		return Rect2(p - s * 0.5 - Vector2(0, 6), s + Vector2(0, 8))
	if o is ArenaDecal:
		var d := o as ArenaDecal
		var h := d.width * (d.texture.get_height() / float(d.texture.get_width()) if d.texture != null else 1.0)
		return Rect2(p - Vector2(d.width, h) * 0.5, Vector2(d.width, h))
	if o is EnemySpawner:
		return Rect2(p - Vector2(12, 24), Vector2(24, 30))
	if o is ArenaProp:
		var tex := (o as ArenaProp).texture()
		var w := float(PropData.PROPS.get((o as ArenaProp).prop_id, {}).get("width", 16.0))
		var h2 := w * tex.get_height() / tex.get_width() if tex != null else w
		return Rect2(p - Vector2(w * 0.5, h2), Vector2(w, h2))
	var icon := o.palette_icon()
	var width := o.palette_width()
	var hh := width * icon.get_height() / icon.get_width() if icon != null else width
	return Rect2(p - Vector2(width * 0.5, hh), Vector2(width, hh)).grow(2.0)


## Zones (triggers, hazards, boss areas) are big: anything standing in them wins.
static func _is_zone(o: ArenaObject) -> bool:
	return o is ArenaTrigger or o is HazardArea or o is BossTrigger


## The object under `global_point`: standing things before zones and flat decals, the
## one drawn in front (lowest on screen) first.
static func pick(arena: Arena, global_point: Vector2) -> ArenaObject:
	var best: ArenaObject = null
	var best_rank := -INF
	for o in arena.objects():
		if not o.is_visible_in_tree() or not bounds(o).has_point(global_point):
			continue
		var rank := o.global_position.y
		if _is_zone(o) or (o is ArenaScenery and (o as ArenaScenery).flat) or o is ArenaDecal:
			rank -= 100000.0
		if rank > best_rank:
			best_rank = rank
			best = o
	return best


func selected(arena: Arena) -> Array[ArenaObject]:
	var out: Array[ArenaObject] = []
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is ArenaObject and arena.is_ancestor_of(n):
			out.append(n as ArenaObject)
	return out


func handle_input(event: InputEvent, arena: Arena, xf: Transform2D) -> bool:
	if painting():
		hover = null
		return false
	var at: Vector2 = arena.to_global(xf.affine_inverse() * event.position) if event is InputEventMouse else Vector2.ZERO
	if event is InputEventMouseMotion:
		if _drag != null:
			var target: Vector2 = arena.to_global(grid.snap_point(arena.to_local(at + _offset))) if grid.snap else (at + _offset).round()
			var delta := target - _drag.global_position
			if delta != Vector2.ZERO:
				for o in _group:
					o.global_position += delta
				_moved = true
			return true
		hover = pick(arena, at)
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var o := pick(arena, at)
			if o == null:
				return false
			var selection := EditorInterface.get_selection()
			var already := selection.get_selected_nodes().has(o)
			if mb.shift_pressed and already:
				selection.remove_node(o)
				return true
			if not mb.shift_pressed and not already:
				selection.clear()
			selection.add_node(o)
			if not mb.shift_pressed and not already:
				EditorInterface.inspect_object(o)  # (it would reset a multiple selection)
			_drag = o
			_group = selected(arena)
			_from.clear()
			for g in _group:
				_from.append(g.global_position)
			_offset = o.global_position - at
			_moved = false
			return true
		if _drag != null:
			if _moved:
				var ur := plugin.get_undo_redo()
				ur.create_action("Move %d arena object(s)" % _group.size(), UndoRedo.MERGE_DISABLE, arena)
				for i in _group.size():
					ur.add_do_property(_group[i], "global_position", _group[i].global_position)
					ur.add_undo_property(_group[i], "global_position", _from[i])
				ur.commit_action(false)
			_drag = null
			_group.clear()
			return true
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.alt_pressed:
		var k := event as InputEventKey
		match k.keycode:
			KEY_DELETE, KEY_BACKSPACE:
				return delete_selected(arena)
			KEY_R:
				return rotate_selected(arena, 15.0 if k.shift_pressed else 90.0)
			KEY_F:
				return flip_selected(arena, true)
			KEY_V:
				return flip_selected(arena, false)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				return scale_selected(arena, 1.1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				return scale_selected(arena, 1.0 / 1.1)
			KEY_D:
				return duplicate_selected(arena)
	return false


## One undoable property change on every selected object; `value_for(o)` gives the new value.
func _change(arena: Arena, label: String, prop: String, value_for: Callable) -> bool:
	var objs := selected(arena)
	if objs.is_empty():
		return false
	var ur := plugin.get_undo_redo()
	ur.create_action("%s %d arena object(s)" % [label, objs.size()], UndoRedo.MERGE_DISABLE, arena)
	for o in objs:
		ur.add_do_property(o, prop, value_for.call(o))
		ur.add_undo_property(o, prop, o.get(prop))
	ur.commit_action()
	return true


func rotate_selected(arena: Arena, degrees: float) -> bool:
	return _change(arena, "Rotate", "rotation_degrees", func(o: ArenaObject) -> float:
		return fmod(o.rotation_degrees + degrees, 360.0))


## Horizontal flips use the object's own `flip_h` (sprites keep their shadow and pivot);
## vertical flips (and objects without flip_h) mirror the node.
func flip_selected(arena: Arena, horizontal: bool) -> bool:
	var objs := selected(arena)
	if objs.is_empty():
		return false
	var ur := plugin.get_undo_redo()
	ur.create_action("Flip %d arena object(s)" % objs.size(), UndoRedo.MERGE_DISABLE, arena)
	for o in objs:
		if horizontal and "flip_h" in o:
			ur.add_do_property(o, "flip_h", not o.get("flip_h"))
			ur.add_undo_property(o, "flip_h", o.get("flip_h"))
		else:
			var s := o.scale * (Vector2(-1, 1) if horizontal else Vector2(1, -1))
			ur.add_do_property(o, "scale", s)
			ur.add_undo_property(o, "scale", o.scale)
	ur.commit_action()
	return true


## Pictures with a `width` (scenery, decals) grow by width; the rest by scale.
func scale_selected(arena: Arena, k: float) -> bool:
	var objs := selected(arena)
	if objs.is_empty():
		return false
	var ur := plugin.get_undo_redo()
	ur.create_action("Resize %d arena object(s)" % objs.size(), UndoRedo.MERGE_DISABLE, arena)
	for o in objs:
		if o is ArenaScenery or o is ArenaDecal:
			ur.add_do_property(o, "width", roundf(float(o.get("width")) * k * 2.0) / 2.0)
			ur.add_undo_property(o, "width", o.get("width"))
			if o is ArenaScenery:
				ur.add_do_property(o, "footprint", (o as ArenaScenery).footprint * k)
				ur.add_undo_property(o, "footprint", (o as ArenaScenery).footprint)
		else:
			ur.add_do_property(o, "scale", o.scale * k)
			ur.add_undo_property(o, "scale", o.scale)
	ur.commit_action()
	return true


## Copies next to the originals (one grid cell to the right), which become the selection.
func duplicate_selected(arena: Arena) -> bool:
	var objs := selected(arena)
	if objs.is_empty():
		return false
	var step := Vector2(float(grid.size), 0.0)
	var copies: Array[Node] = []
	var ur := plugin.get_undo_redo()
	ur.create_action("Duplicate %d arena object(s)" % objs.size(), UndoRedo.MERGE_DISABLE, arena)
	for o in objs:
		var c := o.duplicate()
		c.position = o.position + step
		var parent := o.get_parent()
		ur.add_do_method(parent, "add_child", c, true)
		ur.add_do_method(c, "set_owner", arena)
		ur.add_do_reference(c)
		ur.add_undo_method(parent, "remove_child", c)
		copies.append(c)
	ur.commit_action()
	var selection := EditorInterface.get_selection()
	selection.clear()
	for c in copies:
		selection.add_node(c)
	return true


## Removes the selected arena objects in one undoable action.
func delete_selected(arena: Arena) -> bool:
	var doomed: Array[Node] = []
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is ArenaObject and arena.is_ancestor_of(n):
			doomed.append(n)
	if doomed.is_empty():
		return false
	var ur := plugin.get_undo_redo()
	ur.create_action("Delete %d arena object(s)" % doomed.size(), UndoRedo.MERGE_DISABLE, arena)
	for n in doomed:
		var parent := n.get_parent()
		ur.add_do_method(parent, "remove_child", n)
		ur.add_undo_method(parent, "add_child", n, true)
		ur.add_undo_method(parent, "move_child", n, n.get_index())
		ur.add_undo_method(n, "set_owner", arena)
		ur.add_undo_reference(n)
	EditorInterface.get_selection().clear()
	ur.commit_action()
	hover = null
	return true


func draw(overlay: Control, arena: Arena) -> void:
	if painting():
		return
	var canvas := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var font := overlay.get_theme_default_font()
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is ArenaObject and arena.is_ancestor_of(n):
			var r := bounds(n as ArenaObject)
			var sr := Rect2(canvas * r.position, canvas.basis_xform(r.size))
			overlay.draw_rect(sr, SELECTED, false, 2.0)
			overlay.draw_string(font, sr.position + Vector2(0, -4), str(n.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SELECTED)
	if hover != null and is_instance_valid(hover) and not EditorInterface.get_selection().get_selected_nodes().has(hover):
		var r := bounds(hover)
		var hr := Rect2(canvas * r.position, canvas.basis_xform(r.size))
		overlay.draw_rect(hr, HOVER, false, 1.0)
		overlay.draw_string(font, hr.position + Vector2(0, -4), str(hover.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HOVER)
