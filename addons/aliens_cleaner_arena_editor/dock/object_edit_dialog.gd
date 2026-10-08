@tool
extends ConfirmationDialog
## OBJECTS > Edit: change the palette settings of one or several imported objects at any
## time (category, size, blocks, wind, see-through, flat, shadow). Each field starts as
## "keep" when the selected objects disagree. Optionally applies the change to the copies
## already placed in the open arena too (one undoable action).

signal edited(category: String)

const Objects := preload("../editor/object_library.gd")
const KEEP := "(keep)"
const FLAGS := [["sway", "Moves in the wind"], ["fade", "See-through when walked behind"],
	["flat", "Flat on the floor"], ["shadow", "Round shadow (trees)"], ["solid", "Blocks (collision at its base)"]]

var plugin: EditorPlugin
var _paths: Array[String] = []
var _list: Label
var _category: LineEdit
var _width: SpinBox
var _width_on: CheckBox
var _flags := {}  # key -> OptionButton (Keep / Yes / No)
var _placed: CheckBox
var _fps: SpinBox
var _fps_on: CheckBox
var _cols: SpinBox
var _rows: SpinBox
var _grid_on: CheckBox
var _loop: OptionButton


func _init() -> void:
	title = "Edit Objects"
	ok_button_text = "Apply"
	confirmed.connect(_apply)


func start(paths: Array[String]) -> void:
	if _list == null:
		_build()
	_paths = paths
	var items: Array[Dictionary] = []
	for p in paths:
		items.append(Objects.settings(p))
	_list.text = "%d object(s): %s" % [paths.size(), ", ".join(paths.map(func(p: String) -> String: return p.get_file().get_basename()).slice(0, 10))]
	var cats := _same(items, "category")
	_category.text = str(cats) if cats != null else ""
	_category.placeholder_text = KEEP if cats == null else ""
	var w: Variant = _same(items, "width")
	_width.value = float(w) if w != null else float(items[0].get("width", 40.0))
	_width_on.button_pressed = false
	for f: Array in FLAGS:
		var key: String = f[0]
		var o: OptionButton = _flags[key]
		var vals := items.map(func(i: Dictionary) -> bool: return _on(i.get(key)))
		if vals.all(func(v: bool) -> bool: return v == vals[0]):
			o.select(1 if vals[0] else 2)
		else:
			o.select(0)
	var anim: Dictionary = items[0].get("anim", {})
	_fps.set_value_no_signal(float(anim.get("fps", 8.0)))
	_cols.set_value_no_signal(int(anim.get("columns", 1)))
	_rows.set_value_no_signal(int(anim.get("rows", 1)))
	_fps_on.button_pressed = false
	_grid_on.button_pressed = false
	_loop.select(0)
	popup_centered()


## A kit flag: true/false, or for "solid" a [w, h] footprint (null = off).
static func _on(v: Variant) -> bool:
	if v is bool:
		return v
	return v != null


func _same(items: Array[Dictionary], key: String) -> Variant:
	var first: Variant = items[0].get(key)
	for i in items:
		if i.get(key) != first:
			return null
	return first


func _build() -> void:
	var scale := EditorInterface.get_editor_scale()
	var v := VBoxContainer.new()
	add_child(v)
	_list = Label.new()
	_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.custom_minimum_size.x = 440 * scale
	_list.modulate = Color(1, 1, 1, 0.7)
	v.add_child(_list)
	var g := GridContainer.new()
	g.columns = 2
	v.add_child(g)
	_category = _row(g, "Category", LineEdit.new())
	var size_row := HBoxContainer.new()
	_width_on = CheckBox.new()
	_width_on.text = "change"
	size_row.add_child(_width_on)
	_width = SpinBox.new()
	_width.min_value = 2.0
	_width.max_value = 600.0
	_width.step = 0.5
	_width.suffix = "units"
	_width.value_changed.connect(func(_v: float) -> void: _width_on.button_pressed = true)
	size_row.add_child(_width)
	_row(g, "Width", size_row)
	for f: Array in FLAGS:
		var o := OptionButton.new()
		o.add_item(KEEP)
		o.add_item("Yes")
		o.add_item("No")
		_flags[f[0]] = _row(g, f[1], o)
	# animation (spritesheets)
	var fps_row := HBoxContainer.new()
	_fps_on = CheckBox.new()
	_fps_on.text = "change"
	fps_row.add_child(_fps_on)
	_fps = SpinBox.new()
	_fps.min_value = 0.5
	_fps.max_value = 60
	_fps.step = 0.5
	_fps.value_changed.connect(func(_v: float) -> void: _fps_on.button_pressed = true)
	fps_row.add_child(_fps)
	_row(g, "Animation FPS", fps_row)
	var grid_row := HBoxContainer.new()
	_grid_on = CheckBox.new()
	_grid_on.text = "change"
	grid_row.add_child(_grid_on)
	_cols = SpinBox.new()
	_cols.min_value = 1
	_cols.max_value = 256
	_cols.prefix = "cols"
	_rows = SpinBox.new()
	_rows.min_value = 1
	_rows.max_value = 256
	_rows.prefix = "rows"
	for sp: SpinBox in [_cols, _rows]:
		sp.value_changed.connect(func(_v: float) -> void: _grid_on.button_pressed = true)
		grid_row.add_child(sp)
	_row(g, "Frames (spritesheet)", grid_row)
	_loop = OptionButton.new()
	_loop.add_item(KEEP)
	_loop.add_item("Yes")
	_loop.add_item("No (play once)")
	_row(g, "Animation loops", _loop)
	_placed = CheckBox.new()
	_placed.text = "Also change the copies already placed in this arena"
	_placed.button_pressed = true
	v.add_child(_placed)


