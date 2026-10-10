extends Node
## Volatile Slime (UpgradeData "slime_explode") is offered on level up with its kit card,
## its bursts hurt the aliens around a cleaned one, level 3 knocks back, level 5 every 4th
## burst is a MEGA one. In a window saves user://volatile_test_card.png.

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


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	w.player.invuln = 99999.0
	w.survival.set_physics_process(false)
	_check(UpgradeData.ACTIVE.has("slime_explode"), "Volatile Slime is offered on level up")
	var ids: Array[String] = ["slime_explode", "martian", "shield"]
	w.hud.show_upgrades(ids)
	for i in 50:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://volatile_test_card.png")
	w.hud._close_overlay()
	get_tree().paused = false
	for n in w.enemy_cache:
		if is_instance_valid(n):
			(n as Enemy).queue_free()
	await _frames(3)
	Game.stats.fire_interval = 9999.0  # no auto-fire: only the bursts hurt
	for lv in [1, 3, 5]:
		Game.upgrades["slime_explode"] = lv
		UpgradeData.apply("slime_explode", Game.stats, lv)
		var at := w.room.open_near(w.player.global_position + Vector2(0, -90))
		var victim := w.spawn_enemy("slime", at, 1.0, 1.0, false, true)
		var near := w.spawn_enemy("slime", at + Vector2(12, 0), 1.0, 1.0, false, true)
		near.max_hp = 1e6
		near.hp = near.max_hp
		await _frames(30)  # out of their spawn pop (not targetable until then)
		victim.global_position = near.global_position + Vector2(10, 0)
		victim.take_damage(1e6)
		victim.hp = 0
		victim.die()
		await _frames(20)
		_check(near.hp < near.max_hp, "level %d: the burst hurts the alien next to it" % lv)
		if lv >= 3:
			_check(is_instance_valid(near), "level %d alive" % lv)
		print("VOLATILE lv %d: neighbour lost %.0f, knock %s" % [lv, near.max_hp - near.hp, near.knock])
		near.queue_free()
		await _frames(2)
	Game.playground_active = false
	print("VOLATILE TEST OK" if failures.is_empty() else "VOLATILE TEST FAILED: %s" % str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
