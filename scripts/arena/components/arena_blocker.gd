@tool
class_name ArenaBlocker
extends ArenaObject
## An invisible solid box (rectangle centred on the node): collision for maps whose art is
## one big picture (a painted room, a deck) instead of pieces with their own footprint,
## or to close a gap by hand. Seen only in the editor (red box). The boss ring of a
## survival world clears the ones inside it.

const COLOR := Color("ff5566")

@export var size := Vector2(64, 32):
	set(value):
		size = value.max(Vector2(2, 2)).round()
		queue_redraw()
## Off: only bodies stop (aliens, the astronaut); shots fly over it (a low railing).
@export var blocks_bullets := true:
	set(value):
		blocks_bullets = value
		queue_redraw()

var body: StaticBody2D


func arena_layer() -> String:
	return "Obstacles"


func palette_editor_icon() -> String:
	return "CollisionShape2D"


func activate(_director: Node) -> void:
	body = StaticBody2D.new()
	body.collision_layer = 1 if blocks_bullets else PropData.LAYER_BODIES_ONLY
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


## World rect it fills.
func rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func _draw_editor() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color(COLOR, 0.18))
	draw_rect(r, COLOR if blocks_bullets else Color("ffcd75"), false, 1.0)
	_editor_label("BLOCK" if blocks_bullets else "BLOCK (shots pass)", Vector2(0, 3), COLOR, 7)
