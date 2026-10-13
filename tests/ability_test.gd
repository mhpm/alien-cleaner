extends Node
## Character abilities (CharacterData.ability -> CharacterAbility):
## - the girl's HEART SHOT: every EVERY shots a heart charms the alien it hits (Charm):
##   not a target, never touches her, bites other aliens, ends after CHARM_TIME; bosses
##   are only slowed; at most Charm.MAX_ACTIVE charmed at once;
## - the kid's HOLO DECOY: BLAST leaves a HoloDecoy that lures the aliens around it and
##   bursts when it fades, hurting them;
## - changing character rebuilds the Player's ability.
## In a window saves user://ability_test_heart.png and _decoy.png.

var failures: Array[String] = []
var w: GameWorld


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, m: String) -> void:
	if not ok:
		failures.append(m)
		push_error(m)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://ability_test_%s.png" % name)


func _alien(offset: Vector2, hp := 1e6) -> Enemy:
	var e := w.spawn_enemy("slime", w.room.open_near(w.player.global_position + offset), 1.0, 1.0, false, true)
	e.max_hp = hp
	e.hp = hp
	return e


func _clear() -> void:
	for n in w.enemy_cache:
		if is_instance_valid(n):
			(n as Enemy).queue_free()


func _run() -> void:
	Game.playground_active = true
	var keep := Game.character
	Game.character = "girl"
	Game.new_run(0)
	w = (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	w.player.invuln = 99999.0
	w.player.locked = true  # no weapon fire: only what the test throws
	w.survival.set_physics_process(false)
	_clear()
	w.camera.zoom = Vector2(3, 3)
	await _frames(3)
	await _girl()
	await _kid()
	Game.character = keep
	Game.playground_active = false
	if failures.is_empty():
		print("ABILITY TEST OK")
	else:
		print("ABILITY TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func _girl() -> void:
	var ab := w.player.ability
	_check(ab is HeartShotAbility, "the girl has the Heart Shot")
	if not ab is HeartShotAbility:
		return
	var a := _alien(Vector2(45, 0))
	var b := _alien(Vector2(45, 55))
	await _frames(25)  # spawn-in done: targetable
	var origin := w.player.global_position + Vector2(0, Player.BODY_Y)
	for i in HeartShotAbility.EVERY - 1:
		ab.on_fire(origin, Vector2.RIGHT, a)
	_check(_hearts() == 0, "no heart before the %dth shot" % HeartShotAbility.EVERY)
	ab.on_fire(origin, Vector2.RIGHT, a)
	_check(_hearts() == 1, "the %dth shot throws a heart" % HeartShotAbility.EVERY)
	for i in 40:
		await get_tree().physics_frame
		if a.charm != null:
			break
	_check(a.charm != null, "the heart charms the alien it hits")
	_check(not a.targetable, "a charmed alien is not a target")
	var b0 := b.hp
	await _frames(90)
	await _shot("heart")
	_check(b.hp < b0, "the charmed alien bites the other one (%.0f -> %.0f)" % [b0, b.hp])
	# its victim dies (freed) mid-hunt: the charmed alien just looks for another one
	b.die()
	await _frames(40)
	_check(a.charm != null and a.charm.target == null, "a dead victim is dropped, the charm goes on")
	# a victim removed without dying (horde wipe, leash: queue_free) mid-bite too
	var c := _alien(Vector2(45, 40))
	await _frames(25)
	a.charm.target = c
	c.queue_free()
	await _frames(20)
	_check(a.charm != null and a.charm.target == null, "a removed victim is dropped, the charm goes on")
	await _frames(int(HeartShotAbility.CHARM_TIME * 60.0))
	_check(a.charm == null and a.targetable, "the charm wears off after %.0f s" % HeartShotAbility.CHARM_TIME)
	# a charmed alien dies mid-burst: its hearts go with it, nothing points at them
	var doomed := _alien(Vector2(-45, 0))
	await _frames(25)
	_check(Charm.apply(doomed, 3.0), "the doomed alien is charmed")
	doomed.die()
	await _frames(70)
	# at most MAX_ACTIVE charmed at once
	_clear()
	await _frames(3)
	var many: Array[Enemy] = []
	for i in Charm.MAX_ACTIVE + 1:
		many.append(_alien(Vector2(-60 + i * 30, -70)))
	await _frames(25)
	var ok := 0
	for e in many:
		if Charm.apply(e, 3.0):
			ok += 1
	_check(ok == Charm.MAX_ACTIVE, "only %d charmed at once (%d)" % [Charm.MAX_ACTIVE, ok])
	# bosses are slowed, never charmed
	var boss := many[0]
	boss.charm.end()
	boss.is_boss = true
	_check(not Charm.apply(boss, 3.0) and boss.charm == null and boss.slow_t > 0.0, "a boss is only slowed")
	boss.is_boss = false
	_clear()
	await _frames(3)


func _hearts() -> int:
	var n := 0
	for c in w.effects.get_children():
		if c is HeartShot:
			n += 1
	return n


func _kid() -> void:
	w.player.body.set_character(CharacterData.load_id("kid_astronaut"))
	await _frames(2)
	_check(w.player.ability is DecoyAbility, "switching to the kid rebuilds the ability (Holo Decoy)")
	if not w.player.ability is DecoyAbility:
		return
	var crowd: Array[Enemy] = []
	for i in 6:
		crowd.append(_alien(Vector2.from_angle(TAU * i / 6.0) * 110.0, 500.0))
	await _frames(25)
	w.player.blast_t = 0.0
	w.player.locked = false  # BLAST needs a free astronaut (locked again: no weapon fire)
	w.player.blast()
	w.player.locked = true
	var decoy := (w.player.ability as DecoyAbility).decoy
	_check(decoy != null and is_instance_valid(decoy), "BLAST leaves a decoy")
	w.player.global_position += Vector2(0, 70)  # walk away: they stay on the decoy
	await _frames(30)
	var lured := 0
	for e in crowd:
		if decoy != null and is_instance_valid(e) and e.lure == decoy:
			lured += 1
	_check(lured >= 5, "the aliens around go for the decoy (%d/6)" % lured)
	await _frames(60)
	await _shot("decoy")
	await _frames(int(HoloDecoy.LIFE * 60.0))
	_check(not is_instance_valid(decoy) or decoy.is_resolved(), "the decoy bursts when it fades")
	var hurt := 0
	for e in crowd:
		if not is_instance_valid(e) or e.hp < e.max_hp:
			hurt += 1
	_check(hurt >= 3, "its burst hurts the aliens on it (%d/6)" % hurt)
