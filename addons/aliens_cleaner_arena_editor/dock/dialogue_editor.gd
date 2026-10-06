@tool
extends ConfirmationDialog
## The Dialogue Editor of a Dialogue Trigger (double-click the trigger in the 2D view,
## or "Open Dialogue Editor" in its Inspector). Three columns:
##   CAST     the characters: face (gallery), name, colour, side of the box, voice
##   SCRIPT   the conversation as chat bubbles; each line: who, text, size, effect,
##            how long it stays. "+ <name>" buttons add the next line; Ctrl+Enter in a
##            line adds the reply of the other speaker.
##   PREVIEW  the real game box, typing; play one line or the whole conversation
## Works on a copy: Save applies it to the trigger as one undoable action.

const Picker := preload("portrait_picker.gd")
const Preview := preload("dialogue_preview.gd")
const PALETTE := [Color("73eff7"), Color("ffcd75"), Color("a7f070"), Color("ff6a9a"), Color("c79bff"), Color("ff9a3a"), Color("f4f4f4")]

var undo_redo: EditorUndoRedoManager
var _trigger: ArenaTrigger
var _data: DialogueData
var _sel := 0
var _scale := 1.0
var _cast_box: VBoxContainer
var _lines_box: VBoxContainer
var _lines_scroll: ScrollContainer
var _quick: HFlowContainer
var _count: Label
var _preview: Control
var _pause: CheckButton
var _speed: HSlider
var _speed_label: Label
var _place: OptionButton
var _picker: AcceptDialog
var _picker_for := -1  # cast index the gallery is choosing for
var _rows: Array[Control] = []
var _texts: Array[TextEdit] = []


func _init() -> void:
	title = "Dialogue Editor"
	ok_button_text = "Save dialogue"
	min_size = Vector2i(1080, 640)
	confirmed.connect(_save)
	canceled.connect(func() -> void: _preview.stop())


func start(trigger: ArenaTrigger, ur: EditorUndoRedoManager) -> void:
	if _cast_box == null:
		_build()
	_trigger = trigger
	undo_redo = ur
	_data = trigger.editable_dialogue().copy()
	if _data.cast.is_empty():
		_add_speaker(false)
	title = "Dialogue Editor — %s" % trigger.name
	_sel = 0
	_pause.set_pressed_no_signal(_data.pause_game)
	_speed.set_value_no_signal(_data.speed)
	_place.select(_data.placement)
	_update_speed_label()
	_preview.data = _data
	_rebuild_all()
	popup_centered(Vector2i(1240, 760) * _scale)
	_preview.show_line(_sel)


# ------------------------------------------------------------------- layout

