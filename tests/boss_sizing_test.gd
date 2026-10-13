extends Node
## Boss health (BossBase.fight_hp) in every world, with the damage of a fresh crew (no
## ARMORY upgrades, no run upgrades = the longest fights): every MINI boss of a wave event
## must fall in at most MAX_MINI_SECS of steady fire and never have more health than its
## world's final boss. Prints a table: world, boss, arrives at, health, fight seconds.

const MAX_MINI_SECS := 60.0

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, m: String) -> void:
	if not ok:
		failures.append(m)
		push_error(m)


## The stage definition of world `w` (its survival room).
func _stage(w: int) -> Dictionary:
	for r: Dictionary in WorldData.world(w).rooms:
		if r.has("survival"):
			return r.survival
	return {}


## The boss events of a stage: [[id, seconds into the stage], ...].
func _boss_events(def: Dictionary) -> Array:
	var out: Array = []
	var waves: Array = def.waves
	for i in waves.size():
		var wv: Dictionary = waves[i]
		if str(wv.get("event", "")) == "boss":
			out.append([str(wv.id), i * 30.0])
		for ev: Dictionary in wv.get("events", []):
			if str(ev.get("event", "")) == "boss":
				out.append([str(ev.id), i * 30.0 + float(ev.get("at", 0.0))])
	return out


## Sized like a boss? (BossBase, or the Orbit Warden that uses BossBase.fight_hp)
func _sized(id: String) -> bool:
	var e := EnemyData.create(id)
	var ok := e is BossBase or id == "orbit_warden"
	e.free()
	return ok


## Health of boss `id` on arrival at `t` before sizing: data x world x clock (Survival).
func _base_hp(id: String, def: Dictionary, w: int, t: float) -> float:
	var ramp := t + float(def.get("t_offset", 0.0))
	var clock := 1.0 + ramp / 60.0 * float(def.get("hp_per_min", 0.3)) * 0.75
	return float(EnemyData.TYPES[id].hp) * float(WorldData.world(w).get("enemy_mult", 1.0)) * clock


func _run() -> void:
	Game.playground_active = true
	print("world | boss | at | hp | fight s (fresh crew)")
	for w in WorldData.WORLDS.size():
		Game.new_run(w)
		var def := _stage(w)
		if def.is_empty():
			continue
		var dps := BossBase._player_dps()
		var real := dps * BossBase.DPS_REALISM
		var fin := str(def.boss)
		var fin_hp := BossBase.fight_hp(_base_hp(fin, def, w, float(def.duration)), dps, false)
		print("%d | %s (FINAL) | %ds | %.0f | %.0f" % [w + 1, fin, def.duration, fin_hp, fin_hp / real])
		for ev: Array in _boss_events(def):
			var id := str(ev[0])
			if id == fin or not _sized(id):
				continue
			var hp := BossBase.fight_hp(_base_hp(id, def, w, float(ev[1])), dps, true)
			var secs := hp / real
			print("%d | %s | %ds | %.0f | %.0f" % [w + 1, id, ev[1], hp, secs])
			_check(secs <= MAX_MINI_SECS, "world %d: mini boss %s lasts %.0f s (max %.0f)" % [w + 1, id, secs, MAX_MINI_SECS])
			_check(hp < fin_hp, "world %d: mini boss %s (%.0f) is tougher than the final boss (%.0f)" % [w + 1, id, hp, fin_hp])
	Game.playground_active = false
	if failures.is_empty():
		print("BOSS SIZING TEST OK")
	else:
		print("BOSS SIZING TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
