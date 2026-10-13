class_name CrewPanel
extends Control
## CREW modal (world select > CREW tile): pick who goes on the mission (Game.character).
## Built from the user's kit tools/crew_kit_ref.webp -> tools/make_crew_assets.py ->
## assets/ui/crew/ following the mock-up tools/crew_ref.webp: the kid and the girl around
## the CREW plate, the subtitle plate, one painted card per crew member (Game.CREW; her
## art, portrait, name, tagline and SELECT on the card's green button), BACK below.
## The picked one glows gold and reads SELECTED; locked ones are dark with "???" and how
## to unlock them. Opening it clears the CREW tile's "new crew member" badge.

const DIR := "res://assets/ui/crew/"
const W := 840.0  # stage width in art px
const CARD_X := 25.0
const CARD_Y := 392.0
const CARD_GAP := 22.0
## card art per character (the others use the kid's blue one)
const CARDS := {"kid_astronaut": "card_kid", "girl": "card_girl"}
## spots on a card (its own px): text right of the portrait, the green button
const NAME_RECT := Rect2(458, 34, 290, 54)
const TAG_RECT := Rect2(458, 98, 290, 40)
const BTN_RECT := Rect2(537, 143, 205, 75)
const TITLE_RECT := Rect2(212, 128, 360, 112)  # the plate inside the header
const GOLD := Color("ffcd75")
const CYAN := Color("73eff7")

var on_close: Callable
var dim: ColorRect
var stage: Control
var height := 0.0
var cards: Array[Control] = []
var glow: Control  # gold frame around the picked card
var glow_card: Control
var t := 0.0


