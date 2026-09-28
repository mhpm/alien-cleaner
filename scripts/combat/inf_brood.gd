class_name InfBrood
extends Node2D
## BROOD BURST (mutation phase 4): a spiky eyeball spawn that bursts out of the mutant,
## circles it and rams the nearest alien in reach, then flies back. It lives while the
## mutation lasts. Art: assets/sprites/mutations_player/fase 4/pixel100/brood_<n>.png
## (tools/make_infected_rig.py 4).

const TEX := "res://assets/sprites/mutations_player/fase 4/pixel100/brood_%d.png"
const ORBIT_R := 20.0
const REACH := 90.0  # from the mutant: aliens this close get rammed
const RAM_SPEED := 280.0
const RAM_EVERY := 0.7

var inf: Infected
var slot := 0.0  # angle offset around the mutant
var damage := 20.0
var sprite: Sprite2D
var t := 0.0
var cd := 0.3
var target: Enemy
var returning := false


func _ready() -> void:
	add_to_group("inf_brood")
	sprite = Sprite2D.new()
	sprite.texture = load(TEX % (randi() % 2))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * 0.5
	add_child(sprite)
	t = randf() * TAU


func _physics_process(delta: float) -> void:
	if inf == null or not is_instance_valid(inf) or not inf.active or inf.player.dead:
		_pop()
		return
	t += delta
	sprite.rotation += delta * (9.0 if target != null else 2.5)
	sprite.scale = Vector2.ONE * 0.5 * (1.0 + sin(t * 8.0) * 0.08)
	var home := inf.player.global_position + Vector2(0, -12) \
			+ Vector2.from_angle(slot + t * 2.2) * Vector2(ORBIT_R, ORBIT_R * 0.6)
	if target != null and (not is_instance_valid(target) or not target.targetable):
		target = null
		returning = true
	if target != null:
		var to := target.hit_center() - global_position
		global_position += to.limit_length(RAM_SPEED * delta)
		if to.length() < target.radius + 4.0:
			_hit(target)
		return
	# back in orbit, then look for the next alien
	global_position = global_position.lerp(home, 1.0 - exp(-(6.0 if returning else 10.0) * delta))
	if returning and global_position.distance_to(home) < 4.0:
		returning = false
	cd -= delta
	if cd <= 0.0 and not returning:
		cd = RAM_EVERY
		target = _pick()


func _pick() -> Enemy:
	var best: Enemy = null
	var best_d := REACH
	for n in Game.world.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		var d := e.global_position.distance_to(inf.player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _hit(e: Enemy) -> void:
	var dir := (e.global_position - global_position).normalized()
	e.take_damage(damage, dir)
	e.push(dir * 140.0)
	var w := Game.world
	w.burst(global_position, Infected.MAGENTA, 6, 70.0, 0.3, 2.0)
	w.burst(global_position, Color("a7f070"), 3, 50.0, 0.3, 2.0)
	Sfx.play("hit", 0.2, -8.0)
	target = null
	returning = true


## Burst and vanish (the mutation ended).
func pop() -> void:
	_pop()


func _pop() -> void:
	if is_queued_for_deletion():
		return
	var w := Game.world
	if w != null:
		w.burst(global_position, Infected.MAGENTA, 8, 60.0, 0.3, 2.0)
	queue_free()
