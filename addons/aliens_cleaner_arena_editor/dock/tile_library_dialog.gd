@tool
extends AcceptDialog
## "Tiles" window (dock > PAINT > Tiles): the terrain tile library.
## Left: every tile source by group. Right: the selected source — name, group, solid,
## fill, terrain — its tiles (click to leave one out of the painter), Remove.
## Toolbar: Import Sheet (with a live preview of the cut grid), Import Images, Make
## Autotile, Terrains. All of it goes through tile_library.gd (terrain.json + TileSet).

signal library_changed

const Lib := preload("../editor/tile_library.gd")
const Terrain := preload("../editor/terrain_tileset_builder.gd")

var _tree: Tree
var _cfg: Dictionary = {}
var _id := -1
var _name: LineEdit
var _group: LineEdit
var _solid: CheckBox
var _fill: SpinBox
var _terrain: OptionButton
var _info: Label
var _grid: GridContainer
var _excluded: Array = []
var _picked: Array = []  # tiles selected in the grid
var _details: Control
var _scale := 1.0


func _init() -> void:
	title = "Terrain Tile Library"
	ok_button_text = "Close"
	min_size = Vector2i(980, 620)


func open() -> void:
	if _tree == null:
		_build()
	_reload()
	popup_centered()


func _build() -> void:
	_scale = EditorInterface.get_editor_scale()
	var split := HSplitContainer.new()
	split.split_offset = int(320 * _scale)
	add_child(split)
	var left := VBoxContainer.new()
	split.add_child(left)
	var bar := HFlowContainer.new()
	left.add_child(bar)
	bar.add_child(_btn("Import Sheet", "Load", _import_sheet, "A sheet of tiles: you give the tile size, margins and spacing"))
	bar.add_child(_btn("Import Images", "Image", _import_images, "Loose pictures: each one becomes a tile"))
	bar.add_child(_btn("Make Autotile", "TerrainMatchCorners", _autotile_dialog, "Edges between two textures that paint themselves (Terrains tab)"))
	bar.add_child(_btn("Terrains", "TileSet", _terrains_dialog, "Terrain types of the Terrains tab"))
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_pick)
	left.add_child(_tree)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_details = right
	var g := GridContainer.new()
	g.columns = 4
	right.add_child(g)
	_name = _field(g, "Name", LineEdit.new())
	_group = _field(g, "Group", LineEdit.new())
	_solid = _field(g, "Blocks (solid)", CheckBox.new())
	_fill = _field(g, "Fill tiles", SpinBox.new())
	_fill.tooltip_text = "How many first tiles New Arena uses to fill a floor (0 = not a floor)"
	_terrain = _field(g, "Terrain", OptionButton.new())
	var row := HBoxContainer.new()
	right.add_child(row)
	row.add_child(_btn("Apply", "ImportCheck", _apply, "Save these settings"))
	row.add_child(_btn("Delete Selected Tiles", "Remove", _delete_tiles, "Delete the tiles you selected below (only those)"))
	row.add_child(_btn("Restore Hidden", "Reload", _restore_tiles, "Bring back deleted tiles of built-in art"))
	row.add_child(_btn("Remove Source", "Remove", _remove, "Delete this tile source (cells painted with it go blank)"))
	var coll := HBoxContainer.new()
	right.add_child(coll)
	coll.add_child(_btn("Make Solid", "CollisionShape2D", func() -> void: _tile_collision("solid"),
		"The selected tiles block the astronaut and the aliens (water, rocks...)"))
	coll.add_child(_btn("Make Walkable", "GuiVisibilityVisible", func() -> void: _tile_collision("walk"),
		"The selected tiles never block (a shallow ford, a painted path over water...)"))
	coll.add_child(_btn("Reset Collision", "Reload", func() -> void: _tile_collision("reset"),
		"The selected tiles go back to what the source says (Blocks (solid))"))
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.modulate = Color(1, 1, 1, 0.65)
	right.add_child(_info)
	var hint := Label.new()
	hint.text = "Click tiles to select them (blue), then Make Solid / Make Walkable / Delete. Red = blocks. Faded = deleted."
	hint.modulate = Color(1, 1, 1, 0.5)
	right.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 8
	scroll.add_child(_grid)


