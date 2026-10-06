@tool
extends VBoxContainer
## The ALIENS CLEANER dock. Top: arena file actions, grid, terrain layers. Middle: tabs
## OBJECTS (palette), MISSIONS, WAVES, DECOR, VALIDATION. Bottom: Validate + Play.
## UI only; actions are signals the plugin carries out (list pages edit ArenaData
## directly through the editor's UndoRedo).

signal new_arena_requested(cfg: Dictionary)
signal duplicate_requested(world: int, level: int)
signal repair_requested
signal settings_requested
signal players_requested
signal refit_requested(cfg: Dictionary)
signal entry_armed(entry: RefCounted)
signal grid_changed(size: int, snap: bool, visible: bool)
signal terrain_layer_requested(layer_name: String)
signal sync_tileset_requested
signal validate_requested
signal play_requested(invincible: bool, start_wave: int)
signal issue_activated(path: NodePath)
signal select_requested
signal delete_requested
signal edit_requested(op: String)
signal entry_cleared_request
signal dialogue_requested

const Terrain := preload("../editor/terrain_tileset_builder.gd")
const Missions := preload("missions_page.gd")
const Waves := preload("waves_page.gd")
const Decor := preload("decor_page.gd")
const TileLibrary := preload("tile_library_dialog.gd")
const SheetImport := preload("sheet_import_dialog.gd")
const ObjectImport := preload("object_import_dialog.gd")
const ObjectEdit := preload("object_edit_dialog.gd")
const Objects := preload("../editor/object_library.gd")
const Factory := preload("../editor/arena_factory.gd")
const SEVERITY_ICONS := ["NodeInfo", "NodeWarning", "StatusError"]
const SEVERITY_NAMES := ["INFO", "WARNING", "ERROR"]

var catalog  # palette_catalog.gd
var missions: Missions
var waves: Waves
var decor: Decor
var _scale := 1.0
var _arena: Arena
var _arena_label: Label
var _arena_sections: Array[Control] = []
var _grid_size: OptionButton
var _snap: CheckBox
var _grid_visible: CheckBox
var _category: OptionButton
var _search: LineEdit
var _items: ItemList
var _placing: Label
var _dialogue_btn: Button
var _issues: Tree
var _tabs: TabContainer
var _summary: Label
var _god: CheckBox
var _tiles: TileLibrary
var _auto: SheetImport
var _import: ObjectImport
var object_edit: ObjectEdit
var _last_entry: RefCounted  # the palette item picked last (for Delete)
var _from_wave: SpinBox
var _new_dialog: ConfirmationDialog
var _dup_dialog: ConfirmationDialog
var _refit_dialog: ConfirmationDialog
var _dlg: Dictionary = {}
var _shown: Array = []  # entries listed in _items


