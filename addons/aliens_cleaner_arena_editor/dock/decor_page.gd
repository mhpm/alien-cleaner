@tool
extends VBoxContainer
## DECOR: the random decoration painter. Tick the decorations to use (decals and
## harmless props from the palette), set density / spacing / seed, choose the whole
## arena or a drawn area and press Scatter. Same seed = same layout; the dice rolls a
## new one. "Remove Last" takes the most recent scatter group away (also undoable).

signal scatter_requested(cfg: Dictionary)
signal remove_last_requested
signal draw_area_requested

const Scatter := preload("../editor/decor_scatter.gd")

var catalog
var _list: ItemList
var _entries: Array = []
var _density: SpinBox
var _spacing: SpinBox
var _seed: SpinBox
var _flip: CheckBox
var _rotate: CheckBox
var _area_mode: OptionButton
var _area_label: Label
var area := Rect2()


func build(palette_catalog: RefCounted) -> void:
	catalog = palette_catalog
	var scale := EditorInterface.get_editor_scale()
	_list = ItemList.new()
	_list.select_mode = ItemList.SELECT_MULTI
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.max_columns = 0
	_list.same_column_width = true
	_list.fixed_column_width = int(70 * scale)
	_list.fixed_icon_size = Vector2i(32, 32) * int(maxf(1.0, scale))
	_list.max_text_lines = 2
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 90 * scale)
	_list.tooltip_text = "Ctrl / Shift click to pick several"
	add_child(_list)
	var g := GridContainer.new()
	g.columns = 4
	add_child(g)
	_density = _spin(g, "Density", 0.5, 40.0, 4.0, 0.5, "Items per 100x100 units")
	_spacing = _spin(g, "Min dist.", 4.0, 200.0, 18.0, 1.0, "Minimum distance between items")
	_seed = _spin(g, "Seed", 1, 999999, 1, 1, "Same seed = same layout")
	var dice := Button.new()
	dice.icon = EditorInterface.get_editor_theme().get_icon("RandomNumberGenerator", "EditorIcons")
	dice.tooltip_text = "New random seed"
	dice.pressed.connect(func() -> void: _seed.value = randi_range(1, 999999))
	g.add_child(dice)
	_flip = CheckBox.new()
	_flip.text = "Random flip"
	_flip.button_pressed = true
	g.add_child(_flip)
	_rotate = CheckBox.new()
	_rotate.text = "Random rotation"
	_rotate.tooltip_text = "Decals only"
	g.add_child(_rotate)
	var row := HBoxContainer.new()
	add_child(row)
	_area_mode = OptionButton.new()
	_area_mode.add_item("Whole arena")
	_area_mode.add_item("Drawn area")
	row.add_child(_area_mode)
	var draw_btn := Button.new()
	draw_btn.text = "Draw Area"
	draw_btn.tooltip_text = "Drag a rectangle in the 2D view"
	draw_btn.pressed.connect(func() -> void:
		_area_mode.select(1)
		draw_area_requested.emit())
	row.add_child(draw_btn)
	_area_label = Label.new()
	_area_label.modulate = Color(1, 1, 1, 0.6)
	row.add_child(_area_label)
	var actions := HBoxContainer.new()
	add_child(actions)
	var go := Button.new()
	go.text = "Scatter"
	go.icon = EditorInterface.get_editor_theme().get_icon("Paint", "EditorIcons")
	go.pressed.connect(_scatter)
	actions.add_child(go)
	var undo_last := Button.new()
	undo_last.text = "Remove Last"
	undo_last.pressed.connect(func() -> void: remove_last_requested.emit())
	actions.add_child(undo_last)
	refresh_entries()


func refresh_entries() -> void:
	_list.clear()
	_entries.clear()
	for e in catalog.entries:
		if Scatter.allowed(e):
			var i := _list.add_item(e.name, e.icon)
			_list.set_item_tooltip(i, e.tooltip)
			_entries.append(e)


func set_area(r: Rect2) -> void:
	area = r
	_area_label.text = "%d x %d" % [r.size.x, r.size.y]


func _scatter() -> void:
	var picked: Array = []
	for i in _list.get_selected_items():
		picked.append(_entries[i])
	if picked.is_empty():
		push_warning("Arena Editor: pick at least one decoration in DECOR.")
		return
	scatter_requested.emit({
		"entries": picked, "density": _density.value, "min_distance": _spacing.value,
		"seed": int(_seed.value), "random_flip": _flip.button_pressed, "random_rotation": _rotate.button_pressed,
		"whole": _area_mode.selected == 0, "area": area,
	})


func _spin(g: GridContainer, text: String, lo: float, hi: float, value: float, step: float, tip: String) -> SpinBox:
	var l := Label.new()
	l.text = text
	g.add_child(l)
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.tooltip_text = tip
	g.add_child(s)
	return s
