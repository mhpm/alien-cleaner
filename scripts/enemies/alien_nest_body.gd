class_name AlienNestBody
extends Enemy
## The living part of an arena AlienNest: a big hive egg that throbs and, while the
## astronaut is within `wake_range`, births an alien from its list every `interval`
## (never more than `max_children` of its own alive). Shoot it down to stop it.
## Configured by the AlienNest marker that created it.

signal destroyed

var entries: Array = []  # SpawnEntry
var interval := 4.0
var max_children := 4
var spawn_radius := 40.0
var wake_range := 220.0
var service: ArenaSpawnService
var _children := 0
var _birth_t := 1.5
var _rng := RandomNumberGenerator.new()


func _init_ai() -> void:
	state = "idle"
	knock = Vector2.ZERO
	_rng.randomize()


func _ai(delta: float) -> Vector2:
	var near := player().global_position.distance_to(global_position) < wake_range
	var hurry := 1.0 - hp / max_hp  # throbs faster as it is hurt
	sprite.speed_scale = 1.0 + hurry * 3.0 + (1.0 if near else 0.0)
	squash = Vector2(1.0 + sin(t * (4.0 + hurry * 10.0)) * 0.05, 1.0 - sin(t * (4.0 + hurry * 10.0)) * 0.04)
	if randf() < delta * (2.0 + hurry * 6.0):
		Game.world.burst(hit_center() + Vector2(randf_range(-8, 8), 0), Color("c75bd6"), 1, 18.0, 0.5, 1.5, -30.0)
	if not near or service == null or entries.is_empty():
		return Vector2.ZERO
	_birth_t -= delta
	if _birth_t <= 0.0 and _children < max_children:
		_birth_t = interval * (1.0 - hurry * 0.4)
		_birth()
	return Vector2.ZERO


func _birth() -> void:
	var entry := SpawnEntry.pick(entries, _rng)
	if entry == null:
		return
	_children += 1
	var at := global_position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(spawn_radius * 0.4, spawn_radius)
	squash = Vector2(1.3, 0.75)
	Game.world.burst(hit_center(), Color("c75bd6"), 10, 70.0, 0.4, 2.0)
	Sfx.play("pop", 0.2, -6.0)
	service.spawn(entry.enemy_id, at, _rng.randf() < entry.elite_chance, false, func(e: Enemy) -> void:
		e.tree_exiting.connect(func() -> void: _children -= 1, CONNECT_ONE_SHOT))


func _on_death() -> void:
	var w := Game.world
	w.explosion(global_position + Vector2(0, -6), 34.0, 40.0, 0.0)
	w.burst(hit_center(), Color("c75bd6"), 30, 120.0, 0.6, 2.5)
	w.add_puddle(global_position, 18.0)
	destroyed.emit()