func setup(palette_catalog: RefCounted, grid: RefCounted, undo: EditorUndoRedoManager) -> void:
	catalog = palette_catalog
	_scale = EditorInterface.get_editor_scale()
	name = "AliensCleaner"
	add_theme_constant_override("separation", int(4 * _scale))
	var title := Label.new()
	title.text = "ALIENS CLEANER ARENA"
	title.add_theme_font_size_override("font_size", int(15 * _scale))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var files := HBoxContainer.new()
	add_child(files)
	files.add_child(_button("New", "Add", _open_new_dialog))
	var dup := _button("Duplicate", "Duplicate", _open_dup_dialog)
	dup.tooltip_text = "Copy this arena to another world / level (its own data, new ids)"
	files.add_child(dup)
	_arena_sections.append(dup)
	var settings := _button("Settings", "GDScript", func() -> void: settings_requested.emit())
	settings.tooltip_text = "Arena metadata, difficulty, music, rewards (ArenaData in the Inspector)"
	files.add_child(settings)
	_arena_sections.append(settings)
	var refit := _button("Size & Walls", "ToolScale", _open_refit_dialog)
	refit.tooltip_text = "Change the arena size, its walls (style, band width or none) and its floor"
	files.add_child(refit)
	_arena_sections.append(refit)
	var players := _button("Players", "CharacterBody2D", func() -> void: players_requested.emit())
	players.tooltip_text = "Playable characters: import a sheet, animations, size, weapon; pick who plays this arena"
	files.add_child(players)
	var repair := _button("", "Tools", func() -> void: repair_requested.emit())
	repair.tooltip_text = "Add any missing standard layer"
	files.add_child(repair)
	_arena_sections.append(repair)
	_arena_label = Label.new()
	_arena_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_arena_label)

	var row := _section("GRID")
	_grid_size = OptionButton.new()
	for s: int in grid.SIZES:
		_grid_size.add_item("%d x %d" % [s, s], s)
	_grid_size.select(grid.SIZES.find(grid.size))
	_grid_size.item_selected.connect(func(_i: int) -> void: _emit_grid())
	row.add_child(_grid_size)
	_snap = _check("Snap", grid.snap)
	row.add_child(_snap)
	_grid_visible = _check("Grid", grid.visible)
	row.add_child(_grid_visible)

	var tl := _section("PAINT", true)
	var pick := _button("Select", "ToolSelect", func() -> void: select_requested.emit())
	pick.tooltip_text = "Stop painting terrain: click objects to select, drag to move, Supr to delete"
	tl.add_child(pick)
	for layer_name: String in Arena.TERRAIN + ["Walls"]:
		var paint := _button(layer_name, "", func() -> void: terrain_layer_requested.emit(layer_name))
		paint.tooltip_text = "Select the %s layer and paint it with Godot's TileMap panel (bottom)." % layer_name
		tl.add_child(paint)
	var lib := _button("Tiles…", "TileSet", func() -> void: _tiles.open())
	lib.tooltip_text = "Tile library: import sheets or pictures, groups, remove tiles, autotiles, terrains"
	tl.add_child(lib)
	var auto := _button("Auto-import…", "AssetLib", func() -> void: _auto.start())
	auto.tooltip_text = "One picture of ground art: tiles, paths, patches, plants… sorted on their own into terrain tiles and decoration"
	tl.add_child(auto)
	var sync := _button("", "Reload", func() -> void: sync_tileset_requested.emit())
	sync.tooltip_text = "Rebuild the terrain TileSet from assets/arena/terrain/terrain.json"
	tl.add_child(sync)

	_tabs = TabContainer.new()
	_tabs.clip_tabs = false
	_tabs.add_theme_font_size_override("font_size", int(12 * _scale))
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)
	_arena_sections.append(_tabs)
	_build_objects(_page("OBJECTS"))
	missions = Missions.new()
	missions.name = "MISSIONS"
	_tabs.add_child(missions)
	missions.build(undo)
	waves = Waves.new()
	waves.name = "WAVES"
	_tabs.add_child(waves)
	waves.build(undo)
	decor = Decor.new()
	decor.name = "DECOR"
	_tabs.add_child(decor)
	decor.build(catalog)
	var validation := _page("VALIDATION")
	_issues = Tree.new()
	_issues.hide_root = true
	_issues.custom_minimum_size = Vector2(0, 110 * _scale)
	_issues.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_issues.item_activated.connect(_on_issue_activated)
	_issues.item_selected.connect(_on_issue_activated)
	validation.add_child(_issues)

	# always-visible actions at the bottom
	var actions := HBoxContainer.new()
	add_child(actions)
	_arena_sections.append(actions)
	actions.add_child(_button("Validate", "Search", func() -> void: validate_requested.emit()))
	var play := _button("Play Arena", "PlayScene", func() -> void: play_requested.emit(_god.button_pressed, int(_from_wave.value) - 1))
	play.tooltip_text = "Save and play only this arena (F8 / window close to stop)"
	play.add_theme_color_override("font_color", Color("a7f070"))
	actions.add_child(play)
	_god = CheckBox.new()
	_god.text = "God"
	_god.tooltip_text = "Play invincible"
	actions.add_child(_god)
	_from_wave = SpinBox.new()
	_from_wave.min_value = 1
	_from_wave.max_value = 99
	_from_wave.prefix = "W"
	_from_wave.tooltip_text = "Start at this wave"
	actions.add_child(_from_wave)
	_summary = Label.new()
	_summary.clip_text = true
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.custom_minimum_size.x = 40 * _scale
	actions.add_child(_summary)
	_build_new_dialog()
	_build_dup_dialog()
	_build_refit_dialog()
	_tiles = TileLibrary.new()
	add_child(_tiles)
	_auto = SheetImport.new()
	add_child(_auto)
	_auto.imported.connect(func(_r: String) -> void: reload_palette())
	_import = ObjectImport.new()
	add_child(_import)
	object_edit = ObjectEdit.new()
	add_child(object_edit)
	object_edit.edited.connect(func(_c: String) -> void:
		var keep := _category.get_item_text(_category.selected) if _category.selected >= 0 else ""
		reload_palette()
		for k in _category.item_count:
			if _category.get_item_text(k) == keep:
				_category.select(k)
				_refresh_items())
	_import.imported.connect(func(category: String) -> void:
		reload_palette()
		for k in _category.item_count:
			if _category.get_item_text(k) == category:
				_category.select(k)
				_refresh_items())
	reload_palette()
	set_arena(null)


