extends Control
## Title screen built on the painted menu art (assets/ui/menu_bg.webp).
## The art is laid out on a 941x1672 "stage" scaled to cover the screen; buttons are
## crops of the same art (tools/make_menu_assets.py) so they can react to touches.

const WORLD_SCENE := "res://scenes/world_select.tscn"
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
	Sfx.play_music("menu")


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
	UiTheme.add_backdrop(self, stage, bg.texture)

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


## Fit the whole art inside the safe area (any phone aspect), centered.
func _fit_stage() -> void:
	if stage == null:
		return
	UiTheme.fit_stage(self, stage, ART_SIZE)


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
			Game.menu_scene = "res://scenes/main_menu.tscn"
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
		info_label.text = "WORLDS CLEARED: %d/%d    RUNS: %d" % [Game.worlds_cleared, WorldData.WORLDS.size(), Game.runs]
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


## PLAY opens the world select (pick a world, shop, gear...).
func _play() -> void:
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.03, 0.04, 0.08, 0.0)
	add_child(fade)
	var tw := fade.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(WORLD_SCENE))


# ---------------------------------------------------------------- overlays

func _open_settings() -> void:
	MenuPanels.settings(self)


func _open_shop() -> void:
	MenuPanels.shop(self, Game.PERM.keys(), "CREW UPGRADES", _refresh)
