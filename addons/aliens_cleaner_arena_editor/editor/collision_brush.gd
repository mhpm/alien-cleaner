@tool
extends RefCounted
## PAINT > Collision: paint collision on single cells of the map, right on the 2D view.
##   left click / drag  = the cell blocks (astronaut and aliens)
##   right click / drag = the cell can be walked
## It only switches the painted cell to an alternative of the same tile (same picture,
## TerrainTilesetBuilder.WALKABLE / BLOCKED), so other cells with that tile keep theirs.
## While it is on, blocking cells show red. Each stroke is one undoable action.
## Repainting a cell with the terrain tools gives it back its tile's own collision.

const Terrain := preload("terrain_tileset_builder.gd")
const SHOW := Color(1.0, 0.25, 0.3, 0.35)
const EDGE := Color(1.0, 0.35, 0.4, 0.8)

var active := false
var _plugin: EditorPlugin
var _stroke := 0  # 0 none, 1 block, 2 walk
var _changes: Dictionary = {}  # "layer|cell" -> [layer, cell, src, atlas, old_alt, new_alt]


func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin


func handle_input(event: InputEvent, arena: Arena, xf: Transform2D) -> bool:
	if not active:
		return false
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if mb.pressed:
			_stroke = 1 if mb.button_index == MOUSE_BUTTON_LEFT else 2
			_changes.clear()
			_paint(arena, arena.to_global(xf.affine_inverse() * mb.position))
		else:
			_finish(arena)
		return true
	var mm := event as InputEventMouseMotion
	if mm != null and _stroke != 0:
		_paint(arena, arena.to_global(xf.affine_inverse() * mm.position))
		return true
	return false


## The top painted layer at that spot gets the change (to block); to walk, every layer
## there drops its collision.
func _paint(arena: Arena, at: Vector2) -> void:
	var layers := _layers(arena)
	layers.reverse()  # top first
	for layer in layers:
		var c := layer.local_to_map(layer.to_local(at))
		var src := layer.get_cell_source_id(c)
		if src < 0:
			continue
		var coords := layer.get_cell_atlas_coords(c)
		var atlas := layer.tile_set.get_source(src) as TileSetAtlasSource
		if atlas == null:
			continue
		var want := Terrain.BLOCKED if _stroke == 1 else Terrain.WALKABLE
		var alt := layer.get_cell_alternative_tile(c)
		if alt != want and atlas.has_alternative_tile(coords, want):
			var key := "%s|%s" % [layer.name, c]
			if not _changes.has(key):
				_changes[key] = [layer, c, src, coords, alt, want]
			else:
				_changes[key][5] = want
			layer.set_cell(c, src, coords, want)
		if _stroke == 1:
			return  # one blocking layer is enough
	_plugin.update_overlays()


func _finish(arena: Arena) -> void:
	_stroke = 0
	if _changes.is_empty():
		return
	var ur := _plugin.get_undo_redo()
	ur.create_action("Paint collision (%d cells)" % _changes.size(), UndoRedo.MERGE_DISABLE, arena)
	for k: String in _changes:
		var ch: Array = _changes[k]
		ur.add_do_method(ch[0], "set_cell", ch[1], ch[2], ch[3], ch[5])
		ur.add_undo_method(ch[0], "set_cell", ch[1], ch[2], ch[3], ch[4])
	ur.commit_action(false)  # already painted while dragging
	_changes.clear()


func _layers(arena: Arena) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	for layer_name: String in Arena.TERRAIN + ["Walls"]:
		var l := arena.get_layer(layer_name) as TileMapLayer
		if l != null and l.tile_set != null:
			out.append(l)
	return out


## Red over every blocking cell in view.
func draw(overlay: Control, xf: Transform2D, arena: Arena) -> void:
	if not active:
		return
	var view := xf.affine_inverse() * Rect2(Vector2.ZERO, overlay.size)
	var blocked := {}
	var cell_size := Vector2.ZERO
	var ref: TileMapLayer = null
	for layer in _layers(arena):
		var a := layer.local_to_map(layer.to_local(arena.to_global(view.position)))
		var b := layer.local_to_map(layer.to_local(arena.to_global(view.end)))
		for y in range(mini(a.y, b.y) - 1, maxi(a.y, b.y) + 2):
			for x in range(mini(a.x, b.x) - 1, maxi(a.x, b.x) + 2):
				var c := Vector2i(x, y)
				var td := layer.get_cell_tile_data(c)
				if td != null and layer.tile_set.get_physics_layers_count() > 0 and td.get_collision_polygons_count(0) > 0:
					blocked[c] = true
		if ref == null:
			ref = layer
			cell_size = Vector2(layer.tile_set.tile_size)
	if ref == null:
		return
	var to_overlay := xf * arena.global_transform.affine_inverse() * ref.global_transform
	for c: Vector2i in blocked:
		var center := ref.map_to_local(c)
		var r := Rect2(center - cell_size * 0.5, cell_size)
		var pts := PackedVector2Array([to_overlay * r.position, to_overlay * Vector2(r.end.x, r.position.y),
			to_overlay * r.end, to_overlay * Vector2(r.position.x, r.end.y)])
		overlay.draw_colored_polygon(pts, SHOW)
		pts.append(pts[0])
		for i in 4:
			overlay.draw_line(pts[i], pts[i + 1], EDGE, 1.0)
	var font := overlay.get_theme_default_font()
	overlay.draw_string(font, Vector2(12, overlay.size.y - 14), "COLLISION BRUSH: click / drag = blocks · right click = walkable · red = blocks",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.85))