func _reload() -> void:
	_cfg = Lib.load_config()
	_tree.clear()
	var root := _tree.create_item()
	var by_group := {}
	for gname in Lib.groups(_cfg):
		var gi := _tree.create_item(root)
		gi.set_text(0, gname)
		gi.set_selectable(0, false)
		gi.set_custom_color(0, Color(0.45, 0.94, 0.97))
		by_group[gname] = gi
	for src: Dictionary in _cfg.get("sources", []):
		var it := _tree.create_item(by_group[str(src.get("group", "General"))])
		it.set_text(0, "%s   #%d" % [src.get("name", "?"), int(src.id)])
		it.set_metadata(0, int(src.id))
		if ResourceLoader.exists(str(src.path)):
			it.set_icon(0, load(str(src.path)))
			it.set_icon_max_width(0, int(48 * _scale))
		if int(src.id) == _id:
			it.select(0)
	_terrain.clear()
	_terrain.add_item("None", 0)
	var terrains: Array = _cfg.get("terrains", [])
	for i in terrains.size():
		_terrain.add_item("All: " + str(terrains[i].name), i + 1)
	_show(_id)


func _on_pick() -> void:
	var it := _tree.get_selected()
	if it != null and it.get_metadata(0) != null:
		_show(int(it.get_metadata(0)))


func _show(id: int) -> void:
	_id = id
	var src := Lib.find(_cfg, id)
	for c in _grid.get_children():
		c.queue_free()
	_details.modulate.a = 1.0 if not src.is_empty() else 0.4
	if src.is_empty():
		_info.text = "Pick a source on the left, or import new tiles."
		return
	_name.text = str(src.get("name", ""))
	_group.text = str(src.get("group", "General"))
	_solid.button_pressed = src.has("solid") and str(src.solid) != "false"
	_fill.value = int(src.get("fill", 0))
	var t: Dictionary = src.get("terrain", {})
	_terrain.disabled = t.has("wang")
	_terrain.select(int(t.all) + 1 if t.has("all") else 0)
	_excluded = Array(src.get("exclude", [])).map(func(v: Variant) -> int: return int(v))
	_picked.clear()
	var tex: Texture2D = load(str(src.path)) if ResourceLoader.exists(str(src.path)) else null
	var origin: Dictionary = src.get("origin", {})
	_info.text = "%s\n%s%s" % [src.path, ("autotile (%s) — Terrains tab" % origin.autotile) if origin.has("autotile") else "",
		("from " + str(origin.get("from", ""))) if origin.has("from") else ""]
	if tex == null:
		return
	var cols := tex.get_width() / Lib.T
	var rows := tex.get_height() / Lib.T
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	for i in cols * rows:
		var region := Rect2i((i % cols) * Lib.T, (i / cols) * Lib.T, Lib.T, Lib.T)
		if img.get_region(region).is_invisible():
			continue
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = region
		var b := TextureButton.new()
		b.texture_normal = at
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(56, 56) * _scale
		b.toggle_mode = true
		var blocks := Terrain.tile_blocks(src, i)
		var base := Color(1.0, 0.55, 0.55) if blocks else Color.WHITE
		b.tooltip_text = "Tile %d%s%s" % [i, " · blocks" if blocks else " · walkable", " (deleted)" if _excluded.has(i) else ""]
		b.modulate = Color(1, 1, 1, 0.22) if _excluded.has(i) else base
		b.disabled = _excluded.has(i)
		b.toggled.connect(func(on: bool) -> void:
			b.modulate = Color(0.45, 0.75, 1.0) if on else base
			if on and not _picked.has(i):
				_picked.append(i)
			elif not on:
				_picked.erase(i))
		_grid.add_child(b)


func _apply() -> void:
	if _id < 0:
		return
	var src := Lib.find(_cfg, _id)
	var values := {"name": _name.text.strip_edges(), "group": _group.text.strip_edges() if not _group.text.strip_edges().is_empty() else "General",
		"fill": int(_fill.value) if _fill.value > 0 else null}
	if not (src.get("solid") is String):
		values["solid"] = true if _solid.button_pressed else null
	var t: Dictionary = src.get("terrain", {})
	if not t.has("wang"):
		values["terrain"] = {"all": _terrain.get_selected_id() - 1} if _terrain.get_selected_id() > 0 else null
	await Lib.update(_id, values)
	_changed()


