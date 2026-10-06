@tool
extends EditorPlugin
## Aliens Cleaner Arena Editor: a dock + 2D viewport tools for building Arena scenes.
## Editor-only; the runtime side (Arena, components, ArenaWorld...) is in scripts/arena/.
## This file only wires the pieces together:
##   dock/arena_dock.gd                UI (+ pages: missions, waves, decor)
##   editor/palette_catalog.gd         what can be placed (scene folders, PropData, palette.json)
##   editor/placement_tool.gd          click / drag placement with snap, undoable
##   editor/bounds_handles.gd          resize ArenaBounds in the viewport, undoable
##   editor/area_tool.gd               drag the DECOR area
##   editor/decor_scatter.gd           random decoration painter
##   editor/grid_settings.gd           grid size / snap / visibility + grid overlay
##   editor/arena_factory.gd           New / Duplicate Arena, Repair Structure
##   editor/terrain_tileset_builder.gd TileSet from assets/arena/terrain/terrain.json

const Dock := preload("dock/arena_dock.gd")
const Catalog := preload("editor/palette_catalog.gd")
const Placement := preload("editor/placement_tool.gd")
const BoundsHandles := preload("editor/bounds_handles.gd")
const AreaTool := preload("editor/area_tool.gd")
const SelectTool := preload("editor/select_tool.gd")
const Scatter := preload("editor/decor_scatter.gd")
const Grid := preload("editor/grid_settings.gd")
const Factory := preload("editor/arena_factory.gd")
const Terrain := preload("editor/terrain_tileset_builder.gd")
const DialogueEditor := preload("dock/dialogue_editor.gd")
const DialogueInspector := preload("editor/dialogue_inspector.gd")
const CharacterEditor := preload("dock/character_editor.gd")
const SpawnInspector := preload("editor/spawn_inspector.gd")
const SurvivorInspector := preload("editor/survivor_inspector.gd")
const EnemyInspector := preload("editor/enemy_inspector.gd")

var dock_host: EditorDock
var dock: Dock
var catalog: Catalog
var grid: Grid
var placement: Placement
var bounds_tool: BoundsHandles
var area_tool: AreaTool
var select_tool: SelectTool
var dialogue_editor: DialogueEditor
var dialogue_inspector: DialogueInspector
var character_editor: CharacterEditor
var spawn_inspector: SpawnInspector
var survivor_inspector: SurvivorInspector
var enemy_inspector: EnemyInspector


