extends Node
## The first-run intro cinematic: 9 scenes with captions, tap to advance, the logo at
## the end, then WORLD 1; marks Game.intro_seen. In a window saves user://intro_<n>.png.

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
	get_viewport().get_texture().get_image().save_png("user://intro_%s.png" % tag)


func _tap(s: IntroScreen) -> void:
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	s._gui_input(ev)


func _run() -> void:
	var saved := FileAccess.get_file_as_bytes(Game.SAVE_PATH) if FileAccess.file_exists(Game.SAVE_PATH) else PackedByteArray()
	var seen0 := Game.intro_seen
	var s := (load("res://scenes/intro.tscn") as PackedScene).instantiate() as IntroScreen
	add_child(s)
	await _frames(5)
	_check(s.idx == 0 and s.pic.texture != null, "starts on panel 1")
	for i in IntroScreen.PANELS.size():
		_check(s.idx == i, "on panel %d (idx %d)" % [i + 1, s.idx])
		await _frames(20)
		_check(s.pic.texture != null and s.caption.text != "", "panel %d has art and caption" % (i + 1))
		if s.shown < s.caption.get_total_character_count():
			_tap(s)  # finish typing
		await _frames(20)
		if i in [0, 3, 5, 8]:
			await _snap(str(i + 1))
		if s.idx == i:
			_tap(s)  # next
		await _frames(2)
	await _frames(60)
	_check(s.ending, "after the last scene the logo ending shows")
	await _snap("end")
	# don't let it change scene in the test: check the flag path by hand
	s.set_meta("leaving", true)
	_check(ResourceLoader.exists(IntroScreen.GAME_SCENE), "it leads to the game scene")
	s.queue_free()
	await _frames(3)
	# the STORY button: on WORLD 1 only
	var ws := (load("res://scenes/world_select.tscn") as PackedScene).instantiate()
	add_child(ws)
	await _frames(20)
	ws.sel = 0
	ws._show_world(false)
	await _frames(5)
	_check(ws.story_btn != null and ws.story_btn.visible, "WORLD 1 shows the STORY button")
	await _snap("world1")
	ws.sel = 1
	ws._show_world(false)
	_check(not ws.story_btn.visible, "other worlds do not")
	ws.queue_free()
	Game.intro_seen = seen0
	if saved.size() > 0:
		var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(saved)
		f.close()
	print("INTRO TEST OK" if failures.is_empty() else "INTRO TEST FAILED: %s" % [failures])
	get_tree().quit(0 if failures.is_empty() else 1)
