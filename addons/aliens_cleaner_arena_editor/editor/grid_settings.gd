@tool
extends RefCounted
## Grid size / snap / visibility of the Arena Editor (remembered per project in the
## editor's project metadata, not in the arena scenes) and the grid overlay drawing.

signal changed

const SIZES := [16, 32, 64]
const META := "aliens_cleaner_arena_editor"
const LINE := Color(0.55, 0.85, 1.0, 0.16)
const MAJOR := Color(0.55, 0.85, 1.0, 0.32)
const MIN_SCREEN_STEP := 6.0  # px: denser grids are not drawn

var size := 32
var snap := true
var visible := true


func load_settings() -> void:
	var es := EditorInterface.get_editor_settings()
	size = int(es.get_project_metadata(META, "grid_size", 32))
	snap = bool(es.get_project_metadata(META, "snap", true))
	visible = bool(es.get_project_metadata(META, "grid_visible", true))
	if not SIZES.has(size):
		size = 32


func set_values(new_size: int, new_snap: bool, new_visible: bool) -> void:
	size = new_size
	snap = new_snap
	visible = new_visible
	var es := EditorInterface.get_editor_settings()
	es.set_project_metadata(META, "grid_size", size)
	es.set_project_metadata(META, "snap", snap)
	es.set_project_metadata(META, "grid_visible", visible)
	changed.emit()


## Placement point: the centre of the grid cell (snap on) or the whole pixel (off).
func snap_point(p: Vector2) -> Vector2:
	if not snap:
		return p.round()
	var g := float(size)
	return (p / g).floor() * g + Vector2.ONE * g * 0.5


## Edge point (bounds handles): the nearest grid line (snap on) or the whole pixel.
func snap_line(p: Vector2) -> Vector2:
	if not snap:
		return p.round()
	return (p / float(size)).round() * float(size)


## Grid over the arena bounds (grown by a few cells), in arena-local space `xf`.
func draw(overlay: Control, xf: Transform2D, area: Rect2) -> void:
	if not visible:
		return
	var g := float(size)
	if g * xf.get_scale().x < MIN_SCREEN_STEP:
		return
	var view := xf.affine_inverse() * Rect2(Vector2.ZERO, overlay.size)
	var r := area.grow(g * 4.0).intersection(view)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var x0 := floori(r.position.x / g)
	var x1 := ceili(r.end.x / g)
	var y0 := floori(r.position.y / g)
	var y1 := ceili(r.end.y / g)
	var lines := PackedVector2Array()
	var majors := PackedVector2Array()
	for x in range(x0, x1 + 1):
		var target := majors if x % 4 == 0 else lines
		target.append(xf * Vector2(x * g, y0 * g))
		target.append(xf * Vector2(x * g, y1 * g))
	for y in range(y0, y1 + 1):
		var target := majors if y % 4 == 0 else lines
		target.append(xf * Vector2(x0 * g, y * g))
		target.append(xf * Vector2(x1 * g, y * g))
	if not lines.is_empty():
		overlay.draw_multiline(lines, LINE, 1.0)
	if not majors.is_empty():
		overlay.draw_multiline(majors, MAJOR, 1.0)