func _enter_tree() -> void:
	grid = Grid.new()
	grid.load_settings()
	grid.changed.connect(update_overlays)
	placement = Placement.new(self, grid)
	placement.disarmed.connect(func() -> void:
		dock.clear_armed()
		update_overlays())
	bounds_tool = BoundsHandles.new(self, grid)
	select_tool = SelectTool.new(self, grid)
	area_tool = AreaTool.new(grid)
	area_tool.area_drawn.connect(func(r: Rect2) -> void:
		dock.decor.set_area(r)
		update_overlays())
	catalog = Catalog.new()
	dock_host = EditorDock.new()
	dock_host.title = "Arena"
	dock_host.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	dock = Dock.new()
	dock_host.add_child(dock)
	add_dock(dock_host)
	dock.setup(catalog, grid, get_undo_redo())
	dock.object_edit.plugin = self
	dock.new_arena_requested.connect(_new_arena)
	dock.duplicate_requested.connect(_duplicate_arena)
	dock.repair_requested.connect(_repair)
	dock.settings_requested.connect(_settings)
	dock.players_requested.connect(open_players)
	dock.refit_requested.connect(_refit)
	dock.entry_armed.connect(_arm)
	dock.grid_changed.connect(grid.set_values)
	dock.terrain_layer_requested.connect(_edit_terrain)
	dock.sync_tileset_requested.connect(_sync_tileset)
	dock.validate_requested.connect(_validate)
	dock.play_requested.connect(_play)
	dock.issue_activated.connect(_select_path)
	dock.select_requested.connect(_select_mode)
	dock.entry_cleared_request.connect(func() -> void: placement.disarm())
	dock.edit_requested.connect(func(op: String) -> void:
		var a := _arena()
		if a == null:
			return
		match op:
			"rotate": select_tool.rotate_selected(a, 90.0)
			"flip_h": select_tool.flip_selected(a, true)
			"flip_v": select_tool.flip_selected(a, false)
			"bigger": select_tool.scale_selected(a, 1.1)
			"smaller": select_tool.scale_selected(a, 1.0 / 1.1)
			"duplicate": select_tool.duplicate_selected(a)
		update_overlays())
	dock.delete_requested.connect(func() -> void:
		if _arena() != null:
			select_tool.delete_selected(_arena()))
	dock.waves.spawner_for_wave.connect(_spawner_for_wave)
	dock.decor.scatter_requested.connect(_scatter)
	dock.decor.remove_last_requested.connect(_remove_last_scatter)
	dock.decor.draw_area_requested.connect(_draw_area)
	scene_changed.connect(_on_scene_changed)
	EditorInterface.get_selection().selection_changed.connect(update_overlays)
	EditorInterface.get_selection().selection_changed.connect(_keep_active)
	EditorInterface.get_selection().selection_changed.connect(_dialogue_selection)
	dock.dialogue_requested.connect(func() -> void:
		var t := _selected_dialogue_trigger()
		if t != null:
			open_dialogue(t))
	dialogue_editor = DialogueEditor.new()
	EditorInterface.get_base_control().add_child(dialogue_editor)
	dialogue_inspector = DialogueInspector.new()
	dialogue_inspector.open = open_dialogue
	add_inspector_plugin(dialogue_inspector)
	character_editor = CharacterEditor.new()
	character_editor.undo = get_undo_redo()
	character_editor.characters_changed.connect(func() -> void: dock.reload_palette())
	EditorInterface.get_base_control().add_child(character_editor)
	spawn_inspector = SpawnInspector.new()
	spawn_inspector.open = open_players
	add_inspector_plugin(spawn_inspector)
	survivor_inspector = SurvivorInspector.new()
	survivor_inspector.undo = get_undo_redo()
	add_inspector_plugin(survivor_inspector)
	enemy_inspector = EnemyInspector.new()
	add_inspector_plugin(enemy_inspector)
	set_force_draw_over_forwarding_enabled()
	_on_scene_changed(EditorInterface.get_edited_scene_root())


func _exit_tree() -> void:
	if EditorInterface.get_selection().selection_changed.is_connected(update_overlays):
		EditorInterface.get_selection().selection_changed.disconnect(update_overlays)
	if EditorInterface.get_selection().selection_changed.is_connected(_keep_active):
		EditorInterface.get_selection().selection_changed.disconnect(_keep_active)
	if EditorInterface.get_selection().selection_changed.is_connected(_dialogue_selection):
		EditorInterface.get_selection().selection_changed.disconnect(_dialogue_selection)
	# the dock first: if anything below fails, no ghost "Arena" dock stays behind
	if dock_host != null:
		remove_dock(dock_host)
		dock_host.queue_free()
	if spawn_inspector != null:
		remove_inspector_plugin(spawn_inspector)
	if survivor_inspector != null:
		remove_inspector_plugin(survivor_inspector)
	if enemy_inspector != null:
		remove_inspector_plugin(enemy_inspector)
	if is_instance_valid(character_editor):
		character_editor.queue_free()
	if dialogue_inspector != null:
		remove_inspector_plugin(dialogue_inspector)
	if is_instance_valid(dialogue_editor):
		dialogue_editor.queue_free()


func _arena() -> Arena:
	return EditorInterface.get_edited_scene_root() as Arena


## Arena-local space -> 2D viewport overlay space.
func _xform(arena: Arena) -> Transform2D:
	return EditorInterface.get_editor_viewport_2d().global_canvas_transform * arena.global_transform


func _handles(object: Object) -> bool:
	var arena := _arena()
	return arena != null and object is Node and (object == arena or arena.is_ancestor_of(object))


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var arena := _arena()
	if arena == null:
		return false
	var xf := _xform(arena)
	if _dialogue_double_click(event, arena, xf):
		return true
	var used := area_tool.handle_input(event, xf) or placement.handle_input(event, arena, xf) \
			or bounds_tool.handle_input(event, arena, xf) \
			or (not placement.armed() and not area_tool.drawing and select_tool.handle_input(event, arena, xf))
	if used or event is InputEventMouseMotion:
		update_overlays()
	return used


