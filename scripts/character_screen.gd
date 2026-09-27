extends Control
## CHARACTER screen: buy, equip and level up astronaut gear with banked coins.
## Laid out on the painted art (assets/ui/character/bg.webp, 1024x1536) scaled to
## fit; every live element sits on the exact rect of its painted counterpart.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const ART := Vector2(1024, 1536)
const DIR := "res://assets/ui/character/"

const SLOT_RECTS := {
	"helmet": Rect2(117, 213, 120, 122), "arms": Rect2(498, 213, 120, 122),
	"backpack": Rect2(48, 352, 122, 124), "weapon": Rect2(537, 352, 123, 124),
	"legs": Rect2(70, 493, 122, 122), "armor": Rect2(515, 493, 122, 122),
}
const TAB_X := [8, 175, 345, 513, 683, 852]
const TAB_W := [157, 157, 155, 157, 157, 160]
const CARD_X := [25, 200, 373, 547]
const CARD_Y := [877, 1132]
const SET_ROWS := [Rect2(700, 388, 296, 50), Rect2(700, 446, 296, 52), Rect2(700, 505, 296, 54), Rect2(700, 562, 296, 66)]

const C_PANEL := Color("121b38")
const C_EDGE := Color("33426e")
const C_GOLD := Color("f2b632")
const C_GREEN := Color("4fd44a")
const C_TEXT := Color("e8eefc")
const C_DIM := Color("8392bb")

var stage: Control
var floor_fill: TextureRect
var preview: Sprite2D  # the reference astronaut (always the same look), breathing
const PREVIEW_FEET := Vector2(362, 592)
const PREVIEW_SCALE := 0.95
const PREVIEW_ANCHOR := Vector2(103, 312)  # feet centre in preview_astronaut.png
var slot_nodes: Dictionary = {}
var tab_nodes: Array[Button] = []
var card_nodes: Array[Control] = []
var set_nodes: Array[Control] = []
var labels: Dictionary = {}
var detail_icon: TextureRect
var detail_level: Label
var detail_btn: Button
var toast: Label
var tab := "helmet"
var selected := ""
var t := 0.0


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dark := ColorRect.new()
	dark.color = Color("080c18")
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dark)
	# the painted floor keeps going below the art on tall phones
	var floor_tex := AtlasTexture.new()
	floor_tex.atlas = load(DIR + "bg.webp")
	floor_tex.region = Rect2(0, 1440, 1024, 96)
	floor_fill = TextureRect.new()
	floor_fill.texture = floor_tex
	floor_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_fill.stretch_mode = TextureRect.STRETCH_SCALE
	floor_fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	floor_fill.modulate = Color(0.7, 0.72, 0.8)
	add_child(floor_fill)
	stage = Control.new()
	stage.size = ART
	add_child(stage)
	var bg := TextureRect.new()
	bg.texture = load(DIR + "bg.webp")
	bg.size = ART
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	# the astronaut from the reference art; gear changes stats, not its look
	preview = Sprite2D.new()
	preview.texture = load(DIR + "preview_astronaut.png")
	preview.centered = false
	preview.offset = -PREVIEW_ANCHOR
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	preview.position = PREVIEW_FEET
	preview.scale = Vector2.ONE * PREVIEW_SCALE
	stage.add_child(preview)
	_build()
	resized.connect(_fit)
	_fit()
	selected = str(Game.gear_equipped[tab])
	_refresh()
	Sfx.play_music()


func _fit() -> void:
	var s := minf(size.x / ART.x, size.y / ART.y)
	stage.scale = Vector2(s, s)
	# pinned to the top (top bar under the thumb-free area); extra height becomes floor
	stage.position = Vector2((size.x - ART.x * s) * 0.5, 0.0)
	var bottom := stage.position.y + ART.y * s
	floor_fill.position = Vector2(0, bottom - 2.0)
	floor_fill.size = Vector2(size.x, maxf(0.0, size.y - bottom + 2.0))


