extends Control
## ARMORY: buy, equip and level up the 10 weapons (GunData) and raise the crew's ATTACK
## and LIFE levels with banked coins. Painted kit from tools/make_armory_assets.py
## (assets/ui/armory/), laid out on a 941x1672 stage (tools/armory_ref.webp) fitted to the
## safe area. The weapon on show fires its real shots on the holo range (GunDemo); the
## SUITS tab is the slot reserved for space suits.

const ART := Vector2(941, 1672)
const DIR := "res://assets/ui/armory/"

const DETAIL := Rect2(495, 188, 430, 750)
const TABS_Y := 952.0
const PANEL := Rect2(18, 1002, 906, 213)
const STRIP := Rect2(80, 1022, 782, 168)  # visible part of the weapon carousel
const SLOT := Vector2(180, 150)
const SLOT_GAP := 20.0
const CARDS_Y := 1232.0
const BTN_Y := 1524.0
const HERO_Y := 700.0  # the astronaut's feet on the pedestal

const C_TEXT := Color("e8eefc")
const C_DIM := Color("8392bb")
const C_GOLD := Color("ffd04a")
const C_GREEN := Color("5ee84c")
const C_CYAN := Color("73eff7")

var stage: Control
var labels: Dictionary = {}
var hero: Sprite2D
var pedestal: TextureRect
var glow: Control
var demo: GunDemo
var strip: Control  # clips the carousel
var row: Control  # the 10 slots, slides inside the strip
var slots: Array[Control] = []
var detail_btns: Control
var level_row: Control
var cards: Dictionary = {}
var toast: Label
var sel := "pulse"
var first := 0  # first slot shown in the carousel
var t := 0.0
var hop_t := 0.0
var drag_from := Vector2.INF
var swipe_ms := -1000  # a swipe just scrolled the carousel: ignore the slot tap it ends on
var motes: Array = []  # [pos, speed, life] holo motes rising from the pedestal


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = ART
	add_child(stage)
	var bg := TextureRect.new()
	bg.texture = load(DIR + "bg.webp")
	bg.size = ART
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	UiTheme.add_backdrop(self, stage, bg.texture)
	_build()
	# tall phones: top bar pinned up, ATTACK/LIFE cards pinned down; the hangar grows
	UiTheme.set_seams(stage, [[195.0, 1.0, 1], [1222.0, 1.0, 1]], 1)
	resized.connect(_fit)
	_fit()
	sel = Game.gun
	first = clampi(GunData.index(sel) - 1, 0, _max_first())
	row.position.x = -first * (SLOT.x + SLOT_GAP)
	_refresh()
	_show_detail(true)
	Sfx.play_music("menu")
	if Game.gear_refund > 0:
		_toast("Old gear refunded: +%s coins!" % _fmt(Game.gear_refund), 2.6)
		Game.gear_refund = 0


func _fit() -> void:
	UiTheme.fit_stage(self, stage, ART)


# ---------------------------------------------------------------- building blocks

