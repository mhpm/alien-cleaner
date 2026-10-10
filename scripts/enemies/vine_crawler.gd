extends Enemy
## VINE CRAWLER (world 8 BIODOME): a mossy crawler droid that TETHERS you. It creeps after
## you; in range it aims (a lane marks the shot) and whips out a vine: if it catches you,
## you are tied to it for TETHER_TIME seconds and cannot get further than TETHER_LEN away
## (the vine pulls you back, slower than you walk) while it reels in and chews; shooting
## it TETHER_BREAK of its health cuts the vine. Out of the lane = no tether. Its body
## falls apart in leaves (the set's "death").

const RANGE := 110.0
const AIM_TIME := 0.7
const WHIP_LEN := 125.0
const WHIP_HIT := 9.0
const TETHER_TIME := 2.0
const TETHER_LEN := 55.0
const PULL := 60.0
const TETHER_BREAK := 0.3
const CHEW_EVERY := 0.6

var _vine: Line2D
var _tether_hp := 0.0
var _chew_t := 0.0


func _init_ai() -> void:
	state = "creep"
	state_t = randf_range(1.5, 2.5)
	_vine = Line2D.new()
	_vine.width = 3.0
	_vine.default_color = Color("4fbf3a")
	_vine.top_level = true
	_vine.z_index = 3
	_vine.visible = false
	add_child(_vine)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	if absf(to_p.x) > 2.0 and state != "tether":
		face = signf(to_p.x)
	match state:
		"creep":
			if state_t <= 0.0 and to_p.length() < RANGE:
				aim = (player().global_position + Vector2(0, Player.BODY_Y) - hit_center()).normalized()  # from the eye
				state = "aim"
				state_t = AIM_TIME
				alert.visible = true
				Game.world.telegraph_line(hit_center(), aim, WHIP_LEN, 10.0, AIM_TIME)
				Sfx.play("charge", 0.4, -10.0)
				return Vector2.ZERO
			# creeps up to whip range, not into you
			return to_p.normalized() * speed * clampf((to_p.length() - 45.0) / 20.0, -0.5, 1.0)
		"aim":
			if state_t <= 0.0:
				alert.visible = false
				_whip()
		"miss":
			_draw_vine(hit_center() + aim * WHIP_LEN * clampf(state_t / 0.3, 0.0, 1.0))
			if state_t <= 0.0:
				_vine.visible = false
				state = "creep"
				state_t = randf_range(2.0, 3.0)
		"tether":
			_hold(delta)
			return Vector2.ZERO
	return Vector2.ZERO


## The vine shoots along the lane: catches the astronaut if he is on it.
func _whip() -> void:
	var p := player()
	var from := hit_center()
	var c := p.global_position + Vector2(0, Player.BODY_Y)
	var q := Geometry2D.get_closest_point_to_segment(c, from, from + aim * WHIP_LEN)
	Sfx.play("slash", 0.3, -6.0)
	if not p.dead and q.distance_to(c) < WHIP_HIT:
		state = "tether"
		state_t = TETHER_TIME
		_tether_hp = hp
		_chew_t = 0.0
		p.take_damage(contact_damage * 0.6, from)
		Game.world.popup_text(p.global_position + Vector2(0, -30), "TETHERED!", Color("8cff5a"), 11)
	else:
		state = "miss"
		state_t = 0.3


## Tied: the astronaut is pulled back if he goes too far; it chews now and then.
func _hold(delta: float) -> void:
	var p := player()
	_draw_vine(p.global_position + Vector2(0, Player.BODY_Y))
	var d := global_position - p.global_position
	if d.length() > TETHER_LEN:
		p.knock = d.normalized() * PULL
	_chew_t -= delta
	if _chew_t <= 0.0:
		_chew_t = CHEW_EVERY
		p.take_damage(contact_damage * 0.25, global_position)
	if state_t <= 0.0 or p.dead or _tether_hp - hp >= max_hp * TETHER_BREAK:
		if _tether_hp - hp >= max_hp * TETHER_BREAK:
			Game.world.popup_text(hit_center() + Vector2(0, -20), "SNAP!", Color.WHITE, 11)
		_vine.visible = false
		state = "creep"
		state_t = randf_range(2.2, 3.0)


func _draw_vine(to: Vector2) -> void:
	_vine.visible = true
	var from := hit_center()
	var pts := PackedVector2Array()
	for k in 7:
		var f := k / 6.0
		var side := (to - from).normalized().orthogonal() * sin(f * PI * 2.0 + t * 8.0) * 3.0 * (1.0 - absf(f - 0.5) * 2.0)
		pts.append(from.lerp(to, f) + side)
	_vine.points = pts


func _anim_name() -> String:
	return "attack" if state in ["aim", "tether", "miss"] else "walk"


func _on_death() -> void:
	_vine.visible = false
	var w := Game.world
	var fx := AnimFx.spawn(w.decals, "vine_crawler", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("8cff5a"), 12, 70.0, 0.5, 2.0, 60.0)
	Sfx.play("explode", 0.4, -10.0)
