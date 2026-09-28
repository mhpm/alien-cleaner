class_name InfMissile
extends Node2D
## Infected mode: a tentacle with an eye (inf_missile) that launches upward, then
## homes in on the nearest alien and bursts in a small magenta blast.

const SPEED := 175.0
const BLAST_R := 26.0

var vel := Vector2.UP * 130.0
var damage := 30.0
var life := 2.6
var target: Enemy
var sprite: AnimatedSprite2D
var trail_t := 0.0


func _ready() -> void:
	sprite = Art.make_anim("inf_missile", 0.07)
	sprite.play("fly")
	add_child(sprite)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_explode()
		return
	if target == null or not is_instance_valid(target) or not target.targetable:
		target = _pick()
	if target != null:
		var want := (target.hit_center() - global_position).normalized() * SPEED
		vel = vel.lerp(want, 1.0 - exp(-4.5 * delta))
		if global_position.distance_to(target.hit_center()) < target.radius + 5.0:
			_explode()
			return
	global_position += vel * delta
	rotation = vel.angle()
	sprite.scale = Vector2(0.07, 0.07 * (1.0 + sin(life * 30.0) * 0.08))
	trail_t -= delta
	if trail_t <= 0.0:
		trail_t = 0.03
		Game.world.burst(global_position - vel.normalized() * 8.0, Infected.MAGENTA, 1, 15.0, 0.3, 2.0)


func _pick() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for n in Game.world.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		var d := e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _explode() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "inf_burst", "pop", global_position, 0.13, rotation + PI)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector2.ONE * 0.17, 0.22)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.22)
	tw.tween_callback(fx.queue_free)
	w.ring(global_position, BLAST_R, Infected.MAGENTA, 0.3, 3.0, true)
	w.burst(global_position, Infected.MAGENTA, 12, 90.0, 0.35, 2.0)
	Sfx.play("pop", 0.15, -3.0)
	for n in w.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		if e.global_position.distance_to(global_position) < BLAST_R + e.radius:
			e.take_damage(damage, (e.global_position - global_position).normalized())
	w.shake(0.15)
	queue_free()
