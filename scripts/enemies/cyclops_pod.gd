extends Enemy
## CYCLOPS RAY POD (world 4): a round blue pod with one big eye. It fires a TETHERED orb:
## the orb flies out slowly and stays joined to the pod's eye by a RAY ("attack"), and
## the pod keeps strafing sideways, so the ray SWEEPS across the floor. Touching the ray
## or the orb hurts. After a few seconds the orb pops and the ray goes out. Kill the pod
## to cut the ray, or keep on the far side of it.
## Breaks apart in blue sparks (the set's "death", played once).

const RANGE := 120.0
const AIM_TIME := 0.6
const ORB_SPEED := 45.0
const TETHER_TIME := 3.0
const RAY_HIT := 6.0
const RAY_CD := 0.5

var _orb: EnemyShot
var _ray: Line2D
var _ray_cd := 0.0
var _turn := 1.0


func _init_ai() -> void:
	state = "drift"
	state_t = randf_range(1.6, 2.6)
	_turn = 1.0 if randf() < 0.5 else -1.0
	_ray = Line2D.new()
	_ray.width = 3.0
	_ray.top_level = true
	_ray.z_index = 4
	_ray.visible = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_ray.material = m
	add_child(_ray)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	_ray_cd -= delta
	air = 10.0 + sin(t * 2.5 + phase) * 2.5
	var to_p := _to_player()
	var orbit := to_p.normalized().orthogonal() * _turn
	var keep := to_p.normalized() * clampf((to_p.length() - RANGE) / 30.0, -1.0, 1.0)
	match state:
		"drift":
			if state_t <= 0.0:
				state = "aim"
				state_t = AIM_TIME
				alert.visible = true
				Sfx.play("charge", 0.2, -10.0)
				return Vector2.ZERO
			return (orbit * 0.7 + keep).normalized() * speed
		"aim":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				_orb = Game.world.spawn_enemy_shot(hit_center() + d * 12.0, d * ORB_SPEED, contact_damage * 0.8, "cyclops")
				_orb.life = TETHER_TIME
				state = "tether"
				state_t = TETHER_TIME
				Sfx.play("zap", 0.0, -4.0)
			return Vector2.ZERO
		"tether":
			_update_ray()
			if state_t <= 0.0 or not is_instance_valid(_orb):
				_ray.visible = false
				_orb = null
				state = "drift"
				state_t = randf_range(2.0, 2.8)
				if randf() < 0.5:
					_turn = -_turn
			return orbit * speed * 1.2  # strafing sweeps the ray
	return Vector2.ZERO


func _update_ray() -> void:
	if not is_instance_valid(_orb):
		return
	var a := hit_center() + Vector2(face * 6.0, 0)
	var b := _orb.global_position
	_ray.visible = true
	_ray.points = PackedVector2Array([a, b])
	_ray.default_color = Color(0.4, 0.9, 1.0, 0.65 + 0.35 * sin(t * 40.0))
	var p := player()
	if _ray_cd <= 0.0 and not p.dead:
		var c := p.global_position + Vector2(0, Player.BODY_Y)
		var q := Geometry2D.get_closest_point_to_segment(c, a, b)
		if q.distance_to(c) < RAY_HIT:
			_ray_cd = RAY_CD
			p.take_damage(contact_damage * 0.7, q)
			Game.world.burst(q, Color("5fd8ff"), 6, 50.0, 0.25, 1.5)


func _anim_name() -> String:
	return "attack" if state in ["aim", "tether"] else "walk"


func _on_death() -> void:
	_ray.visible = false
	if is_instance_valid(_orb):
		_orb.pop()
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "cyclops_pod", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("5fd8ff"), 12, 80.0, 0.4, 2.0)
	Sfx.play("zap", 0.1, -4.0)
