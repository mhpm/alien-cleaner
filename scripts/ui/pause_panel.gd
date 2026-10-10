class_name PausePanel
extends MarginContainer
## The pause modal, built from the user's kit (tools/pause_kit_ref.webp ->
## python tools/make_pause_assets.py -> assets/ui/pause/): the tall neon panel, the PAUSED
## header, a stats strip (weapon / wave / time / coins with the kit's icons), then a
## SCROLLING middle with the rescued crew (pink cards) and the active upgrades (cards of
## 3 per row), and RESUME / QUIT RUN side by side at the bottom. Header, stats and buttons
## stay put; only the middle scrolls, so nothing gets squeezed whatever the run carries.
## Frames are drawn as 9-slices scaled down from the kit (KitPatch), so their corners keep
## the art's proportions at any panel size.

const DIR := "res://assets/ui/pause/"
const K := 0.32  # kit px -> screen units (the frames' corners and borders)
const MAX_W := 340.0
const GAP := 12.0
const CYAN := Color("73eff7")
const SOFT := Color("d6e6ff")

var hud: Hud
var on_resume: Callable
var on_quit: Callable
var _frame: Texture2D
var _mid: ScrollContainer
var _head: TextureRect
var _more: TextureRect  # "there is more below" chevron while the middle scrolls