## Double-click a Dialogue Trigger in the 2D view: open its Dialogue Editor.
func _dialogue_double_click(event: InputEvent, arena: Arena, xf: Transform2D) -> bool:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.double_click or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed or placement.armed():
		return false
	var p := arena.to_global(xf.affine_inverse() * mb.position)
	for o in arena.objects("ArenaTrigger"):
		var t := o as ArenaTrigger
		if t.action == ArenaTrigger.Action.MESSAGE and t.contains(p):
			open_dialogue.call_deferred(t)
			return true
	return false


func open_dialogue(trigger: ArenaTrigger) -> void:
	if is_instance_valid(trigger):
		dialogue_editor.start(trigger, get_undo_redo())


func _selected_dialogue_trigger() -> ArenaTrigger:
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is ArenaTrigger and (n as ArenaTrigger).action == ArenaTrigger.Action.MESSAGE:
			return n as ArenaTrigger
	return null


func _dialogue_selection() -> void:
	dock.set_dialogue_target(_selected_dialogue_trigger())


func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	var arena := _arena()
	if arena == null:
		return
	var xf := _xform(arena)
	var bounds := arena.get_bounds()
	grid.draw(overlay, xf, Rect2(bounds.position, bounds.size) if bounds != null else Rect2(0, 0, 512, 512))
	_draw_links(overlay, arena)
	bounds_tool.draw(overlay, xf, arena)
	if not placement.armed():
		select_tool.draw(overlay, arena)
	if dock._tabs.get_current_tab_control() == dock.decor or area_tool.drawing:
		area_tool.draw(overlay, xf)
	placement.draw(overlay, xf)


