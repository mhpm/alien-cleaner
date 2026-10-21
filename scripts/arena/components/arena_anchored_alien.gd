@tool
class_name ArenaAnchoredAlien
extends ArenaObject
## A rooted alien placed by hand (world 6 GENE VAULT): a SPECIMEN VAT (an objective to
## shoot down: it breeds specimens while you are near; in a survival world on an arena map
## every vat counts, HUD "VATS n/m", and breaking them all leaves the boss without backup)
## or an EGG CLUSTER (hatches octolings when you walk by). Anchored: nothing pushes it.

enum Kind { SPECIMEN_VAT, EGG_CLUSTER }
const IDS := ["specimen_vat", "egg_cluster"]
const COLORS := [Color("5fe8ff"), Color("e86bff")]

@export var kind := Kind.SPECIMEN_VAT:
	set(value):
		kind = value
		queue_redraw()

var alien: Enemy


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func arena_layer() -> String:
	return "GameplayObjects"


func enemy_id() -> String:
	return IDS[kind]


func palette_icon() -> Texture2D:
	return ArenaArt.enemy_icon(enemy_id())


func palette_width() -> float:
	var t := palette_icon()
	return t.get_width() * float(EnemyData.TYPES[enemy_id()].scale) if t != null else 30.0


func activate(director: Node) -> void:
	var w: GameWorld = director.world
	if kind == Kind.EGG_CLUSTER:
		Art.warm(Art.sets_for(["egg_cluster", "octoling"]))
	alien = w.spawn_enemy(enemy_id(), global_position, Game.enemy_mult(), 1.0, false, true)
	if alien != null and kind == Kind.SPECIMEN_VAT and w.explore != null:
		w.explore.add_vat(alien)


func is_resolved() -> bool:
	return alien != null and (not is_instance_valid(alien) or alien.dead)


func _draw_editor() -> void:
	_standing(palette_icon(), palette_width())
	var c: Color = COLORS[kind]
	_editor_label("SPECIMEN VAT" if kind == Kind.SPECIMEN_VAT else "EGG CLUSTER", Vector2(0, 10), c)
	_id_caption(Vector2(0, 18), c)
