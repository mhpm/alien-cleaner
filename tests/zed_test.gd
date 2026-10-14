extends Node
## ZED (CharacterData "zed"): his animations load, BLAST draws his personal shotgun
## (ShotgunAbility): it shows in his hand, fires a fan of pellets that shove the aliens
## back, and goes back in his pocket after DURATION (the equipped weapon returns).
## In a window saves user://zed_test_<name>.png.

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
	get_viewport().get_texture().get_image().save_png("user://zed_test_%s.png" % name)


func _pellets() -> int:
	var n := 0
	for c in w.effects.get_children():
		if c is GunShot and (c as GunShot).push >= ShotgunAbility.PUSH:
			n += 1
	return n


func _run() -> void:
	Game.playground_active = true
	var keep := Game.character
	Game.character = "zed"
	Game.gun = "pulse"
	Game.new_run(0)
	w = (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	w.player.invuln = 99999.0
	w.survival.set_physics_process(false)
	for n in w.enemy_cache:
		if is_instance_valid(n):
			(n as Enemy).queue_free()
	var c := w.player.body.character
	_check(c != null and c.character_id == "zed" and c.display_name == "ZED", "the run plays ZED")
	for a in CharacterData.ANIMS + ["walk_shoot_up", "walk_shoot_down"]:
		_check(c.frames.has_animation(a), "ZED has the %s animation" % a)
	_check(w.player.ability is ShotgunAbility, "ZED's ability is the shotgun")
	w.camera.zoom = Vector2(3, 3)
	await _frames(5)
	await _shot("idle")
	# BLAST: the shotgun comes out
	w.player.blast_t = 0.0
	w.player.blast()
	_check(w.player.body.held == ShotgunAbility.gun_tex(), "BLAST puts the shotgun in his hand")
	_check(w.player.ability.overrides_fire(), "the shotgun fires instead of his weapon")
	var before := _pellets()
	w.player.ability.fire(w.player.global_position + Vector2(0, -60), Vector2.UP, null)
	_check(_pellets() - before == ShotgunAbility.PELLETS, "one blast = a fan of %d pellets" % ShotgunAbility.PELLETS)
	# an alien in front: pellets fly and shove it back
	var e := w.spawn_enemy("slime", w.room.open_near(w.player.global_position + Vector2(40, 0)), 1.0, 1.0, false, true)
	e.max_hp = 1e9
	e.hp = e.max_hp
	await _frames(25)
	var d0 := e.global_position.distance_to(w.player.global_position)
	var far := d0
	for i in 45:
		await get_tree().physics_frame
		if is_instance_valid(e):
			far = maxf(far, e.global_position.distance_to(w.player.global_position))
	await _shot("shotgun")
	_check(far > d0 + 10.0, "its pellets shove the alien back (%.0f -> %.0f)" % [d0, far])
	await _frames(int(ShotgunAbility.DURATION * 60.0))
	_check(w.player.body.held == null and not w.player.ability.overrides_fire(), "after %.0f s he puts it away" % ShotgunAbility.DURATION)
	# the recharge only starts once it is put away: COOLDOWN seconds without it
	_check(is_equal_approx(w.player.blast_cooldown(), ShotgunAbility.COOLDOWN), "the shotgun recharges in %.0f s" % ShotgunAbility.COOLDOWN)
	_check(w.player.blast_t > ShotgunAbility.COOLDOWN - 1.5, "right after putting it away the full recharge is still ahead (%.1f s)" % w.player.blast_t)
	await _frames(int((ShotgunAbility.COOLDOWN - 2.0) * 60.0))
	_check(w.player.blast_t > 0.0, "it is still recharging %.0f s later" % (ShotgunAbility.COOLDOWN - 2.0))
	# hitstops slow the game clock: wait for it (with a margin) instead of counting frames
	for k in 6 * 60:
		if is_zero_approx(w.player.blast_t):
			break
		await get_tree().physics_frame
	_check(is_zero_approx(w.player.blast_t), "about %.0f s after putting it away it is ready again (%.2f left)" % [ShotgunAbility.COOLDOWN, w.player.blast_t])
	Game.character = keep
	Game.playground_active = false
	if failures.is_empty():
		print("ZED TEST OK")
	else:
		print("ZED TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
