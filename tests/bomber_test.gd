extends Node
## Bomber Drone (UpgradeData "bomber"): kit card; bombs the biggest crowd, CLUSTER bomblets
## (2), CARPET RUN (3), proximity MINES (4), MEGA bomb (5). Window: user://bomber_test_*.png.

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
	get_viewport().get_texture().get_image().save_png("user://bomber_test_%s.png" % tag)


func _bombs() -> Array[BomberBomb]:
	var out: Array[BomberBomb] = []
	for c in Game.world.effects.get_children():
		if c is BomberBomb:
			out.append(c)
	return out


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	w.player.invuln = 99999.0
	w.survival.set_physics_process(false)
	_check(UpgradeData.ACTIVE.has("bomber") and UpgradeData.is_kit("bomber"), "Bomber Drone offered with its kit card")
	var ids: Array[String] = ["bomber", "hunter", "magnet"]
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
	Game.stats.fire_interval = 9999.0
	var at := w.player.global_position
	var crowd_at := w.room.open_near(at + Vector2(80, -70))
	var crowd: Array[Enemy] = []
	for i in 8:
		var e := w.spawn_enemy("slime", w.room.open_near(crowd_at + Vector2.from_angle(TAU * i / 8.0) * 16.0), 1.0, 1.0, false, true)
		e.max_hp = 1e9
		e.hp = e.max_hp
		e.speed = 0.0
		crowd.append(e)
	var lone := w.spawn_enemy("slime", w.room.open_near(at + Vector2(-100, 30)), 1.0, 1.0, false, true)
	lone.max_hp = 1e9
	lone.hp = lone.max_hp
	lone.speed = 0.0
	await _frames(30)
	for lv in range(1, 6):
		Game.take_upgrade("bomber")
		w.player.refresh_upgrades()
		var b := w.player.bomber
		_check(b != null and b.lv == lv, "the drone is out at level %d" % lv)
		b.cd = 0.1
		b.drops = 0
		var hp0: Array[float] = []
		for e in crowd:
			hp0.append(e.hp)
		var lone0 := lone.hp
		var small := false
		var ran := false
		var mined := false
		var mega := false
		var far := INF
		for i in 600:
			w.player.global_position = at
			far = minf(far, b.global_position.distance_to(at))
			if b.state == "run":
				ran = true
				if i % 20 == 0 and lv == 3:
					await _snap("carpet")
			for bb in _bombs():
				if bb.size < 7.0:
					small = true
				if bb.landed:
					mined = true
				if bb.mega:
					mega = true
			if lv == 5 and mega and i % 6 == 0:
				for c in w.effects.get_children():
					if c is BombBlast and (c as BombBlast).last == 7 and (c as BombBlast).t > 0.15:
						await _snap("mega")
						break
			if lv == 1 and i == 60:
				await _snap("drop")
			await get_tree().physics_frame
		var hit := 0
		for k in crowd.size():
			if crowd[k].hp < hp0[k]:
				hit += 1
		print("BOMBER lv%d drops %d crowd hit %d/8 lone hurt %s cluster %s run %s mine %s mega %s closest %.0f" % [lv, b.drops, hit, lone.hp < lone0, small, ran, mined, mega, far])
		_check(hit >= 6, "level %d bombs the crowd (%d/8)" % [lv, hit])
		_check(small == (lv >= 2), "CLUSTER bomblets from level 2 (lv %d: %s)" % [lv, small])
		_check(ran == (lv >= 3), "CARPET RUN from level 3 (lv %d: %s)" % [lv, ran])
		_check(mega == (lv >= 5), "MEGA bomb at level 5 (lv %d: %s)" % [lv, mega])
		_check(far > 20.0 or ran, "level %d keeps clear of the astronaut (%.0f)" % [lv, far])
	# level 4+: a bomb with nobody close stays as a mine, and an alien walking in sets it off
	var bd := w.player.bomber
	for n in w.enemy_cache:
		if is_instance_valid(n):
			(n as Enemy).queue_free()
	await _frames(3)
	var spot := w.room.open_near(at + Vector2(0, 80))
	bd._bomb(bd._data(), spot, 0.4, 20.0, false)
	await _frames(40)
	var mines := _bombs().filter(func(x: BomberBomb) -> bool: return x.landed)
	_check(mines.size() >= 1, "a bomb with no alien close stays as a MINE")
	var walker := w.spawn_enemy("slime", spot + Vector2(40, 0), 1.0, 1.0, false, true)
	walker.max_hp = 1e9
	walker.hp = walker.max_hp
	await _frames(30)
	var wh := walker.hp
	walker.global_position = spot + Vector2(4, 0)
	await _frames(20)
	_check(walker.hp < wh, "an alien stepping on the mine sets it off")
	Game.playground_active = false
	print("BOMBER TEST OK" if failures.is_empty() else "BOMBER TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
