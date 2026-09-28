extends Control
## MUTATION LAB (LAB on the world select): buy the 5 mutation phases (MutationData).
## Painted art tools/mutation_lab_ref.webp -> tools/make_lab_assets.py -> assets/ui/lab/,
## laid out on a 941x1672 stage like the other menus. Tap a card to preview that level
## (its look on the pedestal, its stats and new power); MUTATE always buys the next
## level, with a big transformation effect. Owned cards glow green, the next one
## pulses, later ones wait behind a lock.

const DIR := "res://assets/ui/lab/"
const ART_SIZE := Vector2(941, 1672)
const COLS := [Vector2(50, 208), Vector2(220, 378), Vector2(390, 546), Vector2(555, 718), Vector2(732, 893)]
const ROWS := [Vector2(977, 1240)]  # one card per column (tools/make_lab_assets.py)
const PLATES := Vector2(1256, 1426)  # under each card: the power that phase unlocks
const BTN := {"close": Rect2(30, 48, 70, 66), "back": Rect2(98, 1492, 294, 130), "mutate": Rect2(458, 1466, 410, 176)}
const PEDESTAL := Vector2(471, 596)  # feet of the look on the pedestal
const LOOK_SCALE := 0.8  # look px -> art px on the pedestal (later levels are bigger)
const LOOK_MAX_H := 330.0  # tallest look on the pedestal (stays under the bank box)
const BAR := Rect2(207, 918, 557, 29)
const MAG := Color("ff3df0")
const GREEN := Color("5ee84c")
const GOLD := Color("ffcd75")

var t := 0.0
var stage: Control
var fx: Control  # additive glow, bubbles, sparks and card frames over the art
var look: TextureRect
var look_shadow: TextureRect
var sel := 1
var bank_label: Label
var hint1: Label
var hint2: Label
var name_label: Label
var stat_labels: Array[Label] = []
var count_label: Label
var mutate_label: Label
var buttons: Dictionary = {}
var card_prices: Array[Label] = []
var card_marks: Array[TextureRect] = []
var card_looks: Array[TextureRect] = []
var plate_labels: Array[Label] = []
var lock_tex: AtlasTexture
var bubbles: Array[Vector3] = []  # x, y, speed (art px)
var sparks: Array[Dictionary] = []
var flash := 0.0
var bar_fill := 0.0  # animated progress (levels)
var punch := 0.0


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lv := MutationData.level()
	sel = mini(lv + 1, MutationData.MAX)
	bar_fill = lv
	_build()
	resized.connect(_fit_stage)
	_fit_stage()
	_refresh()
	Sfx.play_music("menu")


# ---------------------------------------------------------------- building

