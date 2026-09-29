class_name VictoryScreen
extends Control
## "WORLD n CLEARED!" screen (Hud.show_victory), built on the painted panel
## tools/victory_ref.webp -> tools/make_victory_assets.py -> assets/ui/victory/.
## Plays as a sequence: light rays and the panel drop in, "CLEARED!" punches in, the
## three stats count up, the four rewards pop one by one (coins bonus, XP gems, the
## next world's access chip, the world chest) with a caption for each, then the
## buttons slide up. A tap skips to the end.
## info: time, kills, coins, gems, bonus, first (first clear), next (world unlocked),
## chest (world chest now waiting in the world select).

const DIR := "res://assets/ui/victory/"
const ART := Vector2(1024, 1536)
const NUM_RECT := Rect2(636, 566, 100, 80)
const TITLE_POS := Vector2(196, 640)
const STAT_RECTS := [Rect2(600, 832, 196, 50), Rect2(600, 896, 196, 50), Rect2(600, 960, 196, 50)]
const SLOTS := [Rect2(215, 1110, 135, 152), Rect2(370, 1110, 133, 152), Rect2(525, 1110, 133, 152), Rect2(680, 1110, 133, 152)]
const BTN_MENU := Rect2(136, 1336, 352, 128)
const BTN_NEXT := Rect2(506, 1330, 384, 142)
const GOLD := Color("ffcd75")
const CYAN := Color("73eff7")

signal menu_pressed
signal next_pressed

var info: Dictionary = {}
var stage: Control
var rays: Control
var fx: Control
var title: TextureRect
var stat_labels: Array[Label] = []
var slot_icons: Array[TextureRect] = []
var slot_counts: Array[Label] = []
var caption: Label
var buttons: Array[TextureButton] = []
var tweens: Array[Tween] = []
var sparks: Array[Dictionary] = []  # {p, v, life, col, size} in art px
var t := 0.0
var done := false
var can_next := false


func setup(i: Dictionary) -> void:
	info = i
	var nxt := Game.world_index + 1
	can_next = nxt < WorldData.WORLDS.size() and Game.world_unlocked(nxt)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.08, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_tw().tween_property(dim, "color:a", 0.82, 0.3)
	rays = Control.new()
	rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.draw.connect(_draw_rays)
	rays.modulate.a = 0.0
	add_child(rays)
	_tw().tween_property(rays, "modulate:a", 1.0, 0.6)
	_build_stage()
	fx = Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_draw_fx)
	add_child(fx)
	resized.connect(_fit)
	_fit()
	_play()