func _build() -> void:
	_scale = EditorInterface.get_editor_scale()
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", int(12 * _scale))
	add_child(root)
	# ---- CAST
	var left := _column(root, "CAST", "Who talks: tap a face to change it", 270)
	var add_cast := Button.new()
	add_cast.text = "Add character"
	add_cast.icon = _icon("Add")
	add_cast.pressed.connect(func() -> void: _add_speaker(true))
	left.add_child(add_cast)
	var cast_scroll := ScrollContainer.new()
	cast_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cast_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(cast_scroll)
	_cast_box = VBoxContainer.new()
	_cast_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cast_box.add_theme_constant_override("separation", int(8 * _scale))
	cast_scroll.add_child(_cast_box)
	left.add_child(HSeparator.new())
	left.add_child(_caption("HOW IT PLAYS"))
	_pause = CheckButton.new()
	_pause.text = "Cinematic: pause & tap to continue"
	_pause.tooltip_text = "On: the game stops and the player taps each line.\nOff: lines go by themselves while the action continues."
	_pause.toggled.connect(func(on: bool) -> void:
		_data.pause_game = on
		_preview.queue_redraw())
	left.add_child(_pause)
	var speed_row := HBoxContainer.new()
	left.add_child(speed_row)
	_speed_label = Label.new()
	_speed_label.custom_minimum_size.x = 104 * _scale
	speed_row.add_child(_speed_label)
	_speed = HSlider.new()
	_speed.min_value = 8
	_speed.max_value = 120
	_speed.step = 1
	_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed.value_changed.connect(func(v: float) -> void:
		_data.speed = v
		_update_speed_label())
	speed_row.add_child(_speed)
	var place_row := HBoxContainer.new()
	left.add_child(place_row)
	var pl := Label.new()
	pl.text = "Box on screen"
	pl.custom_minimum_size.x = 104 * _scale
	place_row.add_child(pl)
	_place = OptionButton.new()
	_place.add_item("Bottom")
	_place.add_item("Top")
	_place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_place.item_selected.connect(func(i: int) -> void:
		_data.placement = i
		_preview.queue_redraw())
	place_row.add_child(_place)
	# ---- SCRIPT
	var mid := _column(root, "SCRIPT", "The conversation, top to bottom", 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	mid.add_child(head)
	_count = Label.new()
	_count.modulate = Color(1, 1, 1, 0.6)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_count)
	var templates := MenuButton.new()
	templates.text = "Start from a template"
	templates.icon = _icon("Script")
	templates.flat = false
	for t in ["Radio call (1 voice)", "Two people talking", "Rescue scene", "Briefing (3 people)", "Alien threat (shout!)"]:
		templates.get_popup().add_item(t)
	templates.get_popup().id_pressed.connect(_template)
	head.add_child(templates)
	_lines_scroll = ScrollContainer.new()
	_lines_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lines_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(_lines_scroll)
	_lines_box = VBoxContainer.new()
	_lines_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines_box.add_theme_constant_override("separation", int(6 * _scale))
	_lines_scroll.add_child(_lines_box)
	var add_bar := PanelContainer.new()
	add_bar.add_theme_stylebox_override("panel", _panel(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.1)))
	mid.add_child(add_bar)
	var add_v := VBoxContainer.new()
	add_bar.add_child(add_v)
	var add_l := Label.new()
	add_l.text = "Next line, said by:   (tip: Ctrl+Enter in a line = the other one answers)"
	add_l.modulate = Color(1, 1, 1, 0.6)
	add_v.add_child(add_l)
	_quick = HFlowContainer.new()
	add_v.add_child(_quick)
	# ---- PREVIEW
	var right := _column(root, "PREVIEW", "Exactly as it plays in the game", 0)
	_preview = Preview.new()
	_preview.line_started.connect(func(i: int) -> void: _select(i, false))
	right.add_child(_preview)
	var play_row := HBoxContainer.new()
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(play_row)
	var play := Button.new()
	play.text = "Play this line"
	play.icon = _icon("Play")
	play.pressed.connect(func() -> void: _preview.play_line(_sel))
	play_row.add_child(play)
	var all := Button.new()
	all.text = "Play all"
	all.icon = _icon("PlayStart")
	all.pressed.connect(func() -> void: _preview.play_all())
	play_row.add_child(all)
	var stop := Button.new()
	stop.icon = _icon("Stop")
	stop.tooltip_text = "Stop"
	stop.pressed.connect(func() -> void: _preview.stop())
	play_row.add_child(stop)
	var help := Label.new()
	help.text = "Effects:  Shout! = shakes, caps, red flash · Whisper… = slanted, soft, slow\nRadio = static, comms · Thought = grey, (in brackets), silent\nSizes S / L / XL are the sharpest; M is a little soft."
	help.modulate = Color(1, 1, 1, 0.5)
	help.add_theme_font_size_override("font_size", int(11 * _scale))
	right.add_child(help)
	_picker = Picker.new()
	_picker.picked.connect(_on_face_picked)
	add_child(_picker)


