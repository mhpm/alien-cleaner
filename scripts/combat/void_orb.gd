class_name VoidOrb
extends Node2D
## The Archmage's singularity: a dark orb that swells for `life` seconds dragging the
## astronaut towards it (touching it hurts), then bursts in a ring of orbs and crescent
## blades.

const PULL := 820.0  # a little more than the astronaut's knock decay (700): a slow drag
const PULL_R := 120.0
const BURST_N := 12
const LIFE := 3.4

var life := LIFE
var damage := 16.0
var t := 0.0
var _hit_t := 0.0
var _spr: AnimatedSprite2D


func _ready() -> void:
	z_index = 1
	_spr = Art.make_anim("arch_bigorb", 0.1)
	_spr.play("fly")
	_spr.position = Vector2(0, -8)
	add_child(_spr)
	Sfx.play("charge", 0.0, -4.0)


func _process(delta: float) -> void:
	t += delta
	var k := clampf(t / life, 0.0, 1.0)
	_spr.scale = Vector2.ONE * (0.1 + 0.2 * k) * (1.0 + sin(t * 18.0) * 0.05)
	_spr.rotation = t * 3.0
	_hit_t -= delta
	var p := Game.world.player
	if not p.dead:
		var to_me := global_position - p.global_position
		var d := to_me.length()
		if d < PULL_R and d > 0.1:
			p.knock = (p.knock + to_me / d * PULL * delta).limit_length(130.0)
		if d < 11.0 and _hit_t <= 0.0:
			_hit_t = 1.0
			p.take_damage(damage, global_position)
	if randf() < 0.7:  # dust sucked in
		var a := randf() * TAU
		var at := global_position + Vector2.from_angle(a) * randf_range(30.0, 60.0)
		Game.world.burst(at, Color("d43cff"), 1, 30.0, 0.35, 1.5, 0.0, (global_position - at).normalized(), 0.1)
	queue_redraw()
	if t >= life:
		_burst()


func _draw() -> void:
	var k := clampf(t / life, 0.0, 1.0)
	for i in 3:
		var r := PULL_R * (1.0 - fposmod(t * 0.9 + i / 3.0, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.75))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.85, 0.3, 1.0, 0.15 + 0.25 * k), 1.0)


func _burst() -> void:
	var w := Game.world
	w.ring(global_position, 40.0, Color("d43cff"), 0.4, 3.0, true)
	w.burst(global_position, Color("ff4fd8"), 24, 140.0, 0.6, 2.5)
	AnimFx.spawn(w.effects, "arch_boom", "pop", global_position + Vector2(0, -6), 0.45)
	w.shake(0.6)
	Sfx.play("explode", 0.0, -2.0)
	var off := randf() * TAU
	for i in BURST_N:
		var d := Vector2.from_angle(off + TAU * i / BURST_N)
		var blade := i % 2 == 0
		w.spawn_enemy_shot(global_position + d * 6.0, d * (100.0 if blade else 70.0), damage * 0.5, "arch_blade" if blade else "arch_star")
	queue_free()
