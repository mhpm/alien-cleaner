@tool
class_name ArenaWarpCell
extends ArenaObject
## World 7 (WARP NEXUS) objective placed by hand: a WARP CELL (WarpCell) to pick up; taking
## it sets off an ambush. In a survival world played on an arena map every cell counts
## (HUD "CELLS n/m") and taking them all charges the gate (Explore.gate_charged): the boss
## arrives weaker and cannot warp. Put them far from the start, in dead ends.

const ICON := "res://assets/sprites/gravity_well/fly_0.png"

var cell: WarpCell


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return load(ICON) as Texture2D


func palette_width() -> float:
	return 24.0


func activate(director: Node) -> void:
	var w: GameWorld = director.world
	cell = WarpCell.new()
	cell.position = global_position
	w.entities.add_child(cell)
	w.room.spawned.append(cell)
	if w.explore != null:
		w.explore.add_warp_cell(cell)


func is_resolved() -> bool:
	return cell != null and cell.taken


func _draw_editor() -> void:
	_standing(palette_icon(), palette_width(), Color.WHITE, 6.0)
	if show_details():
		_dashed_circle(WarpCell.PICK_R, Color(WarpCell.COL, 0.8))
	_editor_label("WARP CELL", Vector2(0, 10), WarpCell.COL)
	_id_caption(Vector2(0, 18), WarpCell.COL)
