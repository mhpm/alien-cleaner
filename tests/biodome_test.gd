extends Node
## World 8 BIODOME: the explore map from the w8 kit (loose floor tiles, only top corner
## blocks) and its 5 SEED TANKS (aliens nearby march on them, gnaw them, a lost tank
## counts, the standing ones heal you when the final fight starts). In a window it saves
## user://bio_test_<tag>.png:
##   Godot --path . res://tests/biodome_test.tscn [-- --overview]

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
		img.save_png("user://bio_test_%s.png" % tag)


func _walkable(f: ForgeMap) -> int:
	var n := 0
	for b in f.blocked:
		if b == 0:
			n += 1
	return n


func _run() -> void:
	Game.playground_active = true
	Game.new_run(7)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(5)
	var ex := w.explore
	_check(ex != null and ex.forge != null and ex.forge.set_id == "w8", "World 8 builds its map from the w8 kit")
	if ex == null or ex.forge == null:
		_finish()
		return
	var f := ex.forge
	_check(f.reach(f.start_cell()).size() == _walkable(f), "every cell reachable from the start")
	_check(w.room.is_open(ex.start), "the astronaut starts on open floor")
	_check(ex.tanks.size() == 5, "5 seed tanks (got %d)" % ex.tanks.size())
	var bottom := 0
	for m: Array in f.machines:
		if str(m[1])[0] == "b":
			bottom += 1
	_check(f.machines.size() > 0 and bottom == 0, "only top corner blocks (the kit has no bottom ones)")
	w.player.invuln = 99999.0
	w.survival.choosing = true
	w.survival.set_physics_process(false)
	await _frames(40)
	await _snap("start")
	if OS.get_cmdline_user_args().has("--overview"):
		await _overview(w)
	# aliens near a tank march on it and gnaw it
	var tank: SeedTank = ex.tanks[0]
	var tp := tank.global_position
	w.player.global_position = w.room.open_near(tp + Vector2(0, 260))
	for i in 6:
		var e := w.spawn_enemy("saw_drone", w.room.open_near(tp + Vector2.from_angle(TAU * i / 6.0) * 120.0))
		e.max_hp = 1e6
		e.hp = e.max_hp
	await _frames(240)
	var lured := 0
	for n in w.enemy_cache:
		if is_instance_valid(n) and (n as Enemy).lure == tank:
			lured += 1
	_check(lured > 0, "aliens near a seed tank march on it (%d)" % lured)
	_check(tank.hp < 100.0, "the gnawing aliens hurt the tank (%.0f%%)" % tank.hp)
	w.player.global_position = w.room.open_near(tp + Vector2(0, 90))
	await _frames(20)
	await _snap("tank")
	tank.hp = 0.5
	await _frames(40)
	_check(tank.lost and ex.tanks_lost == 1, "a tank at 0 is lost: TANKS 4/5")
	await _snap("tank_lost")
	for n in w.enemy_cache:
		if is_instance_valid(n):
			(n as Enemy).queue_free()
	await _enemies(w, ex)
	# the final fight: the standing tanks heal
	Game.stats.hp = Game.stats.max_hp * 0.3
	var hp0 := float(Game.stats.hp)
	w.survival._send_final()
	await _frames(30)
	_check(float(Game.stats.hp) > hp0, "the 4 standing tanks heal the astronaut at the final fight")
	await _snap("final")
	await _boss(w)
	_finish()