func _column(parent: Control, title_text: String, sub: String, width: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	if width > 0.0:
		v.custom_minimum_size.x = width * _scale
	v.add_theme_constant_override("separation", int(6 * _scale))
	parent.add_child(v)
	var t := _caption(title_text)
	t.add_theme_font_size_override("font_size", int(16 * _scale))
	v.add_child(t)
	var s := Label.new()
	s.text = sub
	s.modulate = Color(1, 1, 1, 0.5)
	v.add_child(s)
	return v


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.45, 0.94, 0.97))
	return l


func _icon(name_: String) -> Texture2D:
	var th := EditorInterface.get_editor_theme()
	return th.get_icon(name_, "EditorIcons") if th.has_icon(name_, "EditorIcons") else null


func _panel(bg: Color, border: Color, left_w := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_left = left_w
	sb.set_corner_radius_all(int(6 * _scale))
	sb.set_content_margin_all(6 * _scale)
	return sb


func _update_speed_label() -> void:
	var v := _speed.value
	_speed_label.text = "Typing: %s" % ("slow" if v < 25 else "normal" if v < 55 else "fast" if v < 90 else "instant-ish")


# ------------------------------------------------------------------- cast

func _rebuild_all() -> void:
	_rebuild_cast()
	_rebuild_lines()


func _rebuild_cast() -> void:
	for c in _cast_box.get_children():
		c.queue_free()
	for i in _data.cast.size():
		_cast_box.add_child(_cast_card(i))
	_rebuild_quick()


func _cast_card(i: int) -> Control:
	var s := _data.cast[i]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel(Color(s.color, 0.08), s.color, 4))
	var h := HBoxContainer.new()
	card.add_child(h)
	var face := Button.new()
	face.custom_minimum_size = Vector2(64, 64) * _scale
	face.icon = s.portrait
	face.expand_icon = true
	face.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.text = "" if s.portrait != null else "+ face"
	face.tooltip_text = "Choose a face from the gallery"
	face.pressed.connect(func() -> void:
		_picker_for = i
		_picker.start())
	h.add_child(face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var nm := LineEdit.new()
	nm.text = s.name
	nm.placeholder_text = "Name"
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_changed.connect(func(t: String) -> void:
		s.name = t
		_refresh_rows_look())
	top.add_child(nm)
	var del := Button.new()
	del.icon = _icon("Remove")
	del.flat = true
	del.tooltip_text = "Remove this character (their lines go to the first one)"
	del.disabled = _data.cast.size() <= 1
	del.pressed.connect(func() -> void: _remove_speaker(i))
	top.add_child(del)
	var mid := HBoxContainer.new()
	v.add_child(mid)
	var color := ColorPickerButton.new()
	color.color = s.color
	color.custom_minimum_size = Vector2(36, 0) * _scale
	color.tooltip_text = "Colour of the name plate and the box border"
	color.color_changed.connect(func(c: Color) -> void:
		s.color = c
		card.add_theme_stylebox_override("panel", _panel(Color(c, 0.08), c, 4))
		_refresh_rows_look())
	mid.add_child(color)
	var side := Button.new()
	side.toggle_mode = true
	side.button_pressed = s.side == DialogueSpeaker.Side.RIGHT
	side.text = "Face on the right" if side.button_pressed else "Face on the left"
	side.icon = _icon("ArrowRight" if side.button_pressed else "ArrowLeft")
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.tooltip_text = "Put two speakers on opposite sides so they face each other"
	side.toggled.connect(func(on: bool) -> void:
		s.side = DialogueSpeaker.Side.RIGHT if on else DialogueSpeaker.Side.LEFT
		side.text = "Face on the right" if on else "Face on the left"
		side.icon = _icon("ArrowRight" if on else "ArrowLeft")
		_rebuild_lines())
	mid.add_child(side)
	var voice_row := HBoxContainer.new()
	v.add_child(voice_row)
	var vl := Label.new()
	vl.text = "Voice"
	vl.modulate = Color(1, 1, 1, 0.6)
	voice_row.add_child(vl)
	var voice := HSlider.new()
	voice.min_value = 0.4
	voice.max_value = 2.2
	voice.step = 0.05
	voice.value = s.voice
	voice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	voice.tooltip_text = "Pitch of the typing blips: left = deep / robot, right = small / nervous"
	var vv := Label.new()
	vv.text = _voice_name(s.voice)
	vv.custom_minimum_size.x = 52 * _scale
	vv.modulate = Color(1, 1, 1, 0.6)
	voice.value_changed.connect(func(x: float) -> void:
		s.voice = x
		vv.text = _voice_name(x))
	voice_row.add_child(voice)
	voice_row.add_child(vv)
	return card


func _voice_name(v: float) -> String:
	return "deep" if v < 0.75 else "low" if v < 0.95 else "normal" if v < 1.2 else "high" if v < 1.6 else "tiny"


func _add_speaker(refresh: bool) -> void:
	var s := DialogueSpeaker.new()
	var n := _data.cast.size()
	s.name = "MISSION CONTROL" if n == 0 else "CHARACTER %d" % (n + 1)
	s.color = PALETTE[n % PALETTE.size()]
	s.side = DialogueSpeaker.Side.LEFT if n % 2 == 0 else DialogueSpeaker.Side.RIGHT
	_data.cast.append(s)
	if refresh:
		_rebuild_all()
		# a new character starts by choosing a face
		_picker_for = n
		_picker.start()


func _remove_speaker(i: int) -> void:
	_data.cast.remove_at(i)
	for l in _data.lines:
		if l.speaker == i:
			l.speaker = 0
		elif l.speaker > i:
			l.speaker -= 1
	_rebuild_all()


func _on_face_picked(tex: Texture2D) -> void:
	if _picker_for < 0:  # a line's own face
		var k := -1 - _picker_for
		if k < _data.lines.size():
			_data.lines[k].portrait = tex
			_sel = k
			_rebuild_lines()
		return
	if _picker_for >= _data.cast.size():
		return
	var s := _data.cast[_picker_for]
	s.portrait = tex
	# a face from a file name: a good default name for a fresh character
	if s.name.begins_with("CHARACTER ") and tex != null and not tex.resource_path.is_empty():
		s.name = tex.resource_path.get_file().get_basename().get_slice("_", 0).replace("-", " ").to_upper()
	_rebuild_all()


func _rebuild_quick() -> void:
	for c in _quick.get_children():
		c.queue_free()
	for i in _data.cast.size():
		var s := _data.cast[i]
		var b := Button.new()
		b.text = "+ " + (s.name if not s.name.is_empty() else "?")
		b.icon = s.portrait
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", int(28 * _scale))
		b.add_theme_color_override("font_color", s.color)
		b.tooltip_text = "Add a line said by %s" % s.name
		b.pressed.connect(func() -> void: _add_line(i, _data.lines.size()))
		_quick.add_child(b)


# ------------------------------------------------------------------- lines

func _rebuild_lines() -> void:
	for c in _lines_box.get_children():
		c.queue_free()
	_rows.clear()
	_texts.clear()
	for i in _data.lines.size():
		var row := _line_row(i)
		_rows.append(row)
		_lines_box.add_child(row)
	if _data.lines.is_empty():
		var empty := Label.new()
		empty.text = "No lines yet.\nPress a \"+ name\" button below, or start from a template."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.modulate = Color(1, 1, 1, 0.5)
		empty.custom_minimum_size.y = 120 * _scale
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lines_box.add_child(empty)
	_count.text = _data.summary()
	_rebuild_quick()
	_sel = clampi(_sel, 0, maxi(0, _data.lines.size() - 1))
	_paint_selection()
	_preview.show_line(_sel)


## Only colours / names / faces changed: refresh the bubbles in place (keeps focus).
func _refresh_rows_look() -> void:
	_rebuild_quick()
	_count.text = _data.summary()
	for i in _rows.size():
		var row := _rows[i]
		var who := _data.speaker_of(_data.lines[i])
		if who == null:
			continue
		var bubble: PanelContainer = row.get_meta("bubble")
		bubble.add_theme_stylebox_override("panel", _bubble_style(who.color, i == _sel))
		var opt: OptionButton = row.get_meta("who")
		for k in _data.cast.size():
			opt.set_item_text(k, _data.cast[k].name)
	_preview.queue_redraw()


func _bubble_style(c: Color, selected: bool) -> StyleBoxFlat:
	var sb := _panel(Color(c, 0.13 if selected else 0.06), Color(c, 1.0 if selected else 0.35))
	if selected:
		sb.set_border_width_all(2)
	return sb


func _line_row(i: int) -> Control:
	var line := _data.lines[i]
	var who := _data.speaker_of(line)
	var right := who != null and who.side == DialogueSpeaker.Side.RIGHT
	var col := who.color if who != null else Color.WHITE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(6 * _scale))
	var avatar := TextureRect.new()
	avatar.texture = line.portrait if line.portrait != null else (who.portrait if who != null else null)
	avatar.custom_minimum_size = Vector2(48, 48) * _scale
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	avatar.flip_h = right
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := Control.new()  # bubbles lean to their speaker's side, like a chat
	gap.custom_minimum_size.x = 84 * _scale
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", _bubble_style(col, i == _sel))
	bubble.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_select(i))
	row.set_meta("bubble", bubble)
	if right:
		row.add_child(gap)
		row.add_child(bubble)
		row.add_child(avatar)
	else:
		row.add_child(avatar)
		row.add_child(bubble)
		row.add_child(gap)
	var v := VBoxContainer.new()
	bubble.add_child(v)
	# who / size / effect / hold / tools
	var bar := HBoxContainer.new()
	v.add_child(bar)
	var num := Label.new()
	num.text = "%d" % (i + 1)
	num.modulate = Color(1, 1, 1, 0.45)
	bar.add_child(num)
	var opt := OptionButton.new()
	for s in _data.cast:
		opt.add_item(s.name)
	opt.select(clampi(line.speaker, 0, _data.cast.size() - 1))
	opt.tooltip_text = "Who says it"
	opt.item_selected.connect(func(k: int) -> void:
		line.speaker = k
		_rebuild_lines())
	row.set_meta("who", opt)
	bar.add_child(opt)
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 0)
	bar.add_child(sizes)
	var group := ButtonGroup.new()
	for k in DialogueLine.SIZES.size():
		var b := Button.new()
		b.text = DialogueLine.SIZE_NAMES[k]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = line.size == k
		b.tooltip_text = "Text size %d" % DialogueLine.SIZES[k]
		b.custom_minimum_size.x = 26 * _scale
		b.pressed.connect(func() -> void:
			line.size = k
			_select(i))
		sizes.add_child(b)
	var fx := OptionButton.new()
	for k in DialogueLine.EFFECT_NAMES.size():
		fx.add_item(DialogueLine.EFFECT_NAMES[k])
	fx.select(line.effect)
	fx.tooltip_text = "How it is said"
	fx.item_selected.connect(func(k: int) -> void:
		line.effect = k
		_select(i)
		_preview.play_line(i))
	bar.add_child(fx)
	var hold := SpinBox.new()
	hold.min_value = 0.0
	hold.max_value = 15.0
	hold.step = 0.5
	hold.value = line.hold
	hold.suffix = "s"
	hold.custom_minimum_size.x = 84 * _scale
	hold.tooltip_text = "Seconds on screen once typed (0 = automatic by length).\nIn cinematic mode the player taps instead."
	hold.value_changed.connect(func(x: float) -> void: line.hold = x)
	var clock := TextureRect.new()
	clock.texture = _icon("Timer")
	clock.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	clock.tooltip_text = hold.tooltip_text
	bar.add_child(clock)
	bar.add_child(hold)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	for t: Array in [["MoveUp", "Move up", -1], ["MoveDown", "Move down", 1]]:
		var mv := Button.new()
		mv.icon = _icon(t[0])
		mv.flat = true
		mv.tooltip_text = t[1]
		mv.disabled = (i == 0 and t[2] < 0) or (i == _data.lines.size() - 1 and t[2] > 0)
		var dir: int = t[2]
		mv.pressed.connect(func() -> void: _move_line(i, dir))
		bar.add_child(mv)
	var face := Button.new()
	face.icon = _icon("Image")
	face.flat = true
	face.tooltip_text = "Line face: Shift+click to clear. A different expression just for this line"
	face.pressed.connect(func() -> void:
		if Input.is_key_pressed(KEY_SHIFT):
			line.portrait = null
			_rebuild_lines()
			return
		_picker_for = -1 - i  # negative = a line's own face
		_picker.start())
	bar.add_child(face)
	var dup := Button.new()
	dup.icon = _icon("Duplicate")
	dup.flat = true
	dup.tooltip_text = "Duplicate"
	dup.pressed.connect(func() -> void:
		var c := DialogueLine.new()
		for p in ["speaker", "text", "size", "effect", "hold", "portrait"]:
			c.set(p, line.get(p))
		_data.lines.insert(i + 1, c)
		_sel = i + 1
		_rebuild_lines())
	bar.add_child(dup)
	var del := Button.new()
	del.icon = _icon("Remove")
	del.flat = true
	del.tooltip_text = "Delete line"
	del.pressed.connect(func() -> void:
		_data.lines.remove_at(i)
		_sel = mini(_sel, _data.lines.size() - 1)
		_rebuild_lines())
	bar.add_child(del)
	# the text
	var te := TextEdit.new()
	te.text = line.text
	te.placeholder_text = "What does %s say?" % (who.name if who != null else "this character")
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.scroll_fit_content_height = true
	te.custom_minimum_size.y = 34 * _scale
	te.add_theme_color_override("font_color", Color(1, 1, 1).lerp(col, 0.25))
	te.text_changed.connect(func() -> void:
		line.text = te.text
		_count.text = _data.summary()
		if _sel == i:
			_preview.show_line(i))
	te.focus_entered.connect(func() -> void: _select(i))
	te.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode in [KEY_ENTER, KEY_KP_ENTER] and e.ctrl_pressed:
			te.accept_event()
			_add_line(_reply_to(i), i + 1))
	_texts.append(te)
	v.add_child(te)
	if line.portrait != null:
		var own := Label.new()
		own.text = "own face for this line (Shift+click the picture button to clear)"
		own.modulate = Color(1, 1, 1, 0.45)
		own.add_theme_font_size_override("font_size", int(10 * _scale))
		v.add_child(own)
	return row


