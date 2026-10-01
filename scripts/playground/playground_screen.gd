extends Control
## Art-sized stage: supplied plates surround the live EnemyData catalog.
const ART_SIZE := Vector2(941, 1672)
const UI_DIR := "res://assets/ui/playground/"

var bosses := false
var stage: Control
var search: LineEdit
var rows: VBoxContainer
var scroll: ScrollContainer
var summary: RichTextLabel
var play_button: Button
var tabs: Array[Button] = []
var quantity_labels: Dictionary = {}
var select_buttons: Dictionary = {}
var portraits: Dictionary = {}
var textures: Dictionary = {}


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if not PlaygroundSession.enabled():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")
		return
	theme = UiTheme.build()
	Sfx.play_music("menu")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.name = "ArtStage"
	stage.size = ART_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(stage)
	_picture(stage, "bg.webp", Rect2(Vector2.ZERO, ART_SIZE))
	UiTheme.add_backdrop(self, stage, _asset("bg.webp"))
	resized.connect(_fit_stage)
	_fit_stage()
	# The supplied composition paints the static heading and subtitle.
	var back := _button("", "back.png", Rect2(27, 31, 124, 125))
	back.name = "Back"
	back.tooltip_text = "Volver al menú"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	stage.add_child(back)
	for is_boss: bool in [false, true]:
		var tab := _button(("Jefes" if is_boss else "Enemigos") + " (%d)" % PlaygroundSession.catalog(is_boss).size(),
			"tab_idle.png", Rect2(481 if is_boss else 28, 232, 435, 106), 38)
		tab.name = "BossesTab" if is_boss else "EnemiesTab"
		tab.toggle_mode = true
		tab.add_theme_stylebox_override("pressed", _skin("tab_active.png"))
		tab.add_theme_stylebox_override("hover_pressed", _skin("tab_active.png", Color("b9edff")))
		tab.pressed.connect(func() -> void:
			bosses = is_boss
			_rebuild())
		tabs.append(tab)
		stage.add_child(tab)
	_picture(stage, "search.png", Rect2(25, 351, 892, 106))
	search = LineEdit.new()
	search.name = "Search"
	search.position = Vector2(137, 373)
	search.size = Vector2(742, 64)
	search.placeholder_text = "Buscar por nombre..."
	search.add_theme_font_override("font", UiTheme.FONT)
	search.add_theme_font_size_override("font_size", 34)
	search.add_theme_color_override("font_color", Color("e6f4ff"))
	search.add_theme_color_override("font_placeholder_color", Color("8cbae9"))
	search.add_theme_color_override("caret_color", Color("42dfff"))
	for state: String in ["normal", "read_only", "focus"]:
		search.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	search.text_changed.connect(func(_text: String) -> void: _rebuild())
	stage.add_child(search)
	scroll = ScrollContainer.new()
	scroll.name = "Catalog"
	scroll.position = Vector2(27, 474)
	scroll.size = Vector2(888, 741)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar := scroll.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color("071a2d")
	track.content_margin_left = 4
	track.content_margin_right = 4
	bar.add_theme_stylebox_override("scroll", track)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("1c83ba")
	grab.set_corner_radius_all(3)
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, grab)
	stage.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 13)
	scroll.add_child(rows)
	_switch("Invulnerable", "Jugador invencible", 1224, PlaygroundSession.invulnerable,
		func(on: bool) -> void: PlaygroundSession.invulnerable = on)
	_switch("EnemiesInvincible", "Enemigos invencibles", 1296, PlaygroundSession.enemies_invincible,
		func(on: bool) -> void: PlaygroundSession.enemies_invincible = on)
	_switch("BossInvincible", "Jefe invencible", 1368, PlaygroundSession.boss_invincible,
		func(on: bool) -> void: PlaygroundSession.boss_invincible = on)
	summary = RichTextLabel.new()
	summary.name = "SelectionSummary"
	summary.position = Vector2(48, 1442)
	summary.size = Vector2(845, 58)
	summary.bbcode_enabled = true
	summary.scroll_active = false
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_theme_font_override("normal_font", UiTheme.FONT)
	summary.add_theme_color_override("default_color", Color("a9ceff"))
	stage.add_child(summary)
	var clear := _button("Limpiar", "button.png", Rect2(23, 1504, 380, 132), 40)
	clear.name = "Clear"
	clear.pressed.connect(func() -> void:
		PlaygroundSession.counts.clear()
		PlaygroundSession.boss_id = ""
		_refresh())
	stage.add_child(clear)
	play_button = _button("", "play.png", Rect2(416, 1493, 504, 156))
	play_button.name = "Play"
	play_button.tooltip_text = "Iniciar la prueba seleccionada"
	play_button.pressed.connect(_play)
	stage.add_child(play_button)
	_rebuild()


