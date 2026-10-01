extends Control
## World select hub (after PLAY on the title screen), built on the painted art
## tools/world_select_ref.webp -> tools/make_world_select_assets.py -> assets/ui/world/.
## Same 941x1672 "stage" as the title screen; the world pictures float over the sky
## (the world-1 station is removed from bg.webp by the tool). Top bar: crew level (lifetime XP gems),
## gear power, XP gems and coins; the world picture with its name and longest time
## survived (swipe or the arrows to change world; locked until the previous one is
## beaten); the world chest (coins, once, after beating the world); the PLAY button; and the nav
## bar: SHOP (crew upgrades), GEAR (suits & blasters), BATTLE, TALENTS (soon), LAB
## (Infected Mode).

const GAME_SCENE := "res://scenes/game.tscn"
const SELF_SCENE := "res://scenes/world_select.tscn"
const DIR := "res://assets/ui/world/"
const ART_SIZE := Vector2(941, 1672)
const BUTTONS := {
	"menu": Rect2(22, 166, 108, 108),
	"start": Rect2(212, 1222, 520, 185),
	"chest": Rect2(367, 995, 194, 150),
	"shop": Rect2(8, 1478, 170, 187),
	"gear": Rect2(182, 1478, 170, 187),
	"battle": Rect2(358, 1458, 227, 204),
	"talents": Rect2(590, 1478, 175, 187),
	"lab": Rect2(770, 1478, 165, 187),
	"plus_power": Rect2(498, 34, 42, 42),
	"plus_gems": Rect2(688, 34, 42, 42),
	"plus_coins": Rect2(882, 34, 42, 42),
}
const WORLD_RECT := Rect2(118, 398, 740, 614)
## BOSS CHALLENGE button (drawn in code, right of the chest): only once the world is cleared
const BOSS_RECT := Rect2(626, 1004, 296, 176)
const RED := Color("ff4f6a")
const GOLD := Color("ffc933")
const SHOP_IDS := ["health", "power", "speed"]
const CYAN := Color("73eff7")
const GREEN := Color("a7f070")

var t := 0.0
var stage: Control
var buttons: Dictionary = {}
var sel := 0
var pic: TextureRect
var lock_box: Control
var lock_label: Label
var title_num: Label
var title_name: Label
var best_label: Label
var best_value: Label
var chest_label: Label
var arrows: Array[Button] = []
var labels: Dictionary = {}
var level_fill: ColorRect
var badges: Dictionary = {}
var toast: Label
var drag_from := Vector2.INF
var sparkles: Array[Vector3] = []
var stars: Control
var boss_btn: Button
var boss_pic: TextureRect
var boss_best: Label
var boss_frame: NeonFrame
var boss_chest: TextureButton


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.menu_scene = SELF_SCENE
	sel = clampi(Game.worlds_cleared, 0, WorldData.WORLDS.size() - 1)
	_build()
	resized.connect(_fit_stage)
	_fit_stage()
	_show_world(false)
	_refresh()
	Sfx.play_music("menu")


# ---------------------------------------------------------------- building

