class_name EnemyShot
extends Node2D
## Slime glob fired by aliens. Destroyed by walls or the player's air blast.

const WORLD_MASK := 1

var vel := Vector2.ZERO
var damage := 10.0
var life := 4.0
var tex_id := "glob"
var t := 0.0
var sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemy_shots")
	sprite = Art.make_anim("glob", 0.17)
	sprite.rotation = vel.angle()
	if tex_id == "glob_green":
		sprite.self_modulate = Color(0.55, 1.5, 0.5)
	add_child(sprite)


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		pop()
		return
	var motion := vel * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, WORLD_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.collider
		if col != null and col.has_method("bullet_hit"):
			col.call("bullet_hit", damage)
		global_position = hit.position
		pop()
		return
	global_position += motion
	sprite.scale = Vector2.ONE * 0.17 * (1.0 + sin(t * 20.0) * 0.08)
	var p := Game.world.player
	if not p.dead and global_position.distance_to(p.global_position + Vector2(0, Player.BODY_Y)) < 7.5:
		p.take_damage(damage, global_position)
		pop()


func pop() -> void:
	var c := Color("a7f070") if tex_id == "glob_green" else Color("ff4fd8")
	var fx := AnimFx.spawn(Game.world.effects, "glob_pop", "pop", global_position, 0.14)
	if tex_id == "glob_green":
		fx.self_modulate = Color(0.55, 1.5, 0.5)
	Game.world.burst(global_position, c, 5, 40.0, 0.3, 2.0)
	queue_free()
