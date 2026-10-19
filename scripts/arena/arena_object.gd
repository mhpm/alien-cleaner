@tool
class_name ArenaObject
extends Node2D
## Base of everything placed from the Arena Editor palette. Kept deliberately thin:
## components add behaviour by composition; this only gives them
##   - an `object_id` objectives, triggers and waves refer to,
##   - editor-only drawing (`_draw_editor`, never runs in the game),
##   - the layer the palette drops them into (`arena_layer`),
##   - `activate(director)`: called once when the arena starts playing (ArenaDirector),
##   - `validate_arena`: report their own problems.

## How much each gizmo shows while editing (dock GRID > Gizmos), so a map with dozens
## of aliens, spawners and hazards stays readable:
##   SELECTED  ranges, cones, paths and captions only on the selected objects (default)
##   ALL       every object's details
##   NONE      only the icons and shapes
enum Gizmos { SELECTED, ALL, NONE }
const GIZMOS_SETTING := "aliens_cleaner/arena_editor/gizmos"
static var _gizmos := -1

## Name other objects and objectives use to point at this one ("nest_a", "door_1").
@export var object_id := "":
	set(value):
		object_id = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		queue_redraw()
		var sel := _editor_selection()
		if sel != null and _redraws_on_selection():  # SELECTED gizmos follow the selection
			sel.connect("selection_changed", queue_redraw)


## Override (false): pieces with no details to show (scenery) skip the selection signal.
func _redraws_on_selection() -> bool:
	return true


static func gizmo_mode() -> int:
	if _gizmos < 0:
		_gizmos = Gizmos.SELECTED
		var ei := _editor()
		if ei != null:
			var es: Object = ei.call("get_editor_settings")
			if es.call("has_setting", GIZMOS_SETTING):
				_gizmos = int(es.call("get_setting", GIZMOS_SETTING))
	return _gizmos


## The dock's choice (remembered in the editor settings).
static func set_gizmo_mode(mode: int) -> void:
	_gizmos = mode
	var ei := _editor()
	if ei != null:
		ei.call("get_editor_settings").call("set_setting", GIZMOS_SETTING, mode)


## Draw this object's details (ranges, cones, paths, captions) now?
func show_details() -> bool:
	match gizmo_mode():
		Gizmos.ALL:
			return true
		Gizmos.NONE:
			return false
	var sel := _editor_selection()
	if sel == null:
		return true  # no editor selection to ask (game, tests): show everything, as before
	return (sel.call("get_selected_nodes") as Array).has(self)


## (EditorInterface reached by name: this script also runs in the exported game.)
static func _editor() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	return Engine.get_singleton("EditorInterface")


static func _editor_selection() -> Object:
	var ei := _editor()
	return ei.call("get_selection") if ei != null else null


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_editor()


## Override: gizmos shown only while editing (radii, labels, icons).
func _draw_editor() -> void:
	pass


## Override: Arena layer this object belongs in ("GameplayObjects", "Obstacles"...).
func arena_layer() -> String:
	return ""


## Override: picture for the editor palette and its placement ghost (null = none).
func palette_icon() -> Texture2D:
	return null


## Override: editor theme icon used when there is no picture ("Area2D", "Skull"...).
func palette_editor_icon() -> String:
	return "Node2D"


## Override: how wide (world units) the palette ghost draws `palette_icon`.
func palette_width() -> float:
	return 24.0


## Override: the arena starts playing. `director` is the ArenaDirector.
func activate(_director: Node) -> void:
	pass


## Override: add issues to `report` (see ArenaReport). Called by ArenaValidator.
func validate_arena(_report: ArenaReport, _arena: Arena) -> void:
	pass


## Done with (nest destroyed, crew rescued, part collected...): the guide arrow skips it.
func is_resolved() -> bool:
	return false


## Where this object "is" for the guide arrow and objective markers (global).
func focus_point() -> Vector2:
	return global_position


# ---------------------------------------------------------------- editor drawing helpers

## Small caption under an editor gizmo.
func _editor_label(text: String, at: Vector2, color: Color, size := 8) -> void:
	if not show_details():
		return
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.75))
	draw_string(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## A tiny always-visible tag (a pack's size): shown even when details are collapsed.
func _badge(text: String, at: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	draw_rect(Rect2(at - Vector2(2, 7), Vector2(w + 4, 9)), Color(0, 0, 0, 0.7))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color.lightened(0.3))


## Dashed circle (radii: spawn, rescue, blast...).
func _dashed_circle(r: float, color: Color, width := 1.0, dashes := 32) -> void:
	if not show_details():
		return
	for i in dashes:
		var a := TAU * i / dashes
		draw_arc(Vector2.ZERO, r, a, a + TAU / dashes * 0.55, 4, color, width)


## Translucent zone with a bold border (triggers, hazards, boss areas).
func _zone(rect: Rect2, color: Color) -> void:
	draw_rect(rect, Color(color, 0.12))
	draw_rect(rect, color, false, 1.5)


## A texture drawn standing on the origin, `width` world units wide.
func _standing(tex: Texture2D, width: float, color := Color.WHITE, lift := 0.0) -> void:
	if tex == null:
		return
	var size := Vector2(width, width * tex.get_height() / tex.get_width())
	draw_texture_rect(tex, Rect2(Vector2(-size.x * 0.5, -size.y - lift), size), false, color)


## The `object_id` caption every gameplay gizmo shows.
func _id_caption(at: Vector2, color: Color) -> void:
	if not object_id.is_empty():
		_editor_label("#" + object_id, at, color.lightened(0.3), 7)