static var _tex := {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var img := (load(DIR + name + ".png") as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_tex[name] = ImageTexture.create_from_image(img)
	return _tex[name]


static func build(h: Hud, resume: Callable, quit: Callable) -> PausePanel:
	var p := PausePanel.new()
	p.hud = h
	p.on_resume = resume
	p.on_quit = quit
	p._layout()
	return p


func _layout() -> void:
	var w := minf(hud.root.size.x - 20.0, MAX_W)
	custom_minimum_size = Vector2(w, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame = PausePanel.tex("panel")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)
	for side in ["left", "right"]:
		add_theme_constant_override("margin_" + side, 18)
	add_theme_constant_override("margin_top", 16)
	add_theme_constant_override("margin_bottom", 16)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(GAP))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var inner := w - 36.0
	v.add_child(_header(inner))
	v.add_child(_stats(inner))
	_mid = _middle(inner)
	v.add_child(_mid)
	v.add_child(_buttons(inner))


## In the tree the sizes are real: the middle takes what it needs, or scrolls inside what
## is left of the screen once the header, stats and buttons are placed.
func _ready() -> void:
	await get_tree().process_frame
	var max_h := hud.root.size.y - 28.0
	var want := (_mid.get_child(0) as Control).get_combined_minimum_size().y
	var fixed := get_combined_minimum_size().y - _mid.get_combined_minimum_size().y
	if want > max_h - fixed:  # tight: a smaller header gives the list more room
		_head.custom_minimum_size *= 0.72
		await get_tree().process_frame
		fixed = get_combined_minimum_size().y - _mid.get_combined_minimum_size().y
	var room := maxf(40.0, max_h - fixed)
	_mid.custom_minimum_size.y = clampf(want, 40.0, room)
	if want > room:
		_more = _pic("arrow_r", Vector2(14, 22))
		_more.rotation = PI * 0.5
		_more.pivot_offset = Vector2(7, 11)
		_more.modulate = Color(1, 1, 1, 0.9)
		add_child(_more)
		_more.top_level = true
		set_process(true)


func _process(_delta: float) -> void:
	if _more == null:
		set_process(false)
		return
	var bar := _mid.get_v_scroll_bar()
	var at_end := _mid.scroll_vertical >= int(bar.max_value - bar.page) - 2
	_more.visible = not at_end
	var r := _mid.get_global_rect()
	var bob := sin(Time.get_ticks_msec() / 180.0) * 2.0
	_more.global_position = Vector2(r.get_center().x - 7.0, r.end.y - 20.0 + bob)


func _draw() -> void:
	KitPatch.draw_patch(self, _frame, 64.0, K, Rect2(Vector2.ZERO, size))


# ---------------------------------------------------------------- pieces

func _pic(name: String, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = PausePanel.tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _header(w: float) -> Control:
	var t := PausePanel.tex("header")
	var hw := w * 0.92
	_head = _pic("header", Vector2(hw, hw * t.get_height() / t.get_width()))
	return _center(_head)


func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


func _label(text: String, fs: int, col: Color) -> Label:
	var l := UiTheme.label(text, fs, col)
	l.add_theme_constant_override("outline_size", 5)
	return l


## WEAPON | WAVE | TIME | COINS in the kit's strip, each column with its icon.
func _stats(w: float) -> Control:
	var box := KitBox.make("stats", 40, K, Vector4(10, 10, 10, 9))
	box.custom_minimum_size = Vector2(w, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.content.add_child(h)
	var gid := str(Game.stats.get("gun", "pulse"))
	var gun_col := _stat_col("WEAPON", _icon_rect(GunData.icon(gid), Vector2(40, 22)), "Lv.%d" % int(Game.stats.get("gun_lv", 1)), Color.WHITE)
	var gname := str(GunData.gun(gid).name).to_upper()
	gun_col.add_child(_label(gname, UiTheme.fit_size(UiTheme.FONT, gname, 8, (w - 8.0) / 4.0 - 4.0), Color("9fe8ff")))
	h.add_child(gun_col)
	var sv := hud.game.survival
	var wave_txt := "%d / %d" % [Game.global_room(), WorldData.total_rooms()]
	var secs := hud.run_t
	if sv != null:
		wave_txt = "BOSS" if sv.final_sent else "%d / %d" % [maxi(sv.wave + 1, 1), sv.waves.size()]
		secs = sv.t
	h.add_child(_sep())
	h.add_child(_stat_col("WAVE" if sv != null else "ROOM", _pic("ic_alien", Vector2(24, 24)), wave_txt, Color("ffcd75")))
	h.add_child(_sep())
	h.add_child(_stat_col("TIME", _pic("ic_clock", Vector2(24, 24)), "%02d:%02d" % [floori(secs / 60.0), int(secs) % 60], Color.WHITE))
	h.add_child(_sep())
	h.add_child(_stat_col("COINS", _pic("ic_coin", Vector2(24, 24)), str(Game.run_coins), Color.WHITE))
	return box


func _icon_rect(t: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.custom_minimum_size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _stat_col(title: String, icon: Control, value: String, col: Color) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 3)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(_label(title, 9, CYAN))
	var ic := CenterContainer.new()
	ic.custom_minimum_size = Vector2(0, 26)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(icon)
	c.add_child(ic)
	c.add_child(_label(value, 13, col))
	return c


func _sep() -> Control:
	var r := ColorRect.new()
	r.color = Color(0.25, 0.65, 0.96, 0.4)
	r.custom_minimum_size = Vector2(1, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The kit's section banner with its title written on it.
func _banner(text: String, w: float) -> Control:
	var t := PausePanel.tex("banner")
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, w * t.get_height() / t.get_width())
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := _pic("banner", c.custom_minimum_size)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(pic)
	var l := _label(text, UiTheme.fit_size(UiTheme.FONT, text, 14, w * 0.6), CYAN)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c


## Rescued crew and active upgrades, in a scroll area (only the middle scrolls).
func _middle(w: float) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(w, 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(v)
	var ex := hud.game.explore
	if ex != null and not ex.saved_crew.is_empty():
		v.add_child(_banner("RESCUED CREW BONUS", w))
		for i in ex.saved_crew:
			v.add_child(_crew_card(i, w))
	v.add_child(_banner("ACTIVE UPGRADES", w))
	v.add_child(_upgrades(w))
	v.add_child(hud._spacer(2))
	return sc


func _crew_card(i: int, w: float) -> Control:
	var def: Dictionary = SurvivorData.CREW[i]
	var col: Color = def.color
	var box := KitBox.make("crew", 30, K, Vector4(10, 8, 12, 8))
	box.custom_minimum_size = Vector2(w, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.content.add_child(h)
	var pf := Panel.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = col.darkened(0.65)
	psb.border_color = col
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(3)
	pf.add_theme_stylebox_override("panel", psb)
	pf.custom_minimum_size = Vector2(46, 46)
	pf.clip_contents = true
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := TextureRect.new()
	var t := SurvivorData.tex(i, true)
	var at := AtlasTexture.new()
	at.atlas = t
	var tw := float(t.get_width())
	at.region = Rect2(tw * 0.08, 0, tw * 0.84, tw * 0.84)
	face.texture = at
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	face.position = Vector2(2, 2)
	face.size = Vector2(42, 42)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pf.add_child(face)
	h.add_child(pf)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := _label(str(def.name), 14, col.lightened(0.2))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(nl)
	var gift := UiTheme.body(str(def.gift), 12, SOFT)
	gift.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gift.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gift.custom_minimum_size = Vector2(w - 90.0, 0)
	v.add_child(gift)
	h.add_child(v)
	return box


## Every upgrade of the run, 3 cards a row (2 when only 2).
func _upgrades(w: float) -> Control:
	var ids: Array[String] = []
	for id: String in Game.upgrades:
		ids.append(id)
	if ids.is_empty():
		var none := UiTheme.body("No upgrades yet. Level up to pick some!", 12, Color("94b0c2"))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(w, 34)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return none
	var cols := 3 if ids.size() >= 3 else ids.size()
	var gap := 8.0
	var cw := floorf((w - gap * (3 - 1)) / 3.0)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(gap))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in ids:
		grid.add_child(_upgrade_card(id, Vector2(cw, cw * 0.9)))
	return _center(grid)


func _upgrade_card(id: String, sz: Vector2) -> Control:
	var def: Dictionary = UpgradeData.UPGRADES[id]
	var col: Color = def.color
	var lv := UpgradeData.current_level(id)
	var stacking := int(def.max) >= 99
	var box := KitBox.make("card", 34, K, Vector4(6, 7, 6, 7))
	box.custom_minimum_size = sz
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.content.add_child(v)
	v.add_child(_center(_icon_rect(UpgradeData.icon(id) if stacking else UpgradeData.level_tex(id, lv), Vector2(sz.x * 0.42, sz.x * 0.36))))
	var nm := str(def.name)
	v.add_child(_label(nm, UiTheme.fit_size(UiTheme.FONT, nm, 10, sz.x - 12.0), Color.WHITE))
	var maxed := not stacking and lv >= UpgradeData.LEVELS
	var lv_txt := "x%d" % lv if stacking else ("Lv.%d MAX" % lv if maxed else "Lv.%d" % lv)
	v.add_child(_label(lv_txt, 10, Color("ffcd75") if maxed else CYAN))
	if not stacking:
		var pips := HBoxContainer.new()
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 2)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pw := floorf((sz.x - 24.0) / UpgradeData.LEVELS) - 2.0
		for i in UpgradeData.LEVELS:
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(pw, 4)
			pip.color = col.lerp(Color("5fe8ff"), 0.5) if i < lv else Color(0.12, 0.2, 0.36)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips.add_child(pip)
		v.add_child(pips)
	return box


## RESUME and QUIT RUN side by side (the kit's own buttons).
func _buttons(w: float) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rw := (w - 8.0) * 0.53
	var qw := (w - 8.0) - rw
	h.add_child(_button("resume", rw, on_resume))
	h.add_child(_button("quit", qw, on_quit))
	return h


func _button(name: String, bw: float, cb: Callable) -> TextureButton:
	var t := PausePanel.tex(name)
	var b := TextureButton.new()
	b.texture_normal = t
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.custom_minimum_size = Vector2(bw, bw * t.get_height() / t.get_width())
	b.button_down.connect(func() -> void: b.scale = Vector2(0.95, 0.95))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.pressed.connect(func() -> void:
		Sfx.play("select", 0.0)
		cb.call())
	return b


## A kit frame drawn as a 9-slice scaled down by `k` (corners keep the art's shape).
class KitPatch:
	extends Control
	var tex: Texture2D
	var m := 40.0  # margin in kit px
	var k := 0.32

	static func make(name: String, margin: float, scale: float) -> KitPatch:
		var p := KitPatch.new()
		p.tex = PausePanel.tex(name)
		p.m = margin
		p.k = scale
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		p.resized.connect(p.queue_redraw)
		return p

	func _draw() -> void:
		KitPatch.draw_patch(self, tex, m, k, Rect2(Vector2.ZERO, size))

	static func draw_patch(ci: CanvasItem, tex: Texture2D, m: float, k: float, r: Rect2) -> void:
		var size := r.size
		var ts := tex.get_size()
		var d := minf(m * k, minf(size.x, size.y) * 0.5)
		var xs := [0.0, m, ts.x - m, ts.x]
		var ys := [0.0, m, ts.y - m, ts.y]
		var xd := [0.0, d, size.x - d, size.x]
		var yd := [0.0, d, size.y - d, size.y]
		for j in 3:
			for i in 3:
				var src := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
				var dst := Rect2(r.position + Vector2(xd[i], yd[j]), Vector2(xd[i + 1] - xd[i], yd[j + 1] - yd[j]))
				if dst.size.x > 0.0 and dst.size.y > 0.0:
					ci.draw_texture_rect_region(tex, dst, src)


## A kit frame behind padded content: content is a MarginContainer to put things in.
class KitBox:
	extends Control
	var patch: KitPatch
	var content: MarginContainer

	static func make(name: String, margin: float, scale: float, pad: Vector4) -> KitBox:
		var b := KitBox.new()
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.patch = KitPatch.make(name, margin, scale)
		b.patch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(b.patch)
		b.content = MarginContainer.new()
		b.content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.content.add_theme_constant_override("margin_left", int(pad.x))
		b.content.add_theme_constant_override("margin_top", int(pad.y))
		b.content.add_theme_constant_override("margin_right", int(pad.z))
		b.content.add_theme_constant_override("margin_bottom", int(pad.w))
		b.content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(b.content)
		b.content.minimum_size_changed.connect(b.update_minimum_size)
		return b

	func _get_minimum_size() -> Vector2:
		return content.get_combined_minimum_size() if content != null else Vector2.ZERO
