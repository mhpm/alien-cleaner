extends Node
## Regression: the boss health bar must always follow a living boss (a mini boss that
## outlives its wave and dies during the final fight used to hide the final boss's bar).

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	Game.playground_active = true  # no save writes
	Game.new_run(1)  # world 2: brood_mother mini boss + HIVE QUEEN
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(3)
	w.player.invuln = 9999.0
	var hud := w.hud
	var mini := w.spawn_enemy("brood_mother", w.player.position + Vector2(-80, -60))
	var final := w.spawn_enemy("hive_queen", w.player.position + Vector2(80, -60))
	hud.show_boss(mini)
	hud.show_boss(final)  # final boss arrives while the mini boss is still alive
	await _frames(2)
	mini.die()  # the mini boss is cleaned during the final fight
	await _frames(20)
	_check(hud.boss_box.visible, "Bar must stay visible while the final boss lives")
	_check(hud.boss_ref == final, "Bar must follow the final boss")

	# two bosses at once: the bar moves on to the survivor
	var a := w.spawn_enemy("gloop_brute", w.player.position + Vector2(-60, 60))
	hud.show_boss(a)
	final.die()
	await _frames(20)
	_check(hud.boss_box.visible and hud.boss_ref == a, "Bar must switch to the other living boss")

	# a boss that never called show_boss is still picked up
	a.die()
	await _frames(20)
	_check(not hud.boss_box.visible, "Bar hides once no boss is left")
	var late := w.spawn_enemy("magma_drake", w.player.position + Vector2(0, -90))
	# the HUD looks for bosses every 0.25 s: wait by time (fast frames finish 20 early)
	await get_tree().create_timer(0.6).timeout
	_check(hud.boss_box.visible and hud.boss_ref == late, "Bar must find a boss spawned without show_boss")

	if failures.is_empty():
		print("BOSS_BAR_TEST: PASS (final boss kept, switch to survivor, hide when none, auto-detect)")
	else:
		print("BOSS_BAR_TEST: FAIL ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
