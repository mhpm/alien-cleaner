extends Enemy
## World 2 mini boss BROOD MOTHER (room 20): a giant hive octopus. Swims in pulses,
## spins spirals of energy orbs, fires orb rings, lunges along a warning line and
## spawns Greenies. Enraged under 50% HP: faster, double spirals, bigger broods.

const PATTERN := ["swim", "spiral", "swim", "lunge", "brood", "swim", "ring", "lunge", "spiral", "ring"]
const ORB_SPEED := 62.0

var pattern_i := 0
var spin := 0.0
var fire_t := 0.0


func _init_ai() -> void:
	state = "intro"
	state_t = 0.9


func _enraged() -> bool:
	return hp < max_hp * 0.5


func _tempo() -> float:
	return 0.75 if _enraged() else 1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	match state:
		"intro", "rest":
			if state_t <= 0.0:
				_next()
			return Vector2.ZERO
		"swim":
			if state_t <= 0.0:
				_next()
			# jellyfish stroke, circling the player at mid range
			var pulse := maxf(0.0, sin(t * 3.2 + phase))
			squash = Vector2(1.0 + pulse * 0.1, 1.0 - pulse * 0.08)
			var v := to_p.normalized().orthogonal() * (1.0 if sin(t * 0.4) > 0.0 else -1.0)
			if to_p.length() > 80.0:
				v += to_p.normalized()
			elif to_p.length() < 50.0:
				v -= to_p.normalized()
			return v.normalized() * speed * (0.4 + pulse * 1.6) / _tempo()
		"spiral":
			# the "attack" frame: arms up, spraying a rotating spiral
			fire_t -= delta
			spin += delta * (2.6 if _enraged() else 2.0)
			if fire_t <= 0.0:
				fire_t = 0.11
				var arms := 3 if _enraged() else 2
				for i in arms:
					_orb(Vector2.from_angle(spin + TAU * i / arms))
				Sfx.play("spit", 0.2, -12.0)
			if state_t <= 0.0:
				state = "rest"
				state_t = 0.6 * _tempo()
			return Vector2.ZERO
		"attack":
			# ring windup: swell up, then release
			var k := 1.0 - state_t / 0.7
			squash = Vector2(1.0 + k * 0.25, 1.0 + k * 0.15)
			if state_t <= 0.0:
				_ring(16, 0.0)
				if _enraged():
					get_tree().create_timer(0.25).timeout.connect(func() -> void:
						if not dead:
							_ring(16, PI / 16.0))
				squash = Vector2(0.75, 1.3)
				state = "rest"
				state_t = 0.7 * _tempo()
			return Vector2.ZERO
		"aim":
			sprite.position.x = sin(t * 50.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				state = "dash"
				state_t = 0.6
				squash = Vector2(0.75, 1.3)
				Sfx.play("dash", 0.05)
			return Vector2.ZERO
		"dash":
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.03
				Game.world.burst(global_position + Vector2(0, -6), Color("c75bd6"), 2, 10.0, 0.35, 3.0)
			if (hit_wall and state_t < 0.55) or state_t <= 0.0:
				if hit_wall:
					Game.world.shake(0.5)
					Sfx.play("land", 0.1)
					_ring(8, randf() * TAU)
				state = "rest"
				state_t = 0.7 * _tempo()
			return aim * 175.0
	return Vector2.ZERO


func _next() -> void:
	var step: String = PATTERN[pattern_i % PATTERN.size()]
	pattern_i += 1
	match step:
		"swim":
			state = "swim"
			state_t = 1.6 * _tempo()
		"spiral":
			state = "spiral"
			state_t = 2.2
			spin = _to_player().angle()
			Sfx.play("charge", 0.0, -4.0)
		"ring":
			state = "attack"
			state_t = 0.7
			Sfx.play("charge", 0.0, -4.0)
		"lunge":
			state = "aim"
			state_t = 0.55 if _enraged() else 0.75
			aim = _to_player().normalized()
			Game.world.telegraph_line(global_position + Vector2(0, -2), aim, 190.0, 22.0, state_t)
			Sfx.play("charge", 0.0, -4.0)
		"brood":
			_brood()
			state = "rest"
			state_t = 0.8


## Lays Greenies from hive portals around her (capped so the room never floods).
func _brood() -> void:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).type_id == "ufo_alien":
			alive += 1
	var n := mini(4 if _enraged() else 2, 6 - alive)
	for i in n:
		var at := global_position + Vector2.from_angle(TAU * i / maxf(n, 1) + randf()) * 22.0
		_ufo_portal("ufo_alien", at.clamp(Game.world.room.bounds().position + Vector2(12, 12), Game.world.room.bounds().end - Vector2(12, 12)))
	Sfx.play("roar", 0.1, -8.0)


func _orb(dir: Vector2) -> void:
	Game.world.spawn_enemy_shot(hit_center() + dir * 8.0, dir * ORB_SPEED, contact_damage * 0.7, "octopus")


func _ring(n: int, offset: float) -> void:
	for i in n:
		_orb(Vector2.from_angle(offset + TAU * i / n))
	Sfx.play("spit", 0.05)
