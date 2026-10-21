@tool
class_name ArenaReactorCore
extends ArenaObject
## World 5 (THE FORGE) objective placed by hand: an overheating REACTOR CORE (ReactorCore):
## heat waves while you are near, cooled by standing on its blue pad. In a survival world
## played on an arena map every core counts (HUD "CORES n/m") and cooling them all makes the
## bosses arrive weaker (Explore.forge_cooled). Its foot is solid.

var core: ReactorCore


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return RoomKit.tex(ReactorCore.PIECE, "w5")


func palette_width() -> float:
	return palette_icon().get_width() * ReactorCore.SCALE


func activate(director: Node) -> void:
	var w: GameWorld = director.world
	core = ReactorCore.new()
	core.position = global_position
	w.entities.add_child(core)
	w.room.spawned.append(core)
	core.add_child(ArenaObjectiveBody.make(ReactorCore.foot(Vector2.ZERO)))
	if w.explore != null:
		w.explore.add_core(core)


func _draw_editor() -> void:
	_standing(palette_icon(), palette_width())
	if show_details():
		_dashed_circle(ReactorCore.WAVE_R, Color(ReactorCore.HOT, 0.5))
		_dashed_circle(ReactorCore.PAD_R, Color(ReactorCore.COOL, 0.8))
	_editor_label("REACTOR CORE", Vector2(0, 10), ReactorCore.HOT)
	_id_caption(Vector2(0, 18), ReactorCore.HOT)
