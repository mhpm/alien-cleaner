class_name ArenaObjectiveBody
extends RefCounted
## The solid foot of a placed objective (seed tank, reactor core...): a StaticBody2D on
## the world layer with one box, `foot` local to the object's feet.

static func make(foot: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = foot.size
	cs.shape = shape
	cs.position = foot.get_center()
	body.add_child(cs)
	return body