## The 4 new aliens attacking (no auto-fire damage while we watch), and the Bio Droid
## heading for a seed tank.
func _enemies(w: GameWorld, ex: Explore) -> void:
	var dmg0: float = Game.stats.damage
	Game.stats.damage = 0.0
	var at := w.room.open_near(w.player.global_position)
	for id: String in ["bio_droid", "spike_bloom", "vine_crawler", "spore_drone"]:
		for n in w.enemy_cache:
			if is_instance_valid(n):
				(n as Enemy).queue_free()
		await _frames(2)
		var e := w.spawn_enemy(id, w.room.open_near(at + Vector2(60, -40)))
		e.max_hp = 1e6
		e.hp = e.max_hp
		e.state_t = 0.05
		var hp0 := float(Game.stats.hp)
		w.player.invuln = 0.0
		for i in 200:
			w.player.global_position = at
			if is_instance_valid(e):
				e.lure = null  # a seed tank close by would draw it away: we test its attack
			if i == 40:
				await _snap(id + "_a")
			if i == 90:
				await _snap(id + "_b")
			await get_tree().physics_frame
		w.player.invuln = 99999.0
		print("BIO %s: state=%s hp lost %.0f shots %d dist %.0f" % [id, e.state if is_instance_valid(e) else "dead", hp0 - float(Game.stats.hp), get_tree().get_nodes_in_group("enemy_shots").size(), e.global_position.distance_to(w.player.global_position) if is_instance_valid(e) else -1.0])
		var busy := id == "bio_droid" and e.lure != null  # off to wreck a seed tank: its job
		_check(is_instance_valid(e) and (hp0 - float(Game.stats.hp) > 0.0 or busy), id + " attacks and hurts")
		Game.stats.hp = Game.stats.max_hp
	# the saboteur goes for a standing tank, far from the astronaut
	var tank: SeedTank = null
	for t2 in ex.tanks:
		if not t2.lost:
			tank = t2
	for n in w.enemy_cache:
		if is_instance_valid(n):
			(n as Enemy).queue_free()
	await _frames(2)
	w.player.global_position = w.room.open_near(tank.global_position + Vector2(0, 400))
	var d := w.spawn_enemy("bio_droid", w.room.open_near(tank.global_position + Vector2(160, 0)))
	var d0 := d.global_position.distance_to(tank.global_position)
	await _frames(240)
	_check(is_instance_valid(d) and d.global_position.distance_to(tank.global_position) < d0 * 0.5, "the Bio Droid heads for a seed tank")
	Game.stats.damage = dmg0


## Every move of the BLOOM COLOSSUS, its phases, the bud (broken and left to bloom), death.
func _boss(w: GameWorld) -> void:
	_check(str(w.survival.def.boss) == "bloom_colossus", "BLOOM COLOSSUS is the final boss")
	for n in w.enemy_cache:  # the one the final fight brought: we spawn our own
		if is_instance_valid(n):
			(n as Enemy).queue_free()
	await _frames(2)
	var at := w.player.global_position
	var b := w.spawn_enemy("bloom_colossus", w.room.open_near(at + Vector2(0, -120)), 1.0) as BossBloom
	await _frames(5)
	var raw: float = maxf(float(EnemyData.TYPES.bloom_colossus.hp) * Game.enemy_mult(), BossBase._player_dps() * BossBase.DPS_REALISM * BossBase.TARGET_SECS)
	_check(absf(b.max_hp - raw) < raw * 0.05, "health sized like a final boss (%.0f vs %.0f)" % [b.max_hp, raw])
	var dmg0: float = Game.stats.damage
	Game.stats.damage = 0.0  # watch the moves without the auto-fire hurting it
	for move: String in ["seeds", "roots", "sprouts"]:
		b._next_move(move)
		for i in 110:
			w.player.global_position = at
			if i == 40:
				await _snap("boss_" + move)
			await get_tree().physics_frame
	_check(b.sprouts.size() > 0, "sprouts come out of the soil")
	# the bud left alone: it heals
	b.hp = b.max_hp * 0.7
	var h0 := b.hp
	b._next_move("bud")
	await _frames(20)
	await _snap("boss_bud")
	await _frames(int(BossBloom.BUD_TIME * 60.0) + 10)
	_check(b.hp > h0, "a bud left alone blooms and heals")
	# the bud broken: dizzy
	await _frames(60)
	b._next_move("bud")
	await _frames(5)
	for k in 6:
		b.take_damage(b.max_hp)  # each hit capped at HIT_CAP
	await _frames(5)
	_check(b.state == "stun", "hitting the bud hard enough cracks it (state %s)" % b.state)
	await _snap("boss_cracked")
	# wild bloom
	b.state = "drift"
	b.hp = b.max_hp * 0.45
	await _frames(90)
	_check(b.furious, "WILD BLOOM under half health")
	for move: String in ["thorns", "garden", "roots"]:
		b._next_move(move)
		for i in 120:
			w.player.global_position = at
			if i == 50:
				await _snap("boss_fury_" + move)
			await get_tree().physics_frame
	b.hp = b.max_hp * 0.15
	await _frames(60)
	_check(b.desperate, "OVERGROWN under 20%")
	Game.stats.damage = dmg0
	b.hp = 0.0
	b.die()
	await _frames(100)
	await _snap("boss_dead")


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
		print("BIODOME TEST OK")
	else:
		print("BIODOME TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