## Who answers line i: the last other speaker, or the next one in the cast.
func _reply_to(i: int) -> int:
	var me := _data.lines[i].speaker
	for k in range(i - 1, -1, -1):
		if _data.lines[k].speaker != me:
			return _data.lines[k].speaker
	return (me + 1) % maxi(1, _data.cast.size())


func _add_line(speaker: int, at: int) -> void:
	var l := DialogueLine.new()
	l.speaker = speaker
	_data.lines.insert(at, l)
	_sel = at
	_rebuild_lines()
	(func() -> void:
		if _sel < _texts.size():
			_texts[_sel].grab_focus()
			_lines_scroll.ensure_control_visible(_rows[_sel])).call_deferred()


func _move_line(i: int, dir: int) -> void:
	var j := i + dir
	if j < 0 or j >= _data.lines.size():
		return
	var l := _data.lines[i]
	_data.lines[i] = _data.lines[j]
	_data.lines[j] = l
	_sel = j
	_rebuild_lines()


func _select(i: int, preview := true) -> void:
	_sel = i
	_paint_selection()
	if preview:
		_preview.show_line(i)


func _paint_selection() -> void:
	for k in _rows.size():
		var who := _data.speaker_of(_data.lines[k])
		var bubble: PanelContainer = _rows[k].get_meta("bubble")
		bubble.add_theme_stylebox_override("panel", _bubble_style(who.color if who != null else Color.WHITE, k == _sel))


