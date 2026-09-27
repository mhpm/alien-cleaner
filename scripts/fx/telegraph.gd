class_name Telegraph
extends Node2D
## Red warning shape drawn on the floor before a boss attack lands.

var kind := "circle"
var radius := 20.0
var dir := Vector2.RIGHT
var length := 100.0
var width := 12.0
var dur := 1.0
var t := 0.0
var color := Color(1.0, 0.25, 0.3)


func _process(delta: float) -> void:
	t += delta
	if t >= dur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / dur, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * 26.0)
	if kind == "circle":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.75))
		draw_circle(Vector2.ZERO, radius, Color(color, 0.12 + 0.1 * pulse))
		draw_circle(Vector2.ZERO, radius * k, Color(color, 0.3))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.9), 1.5)
	else:
		draw_set_transform(Vector2.ZERO, dir.angle())
		draw_rect(Rect2(0.0, -width * 0.5, length, width), Color(color, 0.12 + 0.1 * pulse))
		draw_rect(Rect2(0.0, -width * 0.5, length * k, width), Color(color, 0.3))
		draw_rect(Rect2(0.0, -width * 0.5, length, width), Color(color, 0.9), false, 1.0)
