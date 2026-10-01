extends Node
## Isolated combat regression checks. No coins/XP pickups or save writes.

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	w.process_mode = Node.PROCESS_MODE_DISABLED
	var boss := w.spawn_enemy("orbit_warden", w.player.position + Vector2(0, -100)) as OrbitRaider
	var raider := w.spawn_enemy("orbit_raider", w.player.position + Vector2(100, 0)) as OrbitRaider
	boss.spawn_t = 0.0
	boss.targetable = true
	raider.spawn_t = 0.0
	raider.targetable = true
	_check(boss.is_boss and not raider.is_boss, "Profiles must distinguish boss and horde")
	_check(boss.max_hp >= 2600.0 and raider.max_hp < 100.0, "Only boss receives DPS-sized health")
	for set_name: String in ["orbit_warden", "orbit_spawn", "orbit_plasma", "orbit_burst", "orbit_beam"]:
		_check(Art.has_set(set_name), "Missing sprite set " + set_name)
		var frames := Art.frames(set_name)
		for anim: String in frames.get_animation_names():
			for i in frames.get_frame_count(anim):
				_check(frames.get_frame_texture(anim, i) != null, "Missing texture " + set_name + "/" + anim)

	var hp_before := boss.hp
	boss.take_damage(boss.max_hp)
	_check(is_equal_approx(hp_before - boss.hp, boss.max_hp * BossBase.HIT_CAP), "Boss single-hit cap")
	hp_before = raider.hp
	raider.take_damage(10.0)
	_check(is_equal_approx(hp_before - raider.hp, 10.0), "Horde damage must remain uncapped")

	boss._begin_attack()
	boss._ai(1.0)
	boss._ai(0.016)
	raider._begin_attack()
	raider._ai(1.1)
	raider._ai(0.016)
	_check(boss.owned_shots.size() == 5 and raider.owned_shots.size() == 1, "Reduced volley: five versus one")
	raider.hp = raider.max_hp * 0.3
	raider._ai(0.016)
	raider._summon()
	_check(not raider.furious and raider.minions.is_empty(), "Horde cannot enrage or summon")
	for i in 5:
		boss._summon()
	_check(boss.minions.size() == OrbitRaider.MINION_CAP, "Summons must respect six-child limit")

	boss.attack_i = 1
	boss._begin_attack()
	raider.attack_i = 2
	raider._begin_attack()
	_check(boss.strikes.size() == 2 and raider.strikes.size() == 1, "Ground attacks: two versus one")
	var strike := raider.strikes[0]
	_check(strike.radius == 17.0 and strike.warning_time >= 1.3, "Horde strike needs smaller radius and long warning")
	var locked_target := strike.global_position
	w.player.global_position = locked_target + Vector2(150, 0)
	var player_hp := float(Game.stats.hp)
	strike._physics_process(strike.warning_time * 0.5)
	_check(not strike.fired, "Ground attack cannot damage during warning")
	strike._physics_process(strike.warning_time * 0.5 + 0.01)
	_check(strike.fired and strike.global_position == locked_target, "Ground target must remain fixed")
	_check(float(Game.stats.hp) == player_hp, "Escaping the ground marker avoids damage")

	var hit := OrbitStrike.new()
	hit.caster = boss
	hit.position = w.player.global_position
	hit.damage = 5.0
	w.effects.add_child(hit)
	w.player.set("hurt_t", 0.0)
	w.player.invuln = 0.0
	w.player.shield_hits = 0
	w.player.buffs.clear()
	hit._physics_process(hit.warning_time + 0.01)
	_check(float(Game.stats.hp) < player_hp, "Standing inside a strike must damage the player")
	player_hp = float(Game.stats.hp)
	w.player.invuln = 0.0
	hit._physics_process(0.01)
	_check(float(Game.stats.hp) == player_hp, "A ground strike only applies damage once")

	boss.hp = boss.max_hp * 0.4
	boss._ai(0.016)
	_check(boss.furious and boss.state == "roar", "Boss changes phase below half health")
	boss.attack_i = 1
	boss._begin_attack()
	_check(boss.strikes.size() == 5, "Enraged boss adds three ground targets")
	# Repeat attacks after owned nodes have been freed, as happens in a long fight.
	# A typed filter callback cannot safely accept those dangling references.
	var retained_shot := boss.owned_shots[2]
	boss.owned_shots[0].free()
	boss.owned_shots[1].free()
	boss._fire_volley()
	_check(boss.owned_shots.size() == 10 and boss.owned_shots.has(retained_shot), "Expired shots are removed before next volley, live shots retained")
	var retained_strike := boss.strikes[2]
	boss.strikes[0].free()
	boss.strikes[1].free()
	boss._strike(w.player.global_position)
	_check(boss.strikes.size() == 4 and boss.strikes.has(retained_strike), "Expired ground strikes are removed, live warnings retained")
	var retained_minion := boss.minions[2]
	boss.minions[0].free()
	boss.minions[1].dead = true
	boss.minions[1].remove_from_group("enemies")
	boss._summon()
	_check(boss.minions.size() == OrbitRaider.MINION_CAP and boss.minions.has(retained_minion), "Dead and freed minions make room for new summons")
	var pending_strike := boss.strikes[-1]
	var child := boss.minions[0]
	var shot := boss.owned_shots[0]
	boss.die()
	_check(pending_strike.is_queued_for_deletion() and child.is_queued_for_deletion() and shot.is_queued_for_deletion(), "Death cleans owned attacks and summons")
	raider.die()
	_check(w.decals.get_child_count() > 0, "Death leaves animated remains")
	await get_tree().process_frame
	w.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("ORBIT_WARDEN_TEST: PASS (profiles, sprites, damage, volleys, summons, warnings, phase, freed-node cleanup, death cleanup)")
	else:
		print("ORBIT_WARDEN_TEST: FAIL ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
