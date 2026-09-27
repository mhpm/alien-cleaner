class_name SpawnMarker
extends Node2D
## Swirling portal on the floor that warns where an alien is about to appear.

signal finished

var dur := 0.7
var size := 8.0
var color := Color("c75bd6")
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= dur:
		finished.emit()
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / dur
	var r := size * (0.35 + 0.65 * k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, r, Color(color, 0.25))
	draw_arc(Vector2.ZERO, r, t * 8.0, t * 8.0 + PI * 1.3, 14, color, 1.0)
	draw_arc(Vector2.ZERO, r * 0.6, -t * 11.0, -t * 11.0 + PI, 10, Color(1, 1, 1, 0.8), 1.0)
