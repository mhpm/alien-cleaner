extends Enemy
## Mini boss GLOOP BRUTE: chases, telegraphed charge dashes, glob rings.
## Enraged under 50% HP. Splits into slimelets when cleaned.

const PATTERN := ["chase", "dash", "chase", "ring", "dash", "chase", "dash", "ring"]

var pattern_i := 0


func _init_ai() -> void:
	state = "intro"
	state_t = 0.8


func _enraged() -> bool:
	return hp < max_hp * 0.5


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	match state:
		"intro":
			if state_t <= 0.0:
				_next()
		"chase":
			if state_t <= 0.0:
				_next()
			return to_p.normalized() * speed * (1.3 if _enraged() else 1.0)
		"aim":
			sprite.position.x = sin(t * 50.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				state = "dash"
				state_t = 0.65
				squash = Vector2(1.3, 0.75)
				Sfx.play("dash", 0.05)
			return Vector2.ZERO
		"dash":
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.03
				Game.world.burst(global_position + Vector2(0, -6), Color("c75bd6"), 2, 10.0, 0.35, 3.0)
			if hit_wall and state_t < 0.6:
				Game.world.shake(0.6)
				Sfx.play("land", 0.1)
				Game.world.burst(global_position, Color(1, 1, 1, 0.8), 12, 70.0, 0.35, 2.0)
				if _enraged():
					_ring(8, 0.0)
				state = "recover"
				state_t = 0.8
			elif state_t <= 0.0:
				state = "recover"
				state_t = 0.45
			return aim * 185.0
		"recover":
			if state_t <= 0.0:
				_next()
			return Vector2.ZERO
		"windup":
			var k := 1.0 - state_t / 0.7
			squash = Vector2(1.0 + k * 0.25, 1.0 + k * 0.15)
			if state_t <= 0.0:
				_ring(12, 0.0)
				if _enraged():
					get_tree().create_timer(0.3).timeout.connect(func() -> void:
						if not dead:
							_ring(12, PI / 12.0))
				squash = Vector2(0.75, 1.3)
				state = "recover"
				state_t = 0.7
			return Vector2.ZERO
	return Vector2.ZERO


func _next() -> void:
	var step: String = PATTERN[pattern_i % PATTERN.size()]
	pattern_i += 1
	match step:
		"chase":
			state = "chase"
			state_t = 1.4
		"dash":
			state = "aim"
			state_t = 0.55 if _enraged() else 0.75
			aim = _to_player().normalized()
			Game.world.telegraph_line(global_position + Vector2(0, -2), aim, 190.0, 20.0, state_t)
			Sfx.play("charge", 0.0, -4.0)
		"ring":
			state = "windup"
			state_t = 0.7
			Sfx.play("charge", 0.0, -4.0)


func _ring(n: int, offset: float) -> void:
	var c := hit_center()
	for i in n:
		var a := offset + TAU * i / n
		Game.world.spawn_enemy_shot(c, Vector2.from_angle(a) * 70.0, 12.0)
	Sfx.play("spit", 0.05)


func _on_death() -> void:
	for i in 4:
		var off := Vector2.from_angle(TAU * i / 4.0 + 0.4) * 12.0
		Game.world.spawn_enemy("mini_slime", global_position + off)