func _build_objects(objects: VBoxContainer) -> void:
	var filter := HBoxContainer.new()
	objects.add_child(filter)
	_category = OptionButton.new()
	_category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category.item_selected.connect(func(_i: int) -> void: _refresh_items())
	filter.add_child(_category)
	_search = LineEdit.new()
	_search.placeholder_text = "Search..."
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _refresh_items())
	filter.add_child(_search)
	var reload := _button("", "Reload", func() -> void: reload_palette())
	reload.tooltip_text = "Reload the palette (new scenes, PropData props, palette.json)"
	filter.add_child(reload)
	var imp := _button("Import", "Load", func() -> void: _import.start(_current_kit_category()))
	imp.tooltip_text = "Import new objects from PNG pictures (one or several, or a sheet to cut apart)"
	filter.add_child(imp)
	var edit := _button("Edit", "Edit", _edit_objects)
	edit.tooltip_text = "Change the settings of the selected objects (size, blocks, wind, shadow...)"
	filter.add_child(edit)
	var del_obj := _button("", "Remove", _delete_object)
	del_obj.tooltip_text = "Delete the selected objects (Ctrl / Shift + click to select several)"
	filter.add_child(del_obj)
	_items = ItemList.new()
	_items.select_mode = ItemList.SELECT_MULTI  # Ctrl / Shift + click: pick several (Delete)
	_items.icon_mode = ItemList.ICON_MODE_TOP
	_items.max_columns = 0
	_items.same_column_width = true
	_items.fixed_column_width = int(96 * _scale)
	_items.fixed_icon_size = Vector2i(48, 48) * int(maxf(1.0, _scale))
	_items.max_text_lines = 2
	_items.custom_minimum_size = Vector2(0, 120 * _scale)
	_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# SELECT_MULTI only emits multi_selected (never item_selected)
	_items.multi_selected.connect(_on_item_multi_selected)
	objects.add_child(_items)
	var help := HBoxContainer.new()
	objects.add_child(help)
	var tip := Label.new()
	tip.text = "Click select · drag move · R rotate · F/V flip · +/- size · D copy · Supr delete"
	tip.modulate = Color(1, 1, 1, 0.55)
	tip.add_theme_font_size_override("font_size", int(11 * _scale))
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.clip_text = true
	help.add_child(tip)
	for op: Array in [["rotate", "RotateRight", "Rotate 90° (R; Shift+R = 15°)"], ["flip_h", "MirrorX", "Flip horizontally (F)"],
			["flip_v", "MirrorY", "Flip vertically (V)"], ["bigger", "ZoomMore", "Bigger (+)"], ["smaller", "ZoomLess", "Smaller (-)"],
			["duplicate", "Duplicate", "Duplicate (D)"]]:
		var b := _button("", op[1], func() -> void: edit_requested.emit(op[0]))
		b.tooltip_text = op[2]
		b.flat = true
		help.add_child(b)
	var del := _button("", "Remove", func() -> void: delete_requested.emit())
	del.tooltip_text = "Delete the selected objects (Supr)"
	del.flat = true
	help.add_child(del)
	# shown while a Dialogue Trigger is selected
	_dialogue_btn = _button("Edit dialogue of the selected trigger", "RichTextLabel", func() -> void: dialogue_requested.emit())
	_dialogue_btn.tooltip_text = "Characters, faces, lines, text size and effects, with a live preview.
