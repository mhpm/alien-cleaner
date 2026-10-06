@tool
class_name ArenaPickup
extends ArenaObject
## A pickup lying in the arena from the start (CollectibleData kinds: heart, medkit,
## gold, magnet, power-ups...). Uses the game's own Pickup, so it behaves exactly like
## a drop. Collecting it reports "item_collected" (tags "pickup" + its kind).

@export var kind := "heart":
	set(value):
		kind = value
		queue_redraw()
## Amount where the kind uses one (XP gems, hearts).
@export_range(1, 999) var value := 1

var _pickup: Pickup


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _validate_property(property: Dictionary) -> void:
	if property.name == "kind":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(kinds())


## Every pickup kind: XP gems plus CollectibleData.ITEMS.
static func kinds() -> Array:
	return ["xp"] + CollectibleData.ITEMS.keys()


func arena_layer() -> String:
	return "Pickups"


func palette_icon() -> Texture2D:
	return CollectibleData.tex(kind, value) if kinds().has(kind) else null


func palette_width() -> float:
	return 12.0


func activate(director: Node) -> void:
	_pickup = Pickup.new()
	_pickup.kind = kind
	_pickup.value = value
	_pickup.position = global_position
	director.world.entities.add_child(_pickup)
	_pickup.tree_exiting.connect(func() -> void:
		if not director.finished:
			director.fire("item_collected", object_id, PackedStringArray(["pickup", kind])), CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func is_resolved() -> bool:
	return not is_instance_valid(_pickup)


func validate_arena(report: ArenaReport, _arena: Arena) -> void:
	if not kinds().has(kind):
		report.error("Pickup %s: unknown kind \"%s\"." % [name, kind], self)


func _draw_editor() -> void:
	var tex := palette_icon()
	if tex != null:
		var s := 12.0 * CollectibleData.SIZE_MULT
		var size := Vector2(s, s * tex.get_height() / tex.get_width())
		draw_texture_rect(tex, Rect2(-size * 0.5 - Vector2(0, 4), size), false)
	_editor_label(kind.to_upper() + (" x%d" % value if value > 1 else ""), Vector2(0, 10), Color("ffcd75"))
