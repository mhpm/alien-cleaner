extends Node
## Modals over everything and fitting any screen: a reward card (chest perk / crew gift)
## showing when the LEVEL UP modal opens stays under it and waits (the card does not run
## out while you choose), and the level-up cards and the WIPED OUT panel fit the screen
## (landscape 640x360 on PC included: shrunk, never cut). In a window it saves
## user://overlay_fit_<tag>.png.
##   godot --path . res://tests/overlay_fit_test.tscn

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _snap(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("user://overlay_fit_%s.png" % tag)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The modal's content (scaled) lies inside the screen.
func _fits(box: Control) -> bool:
	var view := get_viewport().get_visible_rect().grow(1.0)
	var need := box.get_combined_minimum_size()
	var local := Rect2((box.size - need) * 0.5, need)  # the centred content
	var xf := box.get_global_transform()
	var content := Rect2(xf * local.position, Vector2.ZERO).expand(xf * local.end)
	return view.encloses(content)


func _run() -> void:
	Game.playground_active = true
	Game.new_run(7)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(30)
	var hud := w.hud
	print("viewport ", get_viewport().get_visible_rect().size)
	hud.reward(null, "MEGA MAGNET", "+1 Coin Magnet level, pulls in everything now", Color("a7f070"))
	await _frames(20)
	var card := hud.rewards.get_child(hud.rewards.get_child_count() - 1) as Control
	hud.banner("CREW RESCUED 1/5", Color("a7f070"), 22, 0.9)
	var ids: Array[String] = []
	for id in UpgradeData.ACTIVE.slice(0, 3):
		ids.append(str(id))
	hud.show_upgrades(ids)
	await _frames(40)
	_check(get_tree().paused, "the level-up modal pauses the game")
	_check(hud.overlay.z_index > hud.rewards.z_index, "the modal draws over the reward card")
	var box := hud.overlay.get_child(1) as Control
	_check(_fits(box), "the level-up cards fit the screen (scale %.2f)" % box.scale.x)
	await _snap("upgrade")
	var a0 := card.modulate.a
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4500:
		await get_tree().process_frame
	_check(is_instance_valid(card) and absf(card.modulate.a - a0) < 0.01, "the reward card waits while the game is paused")
	_check(hud.banner_label.modulate.a > 0.5, "and so does the CREW RESCUED banner")
	hud._on_pick(ids[0])
	var t1 := Time.get_ticks_msec()
	while get_tree().paused and Time.get_ticks_msec() - t1 < 3000:
		await get_tree().process_frame
	_check(not get_tree().paused, "picking resumes")
	await _frames(20)
	_check(is_instance_valid(card), "the card is still there to read after choosing")
	hud.show_game_over()
	await _frames(60)
	var gbox := hud.overlay.get_child(1) as Control
	_check(_fits(gbox), "the WIPED OUT panel and its buttons fit the screen (scale %.2f)" % gbox.scale.x)
	_check(not is_instance_valid(card), "no reward card left over the WIPED OUT screen")
	await _snap("gameover")
	get_tree().paused = false
	Game.playground_active = false
	print("OVERLAY FIT TEST: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)
