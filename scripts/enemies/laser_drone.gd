extends Enemy
## ORBITAL LASER DRONE (world 7): an eyeball satellite with shield plates orbiting it. It
## keeps to mid range and every few seconds charges its eye ("attack"): two lines mark a
## WEDGE in front of it, then it fires a laser that SWEEPS across the wedge from one edge
## to the other (the side it starts on is the one marked brighter). Step out of the wedge,
## or slip in close under it. Between sweeps it spits a slow orb. Breaks apart in smoke and
## sparks (the set's "death").

const RANGE := 115.0
const CHARGE_TIME := 0.9
const SWEEP_TIME := 0.75
const ARC := 1.1  # radians the beam sweeps
const BEAM_LEN := 190.0
const BEAM_HIT := 7.0
const ORB_SPEED := 70.0

var _turn := 1.0
var _beam: Sprite2D
var _hit := false
var _a0 := 0.0
var _orbs := 0
var _turn_sweep := 1.0  # the way the beam turns across the wedge


func _init_ai() -> void:
	state = "float"
	state_t = randf_range(2.0, 3.2)
	_turn = 1.0 if randf() < 0.5 else -1.0
	_beam = Sprite2D.new()
	_beam.texture = Art.frames("laser_beam").get_frame_texture("fly", 0)
	_beam.centered = false
	_beam.offset = Vector2(0, -_beam.texture.get_height() * 0.5)
	_beam.top_level = true
	_beam.z_index = 4
	_beam.visible = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = m
	add_child(_beam)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 12.0 + sin(t * 2.2 + phase) * 3.0
	var to_p := _to_player()
	match state:
		"float":
			if state_t <= 0.0:
				if to_p.length() < RANGE * 1.5:
					_charge(to_p)
					return Vector2.ZERO
				state_t = 0.6
			if _orbs == 0 and state_t < 1.2 and to_p.length() < RANGE * 1.8:
				_orbs = 1
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * ORB_SPEED, contact_damage * 0.6, "laser_orb").life = 3.5
			var v := to_p.normalized().orthogonal() * _turn * 0.8
			v += to_p.normalized() * clampf((to_p.length() - RANGE) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"charge":
			face = signf(aim.x) if aim.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				state = "sweep"
				state_t = SWEEP_TIME
				_hit = false
				Sfx.play("laser", 0.1, -4.0)
		"sweep":
			_draw_beam()
			if state_t <= 0.0:
				_beam.visible = false
				state = "float"
				state_t = randf_range(2.6, 3.6)
				_orbs = 0
				if randf() < 0.5:
					_turn = -_turn
	return Vector2.ZERO


## Marks the wedge: the edge it starts from bright, the other faint.
func _charge(to_p: Vector2) -> void:
	var centre := (to_p + Vector2(0, Player.BODY_Y)).angle()
	var side := 1.0 if randf() < 0.5 else -1.0
	_a0 = centre - side * ARC * 0.5
	aim = Vector2.from_angle(centre)
	state = "charge"
	state_t = CHARGE_TIME
	alert.visible = true
	var w := Game.world
	w.telegraph_line(hit_center(), Vector2.from_angle(_a0), BEAM_LEN, 12.0, CHARGE_TIME)
	w.telegraph_line(hit_center(), Vector2.from_angle(_a0 + side * ARC), BEAM_LEN, 4.0, CHARGE_TIME)
	_turn_sweep = side
	Sfx.play("charge", 0.15, -8.0)


## The laser art stretched from the eye, turning across the wedge; hurts once per sweep.
func _draw_beam() -> void:
	var k := 1.0 - clampf(state_t / SWEEP_TIME, 0.0, 1.0)
	var dir := Vector2.from_angle(_a0 + _turn_sweep * ARC * k)
	var from := hit_center() + dir * 8.0
	_beam.visible = true
	_beam.global_position = from
	_beam.rotation = dir.angle()
	_beam.scale = Vector2(BEAM_LEN / _beam.texture.get_width(), 0.32)
	var p := player()
	if not _hit and not p.dead:
		var c := p.global_position + Vector2(0, Player.BODY_Y)
		var q := Geometry2D.get_closest_point_to_segment(c, from, from + dir * BEAM_LEN)
		if q.distance_to(c) < BEAM_HIT:
			_hit = true
			p.take_damage(contact_damage * 1.2, q)
			Game.world.burst(q, Color("ff4fd8"), 8, 60.0, 0.25, 2.0)


func _anim_name() -> String:
	match state:
		"charge":
			return "attack"
		"sweep":
			return "fire"
	return "walk"


func _on_death() -> void:
	_beam.visible = false
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "laser_drone", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff4fd8"), 12, 90.0, 0.4, 2.0)
	Sfx.play("explode", 0.2, -10.0)
