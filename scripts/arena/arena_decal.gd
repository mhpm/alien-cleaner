@tool
class_name ArenaDecal
extends ArenaObject
## A flat floor decal (slime, grime, cracks...): drawn centred on its position, no
## collision. The texture is a plain export, so any image can replace it.

@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## Width in world units (height keeps the texture's aspect).
@export_range(4.0, 256.0, 1.0) var width := 24.0:
	set(value):
		width = value
		queue_redraw()
@export var tint := Color.WHITE:
	set(value):
		tint = value
		queue_redraw()
@export var flip_h := false:
	set(value):
		flip_h = value
		queue_redraw()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func arena_layer() -> String:
	return "Decorations"


func validate_arena(report: ArenaReport, _arena: Arena) -> void:
	if texture == null:
		report.warning("Decal without a texture.", self)


func _draw_editor() -> void:
	draw_arc(Vector2.ZERO, width * 0.5, 0.0, TAU, 24, Color(1, 0.8, 0.3, 0.8), 1.0)
	_editor_label("DECAL", Vector2(0, 3), Color(1, 0.8, 0.3))


func _draw() -> void:
	if texture == null:
		super._draw()
		return
	var size := Vector2(width, width * texture.get_height() / texture.get_width())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if flip_h else 1.0, 1.0))
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
	draw_set_transform(Vector2.ZERO)
