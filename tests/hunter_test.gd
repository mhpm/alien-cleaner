extends Node
## Hunter Drone (UpgradeData "hunter"): offered with its kit card; it keeps throwing
## boomerang blades that loop out and back cutting aliens, more blades per level, PINWHEEL
## at 4, the drone throws itself (WHIRLWIND) at 5. In a window saves user://hunter_test_*.png.

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
	get_viewport().get_texture().get_image().save_png("user://hunter_test_%s.png" % tag)


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	w.player.invuln = 99999.0
	w.survival.set_physics_process(false)
	_check(UpgradeData.ACTIVE.has("hunter") and UpgradeData.is_kit("hunter"), "Hunter Drone offered with its kit card")
	var ids: Array[String] = ["hunter", "magnet", "rapid"]
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
	Game.stats.fire_interval = 9999.0  # only the drone hurts
	var at := w.player.global_position
	var foes: Array[Enemy] = []
	for i in 10:
		var e := w.spawn_enemy("slime", w.room.open_near(at + Vector2.from_angle(TAU * i / 10.0) * (50.0 + 15.0 * (i % 3))), 1.0, 1.0, false, true)
		e.max_hp = 1e9
		e.hp = e.max_hp
		e.speed = 0.0
		foes.append(e)
	await _frames(30)
	for lv in range(1, 6):
		Game.take_upgrade("hunter")
		w.player.refresh_upgrades()
		var h := w.player.hunter
		_check(h != null and h.lv == lv, "the drone is out at level %d" % lv)
		var hp0: Array[float] = []
		for e in foes:
			hp0.append(e.hp)
		var most := 0
		var catches := 0
		var was := 0
		var pin := false
		var whirl := false
		var t0 := h.throws
		var quads := {}
		for i in 420:
			w.player.global_position = at
			most = maxi(most, h.out.size())
			if h.out.size() < was:
				catches += was - h.out.size()
			was = h.out.size()
			for b in h.out:
				if is_instance_valid(b) and b.ring_time > 0.0 and b.t < b.ring_time:
					pin = true
					if i % 30 == 0 and lv == 4:
						await _snap("pinwheel")
			if not h.self_out:
				var rel := h.global_position - at
				quads[int(floor((rel.angle() + PI) / (PI * 0.5))) % 4] = true
			if h.self_out:
				whirl = true
				if i % 40 == 0:
					await _snap("whirl")
			if lv == 2 and i == 60:
				await _snap("blades")
			await get_tree().physics_frame
		var hit := 0
		for k in foes.size():
			if foes[k].hp < hp0[k]:
				hit += 1
		print("HUNTER lv%d throws %d most out %d caught %d pinwheel %s whirl %s hit %d/10" % [lv, h.throws - t0, most, catches, pin, whirl, hit])
		_check(quads.size() == 4, "level %d: the drone circles the astronaut (%d quarters)" % [lv, quads.size()])
		var want := 1 if lv == 1 else (2 if lv == 2 else 3)
		_check(most >= want, "level %d throws %d+ blades at once (%d)" % [lv, want, most])
		_check(h.throws - t0 >= 3 and catches >= 3, "level %d keeps throwing and catching (%d throws)" % [lv, h.throws - t0])
		_check(pin == (lv >= 4), "PINWHEEL from level 4 (lv %d: %s)" % [lv, pin])
		_check(whirl == (lv >= 5), "WHIRLWIND at level 5 (lv %d: %s)" % [lv, whirl])
		_check(hit >= (1 if lv == 1 else 3), "level %d cuts several aliens (%d)" % [lv, hit])
	Game.playground_active = false
	print("HUNTER TEST OK" if failures.is_empty() else "HUNTER TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
