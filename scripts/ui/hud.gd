class_name Hud
extends CanvasLayer
## Minimal gameplay HUD (health, coins, room, boss bar) plus all overlays:
## upgrade choice, pause, game over and victory.

const MENU_SCENE := "res://scenes/main_menu.tscn"

var game: GameWorld
var root: Control
var controls: TouchControls
var hp_bar: Bar
var coin_label: Label
var weapon_label: Label
var room_label: Label
var boss_box: Control
var boss_bar: Bar
var boss_name: Label
var boss_ref: Enemy
var banner_label: Label
var banner_tween: Tween
var fade: ColorRect
var hurt: ColorRect
var popups: Control
var overlay: Control = null
var overlay_kind := ""
var last_hp := -1.0


func setup(g: GameWorld) -> void:
	game = g
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	add_child(root)

	hurt = ColorRect.new()
	hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt.color = Color(0.8, 0.1, 0.2, 0.0)
	hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt)

	popups = Control.new()
	popups.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(popups)

	controls = TouchControls.new()
	root.add_child(controls)
	controls.ability_pressed.connect(func() -> void: game.player.blast())

	# --- top bar: painted panels from the room art (assets/room/hud_*.png)
	const K := 360.0 / 957.0  # art px -> screen px
	var hp_panel := _hud_tex("hp", Vector2(0, 0), Vector2(6, 4), Vector2(338, 70) * K)
	root.add_child(hp_panel)
	hp_bar = Bar.new()
	hp_bar.framed = false
	hp_bar.fill = Color("e8323e")
	hp_bar.font_size = 11
	hp_bar.position = Vector2(72, 18) * K
	hp_bar.size = Vector2(255, 34) * K
	hp_panel.add_child(hp_bar)

	var room_panel := _hud_tex("room", Vector2(0.5, 0), Vector2(-46, 4), Vector2(244, 70) * K)
	root.add_child(room_panel)
	room_label = UiTheme.label("", 13)
	room_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_panel.add_child(room_label)

	var coin_panel := _hud_tex("coins", Vector2(1, 0), Vector2(-118, 4), Vector2(194, 70) * K)
	root.add_child(coin_panel)
	coin_label = UiTheme.label("0", 14, Color.WHITE)
	coin_label.position = Vector2(66, 0) * K
	coin_label.size = Vector2(118, 70) * K
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_panel.add_child(coin_label)

	var pause_btn := TextureButton.new()
	pause_btn.texture_normal = load("res://assets/room/hud_pause.png")
	pause_btn.ignore_texture_size = true
	pause_btn.stretch_mode = TextureButton.STRETCH_SCALE
	pause_btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_place(pause_btn, Vector2(1, 0), Vector2(-34, 3), Vector2(74, 74) * K)
	pause_btn.pressed.connect(toggle_pause)
	root.add_child(pause_btn)

	weapon_label = UiTheme.label("", 10, Color("73eff7"))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(weapon_label, Vector2(0, 0), Vector2(10, 31), Vector2(160, 14))
	root.add_child(weapon_label)

	# --- boss bar
	boss_box = Control.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(boss_box, Vector2(0.5, 0), Vector2(-130, 44), Vector2(260, 34))
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = UiTheme.label("", 13, Color("ff9aa8"))
	boss_name.position = Vector2(0, 0)
	boss_name.size = Vector2(260, 16)
	boss_box.add_child(boss_name)
	boss_bar = Bar.new()
	boss_bar.fill = Color("c75bd6")
	boss_bar.position = Vector2(0, 17)
	boss_bar.size = Vector2(260, 12)
	boss_box.add_child(boss_bar)

	# --- banner
	banner_label = UiTheme.label("", 40)
	banner_label.add_theme_constant_override("outline_size", 10)
	_place(banner_label, Vector2(0.5, 0.5), Vector2(-180, -140), Vector2(360, 70))
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.pivot_offset = Vector2(180, 35)
	banner_label.modulate.a = 0.0
	root.add_child(banner_label)

	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.03, 0.04, 0.08, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	fade_to(0.0, 0.4)

	Game.hp_changed.connect(_refresh)
	Game.coins_changed.connect(_refresh)
	_refresh()


func _place(c: Control, anchor: Vector2, pos: Vector2, sz: Vector2, full_width := false) -> void:
	c.anchor_left = 0.0 if full_width else anchor.x
	c.anchor_right = 1.0 if full_width else anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = sz.x if full_width else pos.x + sz.x
	c.offset_bottom = pos.y + sz.y


