extends Enemy
## Mini boss GLOOP BRUTE: chases, telegraphed charge dashes, glob rings and calls in a
## pack of slimes. Enraged under 60% HP: faster, back-to-back dashes, double rings and
## a glob burst whenever a dash hits a wall. Splits into slimelets when cleaned.

const PATTERN := ["chase", "dash", "ring", "dash", "summon", "chase", "dash", "ring", "dash"]
const DASH_SPEED := 215.0
const SHOT_DMG := 16.0
const SHOT_SPEED := 85.0

var pattern_i := 0
var chain := 0  # extra dashes left in an enraged chain
var roared := false


func _init_ai() -> void:
	state = "intro"
	state_t = 0.8


func _enraged() -> bool:
	return hp < max_hp * 0.6


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	if _enraged() and not roared:
		roared = true
		Sfx.play("roar", 0.0)
		Game.world.shake(0.6)
		Game.world.ring(hit_center(), 40.0, Color("ff5566"), 0.4, 3.0)
		tint = Color(1.25, 0.45, 0.9)
	match state:
		"intro":
			if state_t <= 0.0:
				_next()
		"chase":
			if state_t <= 0.0:
				_next()
			return to_p.normalized() * speed * (1.5 if _enraged() else 1.1)
		"aim":
			sprite.position.x = sin(t * 50.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				state = "dash"
				state_t = 0.6
				squash = Vector2(1.3, 0.75)
				Sfx.play("dash", 0.05)
			return Vector2.ZERO
		"dash":
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.03
				Game.world.burst(global_position + Vector2(0, -6), Color("c75bd6"), 2, 10.0, 0.35, 3.0)
			if hit_wall and state_t < 0.55:
				Game.world.shake(0.6)
				Sfx.play("land", 0.1)
				Game.world.burst(global_position, Color(1, 1, 1, 0.8), 12, 70.0, 0.35, 2.0)
				_ring(10 if _enraged() else 6, randf() * TAU)
				_after_dash(0.6)
			elif state_t <= 0.0:
				_after_dash(0.35)
			return aim * DASH_SPEED * (1.15 if _enraged() else 1.0)
		"recover":
			if state_t <= 0.0:
				_next()
			return Vector2.ZERO
		"windup":
			var k := 1.0 - state_t / 0.6
			squash = Vector2(1.0 + k * 0.25, 1.0 + k * 0.15)
			if state_t <= 0.0:
				_ring(16, 0.0)
				if _enraged():
					get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
						if not dead:
							_ring(16, PI / 16.0))
				squash = Vector2(0.75, 1.3)
				state = "recover"
				state_t = 0.55
			return Vector2.ZERO
		"call":
			squash = Vector2(1.0 + sin(t * 30.0) * 0.1, 1.0)
			if state_t <= 0.0:
				_summon()
				state = "recover"
				state_t = 0.4
			return Vector2.ZERO
	return Vector2.ZERO


## Enraged dashes come in pairs: aim again right away.
func _after_dash(rest: float) -> void:
	if chain > 0:
		chain -= 1
		_aim_dash(0.35)
		return
	state = "recover"
	state_t = rest


func _aim_dash(windup: float) -> void:
	state = "aim"
	state_t = windup
	aim = _to_player().normalized()
	Game.world.telegraph_line(global_position + Vector2(0, -2), aim, 200.0, 20.0, state_t)
	Sfx.play("charge", 0.0, -4.0)


func _next() -> void:
	var step: String = PATTERN[pattern_i % PATTERN.size()]
	pattern_i += 1
	match step:
		"chase":
			state = "chase"
			state_t = 0.9
		"dash":
			chain = 1 if _enraged() else 0
			_aim_dash(0.45 if _enraged() else 0.6)
		"ring":
			state = "windup"
			state_t = 0.6
			Sfx.play("charge", 0.0, -4.0)
		"summon":
			state = "call"
			state_t = 0.5
			Sfx.play("roar", 0.1, -6.0)


## Calls a pack of slimes (runners when enraged) around the player.
func _summon() -> void:
	var w := Game.world
	var n := 6 if _enraged() else 4
	var id := "runner" if _enraged() else "slime"
	var p := player().global_position
	var b := w.room.bounds().grow(-14.0)
	# as tough as the horde around them
	var hm := w.survival._hp_mult() if w.survival != null else 1.0
	var dm := w.survival._dmg_mult() if w.survival != null else 1.0
	for i in n:
		var pos := (p + Vector2.from_angle(TAU * i / n + randf() * 0.5) * 70.0).clamp(b.position, b.end)
		w.spawn_with_marker(id, pos, 0.6 + i * 0.05, hm, 1.0, false, dm)


func _ring(n: int, offset: float) -> void:
	var c := hit_center()
	for i in n:
		var a := offset + TAU * i / n
		Game.world.spawn_enemy_shot(c, Vector2.from_angle(a) * SHOT_SPEED, SHOT_DMG)
	Sfx.play("spit", 0.05)


func _on_death() -> void:
	for i in 5:
		var off := Vector2.from_angle(TAU * i / 5.0 + 0.4) * 12.0
		Game.world.spawn_enemy("mini_slime", global_position + off)
