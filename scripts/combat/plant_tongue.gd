class_name PlantTongue
extends Node2D
## The Tentacle Plant's tongue: shoots out from its maw towards `dir`, holds a moment and
## whips back. If the astronaut is on it when it lands it takes `damage` and is yanked
## towards the plant. Its own node, so it finishes even if the plant is cleaned mid-lash.

const OUT := 0.1
const HOLD := 0.14
const BACK := 0.14

var dir := Vector2.RIGHT
var length := 62.0
var damage := 12.0
var t := 0.0
var _hit := false
var _tip: AnimatedSprite2D


func _ready() -> void:
	_tip = Art.make_anim("plant_glob", 0.16)
	_tip.play("fly")
	add_child(_tip)


func _ext() -> float:
	if t < OUT:
		return ease(t / OUT, 0.4)
	if t < OUT + HOLD:
		return 1.0
	return 1.0 - ease((t - OUT - HOLD) / BACK, 2.0)


func _process(delta: float) -> void:
	t += delta
	if t >= OUT + HOLD + BACK:
		queue_free()
		return
	var tip := dir * length * _ext()
	_tip.position = tip
	_tip.scale = Vector2.ONE * 0.16 * (1.0 + sin(t * 40.0) * 0.06)
	if not _hit and t >= OUT:
		_hit = true
		_strike()
	queue_redraw()


func _strike() -> void:
	var p := Game.world.player
	if p.dead:
		return
	var body := p.global_position + Vector2(0, Player.BODY_Y)
	var a := global_position
	var b := global_position + dir * length
	var closest := Geometry2D.get_closest_point_to_segment(body, a, b)
	if closest.distance_to(body) < 9.0:
		p.take_damage(damage, global_position)
		p.knock = (global_position - p.global_position).normalized() * 190.0  # yanked in
		Game.world.burst(body, Color("ff3c6e"), 6, 60.0, 0.3, 2.0)
	Game.world.shake(0.2)


func _draw() -> void:
	var tip := dir * length * _ext()
	draw_line(Vector2.ZERO, tip, Color("7a1233"), 5.0)
	draw_line(Vector2.ZERO, tip, Color("ff5c8a"), 3.0)
	draw_line(Vector2.ZERO, tip * 0.98, Color("ffb3c8"), 1.0)
