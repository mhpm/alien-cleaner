class_name RingShot
extends EnemyShot
## The Saturn Ring Bug's ring thrown like a boomerang: it spins out to where the
## astronaut was, slows to a stop and flies back to the bug, hurting them on both passes
## (at most once every HIT_CD). Pops if the bug dies on the way.

const OUT_SPEED := 150.0
const BACK_SPEED := 135.0
const HIT_CD := 0.5

var bug: Enemy
var back := false
var out_t := 0.8
var hit_cd := 0.0


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	hit_cd -= delta
	if life <= 0.0 or bug == null or not is_instance_valid(bug) or bug.dead:
		pop()
		return
	if not back:
		out_t -= delta
		if out_t < 0.35:
			vel = vel.move_toward(Vector2.ZERO, OUT_SPEED * 2.5 * delta)
		if out_t <= 0.0:
			back = true
	else:
		var to := bug.hit_center() - global_position
		if to.length() < 10.0:
			bug.call("catch_ring")
			queue_free()
			return
		vel = vel.move_toward(to.normalized() * BACK_SPEED, 420.0 * delta)
	global_position += vel * delta
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE * _scale() * (1.0 + sin(t * 20.0) * 0.06)
	var p := Game.world.player
	if hit_cd <= 0.0 and not p.dead and global_position.distance_to(p.global_position + Vector2(0, Player.BODY_Y)) < float(STYLES[tex_id].hit):
		p.take_damage(damage, global_position)
		hit_cd = HIT_CD