func _label(parent: Control, r: Rect2, text: String, fs: int, col := C_TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = r.position
	l.size = r.size
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", maxi(6, roundi(fs / 4.0)))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("fs", fs)
	parent.add_child(l)
	return l


## Sets text, shrinking the font (from the label's own size) so it fits its width.
func _put(l: Label, text: String, col := Color(0, 0, 0, 0)) -> void:
	l.text = text
	var fs := int(l.get_meta("fs", 24))
	l.add_theme_font_size_override("font_size", UiTheme.fit_size(UiTheme.FONT, text, fs, l.size.x - 4.0))
	if col.a > 0.0:
		l.add_theme_color_override("font_color", col)


## Smooth body text (descriptions), wrapped.
func _body(parent: Control, r: Rect2, text: String, fs: int, col := Color("c9d4f2")) -> Label:
	var l := UiTheme.body(text, fs, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(r.size.x, 0)
	l.position = r.position
	l.size = r.size
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _img(parent: Control, file: String, r: Rect2) -> TextureRect:
	var i := TextureRect.new()
	i.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	i.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if file != "":
		i.texture = load(DIR + file)
	i.position = r.position
	i.size = r.size
	i.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(i)
	return i


## A kit frame stretched to `r` keeping its corners (`m` px of border on every side).
func _nine(parent: Control, file: String, r: Rect2, m: int) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(DIR + file)
	n.position = r.position
	n.size = r.size
	n.patch_margin_left = m
	n.patch_margin_right = m
	n.patch_margin_top = m
	n.patch_margin_bottom = m
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n


## Invisible button over `r` that squashes `look` (or itself) when pressed.
func _hit_area(parent: Control, r: Rect2, cb: Callable, look: Control = null) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = r.position
	b.size = r.size
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	var v: Control = look if look != null else b
	b.button_down.connect(func() -> void:
		v.pivot_offset = v.size * 0.5
		v.scale = Vector2(0.94, 0.94))
	b.button_up.connect(func() -> void: v.scale = Vector2.ONE)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Coin icon + amount centred in `r`.
func _price(parent: Control, r: Rect2, amount: int, fs: int, col := Color.WHITE) -> void:
	var txt := _fmt(amount)
	var coin := fs * 1.2
	var tw := UiTheme.FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := r.position.x + (r.size.x - (coin + 8.0 + tw)) * 0.5
	_img(parent, "icon_coin.png", Rect2(x, r.position.y + (r.size.y - coin) * 0.5, coin, coin))
	_label(parent, Rect2(x + coin + 8.0, r.position.y, tw + 12.0, r.size.y), txt, fs, col)


func _fmt(n: int) -> String:
	var s := str(n)
	return s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3) if n >= 1000 else s


# ---------------------------------------------------------------- layout

func _build() -> void:
	# top bar
	var back := _img(stage, "back.png", Rect2(16, 14, 92, 84))
	_hit_area(stage, back.get_rect(), _back, back)
	var pw := _img(stage, "pill_power.png", Rect2(436, 18, 226, 76))
	labels.power = _label(stage, Rect2(490, 26, 110, 56), "", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_hit_area(stage, pw.get_rect(), func() -> void:
		_toast("POWER grows with better weapons and ATTACK / LIFE levels!"), pw)
	var cp := _img(stage, "pill_coins.png", Rect2(672, 18, 252, 76))
	labels.coins = _label(stage, Rect2(742, 26, 110, 56), "", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_hit_area(stage, cp.get_rect(), func() -> void:
		_toast("Earn coins by cleaning alien ships!"), cp)
	_nine(stage, "banner.png", Rect2(110, 106, 410, 76), 26)
	var title := _label(stage, Rect2(130, 110, 370, 68), "ARMORY", 50, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 14)

	_build_hero()
	_build_detail()
	_build_carousel()
	_build_cards()

	toast = _label(self, Rect2(0, 0, 10, 10), "", 16, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	toast.set_meta("fs", 16)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.size = Vector2(320, 70)
	toast.position -= toast.size * 0.5
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(0.03, 0.05, 0.12, 0.92)
	tb.border_color = Color("41a6f6")
	tb.set_border_width_all(2)
	tb.set_corner_radius_all(8)
	tb.set_content_margin_all(10)
	toast.add_theme_stylebox_override("normal", tb)
	toast.modulate.a = 0.0


func _build_hero() -> void:
	pedestal = _img(stage, "pedestal.png", Rect2(40, HERO_Y - 62.0, 430, 260))
	glow = Control.new()
	glow.position = Vector2(40, HERO_Y - 62.0)
	glow.size = Vector2(430, 260)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.draw.connect(_draw_glow)
	stage.add_child(glow)
	hero = Sprite2D.new()
	hero.texture = load(DIR + "astronaut.png")
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hero.centered = false
	var ts := hero.texture.get_size()
	hero.offset = Vector2(-ts.x * 0.5, -ts.y)  # feet at the node
	hero.position = Vector2(258, HERO_Y)
	hero.scale = Vector2(1.08, 1.08)
	stage.add_child(hero)
	_hit_area(stage, Rect2(130, HERO_Y - 350.0, 260, 360), _poke_hero)


## Pulsing light on the pedestal's ring and holo motes rising from it.
func _draw_glow() -> void:
	var c := Vector2(215, 52)
	var p := 0.5 + 0.5 * sin(t * 2.4)
	glow.draw_set_transform(c, 0.0, Vector2(1.0, 0.3))
	for i in 3:
		var r := 150.0 - i * 40.0 + p * 6.0
		glow.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.25, 0.6, 1.0, 0.18 + 0.12 * p), 6.0 - i)
	glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var col := GunData.color(Game.gun)
	for m: Array in motes:
		var a := clampf(float(m[2]), 0.0, 1.0)
		glow.draw_circle(m[0], 3.0, Color(col, a * 0.8))


func _build_detail() -> void:
	var d := Control.new()
	d.position = DETAIL.position
	d.size = DETAIL.size
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(d)
	labels.detail = d
	_nine(d, "detail.png", Rect2(Vector2.ZERO, DETAIL.size), 44)
	labels.name = _label(d, Rect2(30, 30, 370, 50), "", 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	labels.tag = _label(d, Rect2(30, 82, 370, 30), "", 22, C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_nine(d, "bracket.png", Rect2(22, 124, 386, 166), 30)
	demo = GunDemo.new()
	demo.position = Vector2(34, 134)
	demo.size = Vector2(362, 146)
	d.add_child(demo)
	level_row = Control.new()  # weapon level dots, top-left of the holo range
	level_row.position = Vector2(30, 136)
	level_row.size = Vector2(96, 24)
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_child(level_row)
	labels.ability = _label(d, Rect2(34, 304, 362, 36), "", 28, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	labels.desc = _body(d, Rect2(40, 344, 350, 60), "", 19)
	labels.desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.mod = _label(d, Rect2(34, 408, 362, 30), "", 21, C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var icons := ["icon_dmg.png", "icon_rate.png", "icon_range.png"]
	var names := ["DAMAGE", "FIRE RATE", "RANGE"]
	for i in 3:
		var y := 452.0 + i * 60.0
		_nine(d, "pill.png", Rect2(22, y, 386, 50), 16)
		_img(d, icons[i], Rect2(38, y + 9, 34, 32))
		_label(d, Rect2(82, y, 132, 50), names[i], 21, Color("9fc4ff"))
		labels["stat%d" % i] = _label(d, Rect2(228, y, 116, 50), "", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		labels["bonus%d" % i] = _label(d, Rect2(344, y, 54, 50), "", 20, C_GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	detail_btns = Control.new()
	detail_btns.position = Vector2(22, 642)
	detail_btns.size = Vector2(386, 70)
	detail_btns.mouse_filter = Control.MOUSE_FILTER_PASS
	d.add_child(detail_btns)


func _build_carousel() -> void:
	# tabs: WEAPONS (open) and SUITS (the space for the space suits, coming soon)
	var wt := _nine(stage, "pill.png", Rect2(24, TABS_Y - 10.0, 300, 56), 16)
	wt.modulate = Color(1.25, 1.25, 1.4)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = GunData.icon("pulse")
	ic.position = Vector2(22, 10)
	ic.size = Vector2(54, 36)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	wt.add_child(ic)
	_label(wt, Rect2(92, 0, 190, 56), "WEAPONS", 28, Color.WHITE)
	var st := _nine(stage, "pill.png", Rect2(344, TABS_Y - 10.0, 290, 56), 16)
	st.modulate = Color(0.7, 0.72, 0.85)
	_label(st, Rect2(28, 0, 110, 56), "SUITS", 26, C_DIM)
	var soon := _label(st, Rect2(160, 12, 104, 32), "SOON", 20, Color("1a1c2c"), HORIZONTAL_ALIGNMENT_CENTER)
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_GOLD
	sb.set_corner_radius_all(8)
	soon.add_theme_stylebox_override("normal", sb)
	soon.add_theme_constant_override("outline_size", 0)
	_hit_area(stage, st.get_rect(), func() -> void:
		Sfx.play("select", 0.0)
		_toast("SPACE SUITS are coming soon: new looks and perks for your crew!"), st)

	_img(stage, "weapons.png", PANEL)
	strip = Control.new()
	strip.position = STRIP.position
	strip.size = STRIP.size
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(strip)
	row = Control.new()
	row.size = Vector2(GunData.GUNS.size() * (SLOT.x + SLOT_GAP), STRIP.size.y)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	strip.add_child(row)
	for i in GunData.GUNS.size():
		var s := Control.new()
		s.position = Vector2(i * (SLOT.x + SLOT_GAP), (STRIP.size.y - SLOT.y) * 0.5)
		s.size = SLOT
		s.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(s)
		slots.append(s)
	var al := _img(stage, "arrow_l.png", Rect2(PANEL.position.x + 2, PANEL.position.y + 70, 50, 72))
	_hit_area(stage, al.get_rect().grow(14), _scroll.bind(-1), al)
	var ar := _img(stage, "arrow_r.png", Rect2(PANEL.end.x - 54, PANEL.position.y + 70, 50, 72))
	_hit_area(stage, ar.get_rect().grow(14), _scroll.bind(1), ar)
	labels.arrow_l = al
	labels.arrow_r = ar


func _build_cards() -> void:
	for k: String in ["power", "health"]:
		var x := 25.0 if k == "power" else 477.0
		var c := Control.new()
		c.position = Vector2(x, CARDS_Y)
		c.size = Vector2(440, 282)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(c)
		_img(c, "card_attack.png" if k == "power" else "card_life.png", Rect2(0, 0, 440, 282))
		var title := _label(c, Rect2(198, 18, 214, 50), "ATTACK" if k == "power" else "LIFE", 46, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		title.add_theme_constant_override("outline_size", 12)
		var lv := _label(c, Rect2(200, 72, 202, 56), "", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var hint := _label(c, Rect2(200, 134, 210, 44), "ALL WEAPONS" if k == "power" else "MORE HITS", 20, C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		hint.add_theme_constant_override("outline_size", 6)
		_label(c, Rect2(52, 192, 150, 62), "DAMAGE" if k == "power" else "MAX HP", 24, Color("9fc4ff"))
		var stat := _label(c, Rect2(190, 192, 206, 62), "", 28, C_GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
		var btn := Control.new()
		btn.position = Vector2(x + 11.0, BTN_Y)
		btn.size = Vector2(421, 99)
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		stage.add_child(btn)
		cards[k] = {"card": c, "level": lv, "stat": stat, "btn": btn}


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	_put(labels.power, str(Game.crew_power()))
	_put(labels.coins, _fmt(Game.bank))
	_refresh_slots()
	_refresh_cards()


func _refresh_slots() -> void:
	for i in slots.size():
		var s := slots[i]
		for c in s.get_children():
			c.queue_free()
		var id: String = GunData.GUNS[i].id
		var owned := Game.owns_gun(id)
		var equipped := id == Game.gun
		var frame := "slot_sel.png" if equipped else ("slot_pick.png" if id == sel else "slot.png")
		var f := _nine(s, frame, Rect2(Vector2.ZERO, SLOT), 18)
		if id == sel and not equipped:
			f.modulate = Color(1.2, 1.2, 1.2)
		_label(s, Rect2(12, 6, 50, 26), "%02d" % (i + 1), 18, GunData.role_color(id))
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = GunData.icon(id)
		icon.position = Vector2(14, 22)
		icon.size = Vector2(SLOT.x - 28, 82)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(icon)
		var foot := Rect2(8, 106, SLOT.x - 16, 36)
		if equipped:
			var bar := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("f2b632")
			sb.set_corner_radius_all(6)
			bar.add_theme_stylebox_override("panel", sb)
			bar.position = foot.position
			bar.size = foot.size
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.add_child(bar)
			_label(s, foot, "EQUIPPED", 22, Color("2a1a08"), HORIZONTAL_ALIGNMENT_CENTER).add_theme_constant_override("outline_size", 0)
			_pips(s, Vector2(SLOT.x - 70, 8), Game.gun_level(id), 18.0)
		elif owned:
			_pips(s, Vector2((SLOT.x - 3 * 26) * 0.5, 112), Game.gun_level(id), 24.0)
		else:
			icon.modulate = Color(0.32, 0.36, 0.5)
			var can := Game.bank >= GunData.price(id)
			_price(s, foot, GunData.price(id), 24, C_GREEN if can else Color("ff8a8a"))
		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.size = SLOT
		var empty := StyleBoxEmpty.new()
		for stn in ["normal", "hover", "pressed", "focus"]:
			hit.add_theme_stylebox_override(stn, empty)
		hit.mouse_filter = Control.MOUSE_FILTER_PASS
		hit.pressed.connect(_pick.bind(id))
		s.add_child(hit)
	labels.arrow_l.modulate.a = 1.0 if first > 0 else 0.35
	labels.arrow_r.modulate.a = 1.0 if first < _max_first() else 0.35


## `lv` of 3 lit level dots from `at`.
func _pips(parent: Control, at: Vector2, lv: int, sz: float) -> void:
	for k in GunData.MAX_LEVEL:
		_img(parent, "dot_on.png" if k < lv else "dot_off.png", Rect2(at + Vector2(k * (sz + 4.0), 0), Vector2(sz, sz)))


func _refresh_cards() -> void:
	for k: String in cards:
		var c: Dictionary = cards[k]
		var lv := int(Game.perm[k])
		var mx := int(Game.PERM[k].max)
		var lvl_l: Label = c.level
		lvl_l.text = "LEVEL %d" % lv
		var stat: Label = c.stat
		if k == "power":
			var now := roundi(Game.ATTACK_STEP * 100.0 * lv)
			stat.text = "+%d%%" % now if lv >= mx else "+%d%% > +%d%%" % [now, now + roundi(Game.ATTACK_STEP * 100.0)]
		else:
			var hp := roundi(Game.BASE_HP * (1.0 + Game.LIFE_STEP * lv))
			var nx := roundi(Game.BASE_HP * (1.0 + Game.LIFE_STEP * (lv + 1)))
			stat.text = str(hp) if lv >= mx else "%d > %d" % [hp, nx]
		stat.set_meta("fs", 28)
		_put(stat, stat.text)
		var btn: Control = c.btn
		for ch in btn.get_children():
			ch.queue_free()
		var maxed := lv >= mx
		var cost := Game.perm_cost(k)
		var face := _img(btn, "btn_green.png", Rect2(Vector2.ZERO, btn.size))
		face.stretch_mode = TextureRect.STRETCH_SCALE
		if maxed:
			face.modulate = Color(0.55, 0.6, 0.6)
			_label(btn, Rect2(0, 0, 421, 92), "MAX LEVEL", 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			if Game.bank < cost:
				face.modulate = Color(0.62, 0.66, 0.66)
			_label(btn, Rect2(24, 0, 200, 92), "UPGRADE", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER).add_theme_constant_override("outline_size", 12)
			_price(btn, Rect2(214, 0, 190, 92), cost, 36)
		_hit_area(btn, Rect2(Vector2.ZERO, btn.size), _upgrade_perm.bind(k), face)


## The detail panel for `sel` (its holo range restarts when `new_gun`).
func _show_detail(new_gun: bool) -> void:
	var id := sel
	var g := GunData.gun(id)
	var owned := Game.owns_gun(id)
	var lv := maxi(1, Game.gun_level(id))
	_put(labels.name, str(g.name))
	_put(labels.tag, "%s  -  POWER %d" % [g.role, GunData.power(id, lv)], GunData.role_color(id))
	_put(labels.ability, str(g.ability))
	labels.desc.text = str(g.desc)
	if new_gun:
		demo.show_gun(id, owned)
	# stats at the weapon's level (Lv1 if not owned yet), with ATTACK's share in green
	var base := 10.0 * float(g.dmg) * GunData.level_mult(lv)
	var full := base * (1.0 + Game.ATTACK_STEP * int(Game.perm.power))
	var prm := GunData.params(id, lv)
	var mult := int(prm.get("pellets", prm.get("flakes", prm.get("rockets", 1))))
	_put(labels.stat0, ("%d x%d" % [roundi(full), mult]) if mult > 1 else str(roundi(full)))
	var bonus := roundi(full - base)
	labels.bonus0.text = "+%d" % bonus if bonus > 0 else "+0"
	_put(labels.stat1, GunData.rate_label(id))
	_put(labels.stat2, str(g.range))
	labels.bonus1.text = ""
	labels.bonus2.text = ""
	_build_level_row(id, owned, lv)
	_build_detail_buttons(id, owned, lv)


func _build_level_row(id: String, owned: bool, lv: int) -> void:
	for c in level_row.get_children():
		c.queue_free()
	_pips(level_row, Vector2(14, 0), Game.gun_level(id) if owned else 0, 22.0)
	var mod_on := owned and lv >= GunData.MAX_LEVEL
	var mod: Label = labels.mod
	_put(mod, "LV3 BONUS: " + str(GunData.gun(id).mod), Color("d68cff") if mod_on else C_DIM)


func _build_detail_buttons(id: String, owned: bool, lv: int) -> void:
	for c in detail_btns.get_children():
		c.queue_free()
	var w := detail_btns.size.x
	var h := detail_btns.size.y
	if not owned:
		var face := _nine(detail_btns, "btn_green.png", Rect2(0, 0, w, h), 24)
		if Game.bank < GunData.price(id):
			face.modulate = Color(0.62, 0.66, 0.66)
		_label(detail_btns, Rect2(18, 0, 120, h - 6), "BUY", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER).add_theme_constant_override("outline_size", 12)
		_price(detail_btns, Rect2(130, 0, w - 150, h - 6), GunData.price(id), 34)
		_hit_area(detail_btns, Rect2(0, 0, w, h), _buy.bind(id), face)
		return
	var half := (w - 10.0) * 0.5
	var equipped := id == Game.gun
	var eq := _nine(detail_btns, "btn_blue.png", Rect2(0, 0, half, h), 24)
	if equipped:
		eq.modulate = Color(0.55, 0.6, 0.7)
	_label(detail_btns, Rect2(0, 0, half, h - 6), "EQUIPPED" if equipped else "EQUIP", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if not equipped:
		_hit_area(detail_btns, Rect2(0, 0, half, h), _equip.bind(id), eq)
	var r := Rect2(half + 10.0, 0, half, h)
	var up := _nine(detail_btns, "btn_green.png", r, 24)
	if lv >= GunData.MAX_LEVEL:
		up.modulate = Color(0.55, 0.6, 0.6)
		_label(detail_btns, Rect2(r.position, Vector2(half, h - 6)), "MAX LV", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var cost := GunData.upgrade_cost(id, lv)
	if Game.bank < cost:
		up.modulate = Color(0.62, 0.66, 0.66)
	_label(detail_btns, Rect2(r.position.x, 4, half, 28), "TO LV %d" % (lv + 1), 20, Color("eaffd8"), HORIZONTAL_ALIGNMENT_CENTER)
	_price(detail_btns, Rect2(r.position.x, 28, half, 34), cost, 28)
	_hit_area(detail_btns, r, _upgrade_gun.bind(id), up)


# ---------------------------------------------------------------- actions

func _pick(id: String) -> void:
	if id == sel or Time.get_ticks_msec() - swipe_ms < 200:
		return
	Sfx.play("select", 0.0)
	sel = id
	_refresh_slots()
	_show_detail(true)


func _scroll(d: int) -> void:
	var n := clampi(first + d, 0, _max_first())
	if n == first:
		return
	Sfx.play("select", 0.0, -4.0)
	first = n
	var tw := row.create_tween()
	tw.tween_property(row, "position:x", -first * (SLOT.x + SLOT_GAP), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	labels.arrow_l.modulate.a = 1.0 if first > 0 else 0.35
	labels.arrow_r.modulate.a = 1.0 if first < _max_first() else 0.35


func _max_first() -> int:
	return GunData.GUNS.size() - 4


func _buy(id: String) -> void:
	var cost := GunData.price(id)
	if Game.buy_gun(id):
		Sfx.play("upgrade", 0.0)
		_celebrate("NEW WEAPON!", str(GunData.gun(id).name), GunData.color(id))
		_refresh()
		_show_detail(true)
	else:
		_no_coins(cost)


func _equip(id: String) -> void:
	Game.equip_gun(id)
	Sfx.play("shield", 0.0)
	_toast("%s equipped!" % GunData.gun(id).name)
	_hero_hop()
	_refresh()
	_show_detail(false)


func _upgrade_gun(id: String) -> void:
	var cost := GunData.upgrade_cost(id, Game.gun_level(id))
	if Game.upgrade_gun(id):
		Sfx.play("upgrade", 0.0)
		var lv := Game.gun_level(id)
		var sub := str(GunData.gun(id).mod) if lv >= GunData.MAX_LEVEL else "+%d%% damage" % roundi(GunData.LEVEL_DMG * 100.0)
		_celebrate("LEVEL %d!" % lv, sub, GunData.color(id))
		_refresh()
		_show_detail(false)
	else:
		_no_coins(cost)


func _upgrade_perm(k: String) -> void:
	if int(Game.perm[k]) >= int(Game.PERM[k].max):
		return
	var cost := Game.perm_cost(k)
	if Game.buy_perm(k):
		Sfx.play("upgrade", 0.0)
		var c: Control = cards[k].card
		_sparkle(UiTheme.to_screen(stage, c.position + c.size * 0.5),
				Color("ff6a3a") if k == "power" else C_GREEN)
		c.pivot_offset = c.size * 0.5
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2(1.04, 1.04), 0.08)
		tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
		_refresh()
		_show_detail(false)
	else:
		_no_coins(cost)


func _no_coins(cost: int) -> void:
	Sfx.play("hurt", 0.0, -8.0)
	_toast("Need %s more coins - clean more ships!" % _fmt(cost - Game.bank))


func _back() -> void:
	Sfx.play("select", 0.0)
	get_tree().change_scene_to_file(Game.menu_scene)


func _poke_hero() -> void:
	_hero_hop()
	Sfx.play(str(GunFire.SOUNDS[str(GunData.gun(Game.gun).kind)][0]), 0.1, -6.0)


func _hero_hop() -> void:
	hop_t = 0.0
	for i in 14:
		motes.append([Vector2(215 + randf_range(-120, 120), 60 + randf_range(-20, 20)), randf_range(60, 140), 1.0])


# ---------------------------------------------------------------- feedback

## Big centred banner (title + subtitle in the weapon's colour) with a burst of sparks.
func _celebrate(head: String, sub: String, col: Color) -> void:
	var c := UiTheme.to_screen(stage, DETAIL.position + DETAIL.size * Vector2(0.5, 0.31))
	_sparkle(c, col)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var h := UiTheme.title(head, 28, C_GOLD, 300.0)
	box.add_child(h)
	var s := UiTheme.label(sub, UiTheme.fit_size(UiTheme.FONT, sub, 14, 300.0), col.lightened(0.4))
	s.add_theme_constant_override("outline_size", 6)
	box.add_child(s)
	box.size = Vector2(320, 70)
	box.position = Vector2(size.x * 0.5 - 160.0, size.y * 0.42 - 35.0)
	box.pivot_offset = box.size * 0.5
	box.scale = Vector2(0.3, 0.3)
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(box.queue_free)
	_hero_hop()


func _sparkle(at: Vector2, col: Color) -> void:
	for i in 22:
		var dot := ColorRect.new()
		dot.size = Vector2(4, 4)
		dot.color = [col, C_GOLD, Color.WHITE][i % 3]
		dot.position = at
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(30, 95)
		var tw := dot.create_tween().set_parallel()
		tw.tween_property(dot, "position", at + dir, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(dot, "modulate:a", 0.0, 0.55)
		tw.chain().tween_callback(dot.queue_free)


func _toast(text: String, secs := 1.6) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	move_child(toast, -1)
	var tw := toast.create_tween()
	tw.tween_interval(secs)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)


# ---------------------------------------------------------------- input / animation

func _input(event: InputEvent) -> void:
	# swipe the weapon carousel (mouse arrives as touch: emulate_touch_from_mouse)
	var st := event as InputEventScreenTouch
	if st == null:
		return
	var local := UiTheme.to_art(stage, st.position)
	if st.pressed and STRIP.has_point(local):
		drag_from = local
	elif not st.pressed and drag_from != Vector2.INF:
		var dx := local.x - drag_from.x
		drag_from = Vector2.INF
		if absf(dx) > 60.0:
			var n := ceili(absf(dx) / (SLOT.x + SLOT_GAP))
			swipe_ms = Time.get_ticks_msec()
			_scroll(-n if dx > 0.0 else n)


func _process(delta: float) -> void:
	t += delta
	hop_t += delta
	# breathing, plus a hop when a weapon is equipped (feet stay on the pedestal)
	var b := sin(t * 2.2) * 0.012
	var hop := 0.0
	if hop_t < 0.35:
		hop = sin(hop_t / 0.35 * PI) * 22.0
	hero.position.y = HERO_Y - hop
	hero.scale = Vector2(1.08 * (1.0 + b * 0.5), 1.08 * (1.0 + b))
	# holo motes
	if randf() < delta * 6.0:
		motes.append([Vector2(215 + randf_range(-110, 110), 55 + randf_range(-14, 14)), randf_range(25, 55), 1.0])
	for m: Array in motes:
		m[0] = (m[0] as Vector2) + Vector2(0, -float(m[1]) * delta)
		m[2] = float(m[2]) - delta * 0.7
	motes = motes.filter(func(m: Array) -> bool: return float(m[2]) > 0.0)
	glow.queue_redraw()
