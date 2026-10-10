extends Hud
## Sandbox-specific pause/results/retry routes; never bank a run or use victory UI.
## The pause also holds an UPGRADES list for testing: every run upgrade (the ones offered
## on level up first) with - / + to set its level right away, no level up needed
## (Game.set_upgrade_level rebuilds the stats, Player.refresh_upgrades the allies).

const ROW_W := 330.0
const LIST_H := 330.0

var _rows := {}  # id -> level Label

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
	box.add_child(_upgrade_list())
	_test_buttons(box)


func _upgrade_list() -> Control:
	_rows.clear()
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	var head := UiTheme.label("UPGRADES (sin subir de nivel)", 12, Color("ffcd75"))
	wrap.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ROW_W, minf(LIST_H, root.size.y * 0.45))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	wrap.add_child(scroll)
	var ids: Array[String] = []
	for id: String in UpgradeData.ACTIVE:
		ids.append(id)
	for id: String in UpgradeData.UPGRADES:
		if id != "snack" and not ids.has(id):
			ids.append(id)
	for id in ids:
		list.add_child(_upgrade_row(id))
	return _center(wrap)


func _upgrade_row(id: String) -> Control:
	var def: Dictionary = UpgradeData.UPGRADES[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(ROW_W - 12.0, 30)
	var icon := TextureRect.new()
	icon.texture = UpgradeData.icon(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = Vector2(28, 28)
	row.add_child(icon)
	var on := UpgradeData.ACTIVE.has(id)
	var name := UiTheme.label(str(def.name), 11, Color.WHITE if on else Color("94b0c2"))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	row.add_child(name)
	var minus := UiTheme.button("-", Color("5d275d"), 16, Vector2(34, 28))
	minus.pressed.connect(_set_level.bind(id, -1))
	row.add_child(minus)
	var lv := UiTheme.label("", 11, Color("ffcd75"))
	lv.custom_minimum_size = Vector2(40, 0)
	row.add_child(lv)
	_rows[id] = lv
	var plus := UiTheme.button("+", Color("287b61"), 16, Vector2(34, 28))
	plus.pressed.connect(_set_level.bind(id, 1))
	row.add_child(plus)
	_show_level(id)
	return row


func _set_level(id: String, step: int) -> void:
	var mx := int(UpgradeData.UPGRADES[id].max)
	var lv := clampi(UpgradeData.current_level(id) + step, 0, mx)
	if id == "blaster":  # the blaster shows its tier (1-5): level = tier - 1
		lv = clampi(int(Game.upgrades.get("blaster", 0)) + step, 0, mx)
	Game.set_upgrade_level(id, lv)
	game.player.refresh_upgrades()
	Sfx.play("select", 0.0, -8.0)
	_show_level(id)


func _show_level(id: String) -> void:
	var l: Label = _rows.get(id)
	if l != null:
		var cur := int(Game.upgrades.get(id, 0))
		l.text = "%d/%d" % [cur, int(UpgradeData.UPGRADES[id].max)]


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
