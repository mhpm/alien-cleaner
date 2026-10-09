extends Node
## World 5 THE FORGE: the explore maze of "w5" rooms with its kit, 4 reactor cores (heat
## waves hurt, venting heals and counts, all vented = bosses weaker), the 3 new aliens and
## the MAGMA DRAKE as final boss. Saves screenshots to user://forge_test_*.png when run in
## a window (Godot --path . res://tests/forge_test.tscn).

var failures: Array[String] = []
var shot := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## The whole map in one picture (user://forge_test_map.png): camera zoomed out.
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
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://forge_test_map.png")
	# close-ups of a few corner blocks of machinery
	cam.top_level = false
	cam.zoom = keep
	cam.limit_left = lim[0]
	cam.limit_top = lim[1]
	cam.limit_right = lim[2]
	cam.limit_bottom = lim[3]
	var f := w.explore.forge
	for i in mini(4, f.machines.size()):
		w.player.global_position = w.room.open_near(f.cell_rect(f.machines[i][0]).get_center() + Vector2(0, 90))
		await _frames(30)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://forge_test_corner_%d.png" % i)
	cam.top_level = false
	cam.zoom = keep
	w.hud.visible = true


func _walkable(f: ForgeMap) -> int:
	var n := 0
	for b in f.blocked:
		if b == 0:
			n += 1
	return n


func _snap() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://forge_test_%d.png" % shot)
	shot += 1


func _run() -> void:
	Game.playground_active = true
	Game.new_run(4)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(5)
	var ex := w.explore
	_check(ex != null, "World 5 builds its Explore layer")
	if ex == null:
		_finish()
		return
	_check(ex.forge != null and ex.interior == "w5", "w5 map built from the forge kit")
	_check(ex.rooms.size() >= 10, "halls, corridors and mazes (got %d areas)" % ex.rooms.size())
	_check(ex.forge.reach(ex.forge.start_cell()).size() == _walkable(ex.forge), "every cell reachable from the start")
	_check(w.room.is_open(ex.start), "the astronaut starts on open floor")
	_check(ex.cores.size() == 4, "4 reactor cores (got %d)" % ex.cores.size())
	_check(ex.chests.size() == 8, "8 chests")
	_check(ex.survivors.size() > 0, "crew to rescue")
	w.player.invuln = 99999.0
	await _frames(90)
	await _snap()
	if OS.has_feature("overview") or OS.get_cmdline_user_args().has("--overview"):
		await _overview(w)
	# a heat wave: the astronaut next to a core gets burnt (no invulnerability for this)
	var core: ReactorCore = ex.cores[0]
	w.player.invuln = 0.0
	core.erupt_t = 0.05
	var hp0 := float(Game.stats.hp)
	for i in int(ReactorCore.WARN * 60.0) + 30:  # stand in the ring until it bursts
		w.player.global_position = core.global_position + Vector2(40, 10)
		if i == 20:
			await _snap()
		await get_tree().physics_frame
	_check(float(Game.stats.hp) < hp0, "Heat wave burns the astronaut")
	# vent it: hold position on the coolant pad
	w.player.invuln = 99999.0
	for i in int(ReactorCore.VENT_TIME * 60.0) + 30:
		w.player.global_position = core.global_position + ReactorCore.PAD
		await get_tree().physics_frame
	_check(core.cooled and ex.vented == 1, "Core vents after %.0f s" % ReactorCore.VENT_TIME)
	await _snap()
	# vent the rest: the forge cools and the boss comes weaker
	for c in ex.cores:
		if not c.cooled:
			c._vent()
	_check(ex.forge_cooled(), "All cores vented = forge cooled")
	# the new aliens
	for id: String in ["orbit_spawn", "orbit_raider", "eye_blob", "eye_blob"]:
		var e := w.spawn_enemy(id, w.room.open_near(w.player.global_position + Vector2(randf_range(-110, 110), randf_range(-90, 90))))
		_check(e != null, "spawns " + id)
	# a horde running through the halls and mazes: nobody ends up inside a wall
	for i in 60:
		w.spawn_enemy("orbit_spawn", w.room.open_near(w.player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(120, 420)))
	await _frames(150)
	await _snap()
	await _frames(40)
	await _snap()
	var inside := 0
	for n in w.enemy_cache:
		if is_instance_valid(n) and not (n as Enemy).dead and not w.room.is_open((n as Node2D).global_position, -4.0):
			inside += 1
			var e := n as Enemy
			for r in w.room.blockers:
				if r.grow(-4.0).has_point(e.global_position):
					print("INSIDE ", e.def.get("name"), " at ", e.global_position, " rect ", r, " air=", e.air, " boss=", e.is_boss)
	_check(inside == 0, "no alien inside the forge walls (%d)" % inside)
	# the final boss with the cooled-forge discount
	var hp_mult := w.survival._boss_hp_mult()
	var b := w.spawn_enemy("magma_drake", w.room.open_near(w.player.global_position + Vector2(0, -100)), hp_mult)
	await _frames(5)
	var raw: float = maxf(float(EnemyData.TYPES.magma_drake.hp) * Game.enemy_mult() * hp_mult, BossBase._player_dps() * BossBase.DPS_REALISM * BossBase.TARGET_SECS)
	_check(absf(b.max_hp - raw * Explore.COOLED_HP) < raw * 0.05, "Magma Drake final boss: full fight, -25%% HP (%.0f vs %.0f)" % [b.max_hp, raw])
	await _frames(120)
	await _snap()
	_finish()


func _finish() -> void:
	Game.playground_active = false
	if failures.is_empty():
		print("FORGE TEST OK")
	else:
		print("FORGE TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