func _fit_stage() -> void:
	UiTheme.fit_stage(self, stage, ART_SIZE)


func _asset(file: String) -> Texture2D:
	if not textures.has(file):
		textures[file] = load(UI_DIR + file)
	return textures[file] as Texture2D


func _skin(file: String, tint := Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _asset(file)
	box.modulate_color = tint
	box.set_texture_margin_all(24)
	box.set_content_margin_all(0)
	return box


func _picture(parent: Node, file: String, rect: Rect2) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = _asset(file)
	picture.position = rect.position
	picture.size = rect.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture


func _button(text: String, file: String, rect: Rect2, font_size := 34) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color("e6f4ff"))
	button.add_theme_color_override("font_color", Color("e6f4ff"))
	button.add_theme_stylebox_override("normal", _skin(file))
	button.add_theme_stylebox_override("hover", _skin(file, Color("b9edff")))
	button.add_theme_stylebox_override("pressed", _skin(file, Color("8ac2dd")))
	button.add_theme_stylebox_override("disabled", _skin(file, Color(0.47, 0.57, 0.65, 0.8)))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("73eff7")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(12)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(func() -> void: Sfx.play("select", 0.0))
	return button


func _label(text: String, font_size: int, color := Color("eff7ff")) -> Label:
	var label := UiTheme.label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", color)
	return label


func _switch(node_name: String, text: String, y: float, on: bool, callback: Callable) -> void:
	var button := CheckButton.new()
	button.name = node_name
	button.text = text
	button.position = Vector2(30, y)
	button.size = Vector2(882, 72)
	button.button_pressed = on
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color("eff7ff"))
	button.add_theme_constant_override("h_separation", 20)
	button.add_theme_icon_override("unchecked", _asset("toggle_off.png"))
	button.add_theme_icon_override("checked", _asset("toggle_on.png"))
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := _skin("panel.png")
		box.content_margin_left = 36
		box.content_margin_right = 28
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.toggled.connect(callback)
	button.toggled.connect(func(_on: bool) -> void: Sfx.play("select", 0.0))
	stage.add_child(button)


func _portrait(art: String) -> Texture2D:
	if art in ["ufo", "gunship", "scout", "zorp_drone"]:
		return _asset("portrait_%s.png" % art)
	if not portraits.has(art):
		var bitmap := Art.frames(art).get_frame_texture("walk", 0).get_image()
		if bitmap.is_compressed():
			bitmap.decompress()
		portraits[art] = ImageTexture.create_from_image(bitmap.get_region(bitmap.get_used_rect()))
	return portraits[art] as Texture2D