func _build_stage() -> void:
	stage = Control.new()
	stage.size = ART
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.add_child(_tex(load(DIR + "panel.png"), Rect2(Vector2.ZERO, ART)))
	var num := _label(str(Game.world_index + 1), 96, Color("9fe8ff"), NUM_RECT)
	num.add_theme_color_override("font_outline_color", Color("0b2a4a"))
	num.add_theme_constant_override("outline_size", 26)
	num.pivot_offset = NUM_RECT.size * 0.5
	num.scale = Vector2.ZERO
	num.name = "Num"
	title = _tex(load(DIR + "title.png"), Rect2(TITLE_POS, Vector2(640, 116)))
	title.pivot_offset = title.size * 0.5
	title.modulate.a = 0.0
	stage.add_child(title)
	for i in 3:
		var l := _label("", 46, Color.WHITE, STAT_RECTS[i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.modulate.a = 0.0
		stat_labels.append(l)
	for i in 4:
		var r: Rect2 = SLOTS[i]
		var ic := _tex(load(DIR + "reward_%d.png" % i), Rect2(r.position + Vector2(14, 14), Vector2(r.size.x - 28, 96)))
		ic.pivot_offset = ic.size * 0.5
		ic.scale = Vector2.ZERO
		stage.add_child(ic)
		slot_icons.append(ic)
		var c := _label("", 40, Color.WHITE, Rect2(r.position.x, r.position.y + 108, r.size.x, 40))
		c.modulate.a = 0.0
		slot_counts.append(c)
	caption = _label("", 34, GOLD, Rect2(120, 1270, 784, 56))
	caption.add_theme_constant_override("outline_size", 14)
	for k in 2:
		var r: Rect2 = BTN_MENU if k == 0 else BTN_NEXT
		var b := TextureButton.new()
		b.texture_normal = load(DIR + ("btn_menu.png" if k == 0 else "btn_next.png"))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		b.position = r.position
		b.size = r.size
		b.pivot_offset = r.size * 0.5
		b.modulate.a = 0.0
		b.disabled = true
		b.button_down.connect(func() -> void: b.scale = Vector2(0.94, 0.94))
		b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
		b.pressed.connect(_on_button.bind(k))
		stage.add_child(b)
		buttons.append(b)
	if not can_next:
		buttons[1].self_modulate = Color(0.45, 0.45, 0.5)


func _tex(tex: Texture2D, r: Rect2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.position = r.position
	rect.size = r.size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(text: String, fs: int, col: Color, r: Rect2) -> Label:
	var l := UiTheme.label(text, fs, col)
	l.position = r.position
	l.size = r.size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color("0b1029"))
	stage.add_child(l)
	return l


## Fit the panel to the screen width (or height), centred.
func _fit() -> void:
	UiTheme.fit_stage(self, stage, ART, false, 1.04)


func _tw() -> Tween:
	var tw := create_tween()
	tweens.append(tw)
	return tw


# ---------------------------------------------------------------- the sequence

func _play() -> void:
	# panel drops in
	var target := stage.position
	stage.position.y -= 260.0
	stage.modulate.a = 0.0
	var tw := _tw().set_parallel()
	tw.tween_property(stage, "position:y", target.y, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stage, "modulate:a", 1.0, 0.25)
	var seq := _tw()
	seq.tween_interval(0.45)
	seq.tween_callback(_punch_title)
	seq.tween_interval(0.5)
	var vals := [float(info.get("time", 0.0)), float(info.get("kills", 0)), float(info.get("coins", 0))]
	for i in 3:
		seq.tween_callback(_count_stat.bind(i, vals[i]))
		seq.tween_interval(0.42)
	seq.tween_interval(0.25)
	var rewards := _rewards()
	for i in 4:
		seq.tween_callback(_pop_reward.bind(i, rewards[i]))
		seq.tween_interval(0.5)
	seq.tween_callback(_show_buttons)


## [count, caption, active] for coins, gems, chip, chest.
func _rewards() -> Array:
	var nxt := Game.world_index + 1
	var chip_ok := bool(info.get("next", false))
	var chip_text := "WORLD %d UNLOCKED!" % (nxt + 1) if chip_ok else (
			"MORE WORLDS COMING SOON!" if nxt >= WorldData.WORLDS.size() else "WORLD %d ALREADY OPEN" % (nxt + 1))
	var chest_ok := bool(info.get("chest", false))
	if bool(info.get("rush", false)):
		# BOSS CHALLENGE: the record instead of the world chip and chest
		var rec := bool(info.get("record", false))
		var best := float(info.get("best", 0.0))
		return [
			[int(info.get("bonus", 0)), "+%d CHALLENGE COINS!" % int(info.get("bonus", 0)), true],
			[int(info.get("gems", 0)), "+%d XP GEMS FOR YOUR CREW" % int(info.get("gems", 0)), true],
			[1 if rec else 0, "NEW RECORD!" if rec else "BEST: %dm %02ds" % [floori(best / 60.0), int(best) % 60], rec],
			[1, "BOSS CHALLENGE CLEARED!", true],
		]
	return [
		[int(info.get("bonus", 0)), "+%d BONUS COINS!" % int(info.get("bonus", 0)), true],
		[int(info.get("gems", 0)), "+%d XP GEMS FOR YOUR CREW" % int(info.get("gems", 0)), true],
		[1 if chip_ok else 0, chip_text, chip_ok],
		[1 if chest_ok else 0, "WORLD CHEST WAITING IN THE MENU!" if chest_ok else "WORLD CHEST ALREADY OPENED", chest_ok],
	]


func _punch_title() -> void:
	title.modulate.a = 1.0
	title.scale = Vector2(2.2, 2.2)
	var tw := _tw()
	tw.tween_property(title, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var num: Label = stage.get_node("Num")
	var tn := _tw()
	tn.tween_interval(0.12)
	tn.tween_property(num, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_burst(TITLE_POS + Vector2(320, 58), GOLD, 40, 900.0)
	_burst(TITLE_POS + Vector2(320, 58), Color.WHITE, 18, 600.0)
	Sfx.play("upgrade", 0.0)
	_shake()


func _count_stat(i: int, target: float) -> void:
	var l := stat_labels[i]
	l.modulate.a = 1.0
	var tw := _tw()
	tw.tween_method(func(v: float) -> void:
		l.text = _fmt_stat(i, v), 0.0, target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		l.text = _fmt_stat(i, target)
		l.pivot_offset = Vector2(0, l.size.y * 0.5)
		l.scale = Vector2(1.25, 1.25)
		l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.15))
	for k in 5:
		get_tree().create_timer(k * 0.08, true, false, true).timeout.connect(func() -> void: Sfx.play("select", 0.2, -8.0))


func _fmt_stat(i: int, v: float) -> String:
	if i == 0:
		return "%02d:%02d" % [floori(v / 60.0), int(v) % 60]
	return str(roundi(v))


func _pop_reward(i: int, r: Array) -> void:
	var ic := slot_icons[i]
	var c := slot_counts[i]
	var active := bool(r[2])
	var tw := _tw()
	tw.tween_property(ic, "scale", Vector2(1.35, 1.35), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ic, "scale", Vector2.ONE, 0.12)
	c.modulate.a = 1.0
	var count := int(r[0])
	var tc := _tw()
	tc.tween_method(func(v: float) -> void: c.text = "x%d" % roundi(v), 0.0, float(count), 0.35)
	if not active:
		ic.modulate = Color(0.4, 0.4, 0.5)
		c.add_theme_color_override("font_color", Color("566c86"))
		Sfx.play("select", 0.0, -6.0)
	else:
		var sr: Rect2 = SLOTS[i]
		_burst(sr.get_center() + Vector2(0, -16), [GOLD, Color("5ee84c"), CYAN, Color("ffb070")][i], 26, 520.0)
		Sfx.play("coin" if i < 2 else "clean", 0.05, -2.0)
		# the slot keeps a soft shine afterwards
		ic.set_meta("shine", true)
	caption.text = str(r[1])
	caption.add_theme_font_size_override("font_size", UiTheme.fit_size(UiTheme.FONT, caption.text, 34, caption.size.x))
	caption.add_theme_color_override("font_color", GOLD if active else Color("94b0c2"))
	caption.pivot_offset = caption.size * 0.5
	caption.scale = Vector2(0.7, 0.7)
	caption.create_tween().tween_property(caption, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_buttons() -> void:
	done = true
	caption.text = "BANK: %d COINS" % Game.bank
	caption.add_theme_color_override("font_color", GOLD)
	caption.add_theme_font_size_override("font_size", 34)
	for k in 2:
		var b := buttons[k]
		b.disabled = false
		var y := b.position.y
		b.position.y += 60.0
		var tw := create_tween().set_parallel()
		tw.tween_interval(0.08 * k)
		tw.chain().tween_property(b, "position:y", y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate:a", 1.0, 0.25)


## Tap during the sequence: jump to the end.
func _gui_input(e: InputEvent) -> void:
	if done:
		return
	var tap := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
	if not tap:
		return
	accept_event()
	var guard := 0
	while not done and guard < 20:
		guard += 1
		for tw in tweens.duplicate():
			if tw.is_valid():
				tw.custom_step(10.0)


func _on_button(k: int) -> void:
	Sfx.play("select", 0.0)
	if k == 0:
		menu_pressed.emit()
	elif can_next:
		next_pressed.emit()
	else:
		caption.text = "MORE WORLDS COMING SOON!"


# ---------------------------------------------------------------- effects

func _shake() -> void:
	var p := stage.position
	var tw := create_tween()
	for i in 6:
		tw.tween_property(stage, "position", p + Vector2(randf_range(-8, 8), randf_range(-8, 8)), 0.03)
	tw.tween_property(stage, "position", p, 0.03)


func _burst(at: Vector2, col: Color, n: int, spd: float) -> void:
	for i in n:
		var a := randf() * TAU
		sparks.append({"p": at, "v": Vector2.from_angle(a) * spd * randf_range(0.35, 1.0),
				"life": randf_range(0.5, 0.9), "col": col, "size": randf_range(6.0, 14.0)})


func _process(delta: float) -> void:
	t += delta
	for s in sparks:
		s.p += s.v * delta
		s.v *= 0.9
		s.v.y += 900.0 * delta
		s.life -= delta
	sparks = sparks.filter(func(s: Dictionary) -> bool: return float(s.life) > 0.0)
	if done and can_next:
		var k := 1.0 + sin(t * 4.0) * 0.03
		if not buttons[1].is_pressed():
			buttons[1].scale = Vector2(k, k)
	# rewards that were won glint now and then
	for i in 4:
		var ic := slot_icons[i]
		if ic.has_meta("shine"):
			ic.modulate = Color.WHITE * (1.0 + 0.35 * maxf(0.0, sin(t * 3.0 - i * 0.8)) ** 8)
	rays.queue_redraw()
	fx.queue_redraw()


## Slowly turning light rays behind the panel's hero.
func _draw_rays() -> void:
	var c := stage.position + Vector2(ART.x * 0.5, 320.0) * stage.scale.x
	var r := size.length()
	for i in 14:
		var a := t * 0.25 + TAU * i / 14.0
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a - 0.09) * r, c + Vector2.from_angle(a + 0.09) * r])
		rays.draw_colored_polygon(pts, Color(1.0, 0.85, 0.35, 0.07))
	rays.draw_circle(c, 120.0 * stage.scale.x * 3.0, Color(1.0, 0.9, 0.5, 0.06))


func _draw_fx() -> void:
	var s := stage.scale.x
	for sp in sparks:
		var p: Vector2 = stage.position + (sp.p as Vector2) * s
		var sz := float(sp.size) * s * clampf(float(sp.life) * 2.0, 0.0, 1.0)
		var col: Color = sp.col
		fx.draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
