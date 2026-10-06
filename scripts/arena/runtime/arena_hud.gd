extends Hud
## HUD of ArenaWorld: the normal game HUD plus arena pause and result screens.
## Test runs from the editor (ArenaSession.test) close the game window on EXIT, which
## drops you back in the editor.


func toggle_pause() -> void:
	if overlay_kind == "pause":
		_close_overlay()
		get_tree().paused = false
		return
	if not overlay_kind.is_empty():
		return
	var box := _open_overlay("pause", 0.85)
	box.add_child(UiTheme.title("PAUSED", 30, Color("73eff7")))
	var arena: Arena = game.get("arena")
	if arena != null and arena.data != null:
		box.add_child(_center(UiTheme.body(arena.data.display_name + "  ·  " + arena.data.difficulty_name(), 12)))
	var resume := UiTheme.button("RESUME", Color("287b61"), 18, Vector2(230, 48))
	resume.pressed.connect(toggle_pause)
	box.add_child(_center(resume))
	_arena_buttons(box)


func show_arena_result(info: Dictionary) -> void:
	var won := bool(info.won)
	var box := _open_overlay("arena_result", 0.88)
	box.add_child(UiTheme.title("ARENA CLEAR!" if won else "MISSION FAILED", 34, Color("a7f070") if won else Color("ff5566")))
	box.add_child(_center(UiTheme.label(str(info.name).to_upper(), 14, Color("94b0c2"))))
	if not won and not str(info.reason).is_empty():
		box.add_child(_center(UiTheme.body(str(info.reason), 12, Color("ffb0b8"))))
	var secs := float(info.time)
	box.add_child(_center(UiTheme.label("TIME %02d:%02d    CLEANED %d    COINS %d" % [floori(secs / 60.0), int(secs) % 60, int(info.kills), int(info.coins)], 12, Color("ffcd75"))))
	box.add_child(_spacer(4))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	for row: Array in info.objectives:
		var done := bool(row[1])
		var failed := bool(row[2])
		var mark := "[X]" if failed else ("[v]" if done else "[ ]")
		var col := Color("ff5566") if failed else (Color("a7f070") if done else Color("94b0c2"))
		var text := "%s %s%s" % [mark, "BONUS  " if bool(row[3]) else "", str(row[0])]
		if done and not str(row[4]).is_empty() and str(row[4]) != "—":
			text += "   (" + str(row[4]) + ")"
		var l := UiTheme.label(text, 11, col)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(l)
	box.add_child(_center(list))
	if bool(info.test):
		box.add_child(_center(UiTheme.body("Editor test run: progress is not saved.", 11, Color("94b0c2"))))
	box.add_child(_spacer(6))
	_arena_buttons(box)


func _arena_buttons(box: VBoxContainer) -> void:
	var again := UiTheme.button("RETRY ARENA", Color("38b764"), 18, Vector2(230, 48))
	again.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	box.add_child(_center(again))
	var leave := UiTheme.button("BACK TO EDITOR" if ArenaSession.test else "MAIN MENU", Color("263e5f"), 16, Vector2(230, 44))
	leave.pressed.connect(func() -> void:
		get_tree().paused = false
		if ArenaSession.test:
			get_tree().quit()
		else:
			get_tree().change_scene_to_file(Game.menu_scene))
	box.add_child(_center(leave))
