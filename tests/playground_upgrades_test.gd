extends Node
## Playground pause: the UPGRADES list sets any upgrade's level up or down mid-run, no
## level up needed (stats rebuilt, drones added and removed). In a window saves
## user://playground_upgrades.png.

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


func _run() -> void:
	var saved := FileAccess.get_file_as_bytes(Game.SAVE_PATH) if FileAccess.file_exists(Game.SAVE_PATH) else PackedByteArray()
	var setting: Variant = ProjectSettings.get_setting(PlaygroundSession.SETTING, false)
	ProjectSettings.set_setting(PlaygroundSession.SETTING, true)
	PlaygroundSession.counts = {"slime": 1}
	PlaygroundSession.boss_id = ""
	PlaygroundSession.invulnerable = true
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	w.set_script(load("res://scripts/playground/playground_world.gd"))
	w.get_node("HUD").set_script(load("res://scripts/playground/playground_hud.gd"))
	add_child(w)
	await _frames(60)
	var h := w.hud
	var i0: float = Game.stats.fire_interval
	h.toggle_pause()
	await _frames(10)
	_check(h.overlay_kind == "pause" and h._rows.has("bomber") and h._rows.has("rapid") and h._rows.has("power"), "the pause lists every upgrade, the switched-off ones too")
	for i in 3:
		h._set_level("bomber", 1)
	await _frames(5)
	_check(int(Game.upgrades.get("bomber", 0)) == 3 and w.player.bomber != null and w.player.bomber.lv == 3, "+ raises the Bomber Drone to level 3, it is out")
	_check((h._rows["bomber"] as Label).text == "3/5", "the row shows 3/5")
	for i in 7:
		h._set_level("rapid", 1)
	_check(int(Game.upgrades.rapid) == 5 and absf(i0 / float(Game.stats.fire_interval) - 2.38) < 0.02, "+ stops at level 5 (Rapid Fire x2.38)")
	for i in 3:
		h._set_level("rapid", -1)
	_check(int(Game.upgrades.rapid) == 2 and absf(i0 / float(Game.stats.fire_interval) - 1.3225) < 0.01, "- takes it back down to level 2 (x1.32)")
	h._set_level("shield", 1)
	h._set_level("shield", 1)
	_check(w.player.shield_max == 2, "Ion Shield level 2 = 2 hits")
	for i in 4:
		h._set_level("bomber", -1)
	await _frames(5)
	_check(not Game.upgrades.has("bomber") and w.player.bomber == null, "- to 0 removes the Bomber Drone")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://playground_upgrades.png")
	h.toggle_pause()
	await _frames(5)
	w.queue_free()
	await _frames(5)
	ProjectSettings.set_setting(PlaygroundSession.SETTING, setting)
	var now := FileAccess.get_file_as_bytes(Game.SAVE_PATH) if FileAccess.file_exists(Game.SAVE_PATH) else PackedByteArray()
	_check(now == saved, "the save file is untouched")
	print("PLAYGROUND UPGRADES TEST OK" if failures.is_empty() else "PLAYGROUND UPGRADES TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