func _delete_tiles() -> void:
	if _id < 0 or _picked.is_empty():
		return
	var ask := ConfirmationDialog.new()
	ask.dialog_text = "Delete %d selected tile(s)?
Cells painted with them will be blank." % _picked.size()
	ask.confirmed.connect(func() -> void:
		ask.queue_free()
		await Lib.delete_tiles(_id, _picked.duplicate())
		_changed())
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered()


func _tile_collision(mode: String) -> void:
	if _id < 0 or _picked.is_empty():
		return
	await Lib.set_tile_collision(_id, _picked.duplicate(), mode)
	_changed()


func _restore_tiles() -> void:
	if _id >= 0:
		await Lib.restore_tiles(_id)
		_changed()


func _remove() -> void:
	if _id < 0:
		return
	var src := Lib.find(_cfg, _id)
	var ask := ConfirmationDialog.new()
	ask.dialog_text = "Remove \"%s\" from the library?\nCells painted with it will be blank. This cannot be undone." % src.get("name", "")
	ask.confirmed.connect(func() -> void:
		Lib.remove(_id)
		_id = -1
		_changed()
		ask.queue_free())
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered()


func _changed() -> void:
	_reload()
	library_changed.emit()


# ---------------------------------------------------------------- import

func _file_dialog(multiple: bool, on_done: Callable) -> void:
	var fd := EditorFileDialog.new()
	fd.access = EditorFileDialog.ACCESS_FILESYSTEM
	fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES if multiple else EditorFileDialog.FILE_MODE_OPEN_FILE
	fd.filters = PackedStringArray(["*.png, *.webp, *.jpg ; Pictures"])
	fd.title = "Pick the tile picture" + ("s" if multiple else "")
	if multiple:
		fd.files_selected.connect(func(paths: PackedStringArray) -> void:
			on_done.call(paths)
			fd.queue_free())
	else:
		fd.file_selected.connect(func(path: String) -> void:
			on_done.call(PackedStringArray([path]))
			fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	# start where the last import was made (remembered per project)
	var es := EditorInterface.get_editor_settings()
	var last := str(es.get_project_metadata("aliens_cleaner_arena_editor", "last_tile_dir", ""))
	if not last.is_empty() and DirAccess.dir_exists_absolute(last):
		fd.current_dir = last
	var remember := func(path: String) -> void:
		es.set_project_metadata("aliens_cleaner_arena_editor", "last_tile_dir", path.get_base_dir())
	fd.file_selected.connect(remember)
	fd.files_selected.connect(func(paths: PackedStringArray) -> void:
		if not paths.is_empty():
			remember.call(paths[0]))
	# on the editor's own window: a child of a hidden dialog renders black
	EditorInterface.get_base_control().add_child(fd)
	fd.popup_file_dialog()


func _import_sheet() -> void:
	_file_dialog(false, func(paths: PackedStringArray) -> void: _import_options(paths, true))


func _import_images() -> void:
	_file_dialog(true, func(paths: PackedStringArray) -> void: _import_options(paths, false))


## Options for the picked file(s). Sheets show the picture with the cut grid live.
func _import_options(paths: PackedStringArray, sheet: bool) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Import tiles"
	d.ok_button_text = "Import"
	var box := HBoxContainer.new()
	d.add_child(box)
	var g := GridContainer.new()
	g.columns = 2
	box.add_child(g)
	var base := paths[0].get_file().get_basename().capitalize()
	var nm := _field(g, "Name", LineEdit.new()) as LineEdit
	nm.text = base
	var group := _field(g, "Group", LineEdit.new()) as LineEdit
	group.text = "Custom"
	var tw := _spin(g, "Tile width (px)", 1, 4096, 64)
	var th := _spin(g, "Tile height (px)", 1, 4096, 64)
	var mx := _spin(g, "Margin X", 0, 512, 0)
	var my := _spin(g, "Margin Y", 0, 512, 0)
	var sx := _spin(g, "Spacing X", 0, 512, 0)
	var sy := _spin(g, "Spacing Y", 0, 512, 0)
	var skip := _field(g, "Skip empty tiles", CheckBox.new()) as CheckBox
	skip.button_pressed = true
	var seam := _field(g, "Make seamless", CheckBox.new()) as CheckBox
	seam.tooltip_text = "Blend each tile's borders so it repeats without joints (grass, water, dirt...)"
	var solid := _field(g, "Blocks (solid)", CheckBox.new()) as CheckBox
	for c: Control in [tw, th, mx, my, sx, sy]:
		c.get_parent().get_child(c.get_index() - 1).visible = sheet
		c.visible = sheet
	if sheet:
		var preview := _CutPreview.new()
		preview.custom_minimum_size = Vector2(460, 420) * _scale
		preview.image = Lib._load(paths[0])
		box.add_child(preview)
		var refresh := func(_v: float) -> void:
			preview.tile = Vector2i(int(tw.value), int(th.value))
			preview.margin = Vector2i(int(mx.value), int(my.value))
			preview.spacing = Vector2i(int(sx.value), int(sy.value))
			preview.queue_redraw()
		for c: SpinBox in [tw, th, mx, my, sx, sy]:
			c.value_changed.connect(refresh)
		refresh.call(0.0)
	d.confirmed.connect(func() -> void:
		var opts := {"name": nm.text.strip_edges(), "group": group.text.strip_edges(),
			"tile": Vector2i(int(tw.value), int(th.value)), "margin": Vector2i(int(mx.value), int(my.value)),
			"separation": Vector2i(int(sx.value), int(sy.value)), "skip_empty": skip.button_pressed,
			"seamless": seam.button_pressed, "solid": solid.button_pressed}
		d.hide()
		var id := -1
		if sheet:
			id = await Lib.import_sheet(paths[0], opts)
		else:
			id = await Lib.import_images(paths, opts)
		if id >= 0:
			_id = id
		_changed()
		d.queue_free())
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered()


## The sheet with the cut grid drawn over it.
class _CutPreview:
	extends Control
	var image: Image
	var tile := Vector2i(64, 64)
	var margin := Vector2i.ZERO
	var spacing := Vector2i.ZERO
	var _tex: ImageTexture

	func _draw() -> void:
		if image == null:
			return
		if _tex == null:
			_tex = ImageTexture.create_from_image(image)
		var k := minf(size.x / image.get_width(), size.y / image.get_height())
		draw_rect(Rect2(Vector2.ZERO, Vector2(image.get_size()) * k), Color(0, 0, 0, 0.4))
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, Vector2(image.get_size()) * k), false)
		var n := 0
		var y := margin.y
		while y + tile.y <= image.get_height() and n < 4000:
			var x := margin.x
			while x + tile.x <= image.get_width() and n < 4000:
				draw_rect(Rect2(Vector2(x, y) * k, Vector2(tile) * k), Color(1, 0.85, 0.2, 0.9), false, 1.0)
				x += tile.x + spacing.x
				n += 1
			y += tile.y + spacing.y
		draw_string(get_theme_default_font(), Vector2(4, size.y - 6), "%d tiles" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.2))


