extends Enemy
## OCTO-WIZARD: a hooded one-eyed octopus mage that floats at mid range and casts, in turn:
##  - an ORB: it holds a glowing orb ("orb" pose) and hurls a slow one that curves after you
##    (EnemyShot style "wizard", "home"),
##  - a RUNE: it raises a hand and marks the floor where you are heading (magenta circle);
##    a moment later the rune blasts, hurting anyone still on it.
## When you get too close, or after a cast, it BLINKS: spreads its arms, fades out and
## reappears somewhere else around you. Dies melting into a puddle (the set's "splat").

const ORB_TIME := 0.75
const RUNE_TIME := 0.9
const RUNE_R := 24.0
const ORB_SPEED := 46.0
const CLOSE := 42.0
const BLINK_TIME := 0.28

var _casts := 0
var _rune_pos := Vector2.ZERO


func _init_ai() -> void:
	state = "float"
	state_t = randf_range(1.4, 2.4)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"float":
			air = 3.0 + sin(t * 3.0 + phase) * 1.5
			if state_t <= 0.0 or d < CLOSE:
				if d < CLOSE:
					_start_blink()
				else:
					_casts += 1
					if _casts % 2 == 1:
						state = "orb"
						state_t = ORB_TIME
						alert.visible = true
					else:
						state = "rune"
						state_t = RUNE_TIME
						_mark_rune()
					Sfx.play("alert", 0.1, -8.0)
				return Vector2.ZERO
			var v := Vector2.ZERO
			if d < 65.0:
				v = -to_p.normalized()
			elif d > 110.0:
				v = to_p.normalized()
			else:
				v = to_p.normalized().orthogonal() * (1.0 if sin(t * 0.6 + phase) > 0.0 else -1.0) * 0.7
			return v * speed
		"orb":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if randf() < 0.5:  # magic gathers into the hand
				var hand := _hand()
				var p := hand + Vector2.from_angle(randf() * TAU) * 10.0
				Game.world.burst(p, Color("ff4fd8"), 1, 20.0, 0.25, 1.5, 0.0, (hand - p).normalized(), 0.2)
			if state_t <= 0.0:
				alert.visible = false
				_throw_orb()
				_rest()
			return Vector2.ZERO
		"rune":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				_blast()
				_rest()
			return Vector2.ZERO
		"rest":
			if state_t <= 0.0:
				if randf() < 0.5:
					_start_blink()
				else:
					state = "float"
					state_t = randf_range(1.6, 2.4)
			return Vector2.ZERO
		"blink":  # fading out
			sprite.modulate.a = clampf(state_t / BLINK_TIME, 0.0, 1.0)
			if state_t <= 0.0:
				_teleport()
				state = "appear"
				state_t = BLINK_TIME
			return Vector2.ZERO
		"appear":
			sprite.modulate.a = clampf(1.0 - state_t / BLINK_TIME, 0.0, 1.0)
			if state_t <= 0.0:
				sprite.modulate.a = 1.0
				state = "float"
				state_t = randf_range(1.2, 2.0)
			return Vector2.ZERO
	return Vector2.ZERO


func _rest() -> void:
	state = "rest"
	state_t = 0.5


func _hand() -> Vector2:
	return hit_center() + Vector2(face * 10.0, 1.0)


func _throw_orb() -> void:
	var from := _hand()
	var dir := ((player().global_position + Vector2(0, Player.BODY_Y)) - from).normalized()
	var s := Game.world.spawn_enemy_shot(from, dir * ORB_SPEED, contact_damage, "wizard")
	s.life = 5.0
	Sfx.play("zap", 0.15, -6.0)
	squash = Vector2(0.85, 1.15)


## Floor circle where the astronaut is heading (a little ahead of them).
func _mark_rune() -> void:
	var p := player()
	_rune_pos = p.global_position + p.velocity * 0.4
	var b := Game.world.room.bounds().grow(-6.0)
	_rune_pos = _rune_pos.clamp(b.position, b.end)
	var tg := Telegraph.new()
	tg.position = _rune_pos
	tg.radius = RUNE_R
	tg.dur = RUNE_TIME
	tg.color = Color("d43cff")
	Game.world.decals.add_child(tg)


func _blast() -> void:
	var w := Game.world
	var c := Color("d43cff")
	w.ring(_rune_pos, RUNE_R, c, 0.35, 3.0, true)
	w.burst(_rune_pos + Vector2(0, -4), c, 16, 90.0, 0.45, 2.5, 30.0)
	w.burst(_rune_pos + Vector2(0, -4), Color.WHITE, 6, 50.0, 0.25, 2.0)
	w.shake(0.3)
	Sfx.play("explode", 0.1, -6.0)
	var p := player()
	if not p.dead:
		var off := p.global_position - _rune_pos  # the circle is drawn squashed (y * 0.75)
		if Vector2(off.x, off.y / 0.75).length() < RUNE_R:
			p.take_damage(contact_damage * 1.4, _rune_pos)
	squash = Vector2(0.85, 1.15)


func _start_blink() -> void:
	state = "blink"
	state_t = BLINK_TIME
	alert.visible = false
	Game.world.burst(hit_center(), Color("d43cff"), 8, 50.0, 0.3, 2.0)


## Reappears 70-105 units from the astronaut, inside the arena.
func _teleport() -> void:
	var w := Game.world
	var b := w.room.bounds().grow(-14.0)
	var p := player().global_position
	var pos := global_position
	for i in 8:
		var q := p + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 105.0)
		if b.has_point(q):
			pos = q
			break
	global_position = pos
	w.burst(hit_center(), Color("d43cff"), 8, 50.0, 0.3, 2.0)
	w.ring(hit_center(), 12.0, Color("ff4fd8"), 0.25, 2.0)
	Sfx.play("spawn", 0.15, -10.0)


func _anim_name() -> String:
	match state:
		"orb":
			return "orb"
		"rune":
			return "rune"
		"blink", "appear":
			return "blink"
	return "walk"


func _on_death() -> void:
	Game.world.ring(hit_center(), 14.0, Color("d43cff"), 0.35, 2.0)
