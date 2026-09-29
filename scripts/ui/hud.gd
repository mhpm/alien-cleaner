class_name Hud
extends CanvasLayer
## Minimal gameplay HUD (health, coins, room, boss bar) plus all overlays:
## upgrade choice, pause (run stats + active upgrades), game over and victory.


var game: GameWorld
var root: Control
var safe: Control  # top bar, touch controls and banners, kept clear of notches/rounded corners
var controls: TouchControls
var hp_bar: Bar
var coin_label: Label
var weapon_label: Label
var room_label: Label
var wave_label: Label
var xp_bar: Bar  # survival: experience towards the next level
var buff_bar: BuffBar  # active timed power-ups
var _wave_text := ""
var _left := -2
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
var run_t := 0.0  # seconds played in this scene (pause TIME outside survival)
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

	safe = Control.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)
	root.resized.connect(_fit_safe)
	_fit_safe()

	controls = TouchControls.new()
	safe.add_child(controls)
	controls.ability_pressed.connect(func() -> void: game.player.blast())

	# --- top bar: painted panels from the room art (assets/room/hud_*.png)
	const K := 360.0 / 957.0  # art px -> screen px
	var hp_panel := _hud_tex("hp", Vector2(0, 0), Vector2(6, 4), Vector2(338, 70) * K)
	safe.add_child(hp_panel)
	hp_bar = Bar.new()
	hp_bar.framed = false
	hp_bar.fill = Color("e8323e")
	hp_bar.font_size = 11
	hp_bar.position = Vector2(72, 18) * K
	hp_bar.size = Vector2(255, 34) * K
	hp_panel.add_child(hp_bar)

	var room_panel := _hud_tex("room", Vector2(0.5, 0), Vector2(-46, 4), Vector2(244, 70) * K)
	safe.add_child(room_panel)
	room_label = UiTheme.label("", 13)
	room_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_panel.add_child(room_label)
	# wave progress + aliens left, just under the room panel
	wave_label = UiTheme.label("", 10, Color("ffcd75"))
	_place(wave_label, Vector2(0.5, 0), Vector2(-80, 4 + 70 * K), Vector2(160, 14))
	safe.add_child(wave_label)
	xp_bar = Bar.new()
	xp_bar.fill = Color("38b764")
	xp_bar.font_size = 9
	xp_bar.ratio = 0.0
	_place(xp_bar, Vector2(0, 0), Vector2(6, 6 + 70 * K), Vector2(12, 11), true)
	xp_bar.offset_right = -6
	xp_bar.visible = false
	buff_bar = BuffBar.new()
	_place(buff_bar, Vector2(0, 0), Vector2(8, 64), Vector2(220, 30))
	safe.add_child(buff_bar)
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(xp_bar)

	var coin_panel := _hud_tex("coins", Vector2(1, 0), Vector2(-118, 4), Vector2(194, 70) * K)
	safe.add_child(coin_panel)
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
	safe.add_child(pause_btn)

	weapon_label = UiTheme.label("", 10, Color("73eff7"))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(weapon_label, Vector2(0, 0), Vector2(10, 31), Vector2(160, 14))
	safe.add_child(weapon_label)

	# --- boss bar
	boss_box = Control.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(boss_box, Vector2(0.5, 0), Vector2(-130, 44), Vector2(260, 34))
	boss_box.visible = false
	safe.add_child(boss_box)
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
	banner_label = UiTheme.title("", 40)
	banner_label.add_theme_constant_override("outline_size", 10)
	_place(banner_label, Vector2(0.5, 0.5), Vector2(-180, -140), Vector2(360, 70))
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.pivot_offset = Vector2(180, 35)
	banner_label.modulate.a = 0.0
	safe.add_child(banner_label)

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


func _fit_safe() -> void:
	var m := UiTheme.safe_insets(root)
	safe.offset_left = m.x
	safe.offset_top = m.y
	safe.offset_right = -m.z
	safe.offset_bottom = -m.w


func set_room(n: int, total: int) -> void:
	room_label.text = "ROOM %d/%d" % [n, total]


