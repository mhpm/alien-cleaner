@tool
class_name ArenaBounds
extends Node2D
## The playable rectangle of an Arena: Rect2(position, size) in the arena's space
## (keep this node unrotated and unscaled). The editor draws it with drag handles;
## the game uses it to keep the player, aliens and the camera inside.

const MIN_SIZE := Vector2(64, 64)
const EDITOR_COLOR := Color(0.45, 1.0, 0.55, 0.9)

## Width and height in world units (1 terrain tile = Arena.TILE).
@export var size := Vector2(832, 1088):
	set(value):
		size = value.max(MIN_SIZE).round()
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


## Rect in global coordinates.
func global_rect() -> Rect2:
	return Rect2(global_position, size)


func contains(global_point: Vector2, margin := 0.0) -> bool:
	return global_rect().grow(-margin).has_point(global_point)


func clamp_point(global_point: Vector2, margin := 0.0) -> Vector2:
	var r := global_rect().grow(-margin)
	return global_point.clamp(r.position, r.end)


## Keep `camera` from showing anything past the bounds (grown by `pad`).
func apply_camera_limits(camera: Camera2D, pad := 0.0) -> void:
	var r := global_rect().grow(pad)
	camera.limit_left = floori(r.position.x)
	camera.limit_top = floori(r.position.y)
	camera.limit_right = ceili(r.end.x)
	camera.limit_bottom = ceili(r.end.y)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(EDITOR_COLOR, 0.05))
	draw_rect(r, EDITOR_COLOR, false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(4, -6), "ARENA BOUNDS  %d x %d  (%d x %d tiles)" % [size.x, size.y,
		roundi(size.x / Arena.TILE), roundi(size.y / Arena.TILE)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, EDITOR_COLOR)
