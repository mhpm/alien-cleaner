extends Node
## ARMORY weapons: every kind fires without errors and they all deal comparable damage
## (no weapon is simply stronger than another). Prints single-target and crowd damage.

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


## Damage dealt in `secs` by the equipped weapon to `count` aliens in front of the player.
func _trial(w: GameWorld, id: String, count: int, secs: float) -> float:
	for n in get_tree().get_nodes_in_group("enemies"):
		(n as Node).queue_free()
	await _frames(2)
	Game.gun = id
	Game.stats.gun = id
	Game.stats.gun_lv = 1
	w.player.body.refresh()
	var targets: Array[Enemy] = []
	for k in count:
		var near := 40.0 if str(GunData.gun(id).range) == "Short" else 70.0  # each weapon at its own range
		var e := w.spawn_enemy("big_red", w.player.global_position + Vector2(near + 12 * (k % 3), -24 + 16 * (k / 3)), 50.0, 0.0)
		e.spawn_t = 0.0
		e.targetable = true
		e.speed = 0.0
		targets.append(e)
	var hp0 := 0.0
	for e in targets:
		hp0 += e.hp
	await _frames(int(secs * 60.0))
	var hp1 := 0.0
	for e in targets:
		if is_instance_valid(e):
			hp1 += maxf(e.hp, 0.0)
	return hp0 - hp1


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(3)
	w.survival.set_process(false)
	w.survival.set_physics_process(false)
	w.player.invuln = 99999.0
	var single := {}
	for id: String in GunData.ids():
		var d1: float = await _trial(w, id, 1, 4.0)
		var d6: float = await _trial(w, id, 6, 4.0)
		single[id] = d1
		print("  %-9s single %6.0f   crowd(6) %6.0f" % [id, d1, d6])
		_check(d1 > 0.0, id + " must damage a single alien")
	var lo := 1e9
	var hi := 0.0
	for id: String in single:
		lo = minf(lo, float(single[id]))
		hi = maxf(hi, float(single[id]))
	print("  single-target spread: x%.2f" % (hi / maxf(lo, 1.0)))
	if failures.is_empty():
		print("GUNS_TEST: PASS (all 10 weapons fire and damage)")
	else:
		print("GUNS_TEST: FAIL ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