func _build() -> void:
	stage = Control.new()
	stage.size = ART_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var bg := _tex_rect(load(DIR + "bg.webp"), Rect2(Vector2.ZERO, ART_SIZE))
	stage.add_child(bg)
	UiTheme.add_backdrop(self, stage, bg.texture)
	stars = Control.new()
	stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.draw.connect(_draw_stars)
	add_child(stars)
	pic = _tex_rect(null, WORLD_RECT)
	stage.add_child(pic)
	# locked world: dark veil with a lock and what unlocks it
	lock_box = VBoxContainer.new()
	lock_box.position = WORLD_RECT.position + Vector2(0, WORLD_RECT.size.y * 0.32)
	lock_box.size = Vector2(WORLD_RECT.size.x, 200)
	lock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(lock_box as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(lock_box)
	var lock_icon := _tex_rect(load(DIR + "btn_talents.png"), Rect2(0, 0, 175, 110))
	lock_icon.custom_minimum_size = Vector2(175, 110)
	lock_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# only the padlock part of the talents slot
	var at := AtlasTexture.new()
	at.atlas = load(DIR + "btn_talents.png")
	at.region = Rect2(52, 28, 72, 80)
	lock_icon.texture = at
	lock_icon.custom_minimum_size = Vector2(90, 100)
	lock_box.add_child(lock_icon)
	lock_label = _label("", 38, Color("ff9aa8"))
	lock_box.add_child(lock_label)

	# title: "1." in cyan + the world name
	var th := HBoxContainer.new()
	th.position = Vector2(150, 188)
	th.size = Vector2(641, 100)
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 14)
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(th)
	title_num = _label("", 72, CYAN)
	title_name = _label("", 72, Color.WHITE)
	for l: Label in [title_num, title_name]:
		l.add_theme_constant_override("outline_size", 22)
		l.add_theme_color_override("font_outline_color", Color("0b1029"))
		th.add_child(l)
	var bh := HBoxContainer.new()
	bh.position = Vector2(236, 338)
	bh.size = Vector2(470, 50)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 12)
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bh)
	best_label = _label("", 30, Color.WHITE)
	best_value = _label("", 30, GREEN)
	bh.add_child(best_label)
	bh.add_child(best_value)

	for i in 2:
		var a := Button.new()
		a.text = "<" if i == 0 else ">"
		a.flat = true
		a.add_theme_font_size_override("font_size", 90)
		a.add_theme_color_override("font_color", CYAN)
		a.add_theme_color_override("font_hover_color", Color.WHITE)
		a.add_theme_color_override("font_pressed_color", Color.WHITE)
		a.add_theme_constant_override("outline_size", 18)
		a.add_theme_color_override("font_outline_color", Color("0b1029"))
		a.focus_mode = Control.FOCUS_NONE
		a.position = Vector2(14 if i == 0 else 841, 640)
		a.size = Vector2(86, 130)
		a.pressed.connect(_step.bind(-1 if i == 0 else 1))
		stage.add_child(a)
		arrows.append(a)

	for id: String in BUTTONS:
		var r: Rect2 = BUTTONS[id]
		var b := TextureButton.new()
		b.texture_normal = load(DIR + "btn_%s.png" % id)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		b.position = r.position
		b.size = r.size
		b.pivot_offset = r.size * 0.5
		b.button_down.connect(_press_fx.bind(b, true))
		b.button_up.connect(_press_fx.bind(b, false))
		b.pressed.connect(_on_button.bind(id))
		stage.add_child(b)
		buttons[id] = b

	# live values over the erased parts of the art
	labels.name = _stage_label(Rect2(122, 22, 200, 40), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	labels.level = _stage_label(Rect2(122, 64, 80, 36), 28, CYAN, HORIZONTAL_ALIGNMENT_LEFT)
	level_fill = ColorRect.new()
	level_fill.color = Color("5ee84c")
	level_fill.position = Vector2(209, 76)
	level_fill.size = Vector2(0, 15)
	level_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(level_fill)
	labels.power = _stage_label(Rect2(406, 34, 88, 42), 32, Color.WHITE)
	labels.gems = _stage_label(Rect2(608, 34, 76, 42), 32, Color.WHITE)
	labels.coins = _stage_label(Rect2(796, 34, 84, 42), 32, Color.WHITE)
	chest_label = _stage_label(Rect2(345, 952, 253, 44), 30, GREEN)
	chest_label.add_theme_constant_override("outline_size", 12)

	# nav slots redrawn in code: SHOP (coin) and ARMORY (the equipped weapon)
	_nav_icon("shop", CollectibleData.tex("coin"), Vector2(70, 70), "SHOP")
	_nav_icon("gear", GunData.icon(Game.gun), Vector2(110, 70), "ARMORY")
	for id: String in ["shop", "lab", "gear"]:
		var bd := _label("!", 30, Color.WHITE)
		var r: Rect2 = BUTTONS[id]
		var dot := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("e8323e")
		sb.set_corner_radius_all(20)
		sb.set_border_width_all(3)
		sb.border_color = Color.WHITE
		dot.add_theme_stylebox_override("panel", sb)
		dot.size = Vector2(40, 40)
		dot.position = Vector2(r.end.x - 48, r.position.y - 6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bd.size = dot.size
		bd.position = Vector2.ZERO
		dot.add_child(bd)
		stage.add_child(dot)
		badges[id] = dot

	_build_boss_button()

	toast = UiTheme.label("", 16, Color("ffcd75"))
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.size = Vector2(320, 60)
	toast.position -= toast.size * 0.5
	toast.modulate.a = 0.0
	add_child(toast)
	while sparkles.size() < 24:  # in the sky around the world picture
		var sp := Vector3(randf() * ART_SIZE.x, 110.0 + randf() * 880.0, randf())
		if not WORLD_RECT.grow(-40.0).has_point(Vector2(sp.x, sp.y)):
			sparkles.append(sp)


## BOSS CHALLENGE: a red neon card with the world's final boss, "BOSS / CHALLENGE" and
## the best time. Starts a run that goes straight to the boss fight.
func _build_boss_button() -> void:
	boss_btn = Button.new()
	boss_btn.position = BOSS_RECT.position
	boss_btn.size = BOSS_RECT.size
	boss_btn.pivot_offset = BOSS_RECT.size * 0.5
	boss_btn.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		boss_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var f := NeonFrame.new()
	f.color = RED
	f.fill_top = Color(0.22, 0.04, 0.1, 0.92)
	f.fill_bottom = Color(0.07, 0.02, 0.06, 0.92)
	f.cut = 22.0
	f.glow = 3
	f.pulse = true
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_btn.add_child(f)
	boss_frame = f
	boss_pic = TextureRect.new()
	boss_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boss_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_pic.position = Vector2(10, 18)
	boss_pic.size = Vector2(118, 140)
	boss_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_btn.add_child(boss_pic)
	var title := _label("BOSS", 44, RED)
	title.add_theme_color_override("font_outline_color", Color("2a0610"))
	title.position = Vector2(126, 14)
	title.size = Vector2(160, 52)
	boss_btn.add_child(title)
	var sub := _label("CHALLENGE", 26, Color("ffcd75"))
	sub.position = Vector2(126, 64)
	sub.size = Vector2(160, 36)
	boss_btn.add_child(sub)
	boss_best = UiTheme.body("", 22, Color("f4d7de"))
	boss_best.position = Vector2(126, 108)
	boss_best.size = Vector2(160, 50)
	boss_best.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_btn.add_child(boss_best)
	boss_btn.button_down.connect(func() -> void: boss_btn.scale = Vector2(0.95, 0.95))
	boss_btn.button_up.connect(func() -> void: boss_btn.scale = Vector2.ONE)
	boss_btn.pressed.connect(func() -> void:
		Sfx.play("select", 0.0)
		_start(true))
	stage.add_child(boss_btn)
	# once the challenge is won: a golden chest perched on the card's corner (opens once for coins)
	boss_chest = TextureButton.new()
	boss_chest.texture_normal = load(DIR + "btn_chest.png")
	boss_chest.ignore_texture_size = true
	boss_chest.stretch_mode = TextureButton.STRETCH_SCALE
	boss_chest.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_chest.position = BOSS_RECT.position + Vector2(BOSS_RECT.size.x - 112.0, -62.0)
	boss_chest.size = Vector2(100, 77)
	boss_chest.pivot_offset = boss_chest.size * 0.5
	boss_chest.pressed.connect(_open_boss_chest)
	stage.add_child(boss_chest)


func _show_boss_button() -> void:
	if boss_btn == null:
		return
	var open := Game.worlds_cleared > sel
	boss_btn.visible = open
	boss_chest.visible = false
	if not open:
		return
	var rooms: Array = WorldData.world(sel).rooms
	var sd: Dictionary = (rooms[0] as Dictionary).get("survival", {})
	var boss := str(sd.get("boss", ""))
	if EnemyData.TYPES.has(boss):
		boss_pic.texture = Art.frames(str(EnemyData.TYPES[boss].art)).get_frame_texture("walk", 0)
	var best := float(Game.boss_best.get(str(sel), 0.0))
	boss_best.text = "Best %dm %02ds" % [floori(best / 60.0), int(best) % 60] if best > 0.0 else "Beat the boss!"
	var won := best > 0.0
	boss_frame.color = GOLD if won else RED
	boss_frame.fill_top = Color(0.24, 0.16, 0.03, 0.92) if won else Color(0.22, 0.04, 0.1, 0.92)
	boss_frame.queue_redraw()
	boss_chest.visible = won
	var taken := Game.boss_chests.has(sel)
	boss_chest.self_modulate = Color(0.5, 0.5, 0.6) if taken else Color(1.35, 1.12, 0.62)


func _tex_rect(tex: Texture2D, r: Rect2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.position = r.position
	rect.size = r.size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(text: String, fs: int, col: Color) -> Label:
	var l := UiTheme.label(text, fs, col)
	l.add_theme_constant_override("outline_size", 12)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _stage_label(r: Rect2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := _label("", fs, col)
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.set_meta("size", fs)
	stage.add_child(l)
	return l


## Sets a stage label's text, shrinking the font so it fits its rect.
func _fit(l: Label, text: String) -> void:
	l.text = text
	l.add_theme_font_size_override("font_size", UiTheme.fit_size(UiTheme.FONT, text, int(l.get_meta("size")), l.size.x))


func _nav_icon(id: String, tex: Texture2D, sz: Vector2, text: String) -> void:
	var b: TextureButton = buttons[id]
	var ic := _tex_rect(tex, Rect2((b.size.x - sz.x) * 0.5, 40 + (70 - sz.y) * 0.5, sz.x, sz.y))
	b.add_child(ic)
	var l := _label(text, UiTheme.fit_size(UiTheme.FONT, text, 30, b.size.x - 20.0), Color("c7d2ec"))
	l.position = Vector2(0, 116)
	l.size = Vector2(b.size.x, 40)
	b.add_child(l)


## Fit the whole art inside the safe area (any phone aspect), centered.
func _fit_stage() -> void:
	if stage == null:
		return
	UiTheme.fit_stage(self, stage, ART_SIZE)


# ---------------------------------------------------------------- state

func _refresh() -> void:
	_fit(labels.name, "COMMANDER")
	var cl := Game.crew_level()
	_fit(labels.level, "Lv. %d" % int(cl[0]))
	level_fill.size.x = 112.0 * float(cl[1])
	_fit(labels.power, str(Game.crew_power()))
	_fit(labels.gems, _short(Game.total_xp))
	_fit(labels.coins, _short(Game.bank))
	badges.shop.visible = MenuPanels.can_buy(SHOP_IDS)
	badges.lab.visible = MutationData.can_buy()
	badges.gear.visible = Game.armory_affordable()
	_show_chest()


func _short(n: int) -> String:
	if n >= 100000:
		return "%dK" % floori(n / 1000.0)
	return str(n)


func _show_world(fade := true) -> void:
	var wd := WorldData.world(sel)
	var open := Game.world_unlocked(sel)
	var tex: Texture2D = load(DIR + str(wd.pic))
	if fade:
		var tw := create_tween()
		tw.tween_property(pic, "modulate:a", 0.0, 0.1)
		tw.tween_callback(func() -> void: _apply_world(tex, open))
		tw.tween_property(pic, "modulate:a", 1.0, 0.15)
	else:
		_apply_world(tex, open)
	title_num.text = "%d." % (sel + 1)
	title_name.text = str(wd.name)
	var fs := UiTheme.fit_size(UiTheme.FONT, title_num.text + " " + title_name.text, 72, 640.0)
	for l: Label in [title_num, title_name]:
		l.add_theme_font_size_override("font_size", fs)
	var secs := float(Game.best_time.get(str(sel), 0.0))
	if Game.worlds_cleared > sel:
		best_label.text = "CLEARED!  Best:"
	else:
		best_label.text = "Longest Survived:"
	best_value.text = "%dm %02ds" % [floori(secs / 60.0), int(secs) % 60] if secs > 0.0 else "0m 00s"
	arrows[0].visible = sel > 0
	arrows[1].visible = sel < WorldData.WORLDS.size() - 1
	(buttons.start as TextureButton).modulate = Color.WHITE if open else Color(0.45, 0.45, 0.5)
	_show_chest()
	_show_boss_button()


func _apply_world(tex: Texture2D, open: bool) -> void:
	pic.texture = tex
	pic.self_modulate = Color.WHITE if open else Color(0.22, 0.22, 0.32)
	lock_box.visible = not open
	lock_label.text = "Clear WORLD %d to unlock" % sel


func _show_chest() -> void:
	if chest_label == null:
		return
	var b: TextureButton = buttons.chest
	if Game.chests.has(sel):
		chest_label.text = "OPENED"
		chest_label.add_theme_color_override("font_color", Color("94b0c2"))
		b.self_modulate = Color(0.5, 0.5, 0.6)
	elif Game.worlds_cleared > sel:
		chest_label.text = "OPEN ME!"
		chest_label.add_theme_color_override("font_color", GREEN)
		b.self_modulate = Color.WHITE
	else:
		chest_label.text = ""
		b.self_modulate = Color(0.7, 0.7, 0.8)


func _step(d: int) -> void:
	var n := clampi(sel + d, 0, WorldData.WORLDS.size() - 1)
	if n == sel:
		return
	sel = n
	Sfx.play("select", 0.0)
	_show_world()


# ---------------------------------------------------------------- input

func _press_fx(b: TextureButton, down: bool) -> void:
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2(0.94, 0.94) if down else Vector2.ONE, 0.07)
	tw.tween_property(b, "modulate", Color(0.8, 0.8, 0.85) if down else Color.WHITE, 0.07)


func _on_button(id: String) -> void:
	Sfx.play("select", 0.0)
	match id:
		"start":
			_start()
		"chest":
			_open_chest()
		"shop", "plus_coins":
			MenuPanels.shop(self, SHOP_IDS, "CREW SHOP", _refresh)
		"lab":
			get_tree().change_scene_to_file("res://scenes/lab.tscn")
		"gear", "plus_power":
			get_tree().change_scene_to_file("res://scenes/armory.tscn")
		"talents":
			_toast("TALENTS COMING SOON!")
		"plus_gems":
			_toast("Clean aliens to collect XP gems: they raise your crew level!")
		"battle":
			pass
		"menu":
			var title := UiTheme.button("TITLE SCREEN", Color("3b5dc9"), 20, Vector2(240, 54))
			title.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
			MenuPanels.settings(self, [title])


func _input(event: InputEvent) -> void:
	# swipe across the world picture to change world
	var sp := event as InputEventScreenTouch
	if sp == null or _overlay_open():
		return
	var local := (sp.position - stage.position) / stage.scale.x
	if sp.pressed and WORLD_RECT.has_point(local):
		drag_from = local
	elif not sp.pressed and drag_from != Vector2.INF:
		var dx := local.x - drag_from.x
		drag_from = Vector2.INF
		if absf(dx) > 90.0:
			_step(-1 if dx > 0.0 else 1)


func _overlay_open() -> bool:
	# anything added after the toast is an overlay (settings / shop / fade)
	return toast != null and toast.get_index() < get_child_count() - 1


## Starts the selected world; `rush` = BOSS CHALLENGE (straight to its final boss).
func _start(rush := false) -> void:
	if not Game.world_unlocked(sel):
		_toast("Clear WORLD %d first!" % sel)
		return
	Game.new_run(sel, rush)
	Game.room_index = 0
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.03, 0.04, 0.08, 0.0)
	add_child(fade)
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))


