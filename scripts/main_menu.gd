extends Control
## Title screen built on the painted menu art (assets/ui/menu_bg.webp).
## The art is laid out on a 941x1672 "stage" scaled to cover the screen; buttons are
## crops of the same art (tools/make_menu_assets.py) so they can react to touches.

const GAME_SCENE := "res://scenes/game.tscn"
const ART_SIZE := Vector2(941, 1672)
const BUTTONS := {
	"play": Rect2(208, 1098, 528, 148),
	"upgrades": Rect2(243, 1250, 458, 119),
	"characters": Rect2(205, 1393, 157, 144),
	"achievements": Rect2(392, 1393, 170, 144),
	"settings": Rect2(598, 1393, 140, 144),
	"gear": Rect2(844, 22, 77, 71),
}

var t := 0.0
var stage: Control
var buttons: Dictionary = {}
var bank_label: Label
var info_label: Label
var shop: Control = null
var toast: Label
var sparkles: Array[Vector3] = []


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_fit_stage)
	_fit_stage()
	Sfx.play_music()


func _build() -> void:
	stage = Control.new()
	stage.size = ART_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/menu_bg.webp")
	bg.size = ART_SIZE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)

	for id: String in BUTTONS:
		var r: Rect2 = BUTTONS[id]
		var b := TextureButton.new()
		b.texture_normal = load("res://assets/ui/btn_%s.png" % id)
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

	# live values drawn over the erased parts of the art
	bank_label = _stage_label(Rect2(712, 30, 110, 56), 46, Color("fbe7b5"))
	bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_label = _stage_label(Rect2(170, 1556, 600, 44), 30, Color("9fc3ef"))

	toast = UiTheme.label("", 18, Color("ffcd75"))
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.size = Vector2(320, 40)
	toast.position -= toast.size * 0.5
	toast.modulate.a = 0.0
	add_child(toast)

	for i in 26:
		sparkles.append(Vector3(randf() * ART_SIZE.x, randf() * 520.0, randf()))
	_refresh()


func _stage_label(r: Rect2, font_size: int, col: Color) -> Label:
	var l := UiTheme.label("", font_size, col)
	l.position = r.position
	l.size = r.size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 12)
	stage.add_child(l)
	return l


## Scale the art to cover the screen (portrait phones of any aspect), centered.
func _fit_stage() -> void:
	if stage == null:
		return
	var s := maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	stage.scale = Vector2(s, s)
	stage.position = (size - ART_SIZE * s) * 0.5


func _press_fx(b: TextureButton, down: bool) -> void:
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2(0.94, 0.94) if down else Vector2.ONE, 0.07)
	tw.tween_property(b, "modulate", Color(0.8, 0.8, 0.85) if down else Color.WHITE, 0.07)


func _on_button(id: String) -> void:
	Sfx.play("select", 0.0)
	match id:
		"play":
			_play()
		"upgrades":
			_open_shop()
		"settings", "gear":
			_open_settings()
		"characters":
			get_tree().change_scene_to_file("res://scenes/character.tscn")
		"achievements":
			_show_toast("ACHIEVEMENTS COMING SOON!")


func _show_toast(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	toast.scale = Vector2(0.6, 0.6)
	toast.pivot_offset = toast.size * 0.5
	var tw := toast.create_tween()
	tw.tween_property(toast, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)


func _refresh() -> void:
	bank_label.text = str(Game.bank)
	if Game.runs > 0:
		info_label.text = "BEST: ROOM 1-%d    RUNS: %d" % [Game.best_room, Game.runs]
	else:
		info_label.text = "DRAG TO MOVE - CLEANING IS AUTOMATIC!"


func _process(delta: float) -> void:
	t += delta
	# PLAY breathes to invite a tap
	var play: TextureButton = buttons["play"]
	if not play.is_pressed():
		var k := 1.0 + sin(t * 3.2) * 0.025
		play.scale = Vector2(k, k)
	var gear: TextureButton = buttons["gear"]
	gear.rotation = sin(t * 0.8) * 0.12
	queue_redraw()


func _draw() -> void:
	# twinkling stars over the space part of the art
	var s := stage.scale.x
	for sp in sparkles:
		var a := 0.5 + 0.5 * sin(t * (1.5 + sp.z * 2.0) + sp.z * 30.0)
		if a < 0.6:
			continue
		var p := stage.position + Vector2(sp.x, sp.y) * s
		var r := (1.0 + sp.z * 1.5) * a
		draw_rect(Rect2(p - Vector2(r, 0.5), Vector2(r * 2.0, 1.0)), Color(1, 1, 1, a * 0.8))
		draw_rect(Rect2(p - Vector2(0.5, r), Vector2(1.0, r * 2.0)), Color(1, 1, 1, a * 0.8))


func _play() -> void:
	Game.new_run()
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.03, 0.04, 0.08, 0.0)
	add_child(fade)
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))