# ---------------------------------------------------------------- autotile / terrains

func _autotile_dialog() -> void:
	var cfg := Lib.load_config()
	var d := ConfirmationDialog.new()
	d.title = "Make Autotile"
	d.ok_button_text = "Create"
	var g := GridContainer.new()
	g.columns = 2
	d.add_child(g)
	var nm := _field(g, "Name", LineEdit.new()) as LineEdit
	nm.text = "Lava edges"
	var group := _field(g, "Group", LineEdit.new()) as LineEdit
	group.text = "Custom"
	var land_src := _source_picker(g, "Land (outside) source", cfg)
	var land_tile := _spin(g, "Land tile #", 0, 999, 0)
	var other_src := _source_picker(g, "Inside source", cfg)
	var other_tile := _spin(g, "Inside tile #", 0, 999, 0)
	var style := _field(g, "Edge style", OptionButton.new()) as OptionButton
	for s in ["plain", "water", "path", "infested"]:
		style.add_item(s)
	var terrains: Array = cfg.get("terrains", [])
	var land_t := _field(g, "Outside terrain", OptionButton.new()) as OptionButton
	var other_t := _field(g, "Inside terrain", OptionButton.new()) as OptionButton
	for i in terrains.size():
		land_t.add_item(str(terrains[i].name), i)
		other_t.add_item(str(terrains[i].name), i)
	other_t.add_item("+ New terrain", -1)
	other_t.select(other_t.item_count - 1)
	var new_name := _field(g, "New terrain name", LineEdit.new()) as LineEdit
	new_name.text = "Lava"
	var new_color := _field(g, "New terrain color", ColorPickerButton.new()) as ColorPickerButton
	new_color.color = Color("e8572f")
	new_color.custom_minimum_size.x = 80
	var solid := _field(g, "Inside blocks", CheckBox.new()) as CheckBox
	solid.tooltip_text = "Like water: the inside side cannot be walked (polygons follow the edge)"
	var note := Label.new()
	note.text = "Seamless tiles look best. It takes a few seconds."
	note.modulate = Color(1, 1, 1, 0.6)
	g.add_child(Control.new())
	g.add_child(note)
	d.confirmed.connect(func() -> void:
		var land := Lib.tile_image(land_src.get_selected_id(), int(land_tile.value))
		var inside := Lib.tile_image(other_src.get_selected_id(), int(other_tile.value))
		if land == null or inside == null:
			push_error("Make Autotile: pick existing tiles.")
			return
		d.hide()
		var id: int = await Lib.make_autotile(land, inside, {"name": nm.text, "group": group.text, "style": style.get_item_text(style.selected),
			"land_terrain": land_t.get_selected_id(), "other_terrain": other_t.get_selected_id(),
			"new_terrain_name": new_name.text, "new_terrain_color": new_color.color, "solid": solid.button_pressed,
			"seed": randi() % 1000})
		if id >= 0:
			_id = id
		_changed()
		d.queue_free())
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered()


