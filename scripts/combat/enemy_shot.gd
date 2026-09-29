class_name EnemyShot
extends Node2D
## Projectile fired by aliens: slime glob, or a sprite-set shot from STYLES (droid
## plasma, UFO laser, octopus orb). Destroyed by walls or the player's air blast.

## tex_id -> fly art, scale, pop art, pop scale, pop tint, burst colour
const STYLES := {
	"droid": {"art": "droid_shot", "scale": 0.1, "pop": "droid_pop", "pop_s": 0.12, "tint": Color.WHITE, "color": Color("73eff7")},
	"ufo": {"art": "ufo_shot", "scale": 0.16, "pop": "droid_pop", "pop_s": 0.12, "tint": Color(0.55, 1.6, 0.45), "color": Color("a7f070")},
	"octopus": {"art": "octopus_shot", "scale": 0.12, "pop": "octopus_pop", "pop_s": 0.11, "tint": Color.WHITE, "color": Color("41a6f6")},
	# Big Red: fireball, acid blob, and the giant fireball that bursts into "split" blobs
	"big_red": {"art": "big_red_ball", "scale": 0.1, "pop": "glob_pop", "pop_s": 0.2, "tint": Color(1.5, 0.7, 1.1), "color": Color("ff4f9a"), "hit": 8.5},
	"red_blob": {"art": "big_red_blob", "scale": 0.24, "pop": "glob_pop", "pop_s": 0.1, "tint": Color(1.5, 0.7, 1.1), "color": Color("ff4f9a"), "hit": 6.0},
	# HIVE QUEEN: acid ball, crystal lance, crystal shard ("rot": the art points up)
	"hive_acid": {"art": "hive_acid", "scale": 0.13, "pop": "glob_pop", "pop_s": 0.18, "tint": Color(0.9, 1.5, 0.6), "color": Color("c8ff3a"), "hit": 8.0},
	"hive_crystal": {"art": "hive_crystal", "scale": 0.26, "pop": "hive_burst", "pop_s": 0.12, "tint": Color.WHITE, "color": Color("b35cff"), "hit": 7.0, "rot": PI * 0.5},
	"hive_shard": {"art": "hive_shard", "scale": 0.22, "pop": "hive_burst", "pop_s": 0.06, "tint": Color.WHITE, "color": Color("b35cff"), "hit": 5.5, "rot": PI * 0.5},
	"big_red_mega": {"art": "big_red_ball", "scale": 0.19, "pop": "glob_pop", "pop_s": 0.45, "tint": Color(1.6, 0.8, 1.2), "color": Color("ff4f9a"), "hit": 13.0, "split": 12},
}

const WORLD_MASK := 1

var vel := Vector2.ZERO
var damage := 10.0
var life := 4.0
var tex_id := "glob"
var t := 0.0
var sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemy_shots")
	sprite = Art.make_anim(_art(), _scale())
	sprite.rotation = vel.angle() + (float(STYLES[tex_id].get("rot", 0.0)) if STYLES.has(tex_id) else 0.0)
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
	sprite.scale = Vector2.ONE * _scale() * (1.0 + sin(t * 20.0) * 0.08)
	var p := Game.world.player
	var hit_r := float(STYLES[tex_id].get("hit", 7.5)) if STYLES.has(tex_id) else 7.5
	if not p.dead and global_position.distance_to(p.global_position + Vector2(0, Player.BODY_Y)) < hit_r:
		p.take_damage(damage, global_position)
		pop()


func _art() -> String:
	return str(STYLES[tex_id].art) if STYLES.has(tex_id) else "glob"


func _scale() -> float:
	return float(STYLES[tex_id].scale) if STYLES.has(tex_id) else 0.17


func pop() -> void:
	if STYLES.has(tex_id):
		var st: Dictionary = STYLES[tex_id]
		var f := AnimFx.spawn(Game.world.effects, str(st.pop), "pop", global_position, float(st.pop_s))
		f.self_modulate = st.tint
		f.create_tween().tween_property(f, "modulate:a", 0.0, 0.15)
		Game.world.burst(global_position, st.color, 5, 40.0, 0.3, 2.0)
		var n := int(st.get("split", 0))
		if n > 0:  # the giant fireball bursts into a ring of acid blobs
			Sfx.play("explode", 0.1, -4.0)
			Game.world.shake(0.4)
			Game.world.ring(global_position, 24.0, st.color, 0.3, 3.0)
			var off := randf() * TAU
			for i in n:
				Game.world.spawn_enemy_shot(global_position, Vector2.from_angle(off + TAU * i / n) * 80.0, damage * 0.5, "red_blob")
		queue_free()
		return
	var c := Color("a7f070") if tex_id == "glob_green" else Color("ff4fd8")
	var fx := AnimFx.spawn(Game.world.effects, "glob_pop", "pop", global_position, 0.14)
	if tex_id == "glob_green":
		fx.self_modulate = Color(0.55, 1.5, 0.5)
	Game.world.burst(global_position, c, 5, 40.0, 0.3, 2.0)
	queue_free()
