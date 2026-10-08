class_name ArenaMinimap
extends Control
## Explorer's minimap for maps bigger than the screen (top-right of the HUD). The map
## is a tiny picture built once from the painted terrain (each tile's average colour,
## walls and solid props darker) under a fog that lifts where the astronaut has been.
## On top: the astronaut, the open exit, crew to rescue, nests, cores, the boss and a
## pulsing ring on the current objective target.

const CELL := 32.0  # world units per minimap pixel
const REVEAL := 230.0  # world units around the astronaut that get explored
const MAX_SIDE := 92.0
const FOG := Color(0.02, 0.03, 0.06, 0.92)

var director: ArenaDirector
var _area := Rect2()
var _base: Image
var _shown: Image
var _tex: ImageTexture
var _seen: PackedByteArray
var _cols := 0
var _rows := 0
var _k := 1.0  # minimap px per world unit
var _t := 0.0
var _redraw := 0.0
var _tile_colors: Dictionary = {}


func setup(d: ArenaDirector, area: Rect2) -> ArenaMinimap:
	director = d
	_area = area
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cols = maxi(1, ceili(area.size.x / CELL))
	_rows = maxi(1, ceili(area.size.y / CELL))
	var side := maxf(area.size.x, area.size.y)
	_k = MAX_SIDE / side
	var side_px := area.size * _k
	_build_base()
	_seen = PackedByteArray()
	_seen.resize(_cols * _rows)
	_shown = Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	_shown.fill(FOG)
	_tex = ImageTexture.create_from_image(_shown)
	custom_minimum_size = side_px
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -side_px.x - 6.0
	offset_right = -6.0
	offset_top = 40.0
	offset_bottom = 40.0 + side_px.y
	return self


## Average colour of every painted cell (Floor, then Environment/Details over it) and
## the walls / solid objects, darker.
func _build_base() -> void:
	_base = Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	_base.fill(Color(0.12, 0.14, 0.2))
	var arena := director.arena
	for layer_name: String in ["Floor", "Environment", "Walls"]:
		var layer := arena.get_layer(layer_name) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for c in layer.get_used_cells():
			var at := layer.to_global(layer.map_to_local(c)) - _area.position
			var px := Vector2i((at / CELL).floor())
			if px.x < 0 or px.y < 0 or px.x >= _cols or px.y >= _rows:
				continue
			var col := _tile_color(layer, c)
			if layer_name == "Walls":
				col = col.darkened(0.55)
			elif layer_name == "Environment":
				col = _base.get_pixelv(px).lerp(col, 0.5)
			_base.set_pixelv(px, col)
	for o in director.objects_of("ArenaScenery") + director.objects_of("ArenaProp"):
		var solid := o is ArenaProp or ((o as ArenaScenery).footprint.x > 0.0)
		if not solid:
			continue
		var px := Vector2i(((o.global_position - _area.position) / CELL).floor())
		if px.x >= 0 and px.y >= 0 and px.x < _cols and px.y < _rows:
			_base.set_pixelv(px, _base.get_pixelv(px).darkened(0.45))


func _tile_color(layer: TileMapLayer, c: Vector2i) -> Color:
	var key := "%d:%s" % [layer.get_cell_source_id(c), layer.get_cell_atlas_coords(c)]
	if not _tile_colors.has(key):
		var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
		var col := Color(0.3, 0.3, 0.35)
		if src != null and src.texture != null:
			var img := src.texture.get_image()
			if img.is_compressed():
				img.decompress()
			var r := src.get_tile_texture_region(layer.get_cell_atlas_coords(c))
			var region := img.get_region(r)
			region.resize(1, 1, Image.INTERPOLATE_BILINEAR)
			col = region.get_pixel(0, 0)
			col.a = 1.0
		_tile_colors[key] = col
	return _tile_colors[key]


func _process(delta: float) -> void:
	_t += delta
	_redraw -= delta
	if _redraw > 0.0:
		return
	_redraw = 0.1
	_reveal()
	queue_redraw()


func _reveal() -> void:
	var p := director.world.player.global_position - _area.position
	var r := int(ceil(REVEAL / CELL))
	var c := Vector2i((p / CELL).floor())
	var changed := false
	for y in range(maxi(0, c.y - r), mini(_rows, c.y + r + 1)):
		for x in range(maxi(0, c.x - r), mini(_cols, c.x + r + 1)):
			var i := y * _cols + x
			if _seen[i] == 0 and Vector2(x - c.x, y - c.y).length() <= r:
				_seen[i] = 1
				_shown.set_pixel(x, y, _base.get_pixel(x, y))
				changed = true
	if changed:
		_tex.update(_shown)


func _to_map(global_point: Vector2) -> Vector2:
	return (global_point - _area.position) * _k


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(0, 0, 0, 0.6))
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color("73eff7", 0.55), false, 1.0)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	for o in director.objects_of("ArenaSurvivor"):
		if is_instance_valid(o) and not o.is_resolved():
			FastDraw.disc(self, _to_map(o.focus_point()), 2.0, Color("a7f070"))
	for o in director.objects_of("AlienNest"):
		if is_instance_valid(o) and not o.is_resolved():
			FastDraw.disc(self, _to_map(o.focus_point()), 2.0, Color("c75bd6"))
	for o in director.objects_of("DefendCore"):
		if is_instance_valid(o) and not o.is_resolved():
			draw_rect(Rect2(_to_map(o.focus_point()) - Vector2(2, 2), Vector2(4, 4)), Color("ffcd75"))
	for o in director.objects_of("ArenaExit"):
		if is_instance_valid(o) and (o as ArenaExit).is_open():
			draw_rect(Rect2(_to_map(o.global_position) - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.5, 1.0, 0.6, 0.6 + 0.4 * pulse))
	for o in director.objects_of("BossTrigger"):
		var b := (o as BossTrigger).boss
		if is_instance_valid(b) and not b.dead:
			FastDraw.disc(self, _to_map(b.global_position), 2.5 + pulse, Color("ff5566"))
	if director.guide_target != Vector2.INF:
		FastDraw.ring(self, _to_map(director.guide_target), 3.0 + pulse * 2.0, Color("ffcd75"), 1.0)
	var pl := director.world.player
	var at := _to_map(pl.global_position)
	var dir := pl.input_dir.normalized() if pl.input_dir.length() > 0.2 else Vector2.UP
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([at + dir * 4.0, at - dir * 2.5 + side * 2.5, at - dir * 2.5 - side * 2.5]), Color.WHITE)