(Also: double-click the trigger in the 2D view.)"
	_dialogue_btn.custom_minimum_size.y = 32 * _scale
	_dialogue_btn.add_theme_color_override("font_color", Color(0.45, 0.94, 0.97))
	_dialogue_btn.visible = false
	objects.add_child(_dialogue_btn)
	_placing = Label.new()
	_placing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_placing.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	objects.add_child(_placing)


## The selected Dialogue Trigger (or null): shows / hides the Edit dialogue button.
func set_dialogue_target(trigger: Node) -> void:
	_dialogue_btn.visible = trigger != null
	if trigger != null:
		_dialogue_btn.text = "Edit dialogue: %s" % trigger.name


func reload_palette() -> void:
	catalog.rebuild()
	var keep := _category.get_item_text(_category.selected) if _category.selected >= 0 else ""
	_category.clear()
	for c: String in catalog.categories():
		_category.add_item(c)
		if c == keep:
			_category.select(_category.item_count - 1)
	_refresh_items()
	if decor != null:
		decor.refresh_entries()


## Shows which arena is being edited (null = the edited scene is not an arena).
func set_arena(arena: Arena) -> void:
	_arena = arena
	for c in _arena_sections:
		c.visible = arena != null
	if arena == null:
		_arena_label.text = "Open an arena scene (scenes/arenas/) or create one with New Arena."
	else:
		var d := arena.data
		_arena_label.text = str(arena.name) if d == null else "%s  ·  W%d-L%d  ·  %s" % [
			d.display_name if d.display_name != "" else str(arena.name), d.world_id, d.level_id, d.difficulty_name()]
		_arena_label.tooltip_text = "" if d == null else "%s · %s" % [d.arena_id, d.environment]
	missions.set_arena(arena)
	waves.set_arena(arena)
	_issues.clear()
	_summary.text = ""
	clear_armed()


func clear_armed() -> void:
	if _items.get_selected_items().size() > 1:
		return  # several picked for Edit / Delete: keep them
	_items.deselect_all()
	_placing.text = ""


func show_placing(entry: RefCounted) -> void:
	_placing.text = "Placing %s in %s — click the 2D view (drag paints with snap). Esc / right-click to stop." % [entry.name, entry.layer]
	_tabs.current_tab = 0


func show_report(report: ArenaReport) -> void:
	_issues.clear()
	var root := _issues.create_item()
	var sorted := report.issues.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.severity) > int(b.severity))
	for issue: Dictionary in sorted:
		var item := _issues.create_item(root)
		var sev := int(issue.severity)
		item.set_text(0, "%s  %s" % [SEVERITY_NAMES[sev], issue.message])
		item.set_icon(0, _icon(SEVERITY_ICONS[sev]))
		item.set_metadata(0, issue.path)
		item.set_tooltip_text(0, "%s\n%s" % [issue.message, str(issue.path)])
	_summary.text = "NOT READY" if report.has_errors() else "READY"
	_summary.tooltip_text = "%s — %s" % ["NOT production ready" if report.has_errors() else "Production ready", report.summary()]
	_summary.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if report.has_errors() else Color(0.5, 1, 0.6))
	_tabs.current_tab = _tabs.get_tab_idx_from_control(_issues.get_parent())


