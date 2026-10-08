@tool
class_name ArenaScenery
extends ArenaObject
## Lightweight decoration for big, busy maps (trees, rocks, cars, grass...): one sprite
## (origin = feet), a soft shadow and, optionally, a small collision footprint at the
## base. Built for hundreds per arena: no per-object material or script processing.
##   sway   leans in the wind (one shared shader for every piece)
##   fade   turns see-through while the astronaut walks behind it (ArenaSceneryFader)
##   flat   lies on the floor: drawn under everything, never sorted with the entities
##   frames a spritesheet (columns x rows) played at `fps`: fires, flags, machines...
##          (each copy starts on a different frame so a row of them never blinks in sync)
## Pieces come from decor kits (assets/decor/<kit>/, see the palette); any texture works.

const SWAY := preload("res://assets/shaders/scenery_sway.gdshader")
const FADE_ALPHA := 0.38

static var _sway_mat: ShaderMaterial

@export var texture: Texture2D:
	set(value):
		texture = value
		_refresh()
## Width in world units (height keeps the picture's aspect).
@export_range(2.0, 400.0, 1.0) var width := 40.0:
	set(value):
		width = value
		_refresh()
@export var flip_h := false:
	set(value):
		flip_h = value
		_refresh()
@export var tint := Color.WHITE:
	set(value):
		tint = value
		_refresh()
## Collision box at the base (world units); (0, 0) = walk through it.
@export var footprint := Vector2.ZERO:
	set(value):
		footprint = value
		queue_redraw()
## The footprint also stops bullets (off = only bodies, shots fly past).
@export var blocks_bullets := false
@export var sway := false:
	set(value):
		sway = value
		_refresh()
@export var fade_behind := false
@export var flat := false
## A bridge: the solid terrain under it (water) becomes walkable while playing.
@export var bridge := false
## A soft round shadow at the base (trees).
@export var shadow := false:
	set(value):
		shadow = value
		queue_redraw()

@export_group("Animation")
## Spritesheet layout: columns x rows of frames (1 x 1 = a still picture).
@export var columns := 1:
	set(value):
		columns = maxi(1, value)
		_refresh()
@export var rows := 1:
	set(value):
		rows = maxi(1, value)
		_refresh()
## Frames used (0 = all columns x rows; less when the last row is not full).
@export var frame_count := 0:
	set(value):
		frame_count = maxi(0, value)
		_refresh()
@export_range(0.5, 60.0, 0.5) var fps := 8.0
## Play the animation once and stay on its last frame (off = loop).
@export var play_once := false

var sprite: Sprite2D
var _anim_t := 0.0
var _start_frame := 0


func _ready() -> void:
	super._ready()
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if sprite == null:
		# a duplicated node arrives with the original's sprite: reuse it
		for c in get_children(true):
			if c is Sprite2D and c.get_parent() == self and not c.owner:
				sprite = c
				break
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(sprite, false, Node.INTERNAL_MODE_FRONT)
	sprite.texture = texture
	sprite.flip_h = flip_h
	sprite.modulate = tint
	sprite.hframes = columns
	sprite.vframes = rows
	if texture != null:
		var fs := frame_size()
		var k := width / fs.x
		sprite.scale = Vector2(k, k)
		sprite.offset = Vector2(-fs.x * 0.5, -fs.y)
	# editing: the first frame, still; playing: each copy starts on its own frame
	var playing := is_animated() and not Engine.is_editor_hint()
	_start_frame = absi(hash(position.round())) % frames() if playing else 0
	sprite.frame = _start_frame
	set_process(playing)
	if sway:
		if _sway_mat == null:
			_sway_mat = ShaderMaterial.new()
			_sway_mat.shader = SWAY
		sprite.material = _sway_mat
	else:
		sprite.material = null
	queue_redraw()


func arena_layer() -> String:
	return "Decorations" if flat else "Obstacles"


func is_animated() -> bool:
	return frames() > 1


func frames() -> int:
	return frame_count if frame_count > 0 else columns * rows


## One frame of the sheet, in picture pixels.
func frame_size() -> Vector2:
	if texture == null:
		return Vector2.ONE
	return Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))


func _process(delta: float) -> void:
	if sprite == null or not is_animated():
		return
	_anim_t += delta
	var n := int(_anim_t * fps)
	sprite.frame = mini(n, frames() - 1) if play_once else (_start_frame + n) % frames()


func palette_icon() -> Texture2D:
	if is_animated() and texture != null:
		var first := AtlasTexture.new()
		first.atlas = texture
		first.region = Rect2(Vector2.ZERO, frame_size())
		return first
	return texture


func palette_width() -> float:
	return width


func height() -> float:
	var fs := frame_size()
	return width * fs.y / fs.x if texture != null else width


## Playing: tall pieces join the y-sorted entities; solid ones get their footprint.
func activate(director: Node) -> void:
	if bridge and texture != null:  # a bridge whose picture is gone would be an invisible way across
		open_terrain(Arena.of(self))
	if footprint.x > 0.0 and footprint.y > 0.0:
		var body := StaticBody2D.new()
		body.collision_layer = 1 if blocks_bullets else PropData.LAYER_BODIES_ONLY
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = footprint
		cs.shape = shape
		cs.position = Vector2(0, -footprint.y * 0.5)
		body.add_child(cs)
		add_child(body)
	if not flat:
		reparent(director.world.entities)


## Bridges: switch every solid terrain cell under the picture to its walkable twin
## (alternative tile 1, made by the TileSet sync).
func open_terrain(arena: Arena) -> void:
	if arena == null:
		return
	var r := cover_rect()
	for layer_name: String in Arena.TERRAIN + ["Walls"]:
		var layer := arena.get_layer(layer_name) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var a := layer.local_to_map(layer.to_local(r.position))
		var b := layer.local_to_map(layer.to_local(r.end))
		for y in range(a.y, b.y + 1):
			for x in range(a.x, b.x + 1):
				var c := Vector2i(x, y)
				var td := layer.get_cell_tile_data(c)
				if td != null and td.get_collision_polygons_count(0) > 0:
					var src := layer.get_cell_source_id(c)
					var atlas := layer.tile_set.get_source(src) as TileSetAtlasSource
					if atlas != null and atlas.has_alternative_tile(layer.get_cell_atlas_coords(c), 1):
						layer.set_cell(c, src, layer.get_cell_atlas_coords(c), 1)


## Rect the picture covers (global), for the see-through check.
func cover_rect() -> Rect2:
	var h := height()
	return Rect2(global_position + Vector2(-width * 0.5, -h), Vector2(width, h))


func validate_arena(report: ArenaReport, _arena: Arena) -> void:
	if texture == null:
		report.warning("Scenery %s has no texture." % name, self)


func _draw() -> void:
	if shadow and not flat:
		draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.32))
		FastDraw.disc(self, Vector2.ZERO, width * 0.36, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO)
	if Engine.is_editor_hint():
		if texture == null:
			draw_rect(Rect2(-6, -12, 12, 12), Color(1, 0.4, 0.4), false, 1.0)
		if footprint.x > 0.0 and footprint.y > 0.0:
			draw_rect(Rect2(Vector2(-footprint.x * 0.5, -footprint.y), footprint), Color(1.0, 0.55, 0.2, 0.55), false, 1.0)
