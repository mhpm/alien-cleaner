extends Node
## Rapid Fire (UpgradeData "rapid") is offered on level up with its kit card and every
## level makes the equipped weapon fire faster (shots counted against a sturdy alien).
## In a window saves user://rapid_test_card.png.

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


## Shots the player fires in 600 frames (10 s) at a dummy that never dies.
func _shots(w: GameWorld, dummy: Enemy) -> int:
	var n := 0
	var prev := w.player.fire_t
	for i in 600:
		dummy.hp = dummy.max_hp
		await get_tree().physics_frame
		if w.player.fire_t > prev + 0.01:  # the fire timer reloaded: one shot went out
			n += 1
		prev = w.player.fire_t
	return n


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	w.player.invuln = 99999.0
	w.survival.set_physics_process(false)
	_check(UpgradeData.ACTIVE.has("rapid") and UpgradeData.is_kit("rapid"), "Rapid Fire is offered with its kit card")
	var ids: Array[String] = ["rapid", "overdrive", "slime_explode"]
	w.hud.show_upgrades(ids)
	for i in 50:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://rapid_test_card.png")
	w.hud._close_overlay()
	get_tree().paused = false
	for n in w.enemy_cache:
		if is_instance_valid(n):
			(n as Enemy).queue_free()
	await _frames(3)
	var dummy := w.spawn_enemy("slime", w.room.open_near(w.player.global_position + Vector2(0, -60)), 1.0, 1.0, false, true)
	dummy.max_hp = 1e9
	dummy.hp = dummy.max_hp
	dummy.speed = 0.0
	await _frames(30)
	var i0: float = Game.stats.fire_interval
	var base := await _shots(w, dummy)
	var last := base
	for lv in range(1, 6):
		Game.take_upgrade("rapid")
		var n := await _shots(w, dummy)
		print("RAPID lv%d interval %.3f (x%.2f) shots %d (base %d)" % [lv, Game.stats.fire_interval, i0 / float(Game.stats.fire_interval), n, base])
		_check(n >= last, "level %d fires at least as fast as the one before (%d < %d)" % [lv, n, last])
		last = n
	_check(absf(i0 / float(Game.stats.fire_interval) - 2.38) < 0.02, "level 5 = x2.38 fire rate")
	_check(last > base * 1.8, "level 5 really shoots much faster (%d vs %d)" % [last, base])
	Game.playground_active = false
	if failures.is_empty():
		print("RAPID TEST OK")
	else:
		print("RAPID TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
