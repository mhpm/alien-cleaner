class_name StickyGoo
extends Node2D
## A patch of sticky green goo left by the Martian Bean Cruiser's globs: it doesn't hurt,
## but while the astronaut stands in it they are slowed (Player.stick), and the slow
## lasts a moment after stepping out. Dries up after `life` seconds.

const RADIUS := 15.0

var life := 5.0
var t := 0.0


func _physics_process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	var p := Game.world.player
	if not p.dead:
		var off := p.global_position - global_position
		if Vector2(off.x, off.y / 0.6).length() < RADIUS:
			p.stick(0.5)
	queue_redraw()


func _draw() -> void:
	var a := clampf((life - t) / 0.8, 0.0, 1.0) * clampf(t / 0.15, 0.0, 1.0)
	var wob := 1.0 + sin(t * 4.0) * 0.04
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(wob, 0.6))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.45, 0.85, 0.15, 0.45 * a))
	draw_circle(Vector2(-3, -2), RADIUS * 0.7, Color(0.65, 1.0, 0.3, 0.45 * a))
	draw_circle(Vector2(-5, -5), RADIUS * 0.22, Color(0.9, 1.0, 0.7, 0.6 * a))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(0.25, 0.55, 0.05, 0.7 * a), 1.5)