# ---------------------------------------------------------------- settings

func _open_settings() -> void:
	var panel := _overlay()
	var box: VBoxContainer = panel.get_child(1)
	box.add_child(UiTheme.label("SETTINGS", 30, Color("73eff7")))
	var music := UiTheme.button("", Color("3b5dc9"), 20, Vector2(240, 54))
	var sfx := UiTheme.button("", Color("3b5dc9"), 20, Vector2(240, 54))
	var refresh := func() -> void:
		music.text = "MUSIC: " + ("ON" if Sfx.music_enabled else "OFF")
		sfx.text = "SOUND FX: " + ("ON" if Sfx.sfx_enabled else "OFF")
	refresh.call()
	music.pressed.connect(func() -> void:
		Sfx.set_music_enabled(not Sfx.music_enabled)
		Game.save()
		refresh.call())
	sfx.pressed.connect(func() -> void:
		Sfx.sfx_enabled = not Sfx.sfx_enabled
		Game.save()
		refresh.call())
	for b: Button in [music, sfx]:
		var cc := CenterContainer.new()
		cc.add_child(b)
		box.add_child(cc)
	var close := UiTheme.button("BACK", Color("566c86"), 18, Vector2(180, 46))
	close.pressed.connect(panel.queue_free)
	var cc2 := CenterContainer.new()
	cc2.add_child(close)
	box.add_child(cc2)


func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(o)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.09, 0.88)
	o.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	o.add_child(box)
	return o


# ---------------------------------------------------------------- shop

func _open_shop() -> void:
	if shop != null:
		shop.queue_free()
	shop = Control.new()
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shop)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.09, 0.9)
	shop.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	shop.add_child(box)
	box.add_child(UiTheme.label("CREW UPGRADES", 28, Color("73eff7")))
	box.add_child(UiTheme.label("Bank: %d coins" % Game.bank, 16, Color("ffcd75")))
	for id: String in Game.PERM:
		box.add_child(_shop_row(id))
	var close := UiTheme.button("BACK", Color("566c86"), 18, Vector2(180, 46))
	close.pressed.connect(func() -> void:
		shop.queue_free()
		shop = null
		_refresh())
	var cc := CenterContainer.new()
	cc.add_child(close)
	box.add_child(cc)


func _shop_row(id: String) -> Control:
	var def: Dictionary = Game.PERM[id]
	var lvl := int(Game.perm[id])
	var maxed := lvl >= int(def.max)
	var cc := CenterContainer.new()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	var sb := UiTheme.box(Color("29366f"), Color("1a1c2c"))
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var n := UiTheme.label(str(def.name), 17, Color("f4f4f4"))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(n)
	var d := UiTheme.label(str(def.desc), 12, Color("94b0c2"))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(d)
	var pips := ""
	for i in int(def.max):
		pips += "#" if i < lvl else "-"
	var p := UiTheme.label("[" + pips + "]", 14, Color("a7f070"))
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(p)
	var cost := Game.perm_cost(id)
	var b := UiTheme.button("MAX" if maxed else str(cost), Color("38b764"), 16, Vector2(84, 44))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = maxed or Game.bank < cost
	b.pressed.connect(func() -> void:
		if Game.buy_perm(id):
			Sfx.play("upgrade", 0.0)
			_open_shop())
	h.add_child(b)
	return cc
