extends Enemy
## JELLY SAUCER (worlds 2-3): a pink octopus in a saucer. It drifts at mid range and
## casts a BUBBLE NET: its tentacles flick (the set's "attack") and bubbles fly to a ring
## round where you stand (a circle marks it), hang there a moment and then all CLOSE IN
## to the centre (EnemyShot style "jelly_bubble"). The ring has one gap, on the saucer's
## side: you can run out through it, but that leads you towards the octopus... or simply
## outrun the ring before it closes. Get too close and it SLAPS with its tentacles: a
## circle round the saucer, then a blow that hurts and throws you back.
## Its dome cracks and it melts into a pink puddle (the set's "splat").

const KEEP := 95.0
const NET_R := 48.0
const SLOTS := 7  # one slot left empty = the gap
const FLY_TIME := 0.5
const HOLD_TIME := 0.75
const CLOSE_SPEED := 115.0
const CAST_TIME := 0.5
const SLAP_RANGE := 46.0
const SLAP_R := 42.0
const SLAP_WIND := 0.55
const SLAP_CD := 2.5
const SLAP_PUSH := 220.0

var _turn := 1.0
var _net: Array[EnemyShot] = []
var _net_to: Array[Vector2] = []
var _net_c := Vector2.ZERO
var _net_phase := ""
var _net_t := 0.0
var _slap_cd := 0.0


func _init_ai() -> void:
	state = "drift"
	state_t = randf_range(1.8, 2.8)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	_slap_cd -= delta
	air = 8.0 + sin(t * 2.2 + phase) * 2.5
	_update_net(delta)
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"drift":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if d < SLAP_RANGE and _slap_cd <= 0.0:
				state = "slap_wind"
				state_t = SLAP_WIND
				alert.visible = true
				Game.world.telegraph_circle(global_position, SLAP_R, SLAP_WIND / aggro)
				Sfx.play("charge", 0.4, -10.0)
				return Vector2.ZERO
			if state_t <= 0.0 and _net_phase == "" and d < KEEP * 2.2:
				_cast_net()
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.6
			v += to_p.normalized() * clampf((d - KEEP) / 25.0, -1.0, 1.0)
			return v.normalized() * speed
		"cast":
			if state_t <= 0.0:
				state = "drift"
				state_t = randf_range(3.0, 4.0)
			return Vector2.ZERO
		"slap_wind":
			if state_t <= 0.0:
				alert.visible = false
				_slap()
				state = "drift"
				state_t = maxf(state_t, 0.8)
			return Vector2.ZERO
	return Vector2.ZERO


## Bubbles to a ring round you, its gap on the saucer's side.
func _cast_net() -> void:
	state = "cast"
	state_t = CAST_TIME
	_net_c = player().global_position
	var gap := (global_position - _net_c).angle()
	var from := hit_center()
	for i in range(1, SLOTS):
		var to := _net_c + Vector2(0, Player.BODY_Y) + Vector2.from_angle(gap + TAU * i / SLOTS) * Vector2(NET_R, NET_R * 0.75)
		var s := Game.world.spawn_enemy_shot(from, Vector2.ZERO, contact_damage * 0.6, "jelly_bubble")
		s.life = 30.0
		_net.append(s)
		_net_to.append(to)
	_net_phase = "fly"
	_net_t = FLY_TIME
	Game.world.telegraph_circle(_net_c, NET_R, (FLY_TIME + HOLD_TIME) / aggro)
	Sfx.play("spit", 0.3, -6.0)
	squash = Vector2(1.1, 0.9)


func _update_net(delta: float) -> void:
	if _net_phase == "":
		return
	_net_t -= delta
	match _net_phase:
		"fly":
			for i in _net.size():
				var b := _net[i]
				if is_instance_valid(b):
					b.vel = (_net_to[i] - b.global_position) / maxf(_net_t, 0.05) * aggro
			if _net_t <= 0.0:
				_net_phase = "hold"
				_net_t = HOLD_TIME
		"hold":
			for i in _net.size():
				var b := _net[i]
				if is_instance_valid(b):
					b.vel = Vector2.ZERO
					b.global_position = _net_to[i]
			if _net_t <= 0.0:
				_close_net()


## Every bubble rushes through the centre and pops on the far side.
func _close_net() -> void:
	var c := _net_c + Vector2(0, Player.BODY_Y)
	for b in _net:
		if is_instance_valid(b):
			b.vel = (c - b.global_position).normalized() * CLOSE_SPEED
			b.life = NET_R * 2.0 / CLOSE_SPEED
	_net.clear()
	_net_to.clear()
	_net_phase = ""
	Sfx.play("pop", 0.2, -8.0)


func _slap() -> void:
	_slap_cd = SLAP_CD
	squash = Vector2(1.25, 0.8)
	Game.world.ring(global_position, SLAP_R, Color("ff3cf0"), 0.25, 3.0)
	Game.world.burst(global_position, Color("ff3cf0"), 10, 90.0, 0.3, 2.5)
	Game.world.shake(0.2)
	Sfx.play("slash", 0.2, -4.0)
	var p := player()
	if p.dead:
		return
	var off := p.global_position - global_position
	if Vector2(off.x, off.y / 0.75).length() < SLAP_R:
		p.take_damage(contact_damage, global_position)
		p.knock = off.normalized() * SLAP_PUSH


func _anim_name() -> String:
	return "attack" if state in ["cast", "slap_wind"] else "walk"


func _on_death() -> void:
	# the net bursts with its caster
	for b in _net:
		if is_instance_valid(b):
			b.pop()
	_net.clear()
	_net_to.clear()
	_net_phase = ""
	Game.world.burst(hit_center(), Color("ff3cf0"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