## Opens the panel over `parent` (full screen); `closed` runs after BACK.
static func open(parent: Control, closed: Callable) -> CrewPanel:
	var p := CrewPanel.new()
	p.on_close = closed
	parent.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not Game.crew_new.is_empty():
		Game.crew_new.clear()
		Game.save()
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.08, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.86, 0.25)
	_build()
	resized.connect(_fit)
	_fit()
	# pops in
	stage.modulate.a = 0.0
	var s := stage.scale
	stage.scale = s * 0.86
	stage.position += Vector2(W, height) * s * 0.07
	var tw := create_tween().set_parallel()
	tw.tween_property(stage, "modulate:a", 1.0, 0.2)
	tw.tween_property(stage, "scale", s, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stage, "position", stage.position - Vector2(W, height) * s * 0.07, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in cards.size():
		var c := cards[i]
		var x := c.position.x
		c.position.x += -120.0 if i % 2 == 0 else 120.0
		c.modulate.a = 0.0
		var ct := create_tween().set_parallel()
		ct.tween_interval(0.12 + 0.08 * i)
		ct.chain().tween_property(c, "position:x", x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.tween_property(c, "modulate:a", 1.0, 0.2)


func _build() -> void:
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var ids: Array = Game.CREW.keys()
	var card_h := 250.0
	var cards_end := CARD_Y + ids.size() * (card_h + CARD_GAP) - CARD_GAP
	var back_y := cards_end + 40.0
	height = back_y + 116.0
	# the panel: the kit's big frame stretched (9-slice) behind everything
	var frame := NinePatchRect.new()
	frame.texture = load(DIR + "frame.png")
	frame.patch_margin_left = 60
	frame.patch_margin_right = 60
	frame.patch_margin_top = 56
	frame.patch_margin_bottom = 56
	frame.position = Vector2(4, 196)
	frame.size = Vector2(W - 8, back_y - 150.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(frame)
	var header := _tex("header.png", Vector2((W - 785.0) * 0.5, 0))
	var title := _label("CREW", 92, Color("9fe8ff"), Rect2(header.position + TITLE_RECT.position, TITLE_RECT.size))
	title.add_theme_color_override("font_outline_color", Color("0b2a4a"))
	title.add_theme_constant_override("outline_size", 28)
	var bar := _tex("bar.png", Vector2((W - 432.0) * 0.5, 292))
	_label("Pick who goes on the mission", 26, Color("e4f2ff"), Rect2(bar.position + Vector2(40, 8), Vector2(352, 64)))
	for i in ids.size():
		var c := CharacterData.load_id(str(ids[i]))
		if c != null:
			cards.append(_card(c, Vector2(CARD_X, CARD_Y + i * (card_h + CARD_GAP))))
	# brackets hug the bottom corners of the frame
	_tex("bracket_l.png", Vector2(0, back_y - 74))
	_tex("bracket_r.png", Vector2(W - 108, back_y - 74))
	var back := _button("btn_back.png", Rect2((W - 295.0) * 0.5, back_y, 295, 96), "BACK", Color("e4f2ff"))
	var bl := back.get_child(0) as Label  # right of the painted arrow (make_crew_assets ARROW_X)
	bl.position.x = 112.0
	bl.size.x = 150.0
	bl.add_theme_font_size_override("font_size", 34)
	back.pressed.connect(_close)
	glow = Control.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.draw.connect(_draw_glow)
	stage.add_child(glow)
	_refresh()


## One crew member's painted card with her name, tagline and the SELECT button.
func _card(c: CharacterData, at: Vector2) -> Control:
	var card := Control.new()
	card.position = at
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("id", c.character_id)
	stage.add_child(card)
	var art := TextureRect.new()
	art.texture = load(DIR + str(CARDS.get(c.character_id, "card_kid")) + ".png")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	card.size = art.texture.get_size()
	card.pivot_offset = card.size * 0.5
	card.set_meta("art", art)
	var pink := c.pulse_skin == "pink"
	card.set_meta("name", _label("", 34, Color.WHITE, NAME_RECT, card, HORIZONTAL_ALIGNMENT_LEFT))
	card.set_meta("tag", _label("", 22, Color("ff9ad8") if pink else Color("9fd2ff"), TAG_RECT, card, HORIZONTAL_ALIGNMENT_LEFT))
	var b := _button("", BTN_RECT, "SELECT", Color.WHITE, card)
	b.pressed.connect(_pick.bind(c.character_id, card))
	card.set_meta("btn", b)
	return card


## Cards follow the save: SELECTED (gold glow), SELECT, or locked (dark, "???").
func _refresh() -> void:
	glow_card = null
	for card in cards:
		var id := str(card.get_meta("id"))
		var c := CharacterData.load_id(id)
		var open := Game.character_unlocked(id)
		var chosen := Game.character == id
		(card.get_meta("art") as CanvasItem).modulate = Color.WHITE if open else Color(0.28, 0.28, 0.36)
		var n: Label = card.get_meta("name")
		n.text = c.display_name.to_upper() if open else "???"
		n.add_theme_font_size_override("font_size", UiTheme.fit_size(UiTheme.FONT, n.text, 34, NAME_RECT.size.x))
		var tg: Label = card.get_meta("tag")
		tg.text = c.tagline if open else "Clear WORLD %d to unlock" % (int(Game.CREW[id]) + 1)
		tg.add_theme_font_size_override("font_size", UiTheme.fit_size(UiTheme.FONT, tg.text, 22, TAG_RECT.size.x))
		var b: TextureButton = card.get_meta("btn")
		var bl := b.get_child(0) as Label
		b.disabled = chosen or not open
		b.texture_normal = load(DIR + "btn_gray.png") if b.disabled else null
		bl.text = "SELECTED" if chosen else ("SELECT" if open else "LOCKED")
		bl.add_theme_color_override("font_color", GOLD if chosen else (Color.WHITE if open else Color("94b0c2")))
		# the grey button's frame is thick: keep the word well inside it
		bl.add_theme_font_size_override("font_size", UiTheme.fit_size(UiTheme.FONT, bl.text, 30, BTN_RECT.size.x - 76.0))
		if chosen:
			glow_card = card
	glow.queue_redraw()


func _pick(id: String, card: Control) -> void:
	if not Game.select_character(id):
		return
	Sfx.play("upgrade", 0.0)
	_refresh()
	card.scale = Vector2(1.05, 1.05)
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	Sfx.play("select", 0.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(stage, "modulate:a", 0.0, 0.15)
	tw.tween_property(dim, "color:a", 0.0, 0.18)
	tw.chain().tween_callback(func() -> void:
		queue_free()
		on_close.call())


func _process(delta: float) -> void:
	t += delta
	if glow_card != null:
		glow.queue_redraw()


## The picked card's frame breathes in gold (menu: a few rects per frame).
func _draw_glow() -> void:
	if glow_card == null:
		return
	var r := Rect2(glow_card.position, glow_card.size).grow(-2.0)
	var k := 0.75 + 0.25 * sin(t * 4.0)
	glow.draw_rect(r.grow(-12.0), Color(Color("ffb000"), k), false, 6.0)
	glow.draw_rect(r.grow(-7.0), Color(GOLD, 0.45 * k), false, 4.0)


## Fit the stage to the safe area (width, or height on short screens), centred.
func _fit() -> void:
	var safe := UiTheme.safe_rect(self)
	var s := minf(safe.size.x * 0.97 / W, safe.size.y * 0.97 / height)
	stage.scale = Vector2(s, s)
	stage.position = safe.position + (safe.size - Vector2(W, height) * s) * 0.5


func _tex(file: String, at: Vector2, parent: Control = null) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(DIR + file)
	r.position = at
	r.size = r.texture.get_size()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else stage).add_child(r)
	return r


func _label(text: String, fs: int, col: Color, r: Rect2, parent: Control = null,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := UiTheme.label(text, fs, col)
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color("0b1029"))
	(parent if parent != null else stage).add_child(l)
	return l


## A button over `r` (its art from the kit, or none = the art painted under it).
func _button(file: String, r: Rect2, text: String, col: Color, parent: Control = null) -> TextureButton:
	var b := TextureButton.new()
	if file != "":
		b.texture_normal = load(DIR + file)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.position = r.position
	b.size = r.size
	b.pivot_offset = r.size * 0.5
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(func() -> void: b.scale = Vector2(0.94, 0.94))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	(parent if parent != null else stage).add_child(b)
	var l := UiTheme.label(text, 34, col)
	l.size = r.size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color("0b1029"))
	b.add_child(l)
	return b