func _open_chest() -> void:
	if Game.chests.has(sel):
		_toast("Already opened.")
		return
	if Game.worlds_cleared <= sel:
		_toast("Clear WORLD %d to open its chest!" % (sel + 1))
		return
	var coins := int(WorldData.world(sel).get("chest", 200))
	Game.chests.append(sel)
	Game.bank += coins
	Game.save()
	Sfx.play("victory", 0.0)
	var b: TextureButton = buttons.chest
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.25, 0.8), 0.08)
	tw.tween_property(b, "scale", Vector2(0.85, 1.2), 0.1)
	tw.tween_property(b, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast("+%d COINS!" % coins)
	_refresh()


## The golden chest of a won BOSS CHALLENGE: coins, once per world.
func _open_boss_chest() -> void:
	if Game.boss_chests.has(sel):
		_toast("Already opened.")
		return
	if float(Game.boss_best.get(str(sel), 0.0)) <= 0.0:
		return
	var coins := Game.boss_chest_coins(sel)
	Game.boss_chests.append(sel)
	Game.bank += coins
	Game.save()
	Sfx.play("victory", 0.0)
	var b := boss_chest
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.25, 0.8), 0.08)
	tw.tween_property(b, "scale", Vector2(0.85, 1.2), 0.1)
	tw.tween_property(b, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast("+%d COINS!" % coins)
	_refresh()
	_show_boss_button()


func _toast(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	toast.scale = Vector2(0.6, 0.6)
	toast.pivot_offset = toast.size * 0.5
	var tw := toast.create_tween()
	tw.tween_property(toast, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	t += delta
	var start: TextureButton = buttons.start
	if not start.is_pressed() and Game.world_unlocked(sel):
		var k := 1.0 + sin(t * 3.2) * 0.025
		start.scale = Vector2(k, k)
	var chest: TextureButton = buttons.chest
	if Game.worlds_cleared > sel and not Game.chests.has(sel) and not chest.is_pressed():
		chest.rotation = sin(t * 9.0) * 0.06 * maxf(0.0, sin(t * 2.0))
	else:
		chest.rotation = 0.0
	if boss_chest.visible:
		if Game.boss_chests.has(sel):
			boss_chest.rotation = 0.0
			boss_chest.position.y = BOSS_RECT.position.y - 62.0
		else:  # waiting to be opened: bobs and rattles
			boss_chest.position.y = BOSS_RECT.position.y - 62.0 + sin(t * 3.0) * 4.0
			boss_chest.rotation = sin(t * 11.0) * 0.07 * maxf(0.0, sin(t * 2.0))
	var battle: TextureButton = buttons.battle
	battle.self_modulate = Color(1, 1, 1).lerp(Color(1.3, 1.3, 1.5), 0.5 + 0.5 * sin(t * 2.5))
	for a in arrows:
		a.modulate.a = 0.65 + 0.35 * sin(t * 4.0)
	# the world picture floats over the (empty) sky of the art
	pic.position.y = WORLD_RECT.position.y + sin(t * 1.3) * 7.0
	stars.queue_redraw()


## Twinkling stars over the space part of the art (drawn by `stars`, above the art).
func _draw_stars() -> void:
	var s := stage.scale.x
	for sp in sparkles:
		var a := 0.5 + 0.5 * sin(t * (1.5 + sp.z * 2.0) + sp.z * 30.0)
		if a < 0.6:
			continue
		var p := stage.position + Vector2(sp.x, sp.y) * s
		var r := (1.0 + sp.z * 1.5) * a
		stars.draw_rect(Rect2(p - Vector2(r, 0.5), Vector2(r * 2.0, 1.0)), Color(1, 1, 1, a * 0.8))
		stars.draw_rect(Rect2(p - Vector2(0.5, r), Vector2(1.0, r * 2.0)), Color(1, 1, 1, a * 0.8))
