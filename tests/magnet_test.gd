extends Node
## Coin Magnet (UpgradeData "magnet") with its kit card: pull range grows each level,
## +1 coin per alien from level 4, level 5 VACUUM PULSE sucks in loot far away.
## In a window saves user://magnet_test_*.png.

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
	get_viewport().get_texture().get_image().save_png("user://magnet_test_%s.png" % tag)


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	w.player.invuln = 99999.0
	w.survival.set_physics_process(false)
	_check(UpgradeData.ACTIVE.has("magnet") and UpgradeData.is_kit("magnet"), "Coin Magnet offered with its kit card")
	var ids: Array[String] = ["magnet", "hunter", "rapid"]
	w.hud.show_upgrades(ids)
	for i in 50:
		await get_tree().process_frame
	await _snap("card")
	w.hud._close_overlay()
	get_tree().paused = false
	var r0 := w.survival.pickup_range()
	var last := r0
	for lv in range(1, 6):
		Game.take_upgrade("magnet")
		var r := w.survival.pickup_range()
		_check(r > last, "level %d pulls from further (%.0f > %.0f)" % [lv, r, last])
		last = r
		_check(bool(Game.stats.magnet) == (lv >= 4), "+1 coin per alien only from level 4 (lv %d)" % lv)
	# level 5: loot far away is sucked in by the pulse
	var at := w.player.global_position
	for i in 8:
		w.survival._drop("xp", w.room.open_near(at + Vector2.from_angle(TAU * i / 8.0) * 170.0))
	await _frames(30)
	var far := 0
	for n in get_tree().get_nodes_in_group("pickups"):
		if (n as Node2D).global_position.distance_to(at) > 120.0:
			far += 1
	w.player.magnet_t = 0.05
	await _frames(20)
	await _snap("pulse")
	await _frames(150)
	var left := 0
	for n in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(n) and (n as Node2D).global_position.distance_to(w.player.global_position) > 120.0:
			left += 1
	print("MAGNET range %.0f -> %.0f, far gems %d -> %d after the pulse" % [r0, last, far, left])
	_check(far >= 6 and left == 0, "VACUUM PULSE sucks in the far gems (%d left of %d)" % [left, far])
	Game.playground_active = false
	print("MAGNET TEST OK" if failures.is_empty() else "MAGNET TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
