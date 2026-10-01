extends Enemy
## EYECLOPS: a floating one-eyed octopus. It hovers at mid range, strafing, and every
## few seconds either turns to face you with its core glowing ("charge") and lets out a
## pulse of orbs (a ring of 8, or a fast aimed fan of 3 on every other attack), or, if
## you are close, curls up ("crawl" frames), telegraphs a line and lunges. Below
## WOUNDED of its health it can no longer float: it drops and crawls after you faster,
## without shooting. Dies melting into a puddle (the set's "splat" animation).

const WOUNDED := 0.3
const NOVA_TIME := 0.8
const LUNGE_SPEED := 150.0
const LUNGE_REACH := 55.0
const CRAWL_MULT := 1.5

var _attacks := 0


func _init_ai() -> void:
	state = "float"
	state_t = randf_range(1.4, 2.2)


func _ai(delta: float) -> Vector2:
	if state != "crawl" and hp < max_hp * WOUNDED:
		_wound()
	state_t -= delta
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"float":
			air = 2.0 + sin(t * 3.0 + phase) * 1.2
			if state_t <= 0.0:
				if d < LUNGE_REACH:
					state = "wind"
					state_t = 0.45
					aim = to_p.normalized()
					Game.world.telegraph_line(global_position + Vector2(0, -2), aim, 55.0, 12.0, state_t)
					Sfx.play("alert", 0.1, -8.0)
				else:
					state = "charge"
					state_t = NOVA_TIME
					alert.visible = true
					Sfx.play("alert", 0.1, -8.0)
				return Vector2.ZERO
			var v := Vector2.ZERO
			if d < 55.0:
				v = -to_p.normalized()
			elif d > 100.0:
				v = to_p.normalized()
			else:
				v = to_p.normalized().orthogonal() * (1.0 if sin(t * 0.6 + phase) > 0.0 else -1.0) * 0.7
			return v * speed
		"charge":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			sprite.position.x = sin(t * 55.0) * (0.3 + (NOVA_TIME - state_t) * 0.8)
			if randf() < 0.6:  # energy gathers into the core
				var p := hit_center() + Vector2.from_angle(randf() * TAU) * 14.0
				Game.world.burst(p, Color("ff4fd8"), 1, 22.0, 0.25, 1.5, 0.0, (hit_center() - p).normalized(), 0.2)
			if state_t <= 0.0:
				sprite.position.x = 0.0
				alert.visible = false
				_nova(to_p)
				state = "float"
				state_t = randf_range(2.0, 3.0)
			return Vector2.ZERO
		"wind":
			sprite.position.x = sin(t * 60.0) * 0.6
			face = signf(aim.x) if aim.x != 0.0 else face
			air = 0.0
			if state_t <= 0.0:
				sprite.position.x = 0.0
				state = "lunge"
				state_t = 0.4
				squash = Vector2(1.3, 0.75)
				Sfx.play("dash", 0.1, -6.0)
			return Vector2.ZERO
		"lunge":
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.05
				Game.world.burst(global_position + Vector2(0, -3), Color("d43cff"), 1, 6.0, 0.25, 2.0)
			if state_t <= 0.0 or (hit_wall and state_t < 0.35):
				if hit_wall:
					Game.world.burst(global_position, Color(1, 1, 1, 0.7), 5, 40.0, 0.25, 2.0)
				state = "rest"
				state_t = 0.5
			return aim * LUNGE_SPEED
		"rest":
			air = move_toward(air, 2.0, delta * 20.0)
			if state_t <= 0.0:
				state = "float"
				state_t = randf_range(1.6, 2.4)
			return Vector2.ZERO
		"crawl":  # wounded: slithers after you on the floor
			if to_p.x != 0.0:
				face = signf(to_p.x)
			return to_p.normalized() * speed * CRAWL_MULT * (0.85 + 0.25 * sin(t * 6.0 + phase))
	return Vector2.ZERO


## Too hurt to float: falls to the floor and crawls (no more shooting or lunging).
func _wound() -> void:
	state = "crawl"
	air = 0.0
	alert.visible = false
	sprite.position.x = 0.0
	squash = Vector2(1.3, 0.75)
	Game.world.burst(hit_center(), Color("d43cff"), 8, 60.0, 0.35, 2.0, 60.0)
	Sfx.play("hurt", 0.1, -8.0)


## Pulse of orbs: a full ring, or (every other attack) a fast fan aimed at the player.
func _nova(to_p: Vector2) -> void:
	_attacks += 1
	var from := hit_center()
	Game.world.ring(from, 16.0, Color("ff4fd8"), 0.3, 2.0)
	if _attacks % 2 == 1:
		var off := randf() * TAU
		for i in 8:
			Game.world.spawn_enemy_shot(from, Vector2.from_angle(off + TAU * i / 8.0) * 55.0, contact_damage, "eyeclops")
		Sfx.play("spit", 0.1, -4.0)
	else:
		var dir := (player().global_position + Vector2(0, -6) - from).normalized()
		for a: float in [-0.3, 0.0, 0.3]:
			Game.world.spawn_enemy_shot(from + dir * 5.0, dir.rotated(a) * 90.0, contact_damage, "eyeclops")
		Sfx.play("zap", 0.15, -6.0)
	knock -= to_p.normalized() * 40.0
	squash = Vector2(0.8, 1.2)


func _anim_name() -> String:
	match state:
		"charge":
			return "charge"
		"wind", "lunge", "crawl":
			return "crawl"
	return "walk"


func _on_death() -> void:
	Game.world.ring(hit_center(), 14.0, Color("d43cff"), 0.35, 2.0)
