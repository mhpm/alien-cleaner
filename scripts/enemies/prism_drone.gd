extends Enemy
## PRISM SATELLITE DRONE (world 4): a floating crystal satellite. It keeps its distance
## and every few seconds locks on: its facets open ("attack"), a line marks the aim, then
## it fires a PRISM BEAM ("fire"): a laser straight along that line for a moment, hurting
## you if you are on it. Shatters into crystal shards (the set's "death").

const RANGE := 130.0
const AIM_TIME := 0.9
const BEAM_TIME := 0.4
const BEAM_LEN := 230.0
const BEAM_HIT := 7.0

var _turn := 1.0
var _beam: Sprite2D
var _hit := false


func _init_ai() -> void:
	state = "float"
	state_t = randf_range(2.0, 3.0)
	_turn = 1.0 if randf() < 0.5 else -1.0
	_beam = Sprite2D.new()
	_beam.texture = Art.frames("prism_beam").get_frame_texture("fly", 0)
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
	air = 12.0 + sin(t * 2.0 + phase) * 3.0
	var to_p := _to_player()
	match state:
		"float":
			if state_t <= 0.0 and to_p.length() < RANGE * 1.4:
				aim = (to_p + Vector2(0, Player.BODY_Y)).normalized()
				state = "aim"
				state_t = AIM_TIME
				alert.visible = true
				Game.world.telegraph_line(hit_center(), aim, BEAM_LEN, 10.0, AIM_TIME)
				Sfx.play("charge", 0.1, -8.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.7
			v += to_p.normalized() * clampf((to_p.length() - RANGE) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"aim":
			face = signf(aim.x) if aim.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				state = "fire"
				state_t = BEAM_TIME
				_hit = false
				Sfx.play("zap", 0.0, -2.0)
		"fire":
			_draw_beam()
			if state_t <= 0.0:
				_beam.visible = false
				state = "float"
				state_t = randf_range(2.6, 3.6)
				if randf() < 0.4:
					_turn = -_turn
	return Vector2.ZERO


## The laser art stretched from the core along `aim`; hurts once per shot.
func _draw_beam() -> void:
	var from := hit_center() + aim * 8.0
	var k := clampf(state_t / BEAM_TIME, 0.0, 1.0)
	_beam.visible = true
	_beam.global_position = from
	_beam.rotation = aim.angle()
	_beam.scale = Vector2(BEAM_LEN / _beam.texture.get_width(), 0.35 * (0.6 + 0.4 * k))
	_beam.modulate.a = 0.5 + 0.5 * k
	var p := player()
	if not _hit and not p.dead:
		var c := p.global_position + Vector2(0, Player.BODY_Y)
		var q := Geometry2D.get_closest_point_to_segment(c, from, from + aim * BEAM_LEN)
		if q.distance_to(c) < BEAM_HIT:
			_hit = true
			p.take_damage(contact_damage * 1.2, q)
			Game.world.burst(q, Color("ff4fd8"), 8, 60.0, 0.25, 2.0)


func _anim_name() -> String:
	match state:
		"aim":
			return "attack"
		"fire":
			return "fire"
	return "walk"


func _on_death() -> void:
	_beam.visible = false
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "prism_drone", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff4fd8"), 12, 90.0, 0.4, 2.0)
	w.burst(hit_center(), Color("7fe0ff"), 8, 70.0, 0.5, 2.0, 80.0)
	Sfx.play("freeze", 0.15, -6.0)
