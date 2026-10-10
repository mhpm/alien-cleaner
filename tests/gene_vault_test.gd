extends Node
## World 6 GENE VAULT: the explore map built from the bio-lab kit (ForgeMap set "w6"), 4
## specimen vats (breed specimens while you are near, crack with damage, all broken =
## vault purged: the final boss gets no reinforcements) and THE MOTHERSHIP as final boss.
## Run in a window to get screenshots (user://gene_test_*.png; -- --overview adds the
## whole map and close-ups of corner blocks):
##   Godot --path . res://tests/gene_vault_test.tscn [-- --overview]

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


func _snap(tag := "") -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://gene_test_%s.png" % (tag if tag != "" else str(shot)))
	shot += 1


func _run() -> void:
	Game.playground_active = true
	Game.new_run(5)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(5)
	var ex := w.explore
	_check(ex != null and ex.forge != null and ex.forge.set_id == "w6", "World 6 builds its map from the w6 kit")
	if ex == null or ex.forge == null:
		_finish()
		return
	var f := ex.forge
	_check(f.reach(f.start_cell()).size() == _walkable(f), "every cell reachable from the start")
	_check(w.room.is_open(ex.start), "the astronaut starts on open floor")
	_check(ex.vats.size() == 5, "5 specimen vats (got %d)" % ex.vats.size())
	_check(ex.cores.is_empty(), "no reactor cores in world 6")
	_check(ex.chests.size() == 8, "8 chests")
	var eggs: Array = w.enemy_cache.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e is EggCluster)
	_check(eggs.size() >= 8, "egg clusters around the map (got %d)" % eggs.size())
	if not eggs.is_empty():
		# walk up to one: it cracks and hatches octolings, the nest stays
		var egg: EggCluster = eggs[0]
		var dmg0: float = Game.stats.damage
		Game.stats.damage = 0.0  # the auto-fire would break the egg or clean the octolings first
		var ep := egg.global_position
		var n0 := w.enemy_cache.size()
		for i in 40:  # just out of its reach: the sleeping nest, its shadow
			w.player.global_position = w.room.open_near(ep + Vector2(0, 150))
			await get_tree().physics_frame
		await _snap("egg_idle")
		for i in 150:
			w.player.global_position = w.room.open_near(ep + Vector2(0, 60))
			await get_tree().physics_frame
		var octos := w.enemy_cache.filter(func(e: Variant) -> bool: return is_instance_valid(e) and (e as Enemy).type_id == "octoling")
		_check(not is_instance_valid(egg) and octos.size() >= 2, "an egg cluster hatches octolings when you come near")
		Game.stats.damage = dmg0
		await _snap("egg")
		_check(w.enemy_cache.size() >= n0, "octolings out")
	_check(f.machines.size() > 0, "corner machinery placed")
	var mazes := 0
	for l: Dictionary in f.leaves:
		if l.type == "maze":
			mazes += 1
	_check(mazes >= 3, "at least 3 mazes (got %d)" % mazes)
	w.player.invuln = 99999.0
	w.survival.choosing = true
	await _frames(60)
	await _snap()
	if OS.get_cmdline_user_args().has("--overview"):
		await _overview(w)
	# a vat breeds while the astronaut is near and never moves
	var vat: Enemy = ex.vats[0]
	var at := vat.global_position
	var before := w.enemy_cache.size()
	(vat as SpecimenVat)._birth_t = 0.5
	for i in 90:
		w.player.global_position = w.room.open_near(at + Vector2(0, 70))
		await get_tree().physics_frame
	_check((vat as SpecimenVat)._own.size() > 0, "a vat breeds specimens when the astronaut is near")
	await _snap("vat")
	_check(vat.global_position.distance_to(at) < 1.0, "the vat never moves")
	# the leash and the horde wipe leave it alone
	w.player.global_position = w.room.open_near(at + Vector2(900, 0).limit_length(800))
	w.survival._leash()
	_check(is_instance_valid(vat) and vat.global_position.distance_to(at) < 1.0, "the leash does not move vats")
	# crack and break it
	w.player.global_position = w.room.open_near(at + Vector2(0, 70))
	vat.take_damage(vat.max_hp * 0.5)
	await _frames(20)
	_check(vat.sprite.animation == "crack", "a hurt vat shows cracks")
	await _snap("vat_crack")
	vat.take_damage(vat.max_hp)
	await _frames(40)
	await _snap("vat_broken")
	_check(ex.vats_broken == 1 and not ex.vault_purged(), "VAT DESTROYED 1/5")
	for v in ex.vats:
		if is_instance_valid(v) and not v.dead:
			v.take_damage(v.max_hp * 2.0)
	await _frames(5)
	_check(ex.vault_purged(), "all vats broken = vault purged")
	# a horde through the halls and mazes: nobody ends up inside a wall
	for i in 60:
		w.spawn_enemy("mini_slime", w.room.open_near(w.player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(120, 420)))
	await _frames(200)
	await _snap()
	var inside := 0
	for n in w.enemy_cache:
		if is_instance_valid(n) and not (n as Enemy).dead and not w.room.is_open((n as Node2D).global_position, -4.0):
			inside += 1
			print("INSIDE ", (n as Enemy).def.get("name"), " at ", (n as Node2D).global_position)
	_check(inside == 0, "no alien inside the vault walls (%d)" % inside)
	# the final boss: health sized to the astronaut, and it works in the open
	var b := w.spawn_enemy("mothership", w.room.open_near(w.player.global_position + Vector2(0, -110)), w.survival._boss_hp_mult())
	await _frames(5)
	var raw: float = maxf(float(EnemyData.TYPES.mothership.hp) * Game.enemy_mult() * w.survival._boss_hp_mult(), BossBase._player_dps() * BossBase.DPS_REALISM * BossBase.TARGET_SECS)
	_check(absf(b.max_hp - raw) < raw * 0.05, "Mothership health sized like a final boss (%.0f vs %.0f)" % [b.max_hp, raw])
	await _frames(480)  # a few of its attacks, the tractor beam included
	await _snap("boss")
	b.take_damage(b.max_hp * 0.02)
	b.hp = b.max_hp * 0.45
	await _frames(60)
	_check(b.get("furious") == true, "the Mothership gets furious under half health")
	await _frames(240)
	await _snap("boss_fury")
	_finish()


## The whole map (user://gene_test_map.png) and a few corner blocks up close.
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
	for i in mini(4, f.machines.size()):
		w.player.global_position = w.room.open_near(f.cell_rect(f.machines[i][0]).get_center() + Vector2(0, 90))
		await _frames(30)
		await _snap("corner_%d" % i)
	w.hud.visible = true


func _walkable(f: ForgeMap) -> int:
	var n := 0
	for b in f.blocked:
		if b == 0:
			n += 1
	return n


func _finish() -> void:
	Game.playground_active = false
	if failures.is_empty():
		print("GENE VAULT TEST OK")
	else:
		print("GENE VAULT TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