## Survival stages: XP bar under the top panels, wave line and blaster tier below it.
func enable_survival(on: bool) -> void:
	xp_bar.visible = on
	const K := 360.0 / 957.0
	var y := 4 + 70 * K + (13.0 if on else 0.0)
	wave_label.offset_top = y
	wave_label.offset_bottom = y + 14
	weapon_label.offset_top = 31 + (13.0 if on else 0.0)
	weapon_label.offset_bottom = weapon_label.offset_top + 14
	boss_box.offset_top = 44 + (14.0 if on else 0.0)
	boss_box.offset_bottom = boss_box.offset_top + 34


func set_xp(ratio: float, level: int) -> void:
	xp_bar.ratio = clampf(ratio, 0.0, 1.0)
	xp_bar.lag = xp_bar.ratio  # no white "damage" chunk on an XP bar
	xp_bar.text = "LV %d" % level


## Free text for the wave line (survival: "WAVE 3/14").
func set_wave_text(t: String) -> void:
	if t == _wave_text:
		return
	_wave_text = t
	_left = -2
	set_enemies_left(-1)


## Wave i of n (0 = not started). Rooms with a single wave show nothing.
func set_wave(i: int, n: int) -> void:
	_wave_text = "WAVE %d/%d" % [maxi(i, 1), n] if n > 1 else ""
	_left = -2
	set_enemies_left(-1)


## Aliens still to clean in this wave (-1 hides the count).
func set_enemies_left(n: int) -> void:
	if n == _left:
		return
	_left = n
	var parts: Array[String] = []
	if _wave_text != "":
		parts.append(_wave_text)
	if n > 0:
		parts.append("%d LEFT" % n)
	wave_label.text = "   ".join(parts)


func _process(delta: float) -> void:
	if game == null:
		return
	if not get_tree().paused:
		run_t += delta
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
	var cd := float(Game.stats.blast_cooldown)
	controls.cooldown = game.player.blast_t / cd if cd > 0.0 else 0.0
	var inf := game.player.infected
	if not inf.unlocked():
		controls.infect_state = 0
	elif inf.active or inf.transforming or inf.reverting:
		controls.infect_state = 3
		controls.infect = inf.time_left / inf.duration() if inf.active else (1.0 if inf.transforming else 0.0)
		controls.cooldown = inf.dash_cd / Infected.DASH_CD
	else:
		controls.infect_state = 2 if inf.charge >= 1.0 else 1
		controls.infect = inf.charge
	if boss_ref != null:
		if is_instance_valid(boss_ref) and not boss_ref.dead:
			boss_bar.ratio = clampf(boss_ref.hp / boss_ref.max_hp, 0.0, 1.0)
		else:
			boss_bar.ratio = 0.0


# ---------------------------------------------------------------- feedback

func banner(text: String, color := Color.WHITE, font_size := 40, hold := 1.0) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	var fs := UiTheme.fit_size(UiTheme.FONT, text, font_size, 336.0)
	banner_label.add_theme_font_size_override("font_size", fs)
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


## Full-screen colour flash (hurt overlay) that fades out over dur seconds.
func tint_flash(col: Color, alpha: float, dur: float) -> void:
	hurt.color = Color(col, alpha)
	create_tween().tween_property(hurt, "color:a", 0.0, dur)


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


# ---------------------------------------------------------------- level-up modal
## Art kit: assets/ui/upgrades/kit/ (python tools/make_upgrade_kit.py). Every upgrade card
## is built from the same pieces, so new upgrades only need their pictures: card frame,
## portrait in a level box over twinkling stars, pixel-font title (titles only), smooth-font
## description, and 5 level boxes. The boxes pop in one by one, the ones you own lit; then
## an energy link runs into the level you would take, which powers on with a gold tag.

const KIT := "res://assets/ui/upgrades/kit/"
const CARD_SIZE := Vector2(340, 140)
const CELL := 36.0
const LINK_W := 6.0
const GOLD := Color("ffd84a")

var _cards: Array[Button] = []


