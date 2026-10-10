extends Node
## The in-level top bar from the HUD kit (assets/ui/hud/): life panel with its bar,
## timer, coins and pause, in a row that fits the screen. In a window saves
## user://hud_bar_test.png.

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, m: String) -> void:
	if not ok:
		failures.append(m)
		push_error(m)


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	for i in 90:
		await get_tree().physics_frame
	var h := w.hud
	Game.stats.hp = Game.stats.max_hp * 0.6
	Game.run_coins = 1234
	Game.hp_changed.emit()
	await get_tree().process_frame
	var vw := h.root.size.x
	var panels: Array[Control] = [h.hp_bar.get_parent() as Control, h.room_label.get_parent() as Control, h.coin_label.get_parent() as Control]
	var last := 0.0
	for p in panels:
		var r := p.get_global_rect()
		_check(r.position.x >= last - 0.5 and r.end.x <= vw, "panels in a row inside the screen (%s)" % r)
		last = r.end.x
	_check(absf(h.hp_bar.ratio - 0.6) < 0.01, "the life bar shows the life")
	_check(h.coin_label.text == "1234", "the coin panel shows the coins")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://hud_bar_test.png")
	Game.playground_active = false
	print("HUD BAR TEST OK" if failures.is_empty() else "HUD BAR TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