func _hud_tex(name: String, anchor: Vector2, pos: Vector2, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://assets/room/hud_%s.png" % name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(r, anchor, pos, sz)
	return r


func _small_box(c: Color) -> StyleBoxFlat:
	var sb := UiTheme.box(c, Color("1a1c2c"))
	sb.set_content_margin_all(2)
	sb.set_border_width_all(2)
	sb.shadow_size = 0
	return sb


func _refresh() -> void:
	var s := Game.stats
	var hp := float(s.hp)
	hp_bar.ratio = clampf(hp / float(s.max_hp), 0.0, 1.0)
	hp_bar.text = "%d/%d" % [ceili(hp), roundi(float(s.max_hp))]
	coin_label.text = str(Game.run_coins)
	var lvl := int(s.weapon)
	weapon_label.text = "LV%d %s" % [lvl, str(WeaponData.tier(lvl).name).to_upper()]
	if last_hp >= 0.0 and hp < last_hp:
		hurt.color.a = 0.28
		create_tween().tween_property(hurt, "color:a", 0.0, 0.35)
	last_hp = hp


func set_room(n: int, total: int) -> void:
	room_label.text = "ROOM %d/%d" % [n, total]


func _process(_delta: float) -> void:
	if game == null:
		return
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
	var cd := float(Game.stats.blast_cooldown)
	controls.cooldown = game.player.blast_t / cd if cd > 0.0 else 0.0
	if boss_ref != null:
		if is_instance_valid(boss_ref) and not boss_ref.dead:
			boss_bar.ratio = clampf(boss_ref.hp / boss_ref.max_hp, 0.0, 1.0)
		else:
			boss_bar.ratio = 0.0


# ---------------------------------------------------------------- feedback

func banner(text: String, color := Color.WHITE, font_size := 40, hold := 1.0) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	banner_label.add_theme_font_size_override("font_size", font_size)
	if banner_tween != null:
		banner_tween.kill()
	banner_label.scale = Vector2(0.3, 0.3)
	banner_label.modulate.a = 1.0
	banner_tween = create_tween()
	banner_tween.tween_property(banner_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_interval(hold)
	banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.3)


func popup(screen_pos: Vector2, text: String, color: Color, font_size: int) -> void:
	if popups.get_child_count() > 40:
		return
	var l := UiTheme.label(text, font_size, color)
	l.size = Vector2(80, 24)
	l.position = screen_pos - Vector2(40, 12)
	popups.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func fade_to(a: float, dur: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, dur)
	return tw


func show_boss(e: Enemy) -> void:
	boss_ref = e
	boss_name.text = str(e.def.name)
	boss_bar.ratio = 1.0
	boss_bar.lag = 1.0
	boss_box.visible = true


func hide_boss() -> void:
	boss_box.visible = false
	boss_ref = null


# ---------------------------------------------------------------- overlays

func _open_overlay(kind: String, dim := 0.65) -> VBoxContainer:
	_close_overlay()
	overlay_kind = kind
	controls.enabled = false
	get_tree().paused = true
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	root.move_child(overlay, fade.get_index())
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.09, dim)
	overlay.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	overlay.add_child(box)
	overlay.modulate.a = 0.0
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.2)
	return box


func _close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
	overlay = null
	overlay_kind = ""


func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


func show_upgrades(ids: Array[String]) -> void:
	var box := _open_overlay("upgrade")
	box.add_child(UiTheme.label("CHOOSE AN UPGRADE", 24, Color("ffcd75")))
	box.add_child(UiTheme.label("Lasts for this run", 13, Color("94b0c2")))
	for i in ids.size():
		var card := _upgrade_card(ids[i])
		box.add_child(_center(card))
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_interval(0.15 + i * 0.1)
		tw.tween_property(card, "modulate:a", 1.0, 0.2)
	Sfx.play("upgrade", 0.0, -6.0)