func show_upgrades(ids: Array[String], _title := "LEVEL UP", _sub := "Choose an upgrade") -> void:
	var box := _open_overlay("upgrade", 0.82)
	box.add_theme_constant_override("separation", 10)
	_cards.clear()
	var head := _kit_rect("header.png", Vector2(318, 84))
	box.add_child(_center(head))
	head.pivot_offset = Vector2(159, 42)
	head.scale = Vector2(0.4, 0.4)
	head.modulate.a = 0.0
	var tw := head.create_tween().set_parallel()
	tw.tween_property(head, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(head, "modulate:a", 1.0, 0.15)
	box.add_child(_spacer(4))
	for i in ids.size():
		var card := _upgrade_card(ids[i], 0.2 + i * 0.16)
		box.add_child(_center(card))
		_cards.append(card)
	Sfx.play("upgrade", 0.0, -6.0)


func _upgrade_card(id: String, delay: float) -> Button:
	var def: Dictionary = UpgradeData.UPGRADES[id]
	var cur := UpgradeData.current_level(id)
	var next := mini(cur + 1, UpgradeData.LEVELS)
	var b := Button.new()
	b.set_meta("id", id)
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pivot_offset = CARD_SIZE * 0.5
	b.add_child(_nine("card.png", Vector4(40, 34, 40, 34), 0.46))
	b.mouse_entered.connect(func() -> void: b.self_modulate = Color(1.15, 1.15, 1.25))
	b.mouse_exited.connect(func() -> void: b.self_modulate = Color.WHITE)
	b.button_down.connect(func() -> void: b.scale = Vector2(0.97, 0.97))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	b.pressed.connect(_on_pick.bind(id))

	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.offset_top = 12
	h.offset_bottom = -12
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(_portrait(id, next))

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var name_l := UiTheme.title(str(def.name).to_upper(), 18, GOLD, 160.0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_color_override("font_outline_color", Color("5a2408"))
	name_l.add_theme_constant_override("outline_size", 7)
	top.add_child(name_l)
	if cur == 0:
		var nw := _kit_rect("new.png", Vector2(34, 19))
		nw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(nw)
		var ntw := nw.create_tween().set_loops()
		ntw.tween_property(nw, "modulate", Color(1.4, 1.4, 1.4), 0.5)
		ntw.tween_property(nw, "modulate", Color.WHITE, 0.5)
	var desc := UiTheme.body(str(def.desc), 11)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	v.add_child(desc)
	var lt := UpgradeData.level_text(id, next)
	if lt != "":
		var nl := UiTheme.body("Lv %d: %s" % [next, lt], 10, GOLD)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(200, 0)
		v.add_child(nl)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	v.add_child(_level_row(b, id, cur, next, delay + 0.15))

	# the card itself drops in
	b.modulate.a = 0.0
	b.scale = Vector2(0.85, 0.85)
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "modulate:a", 1.0, 0.18).set_delay(delay)
	tw.tween_property(b, "scale", Vector2.ONE, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return b


## A kit picture at a fixed size.
func _kit_rect(file: String, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	if file != "":
		r.texture = load(KIT + file)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = sz
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A 9-slice kit frame filling its parent, drawn at k of the art's pixel size so the
## corners keep their look (and resolution) whatever size the card is.
func _nine(file: String, margins: Vector4, k: float) -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var np := NinePatchRect.new()
	np.texture = load(KIT + file)
	np.patch_margin_left = int(margins.x)
	np.patch_margin_top = int(margins.y)
	np.patch_margin_right = int(margins.z)
	np.patch_margin_bottom = int(margins.w)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	np.scale = Vector2(k, k)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(np)
	holder.resized.connect(func() -> void: np.size = holder.size / k)
	return holder


## Big picture of the upgrade in a level box over twinkling stars, bobbing gently.
func _portrait(id: String, lv: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(96, 96)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := _kit_rect("cell.png", Vector2(96, 96))
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(f)
	var stars := _Stars.new()
	stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stars.offset_left = 10
	stars.offset_top = 10
	stars.offset_right = -10
	stars.offset_bottom = -10
	c.add_child(stars)
	var pic := TextureRect.new()
	pic.texture = UpgradeData.portrait(id, lv)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.position = Vector2(12, 12)
	pic.size = Vector2(72, 72)
	c.add_child(pic)
	var tw := pic.create_tween().set_loops()
	tw.tween_property(pic, "position:y", 9.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pic, "position:y", 15.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return c


## Twinkling 4-point stars behind a portrait.
class _Stars extends Control:
	var pts: Array[Vector3] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 8:
			pts.append(Vector3(randf(), randf(), randf() * TAU))

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var tm := Time.get_ticks_msec() / 1000.0
		for p in pts:
			var k := 0.5 + 0.5 * sin(tm * 2.4 + p.z)
			var pos := Vector2(p.x * size.x, p.y * size.y)
			var col := Color(0.7, 0.9, 1.0, 0.2 + 0.7 * k)
			var r := 0.8 + 2.2 * k
			draw_line(pos - Vector2(r, 0), pos + Vector2(r, 0), col, 1.0)
			draw_line(pos - Vector2(0, r), pos + Vector2(0, r), col, 1.0)


## The 5 level boxes joined by energy links. Owned levels are lit, the one this pick
## gives powers on (gold tag, glowing halo), the rest wait dimmed.
func _level_row(card: Button, id: String, cur: int, next: int, delay: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var on_at := delay + UpgradeData.LEVELS * 0.07 + 0.1  # when the next level powers on
	for lv in range(1, UpgradeData.LEVELS + 1):
		if lv > 1:
			row.add_child(_level_link(lv <= cur, lv == next, on_at))
		var cell := _level_cell(id, lv, lv <= cur, delay + (lv - 1) * 0.07)
		row.add_child(cell)
		if lv == next:
			card.set_meta("next_cell", cell)
			_power_on(cell, lv, on_at + (0.15 if lv > 1 else 0.0))
	return row


func _level_cell(id: String, lv: int, owned: bool, delay: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(CELL, CELL + 8)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.pivot_offset = Vector2(CELL * 0.5, CELL * 0.5)
	var halo := _kit_rect("cell.png", Vector2(CELL, CELL))
	halo.pivot_offset = Vector2(CELL * 0.5, CELL * 0.5)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = add
	halo.modulate = Color(GOLD, 0.0)
	c.add_child(halo)
	var frame := _kit_rect("cell.png", Vector2(CELL, CELL))
	c.add_child(frame)
	var pic := _kit_rect("", Vector2(CELL - 8, CELL - 8))
	pic.texture = UpgradeData.level_tex(id, lv)
	pic.position = Vector2(4, 4)
	pic.pivot_offset = pic.size * 0.5
	c.add_child(pic)
	var tag := _kit_rect("num_%d.png" % lv, Vector2(20, 16))
	tag.position = Vector2((CELL - 20) * 0.5, CELL - 7)
	tag.pivot_offset = Vector2(10, 8)
	c.add_child(tag)
	c.set_meta("halo", halo)
	c.set_meta("frame", frame)
	c.set_meta("pic", pic)
	c.set_meta("tag", tag)
	if not owned:
		frame.modulate = Color(0.5, 0.55, 0.7)
		pic.modulate = Color(0.4, 0.45, 0.6, 0.6)
		tag.modulate = Color(0.6, 0.65, 0.8)
	c.scale = Vector2.ZERO
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return c


## The dash between two boxes: lit when both are owned, charging (gold) into the next.
func _level_link(owned: bool, into_next: bool, at: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(LINK_W, CELL)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := ColorRect.new()
	base.color = Color(0.16, 0.25, 0.45)
	base.position = Vector2(0, CELL * 0.5 - 1)
	base.size = Vector2(LINK_W, 2)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(base)
	if owned or into_next:
		var fill := ColorRect.new()
		fill.color = GOLD if into_next else Color("5fd8ff")
		fill.position = base.position
		fill.size = Vector2(LINK_W if owned else 0.0, 2)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(fill)
		if into_next:
			var tw := fill.create_tween()
			tw.tween_interval(at)
			tw.tween_property(fill, "size:x", LINK_W, 0.15)
	return c


## The level this pick gives lights up: flash, bounce, gold tag and a pulsing halo.
func _power_on(cell: Control, lv: int, at: float) -> void:
	var pic: TextureRect = cell.get_meta("pic")
	var frame: TextureRect = cell.get_meta("frame")
	var tag: TextureRect = cell.get_meta("tag")
	var halo: TextureRect = cell.get_meta("halo")
	var tw := cell.create_tween()
	tw.tween_interval(at)
	tw.tween_callback(func() -> void:
		frame.modulate = Color(1.6, 1.6, 1.6)
		pic.modulate = Color(3.0, 3.0, 3.0)
		cell.scale = Vector2(1.35, 1.35)
		tag.texture = load(KIT + "num_%d_on.png" % lv)
		tag.modulate = Color.WHITE
		tag.scale = Vector2(1.6, 1.6)
		Sfx.play("select", 0.1, -10.0))
	tw.set_parallel()
	tw.tween_property(cell, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pic, "modulate", Color.WHITE, 0.3)
	tw.tween_property(frame, "modulate", Color.WHITE, 0.3)
	tw.tween_property(tag, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		var pulse := halo.create_tween().set_loops()
		pulse.tween_property(halo, "modulate:a", 0.9, 0.55).set_trans(Tween.TRANS_SINE)
		pulse.parallel().tween_property(halo, "scale", Vector2(1.18, 1.18), 0.55).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(halo, "modulate:a", 0.25, 0.55).set_trans(Tween.TRANS_SINE)
		pulse.parallel().tween_property(halo, "scale", Vector2(1.04, 1.04), 0.55).set_trans(Tween.TRANS_SINE)
		var bob := pic.create_tween().set_loops()
		bob.tween_property(pic, "scale", Vector2(1.08, 1.08), 0.55).set_trans(Tween.TRANS_SINE)
		bob.tween_property(pic, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE))


func _on_pick(id: String) -> void:
	if overlay_kind != "upgrade":
		return
	overlay_kind = "upgrade_pick"  # one pick only while the celebration plays
	Sfx.play("upgrade", 0.0)
	for card in _cards:
		card.disabled = true
		if str(card.get_meta("id")) != id:
			var fade_tw := card.create_tween().set_parallel()
			fade_tw.tween_property(card, "modulate:a", 0.25, 0.2)
			fade_tw.tween_property(card, "scale", Vector2(0.94, 0.94), 0.2)
			continue
		card.self_modulate = Color(1.6, 1.6, 1.6)
		card.scale = Vector2(1.06, 1.06)
		var tw := card.create_tween().set_parallel()
		tw.tween_property(card, "self_modulate", Color.WHITE, 0.3)
		tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if card.has_meta("next_cell"):
			_cell_burst(card.get_meta("next_cell"))
	var done := create_tween()
	done.tween_interval(0.6)
	done.tween_callback(func() -> void:
		_close_overlay()
		get_tree().paused = false
		controls.enabled = true
		game.on_upgrade_chosen(id))


## The taken level jumps and sprays sparks.
func _cell_burst(cell: Control) -> void:
	var pic: TextureRect = cell.get_meta("pic")
	cell.scale = Vector2(1.5, 1.5)
	pic.modulate = Color(3.0, 3.0, 3.0)
	var tw := cell.create_tween().set_parallel()
	tw.tween_property(cell, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pic, "modulate", Color.WHITE, 0.35)
	var center := cell.global_position + Vector2(CELL, CELL) * 0.5
	for i in 14:
		var sp := ColorRect.new()
		sp.color = GOLD if i % 2 == 0 else Color("9ff6ff")
		sp.size = Vector2(3, 3)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(sp)
		sp.global_position = center - Vector2(1.5, 1.5)
		var d := Vector2.from_angle(TAU * i / 14.0 + randf_range(-0.2, 0.2)) * randf_range(22.0, 40.0)
		var st := sp.create_tween().set_parallel()
		st.tween_property(sp, "position", sp.position + d, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(sp, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)


## "LEVEL n!" in big gold letters between two pixel speed-wings, subtitle below.
func _upgrade_header(title: String, sub: String, col := Color("ffd84a"), outline := Color("5a2408")) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lw := NeonWings.new()
	lw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lw)
	var t := UiTheme.title(title, 34, col, 220.0)
	t.add_theme_color_override("font_outline_color", outline)
	t.add_theme_constant_override("outline_size", 12)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 3)
	row.add_child(t)
	var rw := NeonWings.new()
	rw.flip = true
	rw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rw)
	v.add_child(row)
	var st := UiTheme.label(sub, 14, Color("9fe8ff"))
	v.add_child(st)
	return v


func toggle_pause() -> void:
	if overlay_kind == "pause":
		_close_overlay()
		get_tree().paused = false
		controls.enabled = true
		return
	if overlay != null or game.state not in ["intro", "fight", "gap", "cleared", "exit", "explore", "survive"]:
		return
	var box := _open_overlay("pause", 0.75)
	box.add_child(_center(_pause_panel()))


## Pause screen: one neon panel with the run's stats (blaster, wave, time, coins), every
## active upgrade with its level, and the RESUME / QUIT RUN buttons.
func _pause_panel() -> Control:
	var panel := PanelContainer.new()
	var m := StyleBoxEmpty.new()
	m.set_content_margin_all(14)
	m.content_margin_top = 18
	m.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", m)
	panel.custom_minimum_size = Vector2(332, 0)
	var frame := NeonFrame.new()
	frame.color = Color("41a6f6")
	frame.fill_top = Color(0.05, 0.07, 0.16, 0.94)
	frame.fill_bottom = Color(0.03, 0.04, 0.1, 0.94)
	frame.cut = 16.0
	frame.notches = true
	panel.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	v.add_child(_upgrade_header("PAUSED", "Run temporarily halted", Color("73eff7"), Color("123a6b")))
	v.add_child(_pause_stats())
	v.add_child(_section_title("ACTIVE UPGRADES"))
	v.add_child(_pause_upgrades())
	v.add_child(_spacer(2))
	var resume_row := HBoxContainer.new()
	resume_row.alignment = BoxContainer.ALIGNMENT_CENTER
	resume_row.add_theme_constant_override("separation", 6)
	resume_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resume_row.add_child(UiTheme.label("<", 16, Color("73eff7")))
	var resume := _neon_button("RESUME", Color("38b764"), Vector2(236, 50), 22)
	resume.pressed.connect(toggle_pause)
	resume_row.add_child(resume)
	resume_row.add_child(UiTheme.label(">", 16, Color("73eff7")))
	v.add_child(resume_row)
	var quit := _neon_button("QUIT RUN", Color("d23c50"), Vector2(236, 44), 18, Art.tex("skull"))
	quit.pressed.connect(_to_menu)
	v.add_child(_center(quit))
	return panel


## WEAPON | WAVE (ROOM outside survival) | TIME | COINS columns in a framed strip.
func _pause_stats() -> Control:
	var p := PanelContainer.new()
	var m := StyleBoxEmpty.new()
	m.set_content_margin_all(8)
	m.content_margin_top = 12
	m.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", m)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := NeonFrame.new()
	f.color = Color("41a6f6")
	f.fill_top = Color(0.06, 0.09, 0.2)
	f.fill_bottom = Color(0.03, 0.04, 0.1)
	f.cut = 10.0
	f.glow = 2
	p.add_child(f)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var lvl := int(Game.stats.weapon)
	var gun := _tex_rect(Art.suit_tex(Astronaut.weapon_variant(), "weapon"), Vector2(52, 26))
	var gun_col := _stat_col("WEAPON", gun, "Lv %d" % lvl, Color.WHITE, 11)
	var tier := str(WeaponData.tier(lvl).name)
	var tl := UiTheme.label(tier, UiTheme.fit_size(UiTheme.FONT, tier, 10, 62.0))
	tl.add_theme_constant_override("outline_size", 4)
	gun_col.add_child(tl)
	h.add_child(gun_col)
	var sv := game.survival
	var wave_txt := "%d / %d" % [Game.global_room(), WorldData.total_rooms()]
	var secs := run_t
	if sv != null:
		wave_txt = "BOSS" if sv.final_sent else "%d / %d" % [maxi(sv.wave + 1, 1), sv.waves.size()]
		secs = sv.t
	h.add_child(_stat_sep())
	var alien := _tex_rect(Art.frame_tex("green", "walk", 0), Vector2(26, 26))
	h.add_child(_stat_col("WAVE" if sv != null else "ROOM", alien, wave_txt, Color("ffcd75")))
	h.add_child(_stat_sep())
	var clock := "%02d:%02d" % [floori(secs / 60.0), int(secs) % 60]
	h.add_child(_stat_col("TIME", UiTheme.icon("clock", 24), clock, Color.WHITE))
	h.add_child(_stat_sep())
	var coin := _tex_rect(CollectibleData.tex("coin"), Vector2(24, 24))
	h.add_child(_stat_col("COINS", coin, str(Game.run_coins), Color.WHITE))
	return p


func _tex_rect(tex: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.custom_minimum_size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _stat_col(title: String, icon: Control, value: String, col: Color, fs := 14) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 3)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UiTheme.label(title, 10, Color("73eff7"))
	t.add_theme_constant_override("outline_size", 4)
	c.add_child(t)
	var ic := CenterContainer.new()
	ic.custom_minimum_size = Vector2(0, 28)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(icon)
	c.add_child(ic)
	c.add_child(UiTheme.label(value, fs, col))
	return c


## Thin vertical divider between the stat columns.
func _stat_sep() -> Control:
	var r := ColorRect.new()
	r.color = Color(0.25, 0.65, 0.96, 0.45)
	r.custom_minimum_size = Vector2(1, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## "--  TITLE  --" divider.
func _section_title(text: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		if i == 1:
			row.add_child(UiTheme.label(text, 16, Color("73eff7")))
			continue
		var line := ColorRect.new()
		line.color = Color("41a6f6")
		line.custom_minimum_size = Vector2(22, 2)
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
	return row


const ACTIVE_CARD := Vector2(96, 92)


## Every upgrade taken this run as a small card (picture of its current level, name,
## level and 5 pips), 3 per row; scrolls when there are more rows than fit.
func _pause_upgrades() -> Control:
	var ids: Array[String] = []
	for id: String in Game.upgrades:
		ids.append(id)
	if ids.is_empty():
		var none := UiTheme.label("No upgrades yet. Level up to pick some!", 12, Color("94b0c2"))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(280, 40)
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return none
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in ids:
		grid.add_child(_active_card(id))
	var row_h := ACTIVE_CARD.y + 6.0
	var rows := ceili(ids.size() / 3.0)
	# room left on screen once the header, stats and buttons are placed
	var max_h := maxf(row_h * 2.0 - 6.0, root.size.y - 440.0)
	if rows * row_h - 6.0 <= max_h:
		return _center(grid)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# cut through a row so it is clear the list keeps going
	sc.custom_minimum_size = Vector2(0, (floorf((max_h + 6.0) / row_h) - 0.5) * row_h)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	sc.add_child(grid)
	return sc


func _active_card(id: String) -> Control:
	var def: Dictionary = UpgradeData.UPGRADES[id]
	var col: Color = def.color
	var lv := UpgradeData.current_level(id)
	var stacking := int(def.max) >= 99  # Space Snack: just a count
	var c := Control.new()
	c.custom_minimum_size = ACTIVE_CARD
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := NeonFrame.new()
	f.color = Color("41a6f6")
	f.fill_top = Color(0.07, 0.1, 0.22)
	f.fill_bottom = Color(0.03, 0.04, 0.1)
	f.cut = 8.0
	f.glow = 1
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(f)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 6
	v.offset_bottom = -6
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var pic := _tex_rect(UpgradeData.icon(id) if stacking else UpgradeData.level_tex(id, lv), Vector2(40, 40))
	var pc := CenterContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(pic)
	v.add_child(pc)
	var nm := str(def.name)
	var name_l := UiTheme.label(nm, UiTheme.fit_size(UiTheme.FONT, nm, 11, 88.0))
	name_l.add_theme_constant_override("outline_size", 4)
	v.add_child(name_l)
	var maxed := not stacking and lv >= UpgradeData.LEVELS
	var lv_txt := "x%d" % lv if stacking else ("Lv %d MAX" % lv if maxed else "Lv %d" % lv)
	var lv_l := UiTheme.label(lv_txt, 11, Color("ffcd75") if maxed else col.lerp(Color.WHITE, 0.35))
	lv_l.add_theme_constant_override("outline_size", 4)
	v.add_child(lv_l)
	if not stacking:
		var pips := HBoxContainer.new()
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 2)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in UpgradeData.LEVELS:
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(10, 4)
			pip.color = col.lerp(Color.WHITE, 0.2) if i < lv else Color(0.2, 0.25, 0.4)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(pip)
		v.add_child(pips)
	return c


## Chunky neon button: glowing chamfered frame filled with `col`, optional icon on the left.
func _neon_button(text: String, col: Color, sz: Vector2, fs: int, icon: Texture2D = null) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var f := NeonFrame.new()
	f.color = col.lightened(0.25)
	f.fill_top = col.darkened(0.1)
	f.fill_bottom = col.darkened(0.55)
	f.cut = 12.0
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(f)
	var l := UiTheme.label(text, fs, Color.WHITE)
	l.add_theme_color_override("font_outline_color", col.darkened(0.8))
	l.add_theme_constant_override("outline_size", 8)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	if icon != null:
		var ic := _tex_rect(icon, Vector2(22, 22))
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.position = Vector2(20, (sz.y - 22.0) * 0.5)
		ic.size = Vector2(22, 22)
		b.add_child(ic)
	b.mouse_entered.connect(func() -> void:
		f.color = col.lightened(0.5)
		f.queue_redraw())
	b.mouse_exited.connect(func() -> void:
		f.color = col.lightened(0.25)
		f.queue_redraw())
	b.button_down.connect(func() -> void: b.scale = Vector2(0.96, 0.96))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.pressed.connect(func() -> void: Sfx.play("select", 0.0))
	return b


func show_game_over() -> void:
	var box := _open_overlay("gameover", 0.8)
	box.add_child(UiTheme.title("WIPED OUT!", 44, Color("ff5566")))
	box.add_child(UiTheme.label("The aliens made a mess of you.", 14, Color("94b0c2")))
	box.add_child(_spacer(8))
	box.add_child(UiTheme.label("Reached room %d" % Game.global_room(), 20))
	box.add_child(UiTheme.label("+%d coins banked" % Game.run_coins, 20, Color("ffcd75")))
	box.add_child(UiTheme.label("Bank: %d  (spend in UPGRADES)" % Game.bank, 13, Color("94b0c2")))
	box.add_child(_spacer(12))
	_end_buttons(box)


## "WORLD n CLEARED!" (VictoryScreen): stats and rewards, animated.
func show_victory(info: Dictionary) -> void:
	_close_overlay()
	overlay_kind = "victory"
	controls.enabled = false
	get_tree().paused = true
	var v := VictoryScreen.new()
	v.setup(info)
	v.menu_pressed.connect(_to_menu)
	v.next_pressed.connect(func() -> void:
		get_tree().paused = false
		Game.new_run(Game.world_index + 1)
		Game.room_index = 0
		get_tree().reload_current_scene())
	overlay = v
	root.add_child(v)
	root.move_child(v, fade.get_index())


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
	Game.new_run(Game.world_index, Game.boss_rush)  # a challenge retries as a challenge
	get_tree().reload_current_scene()


func _to_menu() -> void:
	if game.state not in ["dead", "won"]:
		Game.end_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(Game.menu_scene)