## Category of the palette shown now, as a kit category ("Earth · Trees" -> "Trees").
func _current_kit_category() -> String:
	if _category.selected < 0:
		return "Misc"
	var c := _category.get_item_text(_category.selected)
	return c.get_slice(" · ", 1) if c.contains(" · ") else "Misc"


## The imported objects selected in the palette (their picture paths).
func _selected_object_paths() -> Array[String]:
	var out: Array[String] = []
	for i in _items.get_selected_items():
		var e = _shown[i]
		if e.kind == "scenery" and e.texture != null and e.texture.resource_path.begins_with(Objects.DECOR):
			out.append(e.texture.resource_path)
	return out


func _edit_objects() -> void:
	var paths := _selected_object_paths()
	if paths.is_empty():
		# nothing picked in the palette: the objects selected on the map
		for n in EditorInterface.get_selection().get_selected_nodes():
			if n is ArenaScenery and (n as ArenaScenery).texture != null:
				var p := (n as ArenaScenery).texture.resource_path
				if p.begins_with(Objects.DECOR) and not paths.has(p):
					paths.append(p)
	if paths.is_empty():
		push_warning("Arena Editor: select imported objects in the palette or on the map first.")
		return
	object_edit.start(paths)


## Deletes every selected imported object (Ctrl / Shift + click to pick several).
func _delete_object() -> void:
	var doomed: Array[String] = []
	var names: Array[String] = []
	for i in _items.get_selected_items():
		var e = _shown[i]
		if e.kind == "scenery" and e.texture != null and e.texture.resource_path.begins_with(Objects.DECOR):
			doomed.append(e.texture.resource_path)
			names.append(e.name)
	if doomed.is_empty():
		push_warning("Arena Editor: select imported objects in the palette first (Ctrl / Shift + click for several).")
		return
	var ask := ConfirmationDialog.new()
	ask.dialog_text = "Delete %d object(s) from the palette?
%s

Copies already placed in arenas lose their picture." % [
		doomed.size(), ", ".join(names.slice(0, 12)) + (" ..." if names.size() > 12 else "")]
	ask.confirmed.connect(func() -> void:
		for path in doomed:
			Objects.delete_object(path)
		_last_entry = null
		clear_armed()
		entry_cleared_request.emit()
		reload_palette()
		ask.queue_free())
	ask.canceled.connect(ask.queue_free)
	add_child(ask)
	ask.popup_centered()


func _refresh_items() -> void:
	_items.clear()
	_shown.clear()
	if _category.selected < 0:
		return
	for e in catalog.in_category(_category.get_item_text(_category.selected), _search.text):
		var i := _items.add_item(e.name, e.icon)
		_items.set_item_tooltip(i, e.tooltip)
		_shown.append(e)
	_placing.text = ""


## A plain click picks one object to place; Ctrl / Shift + click several (Edit / Delete)
## stops placing.
func _on_item_multi_selected(_i: int, selected: bool) -> void:
	var picked := _items.get_selected_items()
	if picked.size() == 1:
		_on_item_selected(picked[0])
	elif picked.size() > 1:
		entry_cleared_request.emit()
		_placing.text = "%d objects selected (Edit / Delete). Click one to place it." % picked.size()
	elif not selected:
		entry_cleared_request.emit()


func _on_item_selected(i: int) -> void:
	var e = _shown[i]
	_last_entry = e
	show_placing(e)
	entry_armed.emit(e)


func _on_issue_activated() -> void:
	var item := _issues.get_selected()
	if item != null:
		issue_activated.emit(item.get_metadata(0) as NodePath)


func _emit_grid() -> void:
	grid_changed.emit(_grid_size.get_selected_id(), _snap.button_pressed, _grid_visible.button_pressed)


