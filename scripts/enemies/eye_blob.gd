extends Enemy
## EYE BLOB SAUCER (world 5): a one-eyed green blob in a saucer, made for the forge's walled
## rooms. It fires a RICOCHET LASER: it picks the bank shot that reaches you (straight,
## or bounced off one or two walls: it tries a fan of angles and keeps the one whose path
## passes closest to you), warns along the whole bent path with aim lanes, then fires a
## beam that hurts once. Hiding round a corner doesn't save you from it, but the warning
## shows exactly where the beam will go. Keeps its distance and slides to new angles.
## Melts into goo with its eye staring up (the set's "splat").

const RANGE := 120.0
const AIM_TIME := 1.0
const BEAM_TIME := 0.3
const MAX_LEN := 420.0  # total length of the bent beam
const BOUNCES := 2
const HIT := 7.0
const TRIES := 23  # angles tried when looking for a bank shot
const WALL_MASK := 1

var _turn := 1.0
var _path := PackedVector2Array()
var _hit := false
var _line: Line2D


func _init_ai() -> void:
	state = "drift"
	state_t = randf_range(1.8, 2.8)
	_turn = 1.0 if randf() < 0.5 else -1.0
	_line = Line2D.new()
	_line.width = 4.0
	_line.top_level = true
	_line.z_index = 4
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.visible = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_line.material = m
	add_child(_line)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 9.0 + sin(t * 2.6 + phase) * 2.5
	var to_p := _to_player()
	match state:
		"drift":
			if state_t <= 0.0:
				_path = _bank_shot()
				state = "aim"
				state_t = AIM_TIME
				alert.visible = true
				for i in _path.size() - 1:
					var seg := _path[i + 1] - _path[i]
					Game.world.telegraph_line(_path[i], seg.normalized(), seg.length(), 8.0, AIM_TIME)
				Sfx.play("charge", 0.1, -8.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.8
			v += to_p.normalized() * clampf((to_p.length() - RANGE) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"aim":
			face = signf(_path[1].x - _path[0].x) if _path.size() > 1 else face
			if state_t <= 0.0:
				alert.visible = false
				state = "fire"
				state_t = BEAM_TIME
				_hit = false
				Sfx.play("zap", 0.0, -2.0)
		"fire":
			_beam()
			if state_t <= 0.0:
				_line.visible = false
				state = "drift"
				state_t = randf_range(2.4, 3.2)
				if randf() < 0.5:
					_turn = -_turn
	return Vector2.ZERO


## Path of a beam fired at `angle`, bouncing off walls (physics layer 1).
func _trace(from: Vector2, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array([from])
	var dir := Vector2.from_angle(angle)
	var left := MAX_LEN
	var p := from
	var space := get_world_2d().direct_space_state
	for b in BOUNCES + 1:
		var q := PhysicsRayQueryParameters2D.create(p, p + dir * left, WALL_MASK)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			pts.append(p + dir * left)
			break
		var at: Vector2 = hit.position
		pts.append(at)
		left -= p.distance_to(at)
		if left <= 4.0:
			break
		dir = dir.bounce(hit.normal)
		p = at + dir * 0.5
	return pts


## How close a path passes to `c`.
static func _miss(pts: PackedVector2Array, c: Vector2) -> float:
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(c, pts[i], pts[i + 1]).distance_to(c))
	return best


## The direct shot if it reaches the astronaut, else the angle (of a fan) whose bounced
## path passes closest to them.
func _bank_shot() -> PackedVector2Array:
	var from := hit_center()
	var target := player().global_position + Vector2(0, Player.BODY_Y)
	var base := (target - from).angle()
	var best := _trace(from, base)
	var best_miss := _miss(best, target)
	if best_miss < HIT:
		return best
	for i in TRIES:
		var a := base + (i - TRIES * 0.5) * (TAU / TRIES)
		var pts := _trace(from, a)
		var m := _miss(pts, target)
		if m < best_miss:
			best_miss = m
			best = pts
	return best


func _beam() -> void:
	var k := clampf(state_t / BEAM_TIME, 0.0, 1.0)
	_line.visible = true
	_line.points = _path
	_line.width = 2.0 + 4.0 * k
	_line.default_color = Color(1.0, 0.45, 0.95, 0.6 + 0.4 * k)
	var p := player()
	if not _hit and not p.dead and _miss(_path, p.global_position + Vector2(0, Player.BODY_Y)) < HIT:
		_hit = true
		p.take_damage(contact_damage * 1.2, p.global_position)
		Game.world.burst(p.global_position + Vector2(0, Player.BODY_Y), Color("ff6fe0"), 8, 60.0, 0.25, 2.0)
	if randf() < 0.5:
		for i in range(1, _path.size() - 1):  # sparks where it bounces
			Game.world.burst(_path[i], Color("ff9cf0"), 2, 50.0, 0.2, 1.5)


func _anim_name() -> String:
	return "attack" if state in ["aim", "fire"] else "walk"


func _on_death() -> void:
	_line.visible = false
	Game.world.burst(hit_center(), Color("a7f070"), 12, 70.0, 0.45, 2.5, 60.0)
	Sfx.play("pop", 0.15, -4.0)
