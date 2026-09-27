class_name RingFx
extends Node2D
## Expanding shockwave ring (air blast, explosions, boss slams).

var radius := 30.0
var dur := 0.3
var width := 2.0
var filled := false
var color := Color.WHITE
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= dur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / dur
	var r := radius * (1.0 - pow(1.0 - k, 3.0))
	if filled:
		draw_circle(Vector2.ZERO, r, Color(color, 0.3 * (1.0 - k)))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, 1.0 - k), maxf(1.0, width * (1.0 - k) + 0.5))