## One compact row: a coloured caption, then the controls added to the returned box.
func _section(text: String, flow := false) -> Container:
	var box: Container = HFlowContainer.new() if flow else HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 48 * _scale
	label.add_theme_color_override("font_color", Color(0.45, 0.94, 0.97))
	box.add_child(label)
	add_child(box)
	_arena_sections.append(box)
	return box


func _page(title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = title
	_tabs.add_child(page)
	return page


func _button(text: String, icon: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = _icon(icon)
	b.tooltip_text = text
	b.pressed.connect(on_press)
	return b


func _icon(icon_name: String) -> Texture2D:
	var t := EditorInterface.get_editor_theme()
	return t.get_icon(icon_name, "EditorIcons") if t.has_icon(icon_name, "EditorIcons") else null


func _check(text: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(func(_on: bool) -> void: _emit_grid())
	return c


# ---------------------------------------------------------------- dialogs

func _build_new_dialog() -> void:
	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "New Arena"
	_new_dialog.ok_button_text = "Create"
	var g := GridContainer.new()
	g.columns = 2
	_new_dialog.add_child(g)
	_dlg.world = _spin(g, "World", 1, 99, 1)
	_dlg.level = _spin(g, "Level", 1, 99, 1)
	var label := Label.new()
	label.text = "Name"
	g.add_child(label)
	_dlg.name = LineEdit.new()
	_dlg.name.placeholder_text = "e.g. Alien Laboratory"
	_dlg.name.custom_minimum_size.x = 220 * _scale
	g.add_child(_dlg.name)
	_dlg.cols = _spin(g, "Width (tiles of 32)", 8, 256, 26)
	_dlg.rows = _spin(g, "Height (tiles of 32)", 8, 256, 34)
	label = Label.new()
	label.text = "Floor"
	g.add_child(label)
	_dlg.floor = OptionButton.new()
	g.add_child(_dlg.floor)
	_dlg.walls = _option(g, "Walls")
	_dlg.thick = _spin(g, "Band width (tiles)", 1, 16, 3)
	_dlg.thick.tooltip_text = "Only for autotile bands (water...)"
	_dlg.seed = _spin(g, "Floor seed", 1, 99999, 1)
	_new_dialog.confirmed.connect(func() -> void:
		new_arena_requested.emit({
			"world": int(_dlg.world.value), "level": int(_dlg.level.value), "name": _dlg.name.text.strip_edges(),
			"cols": int(_dlg.cols.value), "rows": int(_dlg.rows.value),
			"floor": _dlg.floor.get_selected_id(), "seed": int(_dlg.seed.value),
			"style": str(_dlg.walls.get_item_metadata(_dlg.walls.selected)), "thickness": int(_dlg.thick.value),
		}))
	add_child(_new_dialog)


func _open_new_dialog() -> void:
	_dlg.floor.clear()
	_dlg.floor.add_item("Empty", -1)
	for src in Terrain.floor_sources():
		_dlg.floor.add_item(str(src.name), int(src.id))
	_dlg.floor.select(mini(1, _dlg.floor.item_count - 1))
	_fill_styles(_dlg.walls)
	_new_dialog.popup_centered()


func _build_dup_dialog() -> void:
	_dup_dialog = ConfirmationDialog.new()
	_dup_dialog.title = "Duplicate Arena"
	_dup_dialog.ok_button_text = "Duplicate"
	var g := GridContainer.new()
	g.columns = 2
	_dup_dialog.add_child(g)
	_dlg.dup_world = _spin(g, "World", 1, 99, 1)
	_dlg.dup_level = _spin(g, "Level", 1, 99, 2)
	_dup_dialog.confirmed.connect(func() -> void:
		duplicate_requested.emit(int(_dlg.dup_world.value), int(_dlg.dup_level.value)))
	add_child(_dup_dialog)


func _open_dup_dialog() -> void:
	if _arena == null or _arena.data == null:
		return
	_dlg.dup_world.value = _arena.data.world_id
	var level := _arena.data.level_id + 1
	while FileAccess.file_exists("res://scenes/arenas/arena_world_%02d_level_%02d.tscn" % [_arena.data.world_id, level]):
		level += 1
	_dlg.dup_level.value = level
	_dup_dialog.popup_centered()


func _build_refit_dialog() -> void:
	_refit_dialog = ConfirmationDialog.new()
	_refit_dialog.title = "Size & Walls"
	_refit_dialog.ok_button_text = "Apply"
	var g := GridContainer.new()
	g.columns = 2
	_refit_dialog.add_child(g)
	_dlg.r_cols = _spin(g, "Width (tiles of 32)", 2, 256, 26)
	_dlg.r_rows = _spin(g, "Height (tiles of 32)", 2, 256, 34)
	_dlg.r_style = _option(g, "Walls")
	_dlg.r_thick = _spin(g, "Band width (tiles)", 1, 16, 3)
	_dlg.r_thick.tooltip_text = "Only for autotile bands (water...)"
	_dlg.r_clear = _option(g, "Old walls")
	_dlg.r_clear.add_item("Remove the old frame (strips / bands)", 0)
	_dlg.r_clear.add_item("Clear the whole Walls layer", 1)
	_dlg.r_clear.add_item("Keep them", 2)
	_dlg.r_floor = _option(g, "Floor")
	var label := Label.new()
	label.text = "Outside"
	g.add_child(label)
	_dlg.r_trim = CheckBox.new()
	_dlg.r_trim.text = "Erase floor / environment / details outside"
	_dlg.r_trim.button_pressed = true
	g.add_child(_dlg.r_trim)
	_dlg.r_seed = _spin(g, "Seed", 1, 99999, 1)
	_refit_dialog.confirmed.connect(func() -> void:
		var style_i: int = _dlg.r_style.selected
		refit_requested.emit({
			"cols": int(_dlg.r_cols.value), "rows": int(_dlg.r_rows.value),
			"style": str(_dlg.r_style.get_item_metadata(style_i)), "thickness": int(_dlg.r_thick.value),
			"clear": ["frame", "all", "keep"][_dlg.r_clear.get_selected_id()],
			"floor": _dlg.r_floor.get_selected_id(), "trim": _dlg.r_trim.button_pressed,
			"seed": int(_dlg.r_seed.value),
		}))
	add_child(_refit_dialog)


func _open_refit_dialog() -> void:
	if _arena == null or _arena.get_bounds() == null:
		return
	var size := _arena.get_bounds().size / Arena.TILE
	_dlg.r_cols.value = roundi(size.x)
	_dlg.r_rows.value = roundi(size.y)
	_fill_styles(_dlg.r_style)
	_dlg.r_floor.clear()
	_dlg.r_floor.add_item("Keep as it is", -2)
	for src in Terrain.floor_sources():
		_dlg.r_floor.add_item("Fill empty cells: " + str(src.name), int(src.id))
	_refit_dialog.popup_centered()


## Wall styles into `o`, keeping its current pick (first time: the wall strips).
func _fill_styles(o: OptionButton) -> void:
	var keep: String = str(o.get_item_metadata(o.selected)) if o.item_count > 0 and o.selected >= 0 else ""
	o.clear()
	for st in Factory.wall_styles():
		o.add_item(str(st.name))
		o.set_item_metadata(o.item_count - 1, str(st.key))
		if str(st.key) == keep or (keep == "" and str(st.key).begins_with("border:")):
			o.select(o.item_count - 1)


func _option(g: GridContainer, text: String) -> OptionButton:
	var label := Label.new()
	label.text = text
	g.add_child(label)
	var o := OptionButton.new()
	g.add_child(o)
	return o


func _spin(g: GridContainer, text: String, lo: int, hi: int, value: int) -> SpinBox:
	var label := Label.new()
	label.text = text
	g.add_child(label)
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = value
	g.add_child(s)
	return s
