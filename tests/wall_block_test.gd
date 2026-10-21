extends Node
## No enemy attack goes through a wall: on world 8's map (walls of the w8 kit that stop
## bullets) the astronaut stands just south of a wall run and the attacks come from just
## north of it - damage from behind the wall does nothing (Player.take_damage), shots pop
## on it, aiming lanes, lobbed goo and the plant's tongue stop at it (GameWorld.wall_cut)
## and casters that need to see you (Enemy.sees_player) do not. Control: the same hit in
## the open does hurt.
##   Godot --headless --path . res://tests/wall_block_test.tscn

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A wall run that stops bullets with open floor right in front of it (the astronaut)
## and right behind it (the attacker): [attacker, astronaut], or [] if none.
func _wall_pair(w: GameWorld) -> Array:
	for o in w.explore.director.objects_of("ArenaScenery"):
		var s := o as ArenaScenery
		if not s.blocks_bullets or s.footprint.x < 60.0:
			continue
		var at := s.global_position
		var you := at + Vector2(0, 14)
		var them := at + Vector2(0, -s.footprint.y - 14)
		if w.room.is_open(you, 7.0) and w.room.is_open(them, 7.0) and w.wall_between(them, you):
			return [them, you]
	return []


func _hp() -> float:
	return float(Game.stats.hp)


func _run() -> void:
	Game.playground_active = true
	Game.new_run(7)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(10)
	w.survival.choosing = true
	w.survival.set_physics_process(false)
	var pair := _wall_pair(w)
	_check(not pair.is_empty(), "a wall with floor on both sides")
	if pair.is_empty():
		_finish()
		return
	var them: Vector2 = pair[0]
	var you: Vector2 = pair[1]
	var p := w.player
	p.global_position = you
	p.velocity = Vector2.ZERO
	p.shield_hits = 0
	await _frames(3)
	# damage from behind the wall does nothing, the same hit in the open does
	p.invuln = 0.0
	var hp := _hp()
	p.take_damage(10.0, them)
	_check(is_equal_approx(_hp(), hp), "a hit from behind the wall does no harm")
	p.take_damage(10.0, you + Vector2(12, 0))
	_check(_hp() < hp, "the same hit in the open hurts (%.1f -> %.1f)" % [hp, _hp()])
	# a shot fired at the astronaut pops on the wall
	p.invuln = 0.0
	hp = _hp()
	var shot := w.spawn_enemy_shot(them, (you - them).normalized() * 160.0, 10.0, "droid")
	await _frames(45)
	_check(not is_instance_valid(shot), "the shot popped on the wall")
	_check(is_equal_approx(_hp(), hp), "the shot never reached the astronaut")
	# the aiming lane stops at the wall
	var before := w.decals.get_child_count()
	w.telegraph_line(them, (you - them).normalized(), 150.0, 10.0, 0.5)
	var lane := w.decals.get_child(w.decals.get_child_count() - 1) as Telegraph
	_check(w.decals.get_child_count() == before + 1 and lane.length < them.distance_to(you), "the aiming lane stops at the wall (%.0f)" % lane.length)
	# lobbed goo splats against the wall instead of landing on the astronaut
	var glob := GooGlob.new()
	glob.from = them
	glob.to = you
	w.effects.add_child(glob)
	_check(glob.to.distance_to(them) < you.distance_to(them) - 4.0, "lobbed goo lands on the wall, not beyond it")
	glob.queue_free()
	# the plant's tongue stops at the wall
	var tongue := PlantTongue.new()
	tongue.position = them
	tongue.dir = (you - them).normalized()
	tongue.length = 62.0
	w.effects.add_child(tongue)
	_check(tongue.length < them.distance_to(you), "the tongue stops at the wall (%.0f)" % tongue.length)
	# casters that need to see you do not see through the wall
	var e := w.spawn_enemy("octo_wizard", them)
	await _frames(2)
	e.global_position = them
	_check(not e.sees_player(), "an alien behind the wall does not see the astronaut")
	e.global_position = you + Vector2(0, 30)
	_check(e.sees_player() or w.wall_between(e.global_position, you), "an alien in the open sees the astronaut")
	_finish()


func _finish() -> void:
	Game.playground_active = false
	if failures.is_empty():
		print("WALL BLOCK TEST OK")
	else:
		print("WALL BLOCK TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
