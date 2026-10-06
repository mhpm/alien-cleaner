@tool
class_name ArenaProp
extends ArenaObject
## A PropData prop placed by hand (origin = feet). Reuses the game's own Prop: in the
## game it builds one as its child (collision, glow, sparks, tanks that burst...);
## in the editor it only draws a preview. The art is swappable per instance:
## `variant` picks one of the prop's textures, `texture_override` replaces it.

## Key of PropData.PROPS.
@export var prop_id := "crate":
	set(value):
		prop_id = value
		queue_redraw()
		update_configuration_warnings()
## Index into the prop's texture list; -1 = picked from the position like layout rooms.
@export var variant := -1:
	set(value):
		variant = value
		queue_redraw()
## Any texture; it is scaled to the prop's width and keeps its collision box.
@export var texture_override: Texture2D:
	set(value):
		texture_override = value
		queue_redraw()

var prop: Prop  # the game prop (runtime only)


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint() or not PropData.PROPS.has(prop_id):
		return
	var arena := Arena.of(self)
	prop = Prop.new().setup(prop_id, cell(), Vector2.ZERO, arena.prop_theme() if arena != null else "ship")
	add_child(prop)
	var tex := texture()
	if tex != prop.sprite.texture:
		_fit_sprite(prop.sprite, tex, float(prop.def.width))


func arena_layer() -> String:
	return "Obstacles"


## Playing: stand among the entities so the astronaut and aliens sort around it.
func activate(director: Node) -> void:
	reparent(director.world.entities)


func cell() -> Vector2i:
	return Vector2i((position / 16.0).floor())


func texture() -> Texture2D:
	if texture_override != null:
		return texture_override
	if not PropData.PROPS.has(prop_id):
		return null
	var arena := Arena.of(self)
	var list := PropData.themed(prop_id, PropData.PROPS[prop_id].tex, arena.prop_theme() if arena != null else "ship")
	if variant >= 0:
		return PropData.tex(str(list[variant % list.size()]))
	return PropData.pick(list, cell())


func validate_arena(report: ArenaReport, _arena: Arena) -> void:
	if not PropData.PROPS.has(prop_id):
		report.error("Unknown prop id \"%s\" (see PropData.PROPS)." % prop_id, self)


func _get_configuration_warnings() -> PackedStringArray:
	if not PropData.PROPS.has(prop_id):
		return PackedStringArray(["Unknown prop id \"%s\" (see PropData.PROPS)." % prop_id])
	return PackedStringArray()


func _validate_property(property: Dictionary) -> void:
	if property.name == "prop_id":
		var ids: Array = PropData.PROPS.keys()
		ids.sort()
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(ids)


func _notification(what: int) -> void:
	# the automatic variant depends on the cell
	if what == NOTIFICATION_TRANSFORM_CHANGED and variant < 0:
		queue_redraw()


static func _fit_sprite(sprite: Sprite2D, tex: Texture2D, width: float) -> void:
	sprite.texture = tex
	var tw := float(tex.get_width())
	sprite.scale = Vector2.ONE * (width / tw)
	sprite.offset = Vector2(-tw * 0.5, -tex.get_height())


func _draw_editor() -> void:
	var tex := texture()
	if tex == null:
		draw_circle(Vector2(0, -6), 6.0, Color(1, 0.2, 0.2, 0.8))
		_editor_label("?" + prop_id, Vector2(0, 8), Color(1, 0.4, 0.4))
		return
	var def: Dictionary = PropData.PROPS.get(prop_id, {})
	var width := float(def.get("width", 16.0))
	var k := width / tex.get_width()
	var size := Vector2(tex.get_size()) * k
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, width * 0.45, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(tex, Rect2(Vector2(-size.x * 0.5, -size.y), size), false)
	var box: Vector2 = def.get("box", Vector2.ZERO)
	if box != Vector2.ZERO:
		draw_rect(Rect2(Vector2(-box.x * 0.5, -box.y), box), Color(1.0, 0.55, 0.2, 0.5), false, 1.0)
