extends Node
## The WIPED OUT! screen (GameOverPanel): opens, fits the screen, counts the coins, and
## saves user://gameover_test_<n>.png in a window (start of the animation and settled):
##   Godot --path . res://tests/gameover_test.tscn

func _ready() -> void:
	call_deferred("_run")


func _snap(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://gameover_test_%s.png" % tag)


func _run() -> void:
	Game.playground_active = true
	Game.new_run(4)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	for i in 30:
		await get_tree().process_frame
	w.survival.t = 203.0
	w.survival.wave = 6
	w.survival.kills = 418
	Game.run_coins = 37
	w.hud.show_game_over()
	for i in 12:
		await get_tree().process_frame
	await _snap("anim")
	await get_tree().create_timer(2.0, true, false, true).timeout
	await _snap("done")
	var p: GameOverPanel = w.hud.overlay.find_children("*", "GameOverPanel", true, false)[0]
	var ok := w.hud.root.get_global_rect().grow(1.0).encloses(p.get_global_rect())
	var coins: Label = p._count[0][0]
	ok = ok and coins.text == "+37 coins banked"
	print("GAMEOVER rect %s coins '%s'" % [p.get_global_rect(), coins.text])
	Game.playground_active = false
	print("GAMEOVER TEST OK" if ok else "GAMEOVER TEST FAILED")
	get_tree().quit(0 if ok else 1)
