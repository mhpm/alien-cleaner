@tool
extends ConfirmationDialog
## OBJECTS > Import: new decoration objects from PNGs. Pick one or more pictures; choose
## the kit and category they go in (new names create them), their size, and how they
## behave (blocks, wind, see-through, flat on the floor, shadow). "Several objects per
## picture" cuts a sheet apart by its transparent gaps. They appear in the palette at once.

signal imported(category: String)

const Objects := preload("../editor/object_library.gd")

var _files := PackedStringArray()
var _kit: OptionButton
var _new_kit: LineEdit
var _category: LineEdit
var _cats: OptionButton
var _scale: SpinBox
var _split: CheckBox
var _solid: CheckBox
var _sway: CheckBox
var _fade: CheckBox
var _flat: CheckBox
var _shadow: CheckBox
var _list: Label
var _animated: CheckBox
var _fw: SpinBox
var _fh: SpinBox
var _fps: SpinBox
var _frames: SpinBox
var _loop: CheckBox
var _sheet_img: Image
var _anim_info: Label
var _preview: _AnimPreview
var _anim_rows: Array[Control] = []


func _init() -> void:
	title = "Import Objects"
	ok_button_text = "Import"
	confirmed.connect(_import)


func start(default_category: String) -> void:
	if _kit == null:
		_build()
	var fd := EditorFileDialog.new()
	fd.access = EditorFileDialog.ACCESS_FILESYSTEM
	fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	fd.filters = PackedStringArray(["*.png, *.webp ; Pictures with transparency"])
	fd.title = "Pick the object pictures (one or more)"
	fd.files_selected.connect(func(paths: PackedStringArray) -> void:
		_files = paths
		_list.text = "%d picture(s): %s" % [paths.size(), ", ".join(Array(paths).map(func(p: String) -> String: return p.get_file()))]
		_refresh_kits(default_category)
		_guess_frames()
		popup_centered()
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	# start where the last import was made (remembered per project)
	var es := EditorInterface.get_editor_settings()
	var last := str(es.get_project_metadata("aliens_cleaner_arena_editor", "last_object_dir", ""))
	if not last.is_empty() and DirAccess.dir_exists_absolute(last):
		fd.current_dir = last
	var remember := func(path: String) -> void:
		es.set_project_metadata("aliens_cleaner_arena_editor", "last_object_dir", path.get_base_dir())
	fd.file_selected.connect(remember)
	fd.files_selected.connect(func(paths: PackedStringArray) -> void:
		if not paths.is_empty():
			remember.call(paths[0]))
	# on the editor's own window: a child of a hidden dialog renders black
	EditorInterface.get_base_control().add_child(fd)
	fd.popup_file_dialog()


func _build() -> void:
	var scale := EditorInterface.get_editor_scale()
	var v := VBoxContainer.new()
	add_child(v)
	_list = Label.new()
	_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.custom_minimum_size.x = 420 * scale
	_list.modulate = Color(1, 1, 1, 0.7)
	v.add_child(_list)
	var g := GridContainer.new()
	g.columns = 2
	v.add_child(g)
	_kit = _row(g, "Kit", OptionButton.new())
	_kit.item_selected.connect(func(_i: int) -> void: _refresh_cats())
	_new_kit = _row(g, "  new kit name", LineEdit.new())
	_new_kit.placeholder_text = "only for a new kit (e.g. desert)"
	_cats = _row(g, "Category", OptionButton.new())
	_cats.item_selected.connect(func(i: int) -> void:
		if _cats.get_item_text(i) != "+ New category":
			_category.text = _cats.get_item_text(i))
	_category = _row(g, "  category name", LineEdit.new())
	_scale = _row(g, "Size (world units / px)", SpinBox.new())
	_scale.min_value = 0.05
	_scale.max_value = 4.0
	_scale.step = 0.05
	_scale.value = 0.5
	_scale.tooltip_text = "0.5 = like the Earth kit. The astronaut is about 25 units tall."
	_split = _row(g, "Several objects per picture", CheckBox.new())
	_split.tooltip_text = "Cut the picture apart where it is transparent (a sheet of objects)"
	_solid = _row(g, "Blocks (collision at its base)", CheckBox.new())
	_sway = _row(g, "Moves in the wind", CheckBox.new())
	_fade = _row(g, "See-through when walked behind", CheckBox.new())
	_flat = _row(g, "Flat on the floor (puddles, cracks)", CheckBox.new())
	_shadow = _row(g, "Round shadow (trees)", CheckBox.new())
	# ---- animation: a spritesheet of frames
	v.add_child(HSeparator.new())
	var ag := GridContainer.new()
	ag.columns = 2
	v.add_child(ag)
	_animated = _row(ag, "Animated (spritesheet)", CheckBox.new())
	_animated.tooltip_text = "The picture is a grid of frames played in a loop (fire, flags, machines...)"
	_fw = _row(ag, "Frame width (px)", SpinBox.new())
	_fh = _row(ag, "Frame height (px)", SpinBox.new())
	_frames = _row(ag, "Frames to play", SpinBox.new())
	_frames.min_value = 1
	_frames.tooltip_text = "How many frames the animation uses, in reading order. Detected from the empty cells at the end of the sheet; lower it to skip blank ones."
	_fps = _row(ag, "Frames per second", SpinBox.new())
	_loop = _row(ag, "Loop", CheckBox.new())
	_loop.button_pressed = true
	for sp: SpinBox in [_fw, _fh]:
		sp.min_value = 1
		sp.max_value = 4096
	_fps.min_value = 0.5
	_fps.max_value = 60
	_fps.step = 0.5
	_fps.value = 8
	_anim_info = Label.new()
	_anim_info.modulate = Color(1, 0.85, 0.3)
	v.add_child(_anim_info)
	_preview = _AnimPreview.new()
	_preview.custom_minimum_size = Vector2(440, 160) * scale
	v.add_child(_preview)
	for c: Control in [_fw, _fh, _frames, _fps, _loop]:
		_anim_rows.append(c)
		_anim_rows.append(c.get_parent().get_child(c.get_index() - 1))
	_animated.toggled.connect(func(_on: bool) -> void: _update_anim(true))
	# a new grid size re-detects the frames; the frame count itself is the user's choice
	for sp: SpinBox in [_fw, _fh]:
		sp.value_changed.connect(func(_v: float) -> void: _update_anim(true))
	for sp: SpinBox in [_frames, _fps]:
		sp.value_changed.connect(func(_v: float) -> void: _update_anim())
	_loop.toggled.connect(func(_on: bool) -> void: _update_anim())


## A strip of square frames is the usual sheet: start with frame = picture height.
func _guess_frames() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(_files[0]) if _files[0].begins_with("res://") else _files[0])
	_sheet_img = img if img != null and not img.is_empty() else null
	_preview.sheet = ImageTexture.create_from_image(img) if _sheet_img != null else null
	if _preview.sheet != null:
		var h := img.get_height()
		_fh.set_value_no_signal(h)
		_fw.set_value_no_signal(h if img.get_width() % h == 0 else img.get_width())
	_animated.button_pressed = false
	_update_anim(true)