# ------------------------------------------------------------------- templates

func _template(id: int) -> void:
	var cast: Array = []  # [name, face path, colour, side, voice]
	var lines: Array = []  # [speaker, text, size, effect]
	var crew := "res://assets/sprites/survivors/"
	match id:
		0:
			cast = [["MISSION CONTROL", "", PALETTE[0], 0, 0.8]]
			lines = [[0, "Cleaner, do you copy? We're picking up movement in your sector.", 0, DialogueLine.Effect.RADIO],
				[0, "Clear the area and find the source. Over.", 0, DialogueLine.Effect.RADIO]]
		1:
			cast = [["CLEANER", "res://assets/sprites/player/idle_0.png", PALETTE[0], 0, 1.0], ["VILLAGER", "res://assets/decor/earth/farm/villagers/girl.png", PALETTE[1], 1, 1.3]]
			lines = [[1, "You came! They took over the whole farm...", 0, 0], [0, "How many are there?", 0, 0],
				[1, "Too many to count. Please, hurry!", 0, 0]]
		2:
			cast = [["CLEANER", "res://assets/sprites/player/idle_0.png", PALETTE[0], 0, 1.0], ["SURVIVOR", crew + "pilot_sad.png", PALETTE[2], 1, 1.4]]
			lines = [[1, "Is... is it over? Are they gone?", 0, DialogueLine.Effect.WHISPER], [0, "You're safe now. Stay behind me.", 0, 0],
				[1, "Thank you! I'll head to the ship.", 0, 0]]
		3:
			cast = [["COMMANDER", "", PALETTE[1], 0, 0.75], ["CLEANER", "res://assets/sprites/player/idle_0.png", PALETTE[0], 1, 1.0], ["SCIENTIST", crew + "scientist_happy.png", PALETTE[4], 0, 1.5]]
			lines = [[0, "Listen up. The nest is somewhere in this valley.", 0, 0], [2, "Its spores spread fast. Destroy it before sunset!", 0, 0],
				[1, "Understood. Moving out.", 0, 0], [0, "Good luck, cleaner.", 0, DialogueLine.Effect.RADIO]]
		4:
			cast = [["???", "", PALETTE[3], 1, 0.5], ["CLEANER", "res://assets/sprites/player/idle_0.png", PALETTE[0], 0, 1.0]]
			lines = [[0, "THIS PLANET IS OURS NOW!", 2, DialogueLine.Effect.SHOUT], [1, "Not on my watch.", 0, 0],
				[1, "...I hope I brought enough ammo.", 0, DialogueLine.Effect.THINK]]
	_data.cast.clear()
	_data.lines.clear()
	for c: Array in cast:
		var s := DialogueSpeaker.new()
		s.name = c[0]
		s.portrait = load(c[1]) if not str(c[1]).is_empty() and ResourceLoader.exists(c[1]) else null
		s.color = c[2]
		s.side = c[3]
		s.voice = c[4]
		_data.cast.append(s)
	for t: Array in lines:
		var l := DialogueLine.new()
		l.speaker = t[0]
		l.text = t[1]
		l.size = t[2]
		l.effect = t[3]
		_data.lines.append(l)
	_sel = 0
	_rebuild_all()
	_preview.play_all()


# ------------------------------------------------------------------- save

func _save() -> void:
	_preview.stop()
	if _trigger == null or not is_instance_valid(_trigger):
		return
	var old: DialogueData = _trigger.dialogue
	undo_redo.create_action("Edit dialogue (%s)" % _trigger.name, UndoRedo.MERGE_DISABLE, _trigger)
	undo_redo.add_do_property(_trigger, "dialogue", _data)
	undo_redo.add_undo_property(_trigger, "dialogue", old)
	undo_redo.add_do_reference(_data)
	undo_redo.add_do_method(_trigger, "notify_property_list_changed")
	undo_redo.add_undo_method(_trigger, "notify_property_list_changed")
	undo_redo.commit_action()
