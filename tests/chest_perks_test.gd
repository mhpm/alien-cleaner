extends Node
## The 12 exploration chests (ChestData, art tools/chests2_ref.webp -> make_chests.py):
## every chest has its closed and open art, opening one swaps to the open art, and each
## perk does what its card says in a real survival world:
##   medkit full heal + regen, shield +1 Ion Shield, ammo damage + pierce, xp level up,
##   speed speed + BLAST, coins coin shower + coin per alien, heart max HP + charming
##   hearts, drone Scrub-Bot, rocket homing rockets, magnet +1 Coin Magnet, hazmat aura +
##   half hazards, vortex sucks a pack in and implodes.
## In a window saves user://chest_perks_*.png (the open chests and the effects).
##   godot --headless --path . res://tests/chest_perks_test.tscn

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, m: String) -> void:
	print(("ok    " if ok else "FAIL  ") + m)
	if not ok:
		failures.append(m)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _snap(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://chest_perks_%s.png" % tag)


func _apply(w: GameWorld, id: String) -> void:
	for i in ChestData.CHESTS.size():
		if str(ChestData.CHESTS[i].id) == id:
			ChestData.apply(i, w, w.player.global_position + Vector2(0, -20))
			return
	_check(false, "chest %s exists" % id)


func _pack(w: GameWorld, at: Vector2, n: int, r := 24.0) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for i in n:
		var e := w.spawn_enemy("slime", w.room.open_near(at + Vector2.from_angle(TAU * i / n) * r))
		e.hp = 1e6
		e.max_hp = 1e6
		out.append(e)
	return out


func _hurt(pack: Array[Enemy]) -> float:
	var lost := 0.0
	for e in pack:
		if is_instance_valid(e):
			lost += e.max_hp - e.hp
	return lost


func _clear(w: GameWorld) -> void:
	for n in w.entities.get_children():
		if n is Enemy:
			n.queue_free()
	await _frames(2)


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	var p := w.player
	p.invuln = 99999.0
	p.fire_t = 1e9  # no gun fire: what hurts the aliens is the perks
	w.survival.set_physics_process(false)
	# art: closed and open for every chest
	_check(ChestData.CHESTS.size() == 12, "12 chests")
	for i in ChestData.CHESTS.size():
		var c := ChestData.tex(i)
		var o := ChestData.open_tex(i)
		_check(c != null and o != null and c != o and o.get_height() > c.get_height() * 0.9,
			"%s has closed and open art" % ChestData.CHESTS[i].id)
	# a chest in the world swaps to its open art when it opens
	var chest := SupplyChest.new()
	chest.kind = 0
	w.entities.add_child(chest)
	chest.global_position = p.global_position + Vector2(40, 0)
	await _frames(2)
	var closed_tex := chest.sprite.texture
	chest._open()
	await _frames(2)
	_check(chest.opened and chest.sprite.texture != closed_tex, "opening shows the open art")
	var s := Game.stats
	# medkit: full heal, then regen
	s.hp = float(s.max_hp) * 0.4
	_apply(w, "medkit")
	_check(is_equal_approx(float(s.hp), float(s.max_hp)), "FIELD MEDKIT heals fully")
	s.hp = float(s.max_hp) * 0.5
	await get_tree().create_timer(4.5).timeout
	_check(float(s.hp) > float(s.max_hp) * 0.505, "FIELD MEDKIT regenerates (%.0f%%)" % (100.0 * float(s.hp) / float(s.max_hp)))
	# shield, ammo, speed, coins, magnet, drone, hazmat (stats / upgrades)
	_apply(w, "shield")
	_check(int(Game.upgrades.get("shield", 0)) == 1, "ION BUBBLE gives an Ion Shield level")
	var dmg := float(s.damage)
	var pierce := int(s.pierce)
	_apply(w, "ammo")
	_check(float(s.damage) > dmg * 1.19 and int(s.pierce) == pierce + 1, "HEAVY ROUNDS: damage and pierce")
	var spd := float(s.move_speed)
	var bcd := float(s.blast_cooldown)
	_apply(w, "speed")
	_check(float(s.move_speed) > spd * 1.14 and float(s.blast_cooldown) < bcd * 0.8, "SPRINT CORE: speed and BLAST")
	var coins0 := get_tree().get_nodes_in_group("pickups").size()
	_apply(w, "coins")
	await _frames(2)
	_check(get_tree().get_nodes_in_group("pickups").size() >= coins0 + 15 and int(s.coin_bonus) == 1, "JACKPOT: coin shower and +1 coin per alien")
	_apply(w, "magnet")
	_check(int(Game.upgrades.get("magnet", 0)) == 1, "MEGA MAGNET gives a Coin Magnet level")
	_apply(w, "drone")
	await _frames(2)
	_check(int(Game.upgrades.get("orbiters", 0)) == 1 and p.scrub != null, "DRONE BAY: a Scrub-Bot flies by you")
	var mhp := float(s.max_hp)
	_apply(w, "heart")
	_check(float(s.max_hp) >= mhp + 20.0, "CUPID CORE: +20 max HP")
	# xp: instant level up
	var lv0 := w.survival.level
	_apply(w, "xp")
	await _frames(3)
	_check(w.survival.level > lv0 or w.survival.choosing, "XP SURGE levels up")
	w.hud._close_overlay()
	get_tree().paused = false
	await _frames(2)
	# hazmat: half hazards, the aura burns close aliens
	_apply(w, "hazmat")
	_check(is_equal_approx(float(s.hazard_mult), 0.5), "HAZMAT CORE halves hazard damage")
	await _clear(w)
	var close := _pack(w, p.global_position + Vector2(0, 2), 3, 20.0)
	for e in close:
		e.mind = null
	await get_tree().create_timer(1.6).timeout
	_check(_hurt(close) > 0.0, "HAZMAT aura burns aliens next to you (%.0f)" % _hurt(close))
	await _snap("hazmat")
	# heart: a charming heart flies to the nearest alien
	await _clear(w)
	var crush := _pack(w, p.global_position + Vector2(90, 0), 1, 0.0)
	var perks := ChestPerks.of(p)
	perks._t["heart"] = 0.0
	await get_tree().create_timer(1.6).timeout
	_check(is_instance_valid(crush[0]) and crush[0].charm != null, "CUPID CORE charms the nearest alien")
	# rocket pod
	await _clear(w)
	var targets := _pack(w, p.global_position + Vector2(110, -20), 4, 18.0)
	_apply(w, "rocket")
	perks._t["rocket"] = 0.0
	await get_tree().create_timer(2.5).timeout
	_check(_hurt(targets) > 0.0, "ROCKET POD hits the aliens around (%.0f)" % _hurt(targets))
	await _snap("rocket")
	# vortex: sucks the pack in, then implodes
	await _clear(w)
	var pack := _pack(w, p.global_position + Vector2(120, 0), 6, 50.0)
	var spread0 := 0.0
	for e in pack:
		spread0 += e.global_position.distance_to(pack[0].global_position)
	await get_tree().create_timer(0.5).timeout  # (just spawned aliens cannot be targeted yet)
	_apply(w, "vortex")
	perks._t["vortex"] = 0.0
	await get_tree().create_timer(0.6).timeout
	var spread1 := 0.0
	var centre := Vector2.ZERO
	for e in pack:
		centre += e.global_position / pack.size()
	for e in pack:
		spread1 += e.global_position.distance_to(centre) / pack.size()
	_check(spread1 < 40.0, "VOID VORTEX sucks the pack in (%.0f from the middle, was 50)" % spread1)
	await _snap("vortex")
	await get_tree().create_timer(0.8).timeout
	_check(_hurt(pack) > 0.0, "VOID VORTEX implodes on the pack (%.0f)" % _hurt(pack))
	print("CHEST PERKS TEST: %s" % ("PASS" if failures.is_empty() else "FAILED (%d)" % failures.size()))
	Game.playground_active = false
	get_tree().quit(0 if failures.is_empty() else 1)