## Mission links: from the selected objective / wave (dock) to the objects it is about.
func _draw_links(overlay: Control, arena: Arena) -> void:
	var canvas := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var font := overlay.get_theme_default_font()
	var tab := dock._tabs.get_current_tab_control()
	var targets: Array[ArenaObject] = []
	var col := Color("73eff7")
	if tab == dock.missions and dock.missions._selected() is ObjectiveData:
		var od := dock.missions._selected() as ObjectiveData
		if not od.required_object_ids.is_empty():
			for id in od.required_object_ids:
				var o := arena.find_object(id)
				if o != null:
					targets.append(o)
		else:
			var cls: String = ObjectiveData.OBJECT_CLASSES.get(od.type, "")
			if od.type == ObjectiveData.Type.COLLECT:
				targets = arena.objects("AndroidPart") + arena.objects("ArenaChest")
			elif not cls.is_empty():
				targets = arena.objects(cls)
	elif tab == dock.waves and dock.waves._selected() is WaveData:
		col = Color("ff6a4d")
		var w := dock.waves._selected() as WaveData
		targets = arena.objects("EnemySpawner").filter(func(o: ArenaObject) -> bool: return (o as EnemySpawner).wave_id == w.wave_id)
	for o in targets:
		var p := canvas * o.global_position
		overlay.draw_arc(p, 18.0, 0.0, TAU, 32, col, 2.0)
		overlay.draw_arc(p, 22.0, 0.0, TAU, 32, Color(col, 0.4), 1.0)
		overlay.draw_string(font, p + Vector2(24, 4), o.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


## The viewport tools only receive clicks while something of the arena is selected:
## with nothing selected, quietly select the arena root.
func _keep_active() -> void:
	var arena := _arena()
	if arena != null and EditorInterface.get_selection().get_selected_nodes().is_empty():
		(func() -> void:
			if EditorInterface.get_selection().get_selected_nodes().is_empty() and _arena() == arena:
				EditorInterface.get_selection().add_node(arena)).call_deferred()


## Leave terrain painting: back to picking objects.
func _select_mode() -> void:
	var arena := _arena()
	if arena == null:
		return
	placement.disarm()
	area_tool.cancel()
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(arena)
	EditorInterface.set_main_screen_editor("2D")


func _on_scene_changed(_root: Node) -> void:
	placement.disarm()
	area_tool.cancel()
	area_tool.rect = Rect2()
	dock.set_arena(_arena())
	update_overlays()


func _arm(entry: RefCounted) -> void:
	var arena := _arena()
	if arena == null:
		return
	area_tool.cancel()
	placement.arm(entry)
	# input only reaches this plugin while something of the arena is selected
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(arena)
	EditorInterface.set_main_screen_editor("2D")
	update_overlays()


func _spawner_for_wave(wave_id: String) -> void:
	var e = catalog.scene_entry("enemy_spawner")
	if e == null:
		_alert("No enemy_spawner.tscn in scenes/arena/palette/spawners/.")
		return
	var armed = e.with_preset({"wave_id": wave_id}, "Spawner (%s)" % wave_id)
	dock.show_placing(armed)
	_arm(armed)


func _draw_area() -> void:
	var arena := _arena()
	if arena == null:
		return
	placement.disarm()
	area_tool.begin()
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(arena)
	EditorInterface.set_main_screen_editor("2D")
	print("Arena Editor: drag a rectangle in the 2D view (Esc cancels).")


func _scatter(cfg: Dictionary) -> void:
	var arena := _arena()
	if arena == null:
		return
	var b := arena.get_bounds()
	var area: Rect2 = cfg.area
	if bool(cfg.whole) or area.size == Vector2.ZERO:
		area = Rect2(b.position, b.size) if b != null else Rect2(0, 0, 512, 512)
	cfg.area = area
	var nodes := Scatter.generate(arena, cfg)
	if nodes.is_empty():
		_alert("Nothing fitted: lower the minimum distance or raise the density.")
		return
	var ur := get_undo_redo()
	ur.create_action("Scatter Decoration (seed %d)" % int(cfg.seed), UndoRedo.MERGE_DISABLE, arena)
	var groups := {}
	for n in nodes:
		var layer_name: String = (n as ArenaObject).arena_layer()
		if not groups.has(layer_name):
			var g := Node2D.new()
			g.name = "Scatter_%d" % int(cfg.seed)
			g.y_sort_enabled = true
			g.set_meta("arena_scatter", true)
			var parent := arena.get_layer(layer_name)
			if parent == null:
				parent = arena
			ur.add_do_method(parent, "add_child", g, true)
			ur.add_do_method(g, "set_owner", arena)
			ur.add_do_reference(g)
			ur.add_undo_method(parent, "remove_child", g)
			groups[layer_name] = g
		var group: Node2D = groups[layer_name]
		ur.add_do_method(group, "add_child", n, true)
		ur.add_do_method(n, "set_owner", arena)
		ur.add_do_reference(n)
	ur.commit_action()
	print("Arena Editor: scattered %d decorations (seed %d)." % [nodes.size(), int(cfg.seed)])


func _remove_last_scatter() -> void:
	var arena := _arena()
	if arena == null:
		return
	var groups: Array[Node] = []
	for layer_name: String in ["Decorations", "Obstacles"]:
		var layer := arena.get_layer(layer_name)
		if layer != null:
			for c in layer.get_children():
				if c.has_meta("arena_scatter"):
					groups.append(c)
	if groups.is_empty():
		return
	# the newest scatter is the last child; remove its groups in both layers (same name)
	var last_name: StringName = groups.back().name
	var ur := get_undo_redo()
	ur.create_action("Remove Scatter %s" % last_name, UndoRedo.MERGE_DISABLE, arena)
	for g in groups:
		if g.name == last_name:
			var parent := g.get_parent()
			ur.add_do_method(parent, "remove_child", g)
			ur.add_undo_method(parent, "add_child", g, true)
			ur.add_undo_method(g, "set_owner", arena)
			ur.add_undo_reference(g)
	ur.commit_action()


func _new_arena(cfg: Dictionary) -> void:
	var path := Factory.scene_path(int(cfg.world), int(cfg.level))
	if FileAccess.file_exists(path):
		_alert("%s already exists. Choose another world / level, or open it." % path)
		return
	path = Factory.create(cfg)
	if path.is_empty():
		_alert("Could not create the arena (see the Output panel).")
		return
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(path)


func _duplicate_arena(world: int, level: int) -> void:
	var arena := _arena()
	if arena == null or arena.scene_file_path.is_empty():
		return
	EditorInterface.save_scene()
	var res := Factory.duplicate_arena(arena.scene_file_path, world, level)
	if str(res[0]).is_empty():
		_alert("Could not duplicate (does %s exist already?)." % Factory.scene_path(world, level))
		return
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(res[0])
	if int(res[1]) > 0:
		_alert("Duplicated. It carries %d android part(s): their part_id must be unique in the game — change or delete them (Validate lists them)." % int(res[1]))


func _repair() -> void:
	var arena := _arena()
	if arena == null:
		return
	if arena.data == null:
		var ur := get_undo_redo()
		ur.create_action("Add ArenaData", UndoRedo.MERGE_DISABLE, arena)
		ur.add_do_property(arena, "data", Factory.new_data(1, 1, str(arena.name)))
		ur.add_undo_property(arena, "data", null)
		ur.commit_action()
	var n := Factory.repair(arena, get_undo_redo())
	print("Arena Editor: %s" % ("structure OK" if n == 0 else "added %d missing layer(s)" % n))


## Size & Walls: resize the bounds and rebuild walls / floor as one undoable action.
func _refit(cfg: Dictionary) -> void:
	var arena := _arena()
	if arena == null:
		return
	if not arena.missing_layers().is_empty():
		_repair()
	var bounds := arena.get_bounds()
	var layers: Array[TileMapLayer] = []
	for layer_name: String in Arena.TERRAIN + ["Walls"]:
		var tl := arena.get_layer(layer_name) as TileMapLayer
		if tl != null:
			layers.append(tl)
	var before: Array[PackedByteArray] = []
	for tl in layers:
		before.append(tl.tile_map_data)
	var old_size := bounds.size
	Factory.refit(arena, cfg)
	var ur := get_undo_redo()
	ur.create_action("Arena Size & Walls", UndoRedo.MERGE_DISABLE, arena)
	ur.add_do_property(bounds, "size", bounds.size)
	ur.add_undo_property(bounds, "size", old_size)
	for k in layers.size():
		ur.add_do_property(layers[k], "tile_map_data", layers[k].tile_map_data)
		ur.add_undo_property(layers[k], "tile_map_data", before[k])
	ur.commit_action(false)
	update_overlays()


## Players window (playable characters) for the open arena.
func open_players() -> void:
	character_editor.open(_arena())


func _settings() -> void:
	var arena := _arena()
	if arena == null:
		return
	if arena.data == null:
		_repair()
	EditorInterface.edit_resource(arena.data)


func _edit_terrain(layer_name: String) -> void:
	var arena := _arena()
	if arena == null:
		return
	placement.disarm()
	var layer := arena.get_layer(layer_name)
	if layer == null:
		_alert("This arena has no %s layer: use Repair." % layer_name)
		return
	if layer is TileMapLayer and (layer as TileMapLayer).tile_set == null and ResourceLoader.exists(Terrain.tileset_path()):
		(layer as TileMapLayer).tile_set = load(Terrain.tileset_path())
	EditorInterface.set_main_screen_editor("2D")
	EditorInterface.edit_node(layer)


func _sync_tileset() -> void:
	var ts := Terrain.sync()
	if ts == null:
		_alert("TileSet sync failed (see the Output panel).")
		return
	EditorInterface.get_resource_filesystem().scan()
	print("Arena Editor: TileSet synced -> %s (%d sources)" % [Terrain.tileset_path(), ts.get_source_count()])


func _validate() -> ArenaReport:
	var arena := _arena()
	if arena == null:
		return null
	var report := ArenaValidator.validate(arena)
	dock.show_report(report)
	return report


func _play(invincible: bool, start_wave: int) -> void:
	var arena := _arena()
	if arena == null:
		return
	if arena.scene_file_path.is_empty():
		_alert("Save the arena scene first.")
		return
	EditorInterface.save_scene()
	var report := _validate()
	if report != null and report.has_errors():
		push_warning("Arena Editor: playing an arena with %d validation error(s)." % report.count(ArenaReport.Severity.ERROR))
	ArenaSession.write_request(arena.scene_file_path, invincible, maxi(0, start_wave))
	EditorInterface.play_custom_scene(ArenaSession.PLAY_SCENE)


func _select_path(path: NodePath) -> void:
	var arena := _arena()
	if arena == null:
		return
	var node := arena.get_node_or_null(path) if not path.is_empty() else arena
	if node != null:
		EditorInterface.edit_node(node)


func _alert(text: String) -> void:
	var d := AcceptDialog.new()
	d.title = "Arena Editor"
	d.dialog_text = text
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	EditorInterface.get_base_control().add_child(d)
	d.popup_centered()
