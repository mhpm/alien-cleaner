class_name Lightning
extends Node2D
## Short jagged electric arc between two points (Electric Mop chains, zap floors).

var a := Vector2.ZERO
var b := Vector2.ZERO
var dur := 0.18
var t := 0.0
var color := Color("73eff7")


func _process(delta: float) -> void:
	t += delta
	if t >= dur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var pts := PackedVector2Array()
	var n := maxi(3, int(a.distance_to(b) / 6.0))
	var perp := (b - a).orthogonal().normalized()
	for i in n + 1:
		var k := float(i) / n
		var off := 0.0 if i == 0 or i == n else randf_range(-3.5, 3.5)
		pts.append(a.lerp(b, k) + perp * off)
	var alpha := 1.0 - t / dur
	draw_polyline(pts, Color(color, alpha), 2.0)
	draw_polyline(pts, Color(1, 1, 1, alpha), 1.0)
