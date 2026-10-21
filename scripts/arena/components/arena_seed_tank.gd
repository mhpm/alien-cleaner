@tool
class_name ArenaSeedTank
extends ArenaObject
## A SEED TANK to defend (world 8 BIODOME, SeedTank): the glass tank with the dome's last
## plants. Aliens nearby march on it and gnaw at it; in a survival world played on an
## arena map (WorldData "explore": {"map": ...}) every tank still standing when the final
## fight starts heals the astronaut. Its foot is solid. `art` = which of the 8 plant tanks.

@export_range(0, 7) var art := 0:
	set(value):
		art = value
		queue_redraw()

var tank: SeedTank


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return SeedTank.tex(art)


func palette_width() -> float:
	return SeedTank.tex(art).get_width() * SeedTank.SCALE


func activate(director: Node) -> void:
	var w: GameWorld = director.world
	tank = SeedTank.new()
	tank.art = art
	tank.position = global_position
	w.entities.add_child(tank)
	w.room.spawned.append(tank)
	tank.add_child(ArenaObjectiveBody.make(SeedTank.foot(art, Vector2.ZERO)))
	if w.explore != null:
		w.explore.add_tank(tank)


func is_resolved() -> bool:
	return tank != null and tank.lost


func _draw_editor() -> void:
	_standing(palette_icon(), palette_width())
	if show_details():
		_dashed_circle(SeedTank.LURE_R, Color(SeedTank.COL, 0.35))
		_dashed_circle(SeedTank.DANGER_R, Color("ff5566", 0.7))
	_editor_label("SEED TANK", Vector2(0, 10), SeedTank.COL)
	_id_caption(Vector2(0, 18), SeedTank.COL)