func _rebuild() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	quantity_labels.clear()
	select_buttons.clear()
	tabs[0].set_pressed_no_signal(not bosses)
	tabs[1].set_pressed_no_signal(bosses)
	scroll.scroll_vertical = 0
	var catalog := PlaygroundSession.catalog(bosses)
	# Open with the four examples in the supplied composition; the rest stay alphabetical.
	if not bosses:
		for first: String in ["zorp_drone", "scout", "gunship", "ufo"]:
			catalog.erase(first)
			catalog.push_front(first)
	for id: String in catalog:
		var def: Dictionary = EnemyData.TYPES[id]
		if not search.text.is_empty() and not (str(def.name) + " " + id).to_lower().contains(search.text.to_lower()):
			continue
		var card := Control.new()
		card.name = id
		card.custom_minimum_size = Vector2(872, 175)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		rows.add_child(card)
		_picture(card, "card.png", Rect2(0, 0, 872, 175))
		_picture(card, "portrait_frame.png", Rect2(23, 20, 174, 140))
		var portrait := TextureRect.new()
		portrait.position = Vector2(35, 30)
		portrait.size = Vector2(149, 121)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = _portrait(str(def.art))
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		var title := _label(str(def.name), 40)
		title.position = Vector2(222, 24)
		title.size = Vector2(337, 78)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 30 if str(def.name).length() > 20 else 40)
		card.add_child(title)
		var stats := RichTextLabel.new()
		stats.position = Vector2(222, 111)
		stats.size = Vector2(339, 42)
		stats.bbcode_enabled = true
		stats.scroll_active = false
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats.add_theme_font_override("normal_font", UiTheme.FONT)
		stats.add_theme_font_size_override("normal_font_size", 28)
		stats.text = "[color=#27dcff]HP[/color] %d  [color=#3b7ba9]/  [/color][color=#27dcff]ATQ[/color] %d" % [int(def.hp), int(def.damage)]
		card.add_child(stats)
		if bosses:
			var choose := _button("Elegir", "button.png", Rect2(579, 48, 264, 94), 33)
			choose.name = "Choose"
			choose.pressed.connect(func() -> void:
				PlaygroundSession.boss_id = "" if PlaygroundSession.boss_id == id else id
				_refresh())
			select_buttons[id] = choose
			card.add_child(choose)
		else:
			var minus := _button("", "minus.png", Rect2(570, 40, 82, 102))
			minus.name = "Minus"
			minus.tooltip_text = "Quitar " + str(def.name)
			minus.pressed.connect(func() -> void: _quantity(id, -1))
			card.add_child(minus)
			_picture(card, "counter.png", Rect2(669, 40, 82, 102))
			var amount := _label("0", 50, Color("a3ff20"))
			amount.position = Vector2(669, 40)
			amount.size = Vector2(82, 102)
			amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			quantity_labels[id] = amount
			card.add_child(amount)
			var plus := _button("", "plus.png", Rect2(768, 40, 82, 102))
			plus.name = "Plus"
			plus.tooltip_text = "Añadir " + str(def.name)
			plus.pressed.connect(func() -> void: _quantity(id, 1))
			card.add_child(plus)
	if rows.get_child_count() == 0:
		var empty := _label("No hay resultados.", 36, Color("a9ceff"))
		empty.custom_minimum_size = Vector2(872, 160)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(empty)
	_refresh()


func _quantity(id: String, change: int) -> void:
	if change > 0 and PlaygroundSession.total() >= PlaygroundSession.MAX_TOTAL:
		return
	var n := clampi(int(PlaygroundSession.counts.get(id, 0)) + change, 0, 30)
	if n == 0:
		PlaygroundSession.counts.erase(id)
	else:
		PlaygroundSession.counts[id] = n
	_refresh()


func _refresh() -> void:
	for id: String in quantity_labels:
		(quantity_labels[id] as Label).text = str(PlaygroundSession.counts.get(id, 0))
	for id: String in select_buttons:
		var button := select_buttons[id] as Button
		button.text = "Listo" if PlaygroundSession.boss_id == id else "Elegir"
		button.modulate = Color("b4ff75") if PlaygroundSession.boss_id == id else Color.WHITE
	var boss_name := "Sin jefe" if PlaygroundSession.boss_id.is_empty() else str(EnemyData.TYPES[PlaygroundSession.boss_id].name)
	var summary_plain := "%d / 100 enemigos  >  %s" % [PlaygroundSession.total(), boss_name]
	summary.text = "[center][color=#a3ff20]%d[/color] / 100 enemigos  >  %s[/center]" % [PlaygroundSession.total(), boss_name]
	summary.add_theme_font_size_override("normal_font_size", UiTheme.fit_size(UiTheme.FONT, summary_plain, 34, 845))
	play_button.disabled = not PlaygroundSession.valid()


func _play() -> void:
	if PlaygroundSession.valid():
		get_tree().change_scene_to_file(PlaygroundSession.COMBAT)
