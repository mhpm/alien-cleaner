extends Node
## World 7 WARP NEXUS: the explore map from the w7 kit, 5 warp cells (each sets off an
## ambush, all = gate charged: boss weaker and no warp), the 4 new drones attacking and
## every move of the WARP OVERSEER. In a window it saves user://warp_test_<tag>.png:
##   Godot --path . res://tests/warp_nexus_test.tscn [-- --overview]

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


func _snap(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://warp_test_%s.png" % tag)


func _clear(w: GameWorld) -> void:
	for n in w.enemy_cache:
		if is_instance_valid(n) and not (n as Enemy).anchored:
			(n as Enemy).queue_free()
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		n.queue_free()


func _run() -> void:
	Game.playground_active = true
	Game.new_run(6)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(5)
	var ex := w.explore
	_check(ex != null and ex.forge != null and ex.forge.set_id == "w7", "World 7 builds its map from the w7 kit")
	if ex == null or ex.forge == null:
		_finish()
		return
	var f := ex.forge
	_check(f.reach(f.start_cell()).size() > 100, "a big walkable map")
	_check(w.room.is_open(ex.start), "the astronaut starts on open floor")
	_check(ex.warp_cells.size() == 5, "5 warp cells (got %d)" % ex.warp_cells.size())
	w.player.invuln = 99999.0
	w.survival.choosing = true
	w.survival.set_physics_process(false)
	await _frames(40)
	_clear(w)
	await _snap("start")
	if OS.get_cmdline_user_args().has("--overview"):
		await _overview(w)
	# take a warp cell: ambush
	var cell: WarpCell = ex.warp_cells[0]
	var cpos := cell.global_position
	print("WARP cells valid: ", ex.warp_cells.map(func(c: Variant) -> bool: return is_instance_valid(c)), " taken ", ex.cells_taken)
	w.player.global_position = cpos + Vector2(0, 40)
	await _frames(20)
	await _snap("cell")
	w.player.global_position = cpos
	await _frames(70)
	_check(ex.cells_taken == 1, "walking into a warp cell takes it")
	_check(w.enemy_cache.size() >= 3, "the warp ambush brings drones (%d)" % w.enemy_cache.size())
	await _snap("ambush")
	_clear(w)
	# the 4 new drones, each attacking
	var at := w.room.open_near(w.player.global_position)
	w.player.global_position = at
	for id: String in ["laser_drone", "spider_bot", "gravity_sentinel", "saw_drone"]:
		_clear(w)
		await _frames(2)
		var e := w.spawn_enemy(id, w.room.open_near(at + Vector2(70, -40)))
		if id == "gravity_sentinel":  # a crowd for it to clump and fling
			for i in 8:
				w.spawn_enemy("saw_drone", w.room.open_near(at + Vector2(randf_range(-40, 40), randf_range(-70, -30))))
		e.max_hp = 1e6  # the astronaut's auto-fire would clean it before we see its attack
		e.hp = e.max_hp
		e.state_t = 0.05
		var hp0 := float(Game.stats.hp)
		w.player.invuln = 0.0
		for i in 150:
			w.player.global_position = at
			if i == 45:
				await _snap(id + "_a")
			if i == 75:
				await _snap(id + "_b")
			await get_tree().physics_frame
		w.player.invuln = 99999.0
		print("WARP %s: state=%s hp lost %.0f" % [id, e.state if is_instance_valid(e) else "dead", hp0 - float(Game.stats.hp)])
		_check(is_instance_valid(e), id + " still alive after its attack")
		Game.stats.hp = Game.stats.max_hp
	_clear(w)
	# every cell: the gate charges
	for c in ex.warp_cells:
		if is_instance_valid(c) and not c.taken:
			c._take()
	await _frames(5)
	_check(ex.gate_charged(), "all warp cells = gate charged")
	_clear(w)
	# the boss, every move
	var b := w.spawn_enemy("overseer", w.room.open_near(at + Vector2(0, -110)), 1.0) as BossOverseer
	b.armor = 0.0  # untouchable while we watch
	await _frames(5)
	var raw: float = maxf(float(EnemyData.TYPES.overseer.hp) * Game.enemy_mult(), BossBase._player_dps() * BossBase.DPS_REALISM * BossBase.TARGET_SECS)
	_check(absf(b.max_hp - raw * Explore.GATE_HP) < raw * 0.05, "charged gate: the Overseer comes with -20%% HP (%.0f vs %.0f)" % [b.max_hp, raw])
	for move: String in ["volley", "cone", "summon", "warp"]:
		b.state = move
		_force(b, move)
		for i in 160:
			w.player.global_position = at
			if i == 40:
				await _snap("boss_" + move)
			await get_tree().physics_frame
	_check(b.state != "zip", "no warping once the gate is charged")
	# the warp itself (as if the gate were not charged)
	ex.cells_taken = 0
	b._next_move("warp")
	for i in 120:
		if i == 30:
			await _snap("boss_warp_zip")
		await get_tree().physics_frame
	_check(b.state in ["stun", "drift", "volley", "cone_wind"] or b.warping == false, "warp ends dizzy")
	b.hp = b.max_hp * 0.45
	await _frames(90)
	_check(b.furious, "OVERLOAD under half health")
	b._next_move("nova")
	for i in 120:
		if i == 50:
			await _snap("boss_nova")
		await get_tree().physics_frame
	b.hp = b.max_hp * 0.15
	b._next_move("cone")
	for i in 70:
		if i == 60:
			await _snap("boss_cones3")
		await get_tree().physics_frame
	_check(b.desperate, "CRITICAL under 20%")
	b.armor = 1.0
	b.take_damage(b.max_hp * 10.0)
	b.hp = 0.0
	b.die()
	await _frames(90)
	await _snap("boss_dead")
	_finish()


func _force(b: BossOverseer, move: String) -> void:
	b._next_move(move)


func _overview(w: GameWorld) -> void:
	var cam := w.camera
	var keep := cam.zoom
	var lim := [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	var sz := w.explore.forge.size()
	var v := get_viewport().get_visible_rect().size
	cam.limit_left = -10000
	cam.limit_top = -10000
	cam.limit_right = 10000
	cam.limit_bottom = 10000
	cam.position_smoothing_enabled = false
	cam.top_level = true
	cam.global_position = sz * 0.5
	cam.zoom = Vector2.ONE * minf(v.x / sz.x, v.y / sz.y)
	w.hud.visible = false
	await _frames(3)
	await _snap("map")
	cam.top_level = false
	cam.zoom = keep
	cam.limit_left = lim[0]
	cam.limit_top = lim[1]
	cam.limit_right = lim[2]
	cam.limit_bottom = lim[3]
	var f := w.explore.forge
	for i in mini(3, f.machines.size()):
		w.player.global_position = w.room.open_near(f.cell_rect(f.machines[i][0]).get_center() + Vector2(0, 90))
		await _frames(30)
		await _snap("corner_%d" % i)
	w.hud.visible = true


func _finish() -> void:
	Game.playground_active = false
	if failures.is_empty():
		print("WARP NEXUS TEST OK")
	else:
		print("WARP NEXUS TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
