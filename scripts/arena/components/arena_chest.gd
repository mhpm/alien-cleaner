@tool
class_name ArenaChest
extends ArenaObject
## A supply chest (ChestData: 12 chests = 12 run perks). Stand next to it for a few
## seconds to open it, like in EXPLORE maps. Opening reports "item_collected" (tag "chest").

@export var chest := 0:
	set(value):
		chest = value
		queue_redraw()

var _chest: SupplyChest
var _director: Node
var _done := false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	super._ready()
	set_process(false)


func _validate_property(property: Dictionary) -> void:
	if property.name == "chest":
		var names: Array[String] = []
		for c: Dictionary in ChestData.CHESTS:
			names.append(str(c.name).capitalize())
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(names)


func _kind() -> int:
	return clampi(chest, 0, ChestData.CHESTS.size() - 1)


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return ChestData.tex(_kind())


func palette_width() -> float:
	return SupplyChest.WIDTH


func activate(director: Node) -> void:
	_director = director
	_chest = SupplyChest.new()
	_chest.kind = _kind()
	_chest.position = global_position
	director.world.entities.add_child(_chest)
	set_process(true)


func _process(_delta: float) -> void:
	if _done or _chest == null:
		return
	if _chest.opened:
		_done = true
		set_process(false)
		_director.fire("item_collected", object_id, PackedStringArray(["chest"]))


func is_resolved() -> bool:
	return _done


func _draw_editor() -> void:
	var c: Color = ChestData.CHESTS[_kind()].color
	_standing(palette_icon(), SupplyChest.WIDTH)
	_dashed_circle(ChestData.OPEN_R, Color(c, 0.7))
	_editor_label("CHEST " + str(ChestData.CHESTS[_kind()].name), Vector2(0, 10), Color("ffcd75"))
	_id_caption(Vector2(0, 18), Color("ffcd75"))