func _upgrade_card(id: String) -> Button:
	var def: Dictionary = UpgradeData.UPGRADES[id]
	var col: Color = def.color
	var lvl := int(Game.upgrades.get(id, 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(316, 88)
	b.add_theme_stylebox_override("normal", UiTheme.box(Color("29366f"), col.darkened(0.2)))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color("3b5dc9"), col))
	b.add_theme_stylebox_override("pressed", UiTheme.box(Color("222a4f"), col, true))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -10
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := Panel.new()
	ic.custom_minimum_size = Vector2(60, 60)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := UiTheme.box(col.darkened(0.35), col)
	sb.shadow_size = 0
	ic.add_theme_stylebox_override("panel", sb)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var il := UiTheme.label(str(def.icon), 24, Color.WHITE)
	il.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ic.add_child(il)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var name_l := UiTheme.label(str(def.name), 18, col.lerp(Color.WHITE, 0.45))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name_l)
	var desc_text := str(def.desc)
	if id == "blaster":
		desc_text = "Next: %s! %s" % [WeaponData.tier(int(Game.stats.weapon) + 1).name, desc_text]
	var desc := UiTheme.label(desc_text, 13, Color("f4f4f4"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	v.add_child(desc)
	if int(def.max) > 1 and int(def.max) < 99:
		var lv := UiTheme.label("LV %d > %d" % [lvl, lvl + 1] if lvl > 0 else "NEW!", 11, Color("ffcd75"))
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(lv)
	b.pressed.connect(_on_pick.bind(id))
	return b


func _on_pick(id: String) -> void:
	if overlay_kind != "upgrade":
		return
	Sfx.play("upgrade", 0.0)
	_close_overlay()
	get_tree().paused = false
	controls.enabled = true
	game.on_upgrade_chosen(id)


func toggle_pause() -> void:
	if overlay_kind == "pause":
		_close_overlay()
		get_tree().paused = false
		controls.enabled = true
		return
	if overlay != null or game.state not in ["intro", "fight", "gap", "cleared", "exit"]:
		return
	var box := _open_overlay("pause", 0.75)
	box.add_child(UiTheme.label("PAUSED", 36, Color("73eff7")))
	var names: Array[String] = []
	for id: String in Game.upgrades:
		var def: Dictionary = UpgradeData.UPGRADES[id]
		var lv := int(Game.upgrades[id])
		names.append(str(def.name) + ("" if lv <= 1 or id == "snack" else " x%d" % lv))
	var info := UiTheme.label("Upgrades: " + (", ".join(names) if not names.is_empty() else "none yet"), 13, Color("94b0c2"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(300, 0)
	box.add_child(_center(info))
	var resume := UiTheme.button("RESUME", Color("38b764"), 22)
	resume.pressed.connect(toggle_pause)
	box.add_child(_center(resume))
	var quit := UiTheme.button("QUIT RUN", Color("b13e53"), 18, Vector2(200, 46))
	quit.pressed.connect(_to_menu)
	box.add_child(_center(quit))


func show_game_over() -> void:
	var box := _open_overlay("gameover", 0.8)
	box.add_child(UiTheme.label("WIPED OUT!", 44, Color("ff5566")))
	box.add_child(UiTheme.label("The aliens made a mess of you.", 14, Color("94b0c2")))
	box.add_child(_spacer(8))
	box.add_child(UiTheme.label("Reached room 1-%d" % (Game.room_index + 1), 20))
	box.add_child(UiTheme.label("+%d coins banked" % Game.run_coins, 20, Color("ffcd75")))
	box.add_child(UiTheme.label("Bank: %d  (spend in UPGRADES)" % Game.bank, 13, Color("94b0c2")))
	box.add_child(_spacer(12))
	_end_buttons(box)


func show_victory() -> void:
	var box := _open_overlay("victory", 0.8)
	box.add_child(UiTheme.label("SHIP CLEANED!", 40, Color("a7f070")))
	box.add_child(UiTheme.label("The Slime King has been mopped up.", 14, Color("94b0c2")))
	box.add_child(_spacer(8))
	box.add_child(UiTheme.label("+%d coins banked" % Game.run_coins, 20, Color("ffcd75")))
	box.add_child(UiTheme.label("Bank: %d" % Game.bank, 14, Color("94b0c2")))
	box.add_child(_spacer(4))
	box.add_child(UiTheme.label("Next area unlocked:", 14, Color("f4f4f4")))
	box.add_child(UiTheme.label("ALIEN LABORATORY - coming soon", 16, Color("c75bd6")))
	box.add_child(_spacer(12))
	_end_buttons(box)


func _end_buttons(box: VBoxContainer) -> void:
	var again := UiTheme.button("PLAY AGAIN", Color("38b764"), 22, Vector2(220, 56))
	again.pressed.connect(_restart)
	box.add_child(_center(again))
	var menu := UiTheme.button("MAIN MENU", Color("3b5dc9"), 18, Vector2(220, 46))
	menu.pressed.connect(_to_menu)
	box.add_child(_center(menu))


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _restart() -> void:
	get_tree().paused = false
	Game.new_run()
	get_tree().reload_current_scene()


func _to_menu() -> void:
	if game.state not in ["dead", "won"]:
		Game.end_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