func _update_anim(redetect := false) -> void:
	var on := _animated.button_pressed
	for c in _anim_rows:
		c.visible = on
	_preview.visible = on and _preview.sheet != null
	_split.disabled = on
	if on:
		_split.button_pressed = false
	if _preview.sheet == null or not on:
		_anim_info.text = ""
		return
	var cols := maxi(1, _preview.sheet.get_width() / maxi(1, int(_fw.value)))
	var rws := maxi(1, _preview.sheet.get_height() / maxi(1, int(_fh.value)))
	var total := cols * rws
	_frames.max_value = total
	if redetect:
		_frames.set_value_no_signal(Objects.used_frames(_sheet_img, cols, rws) if _sheet_img != null else total)
	var count := clampi(int(_frames.value), 1, total)
	_anim_info.text = "%d x %d grid · playing %d of %d frames" % [cols, rws, count, total]
	_preview.columns = cols
	_preview.rows = rws
	_preview.count = count
	_preview.fps = _fps.value
	_preview.loop = _loop.button_pressed
	_preview.restart()


func _row(g: GridContainer, label: String, c: Control) -> Control:
	var l := Label.new()
	l.text = label
	g.add_child(l)
	c.custom_minimum_size.x = 220 * EditorInterface.get_editor_scale()
	g.add_child(c)
	return c