func _build() -> void:
	stage = Control.new()
	stage.size = ART_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.add_child(_tex(load(DIR + "bg.webp"), Rect2(Vector2.ZERO, ART_SIZE)))
	lock_tex = AtlasTexture.new()
	lock_tex.atlas = load("res://assets/ui/world/btn_talents.png")
	lock_tex.region = Rect2(52, 28, 72, 80)
	# the look on the pedestal (and a dark copy as its shadow on the platform)
	look_shadow = _tex(null, Rect2())
	look_shadow.modulate = Color(0, 0, 0, 0.45)
	stage.add_child(look_shadow)
	look = _tex(null, Rect2())

	bank_label = _label(Rect2(478, 206, 150, 44), 34, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	hint1 = _label(Rect2(196, 622, 566, 32), 26, Color("f5a3e0"))
	hint2 = _label(Rect2(196, 654, 566, 32), 24, Color("c9d4f2"))
	name_label = _label(Rect2(108, 726, 530, 44), 38, Color("f5a3e0"), HORIZONTAL_ALIGNMENT_LEFT)
	for i in 3:
		stat_labels.append(_label(Rect2(154, 770 + i * 35, 480, 36), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
	count_label = _label(Rect2(778, 908, 100, 48), 40, MAG)

	var k := 0
	for r: Vector2 in ROWS:
		for c: Vector2 in COLS:
			k += 1
			var rect := Rect2(c.x, r.x, c.y - c.x, r.y - r.x)
			var b := Button.new()
			b.flat = true
			b.focus_mode = Control.FOCUS_NONE
			b.position = rect.position
			b.size = rect.size
			for st in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			b.pressed.connect(_select.bind(k))
			stage.add_child(b)
			var lk := _tex(load(DIR + "look_%d.png" % k), Rect2(c.x + 10, r.x + 40, c.y - c.x - 20, r.y - r.x - 92))
			lk.pivot_offset = lk.size * Vector2(0.5, 1.0)
			card_looks.append(lk)
			var p := _label(Rect2(c.x + 50, r.y - 46, c.y - c.x - 92, 38), 30, Color.WHITE)
			card_prices.append(p)
			var m := _tex(null, Rect2(c.y - 44, r.y - 44, 32, 32))
			card_marks.append(m)
			var pl := _label(Rect2(c.x + 8, PLATES.x + 52, c.y - c.x - 16, PLATES.y - PLATES.x - 64), 24, Color.WHITE)
			pl.autowrap_mode = TextServer.AUTOWRAP_WORD
			pl.text = str(MutationData.LEVELS[k].power)
			plate_labels.append(pl)
			var pb := Button.new()  # the plate selects its phase too
			pb.flat = true
			pb.focus_mode = Control.FOCUS_NONE
			pb.position = Vector2(c.x, PLATES.x)
			pb.size = Vector2(c.y - c.x, PLATES.y - PLATES.x)
			for st in ["normal", "hover", "pressed", "focus"]:
				pb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			pb.pressed.connect(_select.bind(k))
			stage.add_child(pb)

	for id: String in BTN:
		var r: Rect2 = BTN[id]
		var b := TextureButton.new()
		b.texture_normal = load(DIR + "btn_%s.png" % id)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		b.position = r.position
		b.size = r.size
		b.pivot_offset = r.size * 0.5
		b.button_down.connect(func() -> void: b.scale = Vector2(0.94, 0.94))
		b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
		b.pressed.connect(_on_button.bind(id))
		stage.add_child(b)
		buttons[id] = b
	mutate_label = _label(Rect2(500, 1562, 340, 44), 32, Color("0f3a12"))
	mutate_label.add_theme_color_override("font_outline_color", Color("c8ff9a"))
	mutate_label.add_theme_constant_override("outline_size", 6)
	mutate_label.reparent(buttons.mutate, false)
	mutate_label.position = Vector2(500, 1564) - BTN.mutate.position

	fx = Control.new()
	fx.size = ART_SIZE
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_draw_fx)
	stage.add_child(fx)
	stage.move_child(fx, 2)  # over the art and the look's shadow, under the look
	for i in 22:
		bubbles.append(Vector3(randf_range(380, 560), randf_range(300, 600), randf_range(20, 60)))


func _tex(tex: Texture2D, r: Rect2) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # before the size, or it snaps to the texture's
	rect.texture = tex
	rect.position = r.position
	rect.size = r.size
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(rect)
	return rect


func _label(r: Rect2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := UiTheme.label("", fs, col)
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color("0b1029"))
	l.set_meta("size", fs)
	stage.add_child(l)
	return l


func _fit(l: Label, text: String) -> void:
	l.text = text
	l.add_theme_font_size_override("font_size", UiTheme.fit_size(UiTheme.FONT, text, int(l.get_meta("size")), l.size.x))


func _fit_stage() -> void:
	if stage == null:
		return
	var s := maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	stage.scale = Vector2(s, s)
	stage.position = (size - ART_SIZE * s) * 0.5


# ---------------------------------------------------------------- state

func _refresh() -> void:
	var lv := MutationData.level()
	_fit(bank_label, "%d coins" % Game.bank)
	count_label.text = "%d/%d" % [lv, MutationData.MAX]
	for i in MutationData.MAX:
		var n := i + 1
		var p := card_prices[i]
		var m := card_marks[i]
		p.text = str(MutationData.cost(n))
		if n <= lv:
			p.add_theme_color_override("font_color", GREEN)
			m.texture = null
			card_looks[i].modulate = Color.WHITE
			plate_labels[i].add_theme_color_override("font_color", Color("b6f5a8"))
		elif n == lv + 1:
			p.add_theme_color_override("font_color", GOLD if Game.bank >= MutationData.cost(n) else Color("ff9aa8"))
			m.texture = null
			card_looks[i].modulate = Color(0.85, 0.85, 0.9)
			plate_labels[i].add_theme_color_override("font_color", GOLD)
		else:
			p.add_theme_color_override("font_color", Color("8a96b8"))
			m.texture = lock_tex
			card_looks[i].modulate = Color(0.42, 0.38, 0.55)
			plate_labels[i].add_theme_color_override("font_color", Color("8a96b8"))
	_show_level(sel)
	if lv >= MutationData.MAX:
		_fit(mutate_label, "FULLY MUTATED!")
	else:
		_fit(mutate_label, "LV %d  -  %d COINS" % [lv + 1, MutationData.cost(lv + 1)])
	(buttons.mutate as TextureButton).self_modulate = Color.WHITE if MutationData.can_buy() else Color(0.6, 0.65, 0.6)


func _show_level(n: int) -> void:
	var lv := MutationData.level()
	var d: Dictionary = MutationData.LEVELS[n]
	var tex: Texture2D = load(DIR + "look_%d.png" % n)
	look.texture = tex
	look.size = tex.get_size() * minf(LOOK_SCALE, LOOK_MAX_H / tex.get_size().y)
	look.pivot_offset = Vector2(look.size.x * 0.5, look.size.y)
	look.self_modulate = Color.WHITE if n <= lv + 1 else Color(0.75, 0.6, 0.85)
	look_shadow.texture = tex
	look_shadow.size = look.size * Vector2(1.0, 0.18)
	look_shadow.position = PEDESTAL - Vector2(look.size.x * 0.5, look_shadow.size.y * 0.55)
	var tag := "OWNED" if n <= lv else ("NEXT" if n == lv + 1 else "LOCKED")
	_fit(name_label, "Lv %d  %s  (%s)" % [n, str(d.power), tag])
	name_label.add_theme_color_override("font_color", GREEN if n <= lv else (MAG.lerp(Color.WHITE, 0.3)))
	# totals at this level (green: what buying up to it would add)
	var col := Color.WHITE if n <= lv else GREEN
	var lines := [
		"+%d%% ATK   (every run)" % roundi(MutationData.atk_bonus(n) * 100.0),
		"+%d%% mutant power   %.1fs mutation" % [roundi((MutationData.power(n) / MutationData.power(1) - 1.0) * 100.0), MutationData.duration(n)],
		"+%.1f%% speed   (every run)" % (MutationData.speed_bonus(n) * 100.0),
	]
	for i in 3:
		_fit(stat_labels[i], lines[i])
		stat_labels[i].add_theme_color_override("font_color", col)
	_fit(hint1, "NEW POWER: " + str(d.power))
	_fit(hint2, str(d.desc))


func _select(n: int) -> void:
	if n == sel:
		return
	sel = n
	Sfx.play("select", 0.0)
	punch = 1.0
	_show_level(n)


# ---------------------------------------------------------------- actions

func _on_button(id: String) -> void:
	match id:
		"close", "back":
			Sfx.play("select", 0.0)
			get_tree().change_scene_to_file(Game.menu_scene)
		"mutate":
			_mutate()


func _mutate() -> void:
	var lv := MutationData.level()
	if lv >= MutationData.MAX:
		_select(MutationData.MAX)
		_pop_text("FULLY MUTATED!", GOLD)
		return
	if not MutationData.buy():
		Sfx.play("hurt", 0.0, -6.0)
		_pop_text("NEED %d MORE COINS" % (MutationData.cost(lv + 1) - Game.bank), Color("ff5566"))
		var b: TextureButton = buttons.mutate
		var x := b.position.x
		var tw := create_tween()
		for i in 4:
			tw.tween_property(b, "position:x", x + (10.0 if i % 2 == 0 else -10.0), 0.04)
		tw.tween_property(b, "position:x", x, 0.04)
		return
	# mutated!
	var n := lv + 1
	sel = n
	flash = 1.0
	punch = 1.6
	Sfx.play("mutate", 0.0)
	Sfx.play("upgrade", 0.0, -2.0)
	_refresh()
	var feet := PEDESTAL
	_burst(feet + Vector2(0, -look.size.y * 0.5), MAG, 60, 900.0)
	_burst(feet + Vector2(0, -look.size.y * 0.5), GREEN, 30, 600.0)
	_burst(_card_rect(n).get_center(), GREEN, 26, 500.0)
	_pop_text("NEW POWER: %s!" % str(MutationData.LEVELS[n].power), MAG.lerp(Color.WHITE, 0.25))
	var st := create_tween()
	var p := stage.position
	for i in 8:
		st.tween_property(stage, "position", p + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.03)
	st.tween_property(stage, "position", p, 0.03)
	var bt := create_tween()
	bt.tween_property(self, "bar_fill", float(n), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _pop_text(text: String, col: Color) -> void:
	var l := _label(Rect2(60, 420, 821, 70), 54, col)
	_fit(l, text)
	l.add_theme_constant_override("outline_size", 16)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.3, 0.3)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.parallel().tween_property(l, "position:y", l.position.y - 40.0, 1.3)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func _card_rect(n: int) -> Rect2:
	var c: Vector2 = COLS[(n - 1) % 5]
	var r: Vector2 = ROWS[floori((n - 1) / 5.0)]
	return Rect2(c.x, r.x, c.y - c.x, r.y - r.x)


func _burst(at: Vector2, col: Color, n: int, spd: float) -> void:
	for i in n:
		sparks.append({"p": at, "v": Vector2.from_angle(randf() * TAU) * spd * randf_range(0.3, 1.0),
				"life": randf_range(0.5, 1.0), "col": col, "size": randf_range(6.0, 14.0)})


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 1.6)
	punch = maxf(0.0, punch - delta * 4.0)
	# the look floats and breathes on the pedestal; a new pick / mutation punches in
	var bob := sin(t * 1.8) * 6.0
	look.position = PEDESTAL - Vector2(look.size.x * 0.5, look.size.y) + Vector2(0, bob - 8.0)
	var br := 1.0 + sin(t * 2.6) * 0.015
	var pk := 1.0 + punch * 0.12
	look.scale = Vector2(pk / br, pk * br)
	var lv := MutationData.level()
	look.modulate = Color.WHITE.lerp(Color(2.2, 1.2, 2.2), flash) if sel <= lv + 1 else Color(0.35, 0.3, 0.45)
	# the selected card's mutant idles, owned ones breathe slowly
	for i in card_looks.size():
		var cl := card_looks[i]
		var on := i + 1 == sel
		var amp := 0.05 if on else (0.015 if i < lv else 0.0)
		cl.scale = Vector2(1.0, 1.0 + sin(t * (5.0 if on else 2.0) + i) * amp)
	for b in bubbles:
		b.y -= b.z * delta
		if b.y < 300.0:
			b.y = 600.0
			b.x = randf_range(380, 560)
	for s in sparks:
		s.p += s.v * delta
		s.v *= 0.9
		s.v.y += 700.0 * delta
		s.life -= delta
	sparks = sparks.filter(func(s: Dictionary) -> bool: return float(s.life) > 0.0)
	var mb: TextureButton = buttons.mutate
	if MutationData.can_buy() and not mb.is_pressed():
		var k := 1.0 + sin(t * 4.0) * 0.03
		mb.scale = Vector2(k, k)
	fx.queue_redraw()


func _draw_fx() -> void:
	var lv := MutationData.level()
	# pedestal glow and rising bubbles in the beam
	var g := 0.5 + 0.5 * sin(t * 2.2)
	for i in 4:
		var rr := 150.0 - i * 30.0
		fx.draw_set_transform(PEDESTAL + Vector2(0, -4), 0.0, Vector2(1.0, 0.28))
		fx.draw_circle(Vector2.ZERO, rr, Color(1.0, 0.25, 0.95, (0.05 + g * 0.05 + flash * 0.25)))
	fx.draw_set_transform(Vector2.ZERO)
	for b in bubbles:
		var a := clampf((b.y - 300.0) / 120.0, 0.0, 1.0) * 0.7
		fx.draw_circle(Vector2(b.x + sin(t * 2.0 + b.z) * 6.0, b.y), 2.0 + b.z * 0.05, Color(1.0, 0.6, 1.0, a))
	# progress segments
	var seg_w := BAR.size.x / MutationData.MAX
	for i in MutationData.MAX:
		var r := Rect2(BAR.position.x + i * seg_w + 3, BAR.position.y + 3, seg_w - 6, BAR.size.y - 6)
		var fill := clampf(bar_fill - i, 0.0, 1.0)
		if fill > 0.0:
			fx.draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), MAG)
			fx.draw_rect(Rect2(r.position, Vector2(r.size.x * fill, 5)), Color(1, 0.75, 1))
		elif i == lv:
			fx.draw_rect(r, Color(1.0, 0.24, 0.94, 0.15 + 0.15 * sin(t * 5.0)))
	# card frames: owned green, next pulsing gold, selected magenta, locked dim
	for n in range(1, MutationData.MAX + 1):
		var r := _card_rect(n).grow(-2.0)
		var col := Color("3a4a78")
		var w := 6.0
		if n <= lv:
			col = GREEN
		elif n == lv + 1:
			col = GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 5.0))
		if n == sel:
			col = MAG.lerp(Color.WHITE, 0.25 + 0.2 * sin(t * 6.0))
			w = 8.0
			fx.draw_rect(r.grow(6.0), Color(1.0, 0.24, 0.94, 0.25), false, 8.0)
		fx.draw_rect(r, col, false, w)
		if n <= lv:
			_draw_check(Vector2(r.end.x - 30, r.end.y - 26))
		# power plate under the card, framed in the card's colour
		var pr := Rect2(r.position.x, PLATES.x, r.size.x, PLATES.y - PLATES.x)
		fx.draw_rect(pr, Color("0b1029"))
		fx.draw_rect(Rect2(pr.position, Vector2(pr.size.x, 40)), col.darkened(0.55))
		fx.draw_rect(pr, col, false, 4.0 if n != sel else 6.0)
		fx.draw_string(UiTheme.FONT, pr.position + Vector2(0, 30), "POWER", HORIZONTAL_ALIGNMENT_CENTER,
				pr.size.x, 22, Color(1, 1, 1, 0.85))
	# sparks
	for s in sparks:
		var sz := float(s.size) * clampf(float(s.life) * 2.0, 0.0, 1.0)
		fx.draw_rect(Rect2((s.p as Vector2) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), s.col)
	if flash > 0.0:
		fx.draw_rect(Rect2(Vector2.ZERO, ART_SIZE), Color(1.0, 0.3, 1.0, flash * 0.25))


func _draw_check(c: Vector2) -> void:
	fx.draw_rect(Rect2(c - Vector2(16, 16), Vector2(32, 32)), Color("0b2a14"))
	fx.draw_rect(Rect2(c - Vector2(16, 16), Vector2(32, 32)), GREEN, false, 3.0)
	fx.draw_polyline(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(-3, 7), c + Vector2(10, -8)]), GREEN, 5.0)
