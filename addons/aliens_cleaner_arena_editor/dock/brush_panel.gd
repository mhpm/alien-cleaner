@tool
extends VBoxContainer
## OBJECTS > Brush: "One" = a click places one copy (the usual). "Area" = drag a
## rectangle in the 2D view and it fills with copies of the picked objects (Ctrl / Shift
## + click several in the palette to mix them) at random spots; tick what else is random:
## size, opacity, tint (between two colours), flip, rotation. A new seed every drag
## unless "Lock seed". Settings are remembered per project.

signal mode_changed(area: bool)

const META := ["arena_editor", "area_brush"]

var _mode: OptionButton
var _opts: GridContainer
var _count: SpinBox
var _spacing: SpinBox
var _round: CheckBox
var _avoid: CheckBox
var _size: CheckBox
var _size_lo: SpinBox
var _size_hi: SpinBox
var _alpha: CheckBox
var _alpha_lo: SpinBox
var _alpha_hi: SpinBox
var _tint: CheckBox
var _tint_a: ColorPickerButton
var _tint_b: ColorPickerButton
var _flip: CheckBox
var _rot: CheckBox
var _rot_max: SpinBox
var _seed: SpinBox
var _lock: CheckBox


func build(scale: float) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var l := Label.new()
	l.text = "Brush"
	row.add_child(l)
	_mode = OptionButton.new()
	_mode.add_item("One (click)")
	_mode.add_item("Area (random)")
	_mode.tooltip_text = "Area: drag a rectangle in the 2D view and it fills with random copies.\nCtrl / Shift + click several objects to mix them."
	_mode.item_selected.connect(func(_i: int) -> void:
		_opts.visible = is_area()
		_save()
		mode_changed.emit(is_area()))
	row.add_child(_mode)
	_opts = GridContainer.new()
	_opts.columns = 4
	add_child(_opts)
	_count = _spin("Copies", 1, 500, 12, 1, "How many copies to drop in the area")
	_spacing = _spin("Min dist.", 0, 300, 16, 1, "Minimum distance between copies (0 = they may overlap)")
	_round = _box("Round area", false, "Fill the ellipse inside the rectangle instead of the whole rectangle")
	_avoid = _box("Avoid objects", false, "Also keep the minimum distance from objects already on the map")
	_opts.add_child(Control.new())
	_opts.add_child(Control.new())
	_size = _box("Random size", true, "Each copy gets a size between these percentages")
	_size_lo = _spin("", 10, 400, 75, 5, "Smallest size %")
	_size_hi = _spin("", 10, 400, 125, 5, "Largest size %")
	_opts.add_child(Control.new())
	_alpha = _box("Random opacity", false, "Each copy gets an opacity between these percentages")
	_alpha_lo = _spin("", 5, 100, 60, 5, "Lowest opacity %")
	_alpha_hi = _spin("", 5, 100, 100, 5, "Highest opacity %")
	_opts.add_child(Control.new())
	_tint = _box("Tint", false, "Each copy is tinted with a colour between these two\n(same colour twice = all the same tint)")
	_tint_a = _color(Color(1, 1, 1))
	_tint_b = _color(Color(0.8, 1, 0.7))
	_opts.add_child(Control.new())
	_flip = _box("Random flip", true, "Half of the copies are mirrored")
	_rot = _box("Random rotation", false, "Tilted up to ± this many degrees")
	_rot_max = _spin("", 1, 180, 15, 1, "Largest tilt in degrees")
	_opts.add_child(Control.new())
	_seed = _spin("Seed", 1, 999999, 1, 1, "Same seed + same area = same result")
	_lock = _box("Lock seed", false, "Off: every drag rolls a new seed")
	var dice := Button.new()
	dice.icon = EditorInterface.get_editor_theme().get_icon("RandomNumberGenerator", "EditorIcons")
	dice.tooltip_text = "New random seed"
	dice.pressed.connect(func() -> void: _seed.value = randi_range(1, 999999))
	_opts.add_child(dice)
	_load()
	_opts.visible = is_area()


func is_area() -> bool:
	return _mode.selected == 1


## Settings for area_brush.gd; rolls the next seed unless it is locked.
func take_config() -> Dictionary:
	var cfg := {
		"count": int(_count.value), "min_dist": _spacing.value, "round": _round.button_pressed,
		"avoid": _avoid.button_pressed, "seed": int(_seed.value),
		"size": [_size.button_pressed, minf(_size_lo.value, _size_hi.value), maxf(_size_lo.value, _size_hi.value)],
		"opacity": [_alpha.button_pressed, minf(_alpha_lo.value, _alpha_hi.value), maxf(_alpha_lo.value, _alpha_hi.value)],
		"tint": [_tint.button_pressed, _tint_a.color, _tint_b.color],
		"flip": _flip.button_pressed, "rotation": [_rot.button_pressed, _rot_max.value],
	}
	if not _lock.button_pressed:
		_seed.value = randi_range(1, 999999)
	return cfg


func is_round() -> bool:
	return _round.button_pressed


func _box(text: String, on: bool, tip: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.tooltip_text = tip
	c.toggled.connect(func(_on: bool) -> void: _save())
	_opts.add_child(c)
	return c


func _spin(text: String, lo: float, hi: float, value: float, step: float, tip: String) -> SpinBox:
	if not text.is_empty():
		var l := Label.new()
		l.text = text
		_opts.add_child(l)
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.tooltip_text = tip
	s.value_changed.connect(func(_v: float) -> void: _save())
	_opts.add_child(s)
	return s


func _color(c: Color) -> ColorPickerButton:
	var b := ColorPickerButton.new()
	b.color = c
	b.edit_alpha = false
	b.custom_minimum_size = Vector2(36, 24) * EditorInterface.get_editor_scale()
	b.color_changed.connect(func(_c: Color) -> void: _save())
	_opts.add_child(b)
	return b


func _fields() -> Dictionary:
	return {"mode": _mode, "count": _count, "spacing": _spacing, "round": _round, "avoid": _avoid,
		"size": _size, "size_lo": _size_lo, "size_hi": _size_hi, "alpha": _alpha, "alpha_lo": _alpha_lo,
		"alpha_hi": _alpha_hi, "tint": _tint, "tint_a": _tint_a, "tint_b": _tint_b, "flip": _flip,
		"rot": _rot, "rot_max": _rot_max, "seed": _seed, "lock": _lock}


func _save() -> void:
	if _lock == null:
		return  # still building
	var d := {}
	var f := _fields()
	for k: String in f:
		var c: Control = f[k]
		if c is OptionButton:
			d[k] = (c as OptionButton).selected
		elif c is SpinBox:
			d[k] = (c as SpinBox).value
		elif c is CheckBox:
			d[k] = (c as CheckBox).button_pressed
		elif c is ColorPickerButton:
			d[k] = (c as ColorPickerButton).color
	EditorInterface.get_editor_settings().set_project_metadata(META[0], META[1], d)


func _load() -> void:
	var d: Variant = EditorInterface.get_editor_settings().get_project_metadata(META[0], META[1], {})
	if not d is Dictionary:
		return
	var f := _fields()
	for k: String in (d as Dictionary):
		if not f.has(k):
			continue
		var c: Control = f[k]
		var v: Variant = d[k]
		if c is OptionButton:
			(c as OptionButton).select(int(v))
		elif c is SpinBox:
			(c as SpinBox).set_value_no_signal(float(v))
		elif c is CheckBox:
			(c as CheckBox).set_pressed_no_signal(bool(v))
		elif c is ColorPickerButton and v is Color:
			(c as ColorPickerButton).color = v
