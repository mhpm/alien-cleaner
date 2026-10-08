class_name ArchBeam
extends Node2D
## The Archmage's eye beam: a magenta laser that starts at `angle` and sweeps round at
## `spin` rad/s for `dur` seconds, following `origin` (a Callable returning the boss's eye).
## The astronaut is hurt while on it (the player's own invulnerability paces the ticks).

var origin := Callable()
var angle := 0.0
var spin := 0.0
var dur := 1.0
var length := 280.0
var width := 9.0
var damage := 12.0
var t := 0.0
var _tick := 0.0


func _ready() -> void:
	z_index = 2
	if origin.is_valid():
		global_position = origin.call()


func _process(delta: float) -> void:
	t += delta
	if t >= dur or not origin.is_valid():
		queue_free()
		return
	var o: Variant = origin.call()
	if o == null:
		queue_free()
		return
	global_position = o
	angle += spin * delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.1
		_hurt()
	if randf() < 0.6:  # sparks along the beam
		var at := global_position + Vector2.from_angle(angle) * randf_range(10.0, length)
		Game.world.burst(at, Color("ff4fd8"), 1, 25.0, 0.25, 1.5)
	queue_redraw()


func _k() -> float:
	return clampf(minf(t / 0.12, (dur - t) / 0.18), 0.0, 1.0)


func _hurt() -> void:
	var p := Game.world.player
	if p.dead or _k() < 0.6:
		return
	var body := p.global_position + Vector2(0, Player.BODY_Y)
	var end := global_position + Vector2.from_angle(angle) * length
	var near := Geometry2D.get_closest_point_to_segment(body, global_position, end)
	if near.distance_to(body) < width * 0.5 + 4.0:
		p.take_damage(damage, global_position)


func _draw() -> void:
	var k := _k()
	var d := Vector2.from_angle(angle) * length
	draw_line(Vector2.ZERO, d, Color(0.85, 0.2, 1.0, 0.25 * k), width * 2.4)
	draw_line(Vector2.ZERO, d, Color(0.9, 0.3, 1.0, 0.6 * k), width * 1.3)
	draw_line(Vector2.ZERO, d, Color(1.0, 0.85, 1.0, 0.95 * k), width * 0.5)
	FastDraw.disc(self, Vector2.ZERO, width * 1.2 * k, Color(1.0, 0.8, 1.0, 0.8 * k))
