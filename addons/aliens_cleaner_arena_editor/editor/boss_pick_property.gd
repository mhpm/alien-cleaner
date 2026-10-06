@tool
extends EditorProperty
## Inspector editor for a boss id (Boss Trigger `boss_id`, a wave's `boss_id`): the
## chosen boss's picture and name; click to pick another from a picture grid ("None"
## where a boss is optional). One undoable inspector edit.

var allow_none := false
var _scale := 1.0
var _button: Button
var _picker: PopupPanel
var _grid: GridContainer


func _init() -> void:
	_scale = EditorInterface.get_editor_scale()
	_button = Button.new()
	_button.expand_icon = true
	_button.custom_minimum_size.y = 52 * _scale
	_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button.pressed.connect(_open)
	add_child(_button)
	add_focusable(_button)
	_picker = PopupPanel.new()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 330) * _scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_picker.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	scroll.add_child(_grid)
	add_child(_picker)


func _update_property() -> void:
	var id := str(get_edited_object().get(get_edited_property()))
	if id == "":
		_button.text = "None (pick a boss)" if allow_none else "Pick a boss"
		_button.icon = null
	else:
		_button.text = "%s   ▾" % ArenaArt.enemy_name(id).capitalize()
		_button.icon = ArenaArt.enemy_icon(id)
	_button.tooltip_text = id


func _open() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var ids: Array[String] = []
	if allow_none:
		ids.append("")
	ids.append_array(ArenaArt.enemy_ids(true))
	for id in ids:
		var b := Button.new()
		b.text = ArenaArt.enemy_name(id).capitalize() if id != "" else "None"
		b.icon = ArenaArt.enemy_icon(id) if id != "" else null
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(100, 96) * _scale
		b.clip_text = true
		b.tooltip_text = id if id != "" else "No boss"
		b.pressed.connect(func() -> void:
			_picker.hide()
			emit_changed(get_edited_property(), id))
		_grid.add_child(b)
	_picker.popup_centered()
