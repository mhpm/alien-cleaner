extends Node
## The pause modal (PausePanel, the user's kit): opens in a bare run, with 2 upgrades,
## and in an explore map with rescued crew, opened chests + 8 upgrades (the middle
## scrolls); fits the screen and RESUME closes it. The character card's stats (RunStats)
## show what the run added (green "+"), and a chest's perk shows as a readable reward
## card (RewardToast) that is still up 2 s later. In a window saves user://pause_test_<n>.png:
##   Godot --path . res://tests/pause_test.tscn

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, m: String) -> void:
	if not ok:
		failures.append(m)
		push_error(m)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _snap(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://pause_test_%s.png" % tag)


func _case(w: GameWorld, tag: String) -> void:
	w.hud.toggle_pause()
	await _frames(20)
	var p: PausePanel = w.hud.overlay.find_children("*", "PausePanel", true, false)[0]
	var r := p.get_global_rect()
	var screen := w.hud.root.get_global_rect()
	print("PAUSE %s: panel %s screen %s" % [tag, r, screen.size])
	_check(screen.grow(1.0).encloses(r), tag + ": the panel fits on screen")
	await _snap(tag)
	w.hud.toggle_pause()
	await _frames(5)
	_check(w.hud.overlay == null and not get_tree().paused, tag + ": RESUME closes it")


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(30)
	w.player.invuln = 99999.0
	await _case(w, "bare")
	for id: String in ["overdrive", "shield"]:
		Game.take_upgrade(id)
	await _case(w, "two")
	for id: String in ["martian", "rapid", "power", "crit", "speed", "vitality"]:
		Game.take_upgrade(id)
	Game.take_upgrade("overdrive")
	Game.take_upgrade("overdrive")
	if w.explore != null:
		w.explore.saved_crew.assign([0, 3, 5])
		w.explore.opened_chests.assign([0, 1, 9])
	var rows := RunStats.rows(Game.stats, Game.base_stats())
	var gains := 0
	for r: Dictionary in rows:
		if str(r.gain) != "" and bool(r.better):
			gains += 1
	print("RUN STATS: ", rows)
	_check(gains >= 3, "the run's upgrades show as gains on the character card (%d)" % gains)
	await _case(w, "full")
	# a chest perk: a reward card that stays readable
	w.hud.reward(ChestData.tex(1), "RAPID CORE", "+18% fire rate", ChestData.CHESTS[1].color)
	w.hud.reward(ChestData.tex(0), "POWER CELL", "+20% damage", ChestData.CHESTS[0].color)
	await get_tree().create_timer(2.0).timeout
	var cards := w.hud.rewards.get_child_count()
	_check(cards == 1 and w.hud.rewards.get_child(0).modulate.a > 0.9, "the reward card is still readable after 2 s (one at a time)")
	await _snap("reward")
	Game.playground_active = false
	print("PAUSE TEST OK" if failures.is_empty() else "PAUSE TEST FAILED: %s" % str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
