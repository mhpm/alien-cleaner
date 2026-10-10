extends Node
## Scrub-Bots (UpgradeData "orbiters" = the ScrubBot drone): offered with its kit card; the
## drone hovers by the astronaut, its pods hit different aliens (level 2+), orbs pop in
## blasts (3+), SPIN SCRUB sprays a spiral (4+). In a window saves user://scrub_test_*.png.

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, m: String) -> void:
	if not ok:
		failures.append(m)
		push_error(m)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _snap(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://scrub_test_%s.png" % tag)


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	w.player.invuln = 99999.0
	w.survival.set_physics_process(false)
	_check(UpgradeData.ACTIVE.has("orbiters") and UpgradeData.is_kit("orbiters"), "Scrub-Bots offered with its kit card")
	_check(UpgradeData.icon("orbiters") != null and UpgradeData.level_tex("orbiters", 5) != null, "kit art scrub*.png loads")
	var ids: Array[String] = ["orbiters", "rapid", "martian"]
	w.hud.show_upgrades(ids)
	for i in 50:
		await get_tree().process_frame
	await _snap("card")
	w.hud._close_overlay()
	get_tree().paused = false
	for n in w.enemy_cache:
		if is_instance_valid(n):
			(n as Enemy).queue_free()
	await _frames(3)
	Game.stats.fire_interval = 9999.0  # the astronaut does not shoot: only the drone
	var at := w.player.global_position
	var dummies: Array[Enemy] = []
	for i in 4:
		var e := w.spawn_enemy("slime", w.room.open_near(at + Vector2.from_angle(-PI * 0.5 + (i - 1.5) * 0.7) * 80.0), 1.0, 1.0, false, true)
		e.max_hp = 1e9
		e.hp = e.max_hp
		e.speed = 0.0
		dummies.append(e)
	await _frames(30)
	for lv in range(1, 6):
		Game.take_upgrade("orbiters")
		w.player.refresh_upgrades()
		var bot := w.player.scrub
		_check(bot != null and bot.lv == lv, "the drone is out at level %d" % lv)
		var hp0: Array[float] = []
		for e in dummies:
			hp0.append(e.hp)
		var spun := false
		for i in 360:
			w.player.global_position = at
			for e in dummies:
				e.global_position = e.global_position  # stay put
			if bot.spin_t > 0.0:
				spun = true
				if lv == 5 and i % 10 == 0:
					await _snap("spin")
			await get_tree().physics_frame
		var hit := 0
		for k in dummies.size():
			if dummies[k].hp < hp0[k]:
				hit += 1
		print("SCRUB lv%d aliens hit %d spun %s dist %.0f" % [lv, hit, spun, bot.global_position.distance_to(w.player.global_position)])
		_check(bot.global_position.distance_to(w.player.global_position) < 50.0, "the drone hovers by the astronaut")
		var want := 1 if lv == 1 else (2 if lv == 2 else 3)
		_check(hit >= want, "level %d hits %d+ different aliens (%d)" % [lv, want, hit])
		_check(spun == (lv >= 4), "SPIN SCRUB from level 4 only (lv %d spun %s)" % [lv, spun])
		if lv == 1:
			await _snap("lv1")
	Game.playground_active = false
	if failures.is_empty():
		print("SCRUB TEST OK")
	else:
		print("SCRUB TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
