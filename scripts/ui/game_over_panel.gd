class_name GameOverPanel
extends VBoxContainer
## The WIPED OUT! screen, from the user's kit (tools/gameover_kit_ref.webp ->
## python tools/make_pause_assets.py -> assets/ui/pause/go_*.png): the goo-dripping title
## with its subtitle plate drops in and wobbles, the stats plate (how far you got, time,
## aliens cleaned, coins banked and the bank) slides up with the numbers counting, then
## PLAY AGAIN and MAIN MENU pop in. A tap skips the animation.

const MAX_W := 330.0

var hud: Hud
var _count: Array = []  # [Label, format, target]
var _t := 0.0
var _parts: Array[Control] = []
var _tweens: Array[Tween] = []


static func build(h: Hud, again: Callable, menu: Callable) -> GameOverPanel:
	var p := GameOverPanel.new()
	p.hud = h
	p._layout(again, menu)
	return p


func _layout(again: Callable, menu: Callable) -> void:
	var w := minf(hud.root.size.x - 24.0, MAX_W)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var head := _pic("go_header", w)
	add_child(_wrap(head))
	add_child(_wrap(_info(w * 0.92)))
	add_child(_wrap(_button("go_again", w * 0.8, again)))
	add_child(_wrap(_button("go_menu", w * 0.72, menu)))
	for c in get_children():
		_parts.append(c as Control)
		(c as Control).modulate.a = 0.0


func _wrap(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


func _pic(name: String, w: float) -> TextureRect:
	var t := PausePanel.tex(name)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = Vector2(w, w * t.get_height() / t.get_width())
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _label(text: String, fs: int, col: Color) -> Label:
	var l := UiTheme.label(text, fs, col)
	l.add_theme_constant_override("outline_size", 6)
	return l


## The stats plate: where you fell, time, aliens cleaned, coins banked, bank.
func _info(w: float) -> Control:
	var plate := _pic("go_info", w)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = w * 0.2
	v.offset_right = -w * 0.2
	v.offset_top = plate.custom_minimum_size.y * 0.17
	v.offset_bottom = -plate.custom_minimum_size.y * 0.17
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(v)
	var sv := hud.game.survival
	var where := "Reached room %d" % Game.global_room()
	var secs := hud.run_t
	var kills := 0
	if sv != null:
		where = "Fell on wave %d / %d" % [maxi(sv.wave + 1, 1), sv.waves.size()] if not sv.final_sent else "Fell to the boss"
		secs = sv.t
		kills = sv.kills
	var top := _label(where, UiTheme.fit_size(UiTheme.FONT, where, 15, w * 0.6), Color.WHITE)
	v.add_child(top)
	var mid := "%02d:%02d survived" % [floori(secs / 60.0), int(secs) % 60]
	if sv != null:
		mid += "  ·  %d cleaned" % kills
	v.add_child(_label(mid, UiTheme.fit_size(UiTheme.FONT, mid, 10, w * 0.6), Color("9fe8ff")))
	var coins := _label("+0 coins banked", 15, Color("ffcd75"))
	v.add_child(coins)
	_count.append([coins, "+%d coins banked", Game.run_coins])
	var bank := _label("Bank: %d  (spend in the ARMORY)" % Game.bank, 9, Color("94b0c2"))
	v.add_child(bank)
	return plate


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


func _ready() -> void:
	await get_tree().process_frame
	# title drops in and wobbles, the plate slides up, the buttons pop
	var head := _parts[0]
	head.pivot_offset = head.size * 0.5
	head.position.y -= 60.0
	head.scale = Vector2(1.15, 0.85)
	var tw := head.create_tween().set_parallel()
	_tweens.append(tw)
	tw.tween_property(head, "modulate:a", 1.0, 0.2)
	tw.tween_property(head, "position:y", head.position.y + 60.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(head, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("goo", 0.0, -2.0)
	for k in range(1, _parts.size()):
		var c := _parts[k]
		var y0 := c.position.y
		c.position.y += 24.0
		var t2 := c.create_tween().set_parallel()
		_tweens.append(t2)
		t2.tween_property(c, "modulate:a", 1.0, 0.25).set_delay(0.35 + k * 0.12)
		t2.tween_property(c, "position:y", y0, 0.35).set_delay(0.35 + k * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf((_t - 0.6) / 0.8, 0.0, 1.0)
	for c: Array in _count:
		(c[0] as Label).text = str(c[1]) % roundi(float(c[2]) * k)
	if k >= 1.0:
		set_process(false)


## A tap shows everything at once.
func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_t = 99.0
		for tw in _tweens:
			if tw.is_valid():
				tw.custom_step(10.0)