func _refresh_kits(default_category: String) -> void:
	_kit.clear()
	for k in Objects.kits():
		_kit.add_item(k)
	_kit.add_item("+ New kit")
	_category.text = default_category
	_refresh_cats()


func _refresh_cats() -> void:
	_cats.clear()
	var kit := _kit.get_item_text(_kit.selected)
	if kit != "+ New kit":
		for c in Objects.categories(kit):
			_cats.add_item(c)
	_cats.add_item("+ New category")
	for i in _cats.item_count:
		if _cats.get_item_text(i) == _category.text:
			_cats.select(i)


func _import() -> void:
	var kit := _kit.get_item_text(_kit.selected)
	if kit == "+ New kit":
		kit = _new_kit.text.strip_edges().to_snake_case()
	var category := _category.text.strip_edges()
	if kit.is_empty() or category.is_empty() or _files.is_empty():
		push_warning("Import Objects: give a kit and a category.")
		return
	var anim := {}
	if _animated.button_pressed:
		anim = {"frame": Vector2i(int(_fw.value), int(_fh.value)), "count": int(_frames.value),
			"fps": _fps.value, "loop": _loop.button_pressed}
	var paths := Objects.import_objects(_files, {"kit": kit, "category": category, "scale": _scale.value,
		"anim": anim, "split": _split.button_pressed, "solid": _solid.button_pressed, "sway": _sway.button_pressed,
		"fade": _fade.button_pressed, "flat": _flat.button_pressed, "shadow": _shadow.button_pressed})
	# Godot imports the new pictures in the background: wait (by time) before listing them
	var fs := EditorInterface.get_resource_filesystem()
	var until := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until and (fs.is_scanning() or not paths.all(func(p: String) -> bool: return ResourceLoader.exists(p))):
		await get_tree().process_frame
	print("Arena Editor: imported %d object(s) into %s / %s" % [paths.size(), kit, category])
	imported.emit("%s · %s" % [kit.capitalize(), category])


## Plays the sheet with the chosen frame size, so a wrong size shows at once.
class _AnimPreview:
	extends Control
	var sheet: Texture2D
	var columns := 1
	var rows := 1
	var count := 1  ## frames actually played, in reading order
	var fps := 8.0
	var loop := true
	var _t := 0.0

	func restart() -> void:
		_t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if visible and sheet != null:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		if sheet == null:
			return
		var n := clampi(count, 1, columns * rows)
		var i := int(_t * fps)
		i = i % n if loop else mini(i, n - 1)
		var fs := Vector2(sheet.get_width() / float(columns), sheet.get_height() / float(rows))
		var region := Rect2(Vector2(i % columns, i / columns) * fs, fs)
		var k := minf((size.y - 8.0) / fs.y, (size.x * 0.45) / fs.x)
		var at := Vector2(size.x * 0.25 - fs.x * k * 0.5, 4.0)
		draw_texture_rect_region(sheet, Rect2(at, fs * k), region)
		# the whole sheet with the current frame boxed
		var sk := minf((size.y - 8.0) / sheet.get_height(), (size.x * 0.45) / sheet.get_width())
		var origin := Vector2(size.x * 0.52, 4.0)
		draw_texture_rect(sheet, Rect2(origin, Vector2(sheet.get_size()) * sk), false)
		for c in columns + 1:
			draw_line(origin + Vector2(c * fs.x * sk, 0), origin + Vector2(c * fs.x * sk, sheet.get_height() * sk), Color(1, 1, 1, 0.25))
		for r in rows + 1:
			draw_line(origin + Vector2(0, r * fs.y * sk), origin + Vector2(sheet.get_width() * sk, r * fs.y * sk), Color(1, 1, 1, 0.25))
		# cells left out of the animation: dimmed and crossed out
		for j in range(n, columns * rows):
			var cell := Rect2(origin + Vector2(j % columns, j / columns) * fs * sk, fs * sk)
			draw_rect(cell, Color(0, 0, 0, 0.55))
			draw_line(cell.position, cell.end, Color(1, 0.4, 0.4, 0.6), 1.5)
			draw_line(Vector2(cell.end.x, cell.position.y), Vector2(cell.position.x, cell.end.y), Color(1, 0.4, 0.4, 0.6), 1.5)
		draw_rect(Rect2(origin + region.position * sk, region.size * sk), Color(1, 0.85, 0.3), false, 2.0)
