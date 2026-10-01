extends Enemy
## TESLA ORB DRONE (world 4): a round drone with a coil and a glowing core. It hovers at
## mid range and fires a crackling orb at you every few seconds (EnemyShot style
## "tesla"). Two tesla drones close to each other (LINK_R) are joined by a LIGHTNING ARC
## that hurts you if you cross it: kill one to break the fence.
## Shorts out and bursts into sparks (the set's "death").

const ORBIT := 95.0
const CHARGE_TIME := 0.55
const ORB_SPEED := 110.0
const LINK_R := 130.0
const ARC_HIT := 6.0  # how close to the arc hurts
const ARC_CD := 0.6

var _turn := 1.0
var _link: Enemy  # the drone this one arcs to (only one of a pair draws it)
var _arc_cd := 0.0
var _arc: Line2D


func _init_ai() -> void:
	state = "hover"
	state_t = randf_range(1.6, 2.6)
	_turn = 1.0 if randf() < 0.5 else -1.0
	_arc = Line2D.new()
	_arc.width = 2.5
	_arc.default_color = Color(0.55, 0.85, 1.0, 0.9)
	_arc.top_level = true
	_arc.z_index = 4
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_arc.material = m
	add_child(_arc)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 9.0 + sin(t * 2.6 + phase) * 2.5
	var to_p := _to_player()
	_update_arc(delta)
	match state:
		"hover":
			if state_t <= 0.0:
				state = "charge"
				state_t = CHARGE_TIME
				alert.visible = true
				Sfx.play("charge", 0.2, -12.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.8
			v += to_p.normalized() * clampf((to_p.length() - ORBIT) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"charge":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if randf() < 0.5:
				Game.world.burst(hit_center() + Vector2(face * 8.0, 0), Color("7fd0ff"), 1, 30.0, 0.2, 1.5)
			if state_t <= 0.0:
				alert.visible = false
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * ORB_SPEED, contact_damage * 0.8, "tesla")
				Sfx.play("zap", 0.15, -6.0)
				state = "hover"
				state_t = randf_range(2.0, 3.0)
			return Vector2.ZERO
	return Vector2.ZERO


## Finds a partner (the older one of each pair draws the arc) and zaps the astronaut
## if they stand on it.
func _update_arc(delta: float) -> void:
	_arc_cd -= delta
	if _link != null and (not is_instance_valid(_link) or _link.dead or _link.global_position.distance_to(global_position) > LINK_R * 1.15):
		_link = null
	if _link == null and fmod(t, 0.5) < delta:
		var best := LINK_R
		for n in Game.world.enemy_cache:
			var e := n as Enemy
			if e == self or not is_instance_valid(e) or e.dead or e.type_id != "tesla_drone":
				continue
			if e.get_instance_id() > get_instance_id():
				continue  # the other one draws it
			var d := e.global_position.distance_to(global_position)
			if d < best:
				best = d
				_link = e
	_arc.visible = _link != null
	if _link == null:
		return
	var a := hit_center()
	var b := _link.hit_center()
	var pts := PackedVector2Array([a])
	for i in range(1, 7):
		var k := i / 7.0
		pts.append(a.lerp(b, k) + (b - a).orthogonal().normalized() * randf_range(-5.0, 5.0))
	pts.append(b)
	_arc.points = pts
	_arc.default_color.a = 0.6 + randf() * 0.4
	var p := player()
	if _arc_cd <= 0.0 and not p.dead:
		var q := Geometry2D.get_closest_point_to_segment(p.global_position + Vector2(0, Player.BODY_Y), a, b)
		if q.distance_to(p.global_position + Vector2(0, Player.BODY_Y)) < ARC_HIT:
			_arc_cd = ARC_CD
			p.take_damage(contact_damage * 0.8, q)
			Game.world.burst(q, Color("7fd0ff"), 8, 60.0, 0.25, 1.5)
			Sfx.play("zap", 0.1, -4.0)


func _anim_name() -> String:
	return "attack" if state == "charge" else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "tesla_drone", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("7fd0ff"), 14, 90.0, 0.4, 2.0)
	Sfx.play("zap", 0.1, -4.0)
