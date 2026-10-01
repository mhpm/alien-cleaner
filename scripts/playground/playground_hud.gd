extends Hud
## Sandbox-specific pause/results/retry routes; never bank a run or use victory UI.

func toggle_pause() -> void:
	if overlay_kind == "pause":
		_close_overlay()
		get_tree().paused = false
		return
	if not overlay_kind.is_empty():
		return
	var box := _open_overlay("pause", 0.85)
	box.add_child(UiTheme.title("PLAYGROUND", 30, Color("73eff7")))
	var resume := UiTheme.button("CONTINUAR", Color("287b61"), 18, Vector2(230, 48))
	resume.pressed.connect(toggle_pause)
	box.add_child(_center(resume))
	_test_buttons(box)


func show_test_result(title: String) -> void:
	var box := _open_overlay("test_result", 0.9)
	box.add_child(UiTheme.title(title, 22, Color("73eff7")))
	box.add_child(UiTheme.body("Tu progreso permanece igual.", 14))
	_test_buttons(box)


func _test_buttons(box: VBoxContainer) -> void:
	var again := UiTheme.button("REPETIR PRUEBA", Color("287b61"), 17, Vector2(230, 48))
	again.pressed.connect(_restart)
	box.add_child(_center(again))
	var choose := UiTheme.button("ELEGIR ENEMIGOS", Color("263e5f"), 17, Vector2(230, 48))
	choose.pressed.connect(_to_menu)
	box.add_child(_center(choose))


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(PlaygroundSession.PICKER)
