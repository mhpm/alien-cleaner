class_name MenuPanels
extends RefCounted
## Full-screen overlays shared by the title screen and the world select: settings and
## the coin shop of permanent crew upgrades (Game.PERM).


## Dimmed full-screen layer with a centred column; returns [layer, column].
static func overlay(parent: Control, dim := 0.9) -> Array:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(o)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.09, dim)
	o.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	o.add_child(box)
	return [o, box]


static func center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


static func settings(parent: Control, extra: Array = []) -> Control:
	var ob := overlay(parent, 0.88)
	var panel: Control = ob[0]
	var box: VBoxContainer = ob[1]
	box.add_theme_constant_override("separation", 14)
	box.add_child(UiTheme.title("SETTINGS", 30, Color("73eff7")))
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
		box.add_child(center(b))
	for b: Button in extra:  # e.g. "TITLE SCREEN" from the world select
		box.add_child(center(b))
	var close := UiTheme.button("BACK", Color("566c86"), 18, Vector2(180, 46))
	close.pressed.connect(panel.queue_free)
	box.add_child(center(close))
	return panel


## Coin shop for the Game.PERM upgrades in `ids`. Rebuilds itself after each purchase
## and calls on_close when it is dismissed. `header` goes between the title and the rows.
static func shop(parent: Control, ids: Array, title: String, on_close: Callable, header: Control = null) -> Control:
	var ob := overlay(parent)
	var panel: Control = ob[0]
	var box: VBoxContainer = ob[1]
	box.add_child(UiTheme.title(title, 28, Color("73eff7")))
	box.add_child(UiTheme.label("Bank: %d coins" % Game.bank, 16, Color("ffcd75")))
	if header != null:
		box.add_child(header)
	for id: String in ids:
		box.add_child(_shop_row(id, func() -> void:
			panel.queue_free()
			shop(parent, ids, title, on_close, _rebuilt(header))))
	var close := UiTheme.button("BACK", Color("566c86"), 18, Vector2(180, 46))
	close.pressed.connect(func() -> void:
		panel.queue_free()
		on_close.call())
	box.add_child(center(close))
	return panel


## A header survives a rebuild only if it can make a fresh copy of itself.
static func _rebuilt(header: Control) -> Control:
	if header != null and header.has_meta("rebuild"):
		return (header.get_meta("rebuild") as Callable).call()
	return null


static func _shop_row(id: String, bought: Callable) -> Control:
	var def: Dictionary = Game.PERM[id]
	var lvl := int(Game.perm[id])
	var maxed := lvl >= int(def.max)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	var sb := UiTheme.box(Color("29366f"), Color("1a1c2c"))
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var n := UiTheme.label(str(def.name), 17, Color("f4f4f4"))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(n)
	var d := UiTheme.label(str(def.get("desc2", def.desc)) if lvl > 0 else str(def.desc), 12, Color("94b0c2"))
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
			bought.call())
	h.add_child(b)
	return center(panel)


## True when some upgrade in `ids` can be bought right now (nav badges).
static func can_buy(ids: Array) -> bool:
	for id: String in ids:
		if int(Game.perm[id]) < int(Game.PERM[id].max) and Game.bank >= Game.perm_cost(id):
			return true
	return false