# ---------------------------------------------------------------- building blocks

func _box(fill: Color, edge: Color, bw := 4, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = false
	return sb


func _label(parent: Control, r: Rect2, text: String, fs: int, col := C_TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = r.position
	l.size = r.size
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", maxi(4, fs / 4))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _icon(parent: Control, path: String, r: Rect2) -> TextureRect:
	var i := TextureRect.new()
	if path != "":
		i.texture = load(path)
	i.position = r.position
	i.size = r.size
	i.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	i.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	i.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(i)
	return i


func _button(parent: Control, r: Rect2, normal: StyleBox, pressed: StyleBox) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(0.95, 0.95))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	parent.add_child(b)
	return b


func _texture_button(path: String, r: Rect2, cb: Callable) -> void:
	var b := TextureButton.new()
	b.texture_normal = load(path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.position = r.position
	b.size = r.size
	b.pivot_offset = r.size * 0.5
	b.button_down.connect(func() -> void: b.scale = Vector2(0.92, 0.92))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	b.pressed.connect(func() -> void:
		Sfx.play("select", 0.0)
		cb.call())
	stage.add_child(b)


func _price_row(parent: Control, r: Rect2, text: String, fs: int) -> void:
	# coin + amount, centered inside r
	var coin := int(fs * 1.25)
	var font := get_theme_default_font()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := coin + 10 + tw
	var x := r.position.x + (r.size.x - w) * 0.5
	_icon(parent, DIR + "icon_coin.png", Rect2(x, r.position.y + (r.size.y - coin) * 0.5, coin, coin))
	_label(parent, Rect2(x + coin + 10, r.position.y, tw + 8, r.size.y), text, fs, Color.WHITE)


func _green_box(pressed := false) -> StyleBoxFlat:
	var sb := _box(Color("39c23a").darkened(0.15 if pressed else 0.0), Color("0c2a12"), 4, 8)
	sb.border_width_bottom = 2 if pressed else 7
	sb.border_color = Color("1d6b22")
	return sb


# ---------------------------------------------------------------- layout

func _build() -> void:
	_texture_button(DIR + "btn_back.png", Rect2(30, 12, 90, 74), _back)
	_texture_button(DIR + "btn_plus_power.png", Rect2(632, 18, 62, 58), func() -> void:
		_toast("Buy and upgrade gear to raise your POWER!"))
	_texture_button(DIR + "btn_plus_coins.png", Rect2(934, 18, 62, 58), func() -> void:
		_toast("Earn coins by cleaning alien ships!"))
	labels.power = _label(stage, Rect2(526, 24, 100, 46), "", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	labels.coins = _label(stage, Rect2(790, 24, 130, 46), "", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	# equipment slots around the astronaut
	for slot: String in SLOT_RECTS:
		var r: Rect2 = SLOT_RECTS[slot]
		var b := _button(stage, r, _box(C_PANEL, C_GOLD, 6, 12), _box(C_PANEL.lightened(0.1), C_GOLD, 6, 12))
		b.pressed.connect(_select_tab.bind(slot, true))
		var icon := _icon(b, "", Rect2(10, 8, r.size.x - 20, r.size.y - 38))
		var lv := _label(b, Rect2(0, r.size.y - 36, r.size.x, 30), "", 24, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		var badge := _badge(b, Vector2(r.size.x - 8, 8))
		slot_nodes[slot] = {"button": b, "icon": icon, "level": lv, "badge": badge}

	# stats
	labels.hp = _label(stage, Rect2(862, 190, 70, 38), "", 28)
	labels.hp_bonus = _label(stage, Rect2(930, 190, 70, 38), "", 28, C_GREEN)
	labels.speed = _label(stage, Rect2(862, 229, 140, 38), "", 28)
	labels.dmg = _label(stage, Rect2(862, 269, 70, 38), "", 28)
	labels.dmg_bonus = _label(stage, Rect2(930, 269, 70, 38), "", 28, C_GREEN)
	for i in SET_ROWS.size():
		var p := Panel.new()
		var r: Rect2 = SET_ROWS[i]
		p.position = r.position
		p.size = r.size
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(p)
		set_nodes.append(p)

	# category tabs
	for i in GearData.SLOTS.size():
		var slot: String = GearData.SLOTS[i]
		var r := Rect2(TAB_X[i], 667, TAB_W[i], 120)
		var b := _button(stage, r, _box(C_PANEL, C_EDGE, 4, 12), _box(C_PANEL.lightened(0.08), C_EDGE, 4, 12))
		b.pressed.connect(_select_tab.bind(slot, false))
		_icon(b, DIR + "icon_tab_%s.png" % slot, Rect2(0, 14, r.size.x, 58))
		_label(b, Rect2(0, 74, r.size.x, 36), slot.to_upper(), 26, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		tab_nodes.append(b)

	# item grid
	labels.grid_title = _label(stage, Rect2(40, 824, 380, 44), "", 36)
	for i in 8:
		var card := Control.new()
		card.position = Vector2(CARD_X[i % 4], CARD_Y[floori(i / 4.0)])
		card.size = Vector2(163, 238)
		stage.add_child(card)
		card_nodes.append(card)

	# detail panel
	labels.detail_title = _label(stage, Rect2(752, 824, 250, 44), "", 30, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var img_box := Panel.new()
	img_box.position = Vector2(755, 870)
	img_box.size = Vector2(243, 205)
	img_box.add_theme_stylebox_override("panel", _box(Color("0f1731"), C_EDGE, 3, 10))
	img_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(img_box)
	detail_icon = _icon(img_box, "", Rect2(24, 16, 195, 170))
	detail_level = _label(img_box, Rect2(8, 166, 227, 34), "", 22, C_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	labels.desc = _label(stage, Rect2(760, 1080, 238, 88), "", 20, Color("c9d4f2"))
	labels.desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	labels.d_hp = _label(stage, Rect2(900, 1192, 90, 36), "", 26, C_GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	labels.d_spd = _label(stage, Rect2(900, 1230, 90, 36), "", 26, C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	labels.d_dmg = _label(stage, Rect2(900, 1267, 90, 36), "", 26, C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	detail_btn = _button(stage, Rect2(758, 1328, 234, 72), _green_box(), _green_box(true))
	detail_btn.pressed.connect(_on_detail_button)

	toast = _label(self, Rect2(0, 0, 10, 10), "", 16, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position = Vector2(-170, -120)
	toast.size = Vector2(340, 60)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.modulate.a = 0.0


func _badge(parent: Control, center: Vector2) -> Control:
	var c := Control.new()
	c.position = center - Vector2(18, 18)
	c.size = Vector2(36, 36)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		c.draw_circle(Vector2(18, 18), 18, Color("0d1a3a"))
		c.draw_circle(Vector2(18, 18), 15, Color("3f8cff"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(18, 7), Vector2(28, 18), Vector2(22, 18),
				Vector2(22, 28), Vector2(14, 28), Vector2(14, 18), Vector2(8, 18)]), Color.WHITE))
	parent.add_child(c)
	return c


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	labels.power.text = str(Game.gear_power())
	labels.coins.text = str(Game.bank)
	_refresh_slots()
	_refresh_stats()
	_refresh_tabs()
	_refresh_cards()
	_refresh_detail()


func _refresh_slots() -> void:
	for slot: String in slot_nodes:
		var n: Dictionary = slot_nodes[slot]
		var id := str(Game.gear_equipped[slot])
		var lvl := Game.gear_level(id)
		var icon: TextureRect = n.icon
		icon.texture = load(GearData.icon_path(id))
		icon.modulate = Color.WHITE if lvl > 0 else Color(0.55, 0.58, 0.68)
		(n.level as Label).text = "Lv.%d" % lvl
		var b: Button = n.button
		var edge := C_GOLD if lvl > 0 else C_EDGE
		if slot == tab:
			edge = Color("ffe082") if lvl > 0 else Color("7d8fc4")
		b.add_theme_stylebox_override("normal", _box(C_PANEL, edge, 6, 12))
		b.add_theme_stylebox_override("hover", _box(C_PANEL, edge, 6, 12))
		var can_up := lvl < GearData.MAX_LEVEL and Game.bank >= GearData.upgrade_cost(id, lvl)
		(n.badge as Control).visible = can_up


func _refresh_stats() -> void:
	var base_hp := 100.0 + 15.0 * int(Game.perm.health)
	var base_dmg := 10.0 * (1.0 + 0.1 * int(Game.perm.power))
	Game.new_run()  # build the stats exactly as the next run will get them
	var s := Game.stats
	labels.hp.text = str(roundi(float(s.max_hp)))
	var hp_b := roundi(float(s.max_hp) - base_hp)
	labels.hp_bonus.text = ("+%d" % hp_b) if hp_b > 0 else ""
	var spd := float(s.move_speed) / (80.0 * (1.0 + 0.06 * int(Game.perm.speed)))
	labels.speed.text = "Very Fast" if spd >= 1.18 else ("Fast" if spd >= 1.06 else ("Slow" if spd < 0.97 else "Normal"))
	labels.dmg.text = str(roundi(float(s.damage)))
	var d_b := roundi(float(s.damage) - base_dmg)
	labels.dmg_bonus.text = ("+%d" % d_b) if d_b > 0 else ""
	var parts := Game.parts_equipped()
	var sp := Game.set_progress()
	for i in set_nodes.size():
		var p: Panel = set_nodes[i] as Panel
		for c in p.get_children():
			c.queue_free()
		var r: Rect2 = SET_ROWS[i]
		var on := false
		var left := ""
		var right := ""
		if i < 3:
			var def: Dictionary = GearData.SET_BONUS[i]
			on = parts >= int(def.parts)
			left = str(def.label)
			right = str(def.bonus)
		else:
			on = int(sp[1]) >= 6
			left = "Full Set (%d/6)" % int(sp[1])
			right = "Special Ability:\nEnergy Surge"
		p.add_theme_stylebox_override("panel", _box(Color("162247") if on else Color("111a35"), Color("2c3b66"), 3, 8))
		var x := 16.0
		if not on:
			_icon(p, DIR + "icon_lock.png", Rect2(12, (r.size.y - 30) * 0.5, 26, 30))
			x = 50.0
		_label(p, Rect2(x, 0, 170, r.size.y), left, 18 if on else 16, C_TEXT if on else C_DIM)
		var rl := _label(p, Rect2(170, 0, r.size.x - 180, r.size.y), right, 17 if on else 15,
				C_GREEN if on else C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		if i == 3:
			rl.add_theme_font_size_override("font_size", 15 if on else 14)


func _refresh_tabs() -> void:
	for i in tab_nodes.size():
		var on: bool = GearData.SLOTS[i] == tab
		var b := tab_nodes[i]
		var sb := _box(Color("1b2750") if on else C_PANEL, C_GOLD if on else C_EDGE, 7 if on else 4, 12)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
	labels.grid_title.text = str(GearData.TAB_TITLES[tab])


func _refresh_cards() -> void:
	for i in card_nodes.size():
		var card := card_nodes[i]
		for c in card.get_children():
			c.queue_free()
		var id := GearData.item_id(tab, GearData.VARIANTS[i])
		var owned := Game.is_owned(id)
		var lvl := Game.gear_level(id)
		var equipped: bool = str(Game.gear_equipped[tab]) == id
		var edge := C_EDGE
		var bw := 4
		var fill := Color("16203f")
		if equipped:
			edge = C_GREEN
			bw = 7
			fill = Color("112a33")
		elif id == selected:
			edge = Color("aebde8")
			bw = 5
		var b := _button(card, Rect2(Vector2.ZERO, card.size), _box(fill, edge, bw, 10), _box(fill.lightened(0.06), edge, bw, 10))
		b.pressed.connect(_select_item.bind(id))
		_label(b, Rect2(0, 8, 150, 28), "Lv.%d" % maxi(lvl, 0), 22, C_TEXT if owned else C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		var icon := _icon(b, GearData.icon_path(id), Rect2(16, 34, 131, 118))
		if not owned:
			icon.modulate = Color(0.92, 0.92, 0.95)
		if equipped:
			var bar := Panel.new()
			bar.position = Vector2(12, 172)
			bar.size = Vector2(139, 44)
			bar.add_theme_stylebox_override("panel", _box(Color("0b1a26"), Color("0b1a26"), 0, 6))
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(bar)
			_label(bar, Rect2(0, 0, 139, 44), "Equipped", 22, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			_icon(b, DIR + "icon_check.png", Rect2(118, 128, 36, 36))
		else:
			_label(b, Rect2(0, 150, 163, 28), GearData.item_name(id), 19, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			if owned:
				var eb := _button(b, Rect2(8, 184, 147, 44), _box(Color("2f6fd6"), Color("153575"), 4, 8),
						_box(Color("2a5fb8"), Color("153575"), 4, 8))
				_label(eb, Rect2(0, 0, 147, 44), "EQUIP", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
				eb.pressed.connect(_equip.bind(id))
			else:
				var pb := _button(b, Rect2(8, 184, 147, 44), _green_box(), _green_box(true))
				_price_row(pb, Rect2(0, 0, 147, 40), _fmt(GearData.price(id)), 26)
				if Game.bank < GearData.price(id):
					pb.modulate = Color(0.7, 0.7, 0.7)
				pb.pressed.connect(_buy.bind(id))


func _refresh_detail() -> void:
	if selected == "" or GearData.slot_of(selected) != tab:
		selected = str(Game.gear_equipped[tab])
	var id := selected
	var owned := Game.is_owned(id)
	var lvl := Game.gear_level(id)
	labels.detail_title.text = GearData.item_name(id).to_upper()
	detail_icon.texture = load(GearData.icon_path(id))
	labels.desc.text = GearData.description(id)
	# preview what the next purchase gives
	var next := 1 if not owned else mini(lvl + 1, GearData.MAX_LEVEL)
	var st := GearData.stats(id, next)
	labels.d_hp.text = "+%d" % int(st.hp)
	labels.d_spd.text = ("+%d%%" % roundi(float(st.spd) * 100.0)) if float(st.spd) >= 0.0 else ("%d%%" % roundi(float(st.spd) * 100.0))
	labels.d_dmg.text = "+%d" % int(st.dmg)
	labels.d_spd.add_theme_color_override("font_color", C_GREEN if float(st.spd) > 0.0 else C_TEXT)
	labels.d_dmg.add_theme_color_override("font_color", C_GREEN if int(st.dmg) > 0 else C_TEXT)
	for c in detail_btn.get_children():
		c.queue_free()
	detail_btn.modulate = Color.WHITE
	if not owned:
		detail_level.text = "NEW"
		_price_row(detail_btn, Rect2(0, 0, 234, 64), _fmt(GearData.price(id)), 34)
		if Game.bank < GearData.price(id):
			detail_btn.modulate = Color(0.65, 0.65, 0.65)
	elif lvl >= GearData.MAX_LEVEL:
		detail_level.text = "Lv.%d MAX" % lvl
		_label(detail_btn, Rect2(0, 0, 234, 64), "MAX LEVEL", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		detail_btn.modulate = Color(0.75, 0.75, 0.75)
	else:
		detail_level.text = "Lv.%d > %d" % [lvl, lvl + 1]
		_label(detail_btn, Rect2(10, 0, 110, 64), "UPGRADE", 22, Color.WHITE)
		_price_row(detail_btn, Rect2(96, 0, 138, 64), _fmt(GearData.upgrade_cost(id, lvl)), 28)
		if Game.bank < GearData.upgrade_cost(id, lvl):
			detail_btn.modulate = Color(0.65, 0.65, 0.65)


func _fmt(n: int) -> String:
	var s := str(n)
	return s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3) if n >= 1000 else s


# ---------------------------------------------------------------- actions

func _select_tab(slot: String, from_slot: bool) -> void:
	Sfx.play("select", 0.0)
	tab = slot
	selected = str(Game.gear_equipped[slot])
	if from_slot:
		Sfx.play("shield", 0.0, -10.0)
	_refresh()


func _select_item(id: String) -> void:
	Sfx.play("select", 0.0)
	selected = id
	_refresh_cards()
	_refresh_detail()


func _buy(id: String) -> void:
	selected = id
	if Game.buy_gear(id):
		Sfx.play("upgrade", 0.0)
		_celebrate("%s equipped!" % GearData.item_name(id))
	else:
		Sfx.play("hurt", 0.0, -8.0)
		_toast("Not enough coins - clean more ships!")
	_refresh()


func _equip(id: String) -> void:
	Game.equip_gear(id)
	selected = id
	Sfx.play("shield", 0.0)
	_refresh()
	_pop_preview()


func _pop_preview() -> void:
	var s := stage.scale.x
	var c := stage.position + (PREVIEW_FEET + Vector2(0, -140)) * s
	for i in 16:
		var dot := ColorRect.new()
		dot.size = Vector2(3, 3)
		dot.color = [C_GOLD, Color("73eff7"), Color.WHITE][i % 3]
		dot.position = c + Vector2(randf_range(-30, 30), randf_range(-40, 40))
		add_child(dot)
		var tw2 := dot.create_tween().set_parallel()
		tw2.tween_property(dot, "position:y", dot.position.y - randf_range(20, 45), 0.6)
		tw2.tween_property(dot, "modulate:a", 0.0, 0.6)
		tw2.chain().tween_callback(dot.queue_free)


func _on_detail_button() -> void:
	var id := selected
	if not Game.is_owned(id):
		_buy(id)
		return
	if Game.gear_level(id) >= GearData.MAX_LEVEL:
		return
	if Game.upgrade_gear(id):
		Sfx.play("upgrade", 0.0)
		_celebrate("%s  Lv.%d!" % [GearData.item_name(id), Game.gear_level(id)])
	else:
		Sfx.play("hurt", 0.0, -8.0)
		_toast("Not enough coins - clean more ships!")
	_refresh()


func _celebrate(text: String) -> void:
	_toast(text)
	_pop_preview()
	var s := stage.scale.x
	var c := stage.position + Vector2(877, 972) * s
	for i in 18:
		var dot := ColorRect.new()
		dot.size = Vector2(4, 4)
		dot.color = [C_GOLD, C_GREEN, Color("73eff7")][i % 3]
		dot.position = c
		add_child(dot)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(30, 80)
		var tw := dot.create_tween().set_parallel()
		tw.tween_property(dot, "position", c + dir, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(dot, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(dot.queue_free)


func _toast(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	var tw := toast.create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)


func _back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _process(delta: float) -> void:
	t += delta
	# idle breathing on the preview (feet stay planted)
	var b := sin(t * 2.2) * 0.012
	preview.scale = Vector2(PREVIEW_SCALE * (1.0 + b * 0.5), PREVIEW_SCALE * (1.0 + b))
	for slot: String in slot_nodes:
		var badge: Control = slot_nodes[slot].badge
		if badge.visible:
			badge.position.y = -10.0 + sin(t * 4.0) * 3.0