func _row(g: GridContainer, label: String, c: Control) -> Control:
	var l := Label.new()
	l.text = label
	g.add_child(l)
	c.custom_minimum_size.x = maxf(c.custom_minimum_size.x, 220 * EditorInterface.get_editor_scale())
	g.add_child(c)
	return c


func _apply() -> void:
	var values := {}
	if not _category.text.strip_edges().is_empty():
		values["category"] = _category.text.strip_edges()
	if _width_on.button_pressed:
		values["width"] = _width.value
	for key: String in _flags:
		var sel: int = (_flags[key] as OptionButton).selected
		if sel > 0:
			values[key] = sel == 1
	var anim := {}
	if _fps_on.button_pressed:
		anim["fps"] = _fps.value
	if _grid_on.button_pressed:
		anim["columns"] = int(_cols.value)
		anim["rows"] = int(_rows.value)
		anim["count"] = 0
	if _loop.selected > 0:
		anim["loop"] = _loop.selected == 1
	if not anim.is_empty():
		values["anim"] = anim
	if values.is_empty():
		return
	Objects.update_objects(_paths, values)
	if _placed.button_pressed:
		_update_placed(values)
	edited.emit(str(values.get("category", "")))


## The same change on the arena's copies of these pictures (undoable).
func _update_placed(values: Dictionary) -> void:
	var arena := EditorInterface.get_edited_scene_root() as Arena
	if arena == null or plugin == null:
		return
	var copies := arena.objects("ArenaScenery").filter(func(o: ArenaObject) -> bool:
		var t := (o as ArenaScenery).texture
		return t != null and _paths.has(t.resource_path))
	if copies.is_empty():
		return
	var ur := plugin.get_undo_redo()
	ur.create_action("Edit %d placed object(s)" % copies.size(), UndoRedo.MERGE_DISABLE, arena)
	for o in copies:
		var s := o as ArenaScenery
		var item := Objects.settings(s.texture.resource_path)
		var props := {"sway": "sway", "fade": "fade_behind", "flat": "flat", "shadow": "shadow"}
		for key: String in props:
			if values.has(key):
				ur.add_do_property(s, props[key], values[key])
				ur.add_undo_property(s, props[key], s.get(props[key]))
		var anim: Dictionary = values.get("anim", {})
		var anim_props := {"fps": "fps", "columns": "columns", "rows": "rows", "count": "frame_count"}
		for key: String in anim_props:
			if anim.has(key):
				ur.add_do_property(s, anim_props[key], anim[key])
				ur.add_undo_property(s, anim_props[key], s.get(anim_props[key]))
		if anim.has("loop"):
			ur.add_do_property(s, "play_once", not bool(anim.loop))
			ur.add_undo_property(s, "play_once", s.play_once)
		if values.has("width"):
			ur.add_do_property(s, "width", float(values.width))
			ur.add_undo_property(s, "width", s.width)
		if values.has("solid") or values.has("width"):
			var fp: Variant = item.get("solid")
			var new_fp := Vector2(float(fp[0]), float(fp[1])) if fp is Array else Vector2.ZERO
			ur.add_do_property(s, "footprint", new_fp)
			ur.add_undo_property(s, "footprint", s.footprint)
	ur.commit_action()