func _terrains_dialog() -> void:
	var cfg := Lib.load_config()
	var d := ConfirmationDialog.new()
	d.title = "Terrains (Terrains tab of the TileMap panel)"
	d.ok_button_text = "Save"
	var g := GridContainer.new()
	g.columns = 2
	d.add_child(g)
	var rows := []
	var terrains: Array = cfg.get("terrains", [])
	for i in terrains.size():
		var n := LineEdit.new()
		n.text = str(terrains[i].name)
		n.custom_minimum_size.x = 200 * _scale
		g.add_child(n)
		var c := ColorPickerButton.new()
		c.color = Color(str(terrains[i].color))
		c.custom_minimum_size.x = 60 * _scale
		g.add_child(c)
		rows.append([n, c])
	var add_name := LineEdit.new()
	add_name.placeholder_text = "New terrain..."
	g.add_child(add_name)
	var add_color := ColorPickerButton.new()
	add_color.color = Color.ORANGE
	g.add_child(add_color)
	d.confirmed.connect(func() -> void:
		var c2 := Lib.load_config()
		c2.terrains = rows.map(func(r: Array) -> Dictionary: return {"name": (r[0] as LineEdit).text, "color": "#" + (r[1] as ColorPickerButton).color.to_html(false)})
		if not add_name.text.strip_edges().is_empty():
			c2.terrains.append({"name": add_name.text.strip_edges(), "color": "#" + add_color.color.to_html(false)})
		await Lib.commit(c2)
		_changed()
		d.queue_free())
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered()


# ---------------------------------------------------------------- helpers

func _source_picker(g: GridContainer, label: String, cfg: Dictionary) -> OptionButton:
	var o := _field(g, label, OptionButton.new()) as OptionButton
	for src: Dictionary in cfg.get("sources", []):
		o.add_item("%s · %s" % [src.get("group", ""), src.get("name", "")], int(src.id))
	return o


func _field(g: GridContainer, label: String, control: Control) -> Control:
	var l := Label.new()
	l.text = label
	g.add_child(l)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 160 * _scale)
	g.add_child(control)
	return control


func _spin(g: GridContainer, label: String, lo: int, hi: int, value: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = value
	return _field(g, label, s) as SpinBox


func _btn(text: String, icon: String, on_press: Callable, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	var t := EditorInterface.get_editor_theme()
	b.icon = t.get_icon(icon, "EditorIcons") if t.has_icon(icon, "EditorIcons") else null
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b
