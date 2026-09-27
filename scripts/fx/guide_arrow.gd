class_name GuideArrow
extends Node2D
## Station guide: a bobbing chevron next to the astronaut pointing at the next dirty
## sector (yellow) or the open exit (green). Hidden when the target is close.

var player: Node2D
var target := Vector2.INF
var color := Color("ffcd75")
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if player == null or target == Vector2.INF:
		return
	var from := player.global_position + Vector2(0, -12)
	var d := target - from
	if d.length() < 36.0:
		return
	var dir := d.normalized()
	var c := from + dir * (20.0 + sin(t * 6.0) * 2.0)
	var side := dir.orthogonal()
	var tip := c + dir * 4.0
	var pts := PackedVector2Array([tip, c - dir * 2.0 + side * 3.5, c - dir * 0.5, c - dir * 2.0 - side * 3.5])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.5))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.8)
	var a := 0.75 + sin(t * 6.0) * 0.25
	draw_colored_polygon(inner, Color(color, a))
