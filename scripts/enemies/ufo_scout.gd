extends Enemy
## UFO SCOUT (world 4): a small, quick pink saucer. It circles you at mid range, weaving
## in and out, and every couple of seconds its lights flare ("attack") and it spits a
## quick pair of comets at where you are going (EnemyShot style "scout"); every third
## attack is one big, fast comet ("scout_comet") instead. Now and then it swoops in close,
## then pulls back out. Fragile: cracks open and crashes (the set's "splat").

const ORBIT := 80.0
const AIM_TIME := 0.45
const SHOT_SPEED := 120.0
const COMET_SPEED := 170.0
const LEAD := 0.35  # how far ahead of the astronaut it aims (s of their movement)

var _attacks := 0
var _turn := 1.0
var _swoop := 0.0


func _init_ai() -> void:
	state = "circle"
	state_t = randf_range(1.2, 2.2)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 9.0 + sin(t * 4.0 + phase) * 3.0
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"circle":
			if state_t <= 0.0:
				state = "attack"
				state_t = AIM_TIME
				alert.visible = true
				Sfx.play("alert", 0.2, -10.0)
				return Vector2.ZERO
			_swoop = maxf(0.0, _swoop - delta)
			if _swoop <= 0.0 and randf() < delta * 0.25:
				_swoop = 1.1  # dives in close for a moment
			var want := ORBIT * (0.45 if _swoop > 0.0 else 1.0) + sin(t * 1.3 + phase) * 14.0
			var v := to_p.normalized().orthogonal() * _turn * 1.1
			v += to_p.normalized() * clampf((d - want) / 30.0, -1.2, 1.2)
			return v.normalized() * speed * (1.4 if _swoop > 0.0 else 1.0)
		"attack":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				_attacks += 1
				_shoot(_attacks % 3 == 0)
				state = "circle"
				state_t = randf_range(1.6, 2.4)
				if randf() < 0.3:
					_turn = -_turn
			return to_p.normalized().orthogonal() * _turn * speed * 0.3
	return Vector2.ZERO


func _shoot(big: bool) -> void:
	var p := player()
	var from := hit_center() + Vector2(0, 3)
	var target := p.global_position + Vector2(0, Player.BODY_Y) + p.velocity * LEAD
	var dir := (target - from).normalized()
	if big:
		Game.world.spawn_enemy_shot(from, dir * COMET_SPEED, contact_damage * 1.3, "scout_comet")
		Sfx.play("zap", 0.1, -4.0)
	else:
		for a in [-0.12, 0.12]:
			Game.world.spawn_enemy_shot(from, dir.rotated(a) * SHOT_SPEED, contact_damage * 0.7, "scout")
		Sfx.play("zap", 0.2, -9.0)
	Game.world.burst(from, Color("ff5fa8"), 4, 40.0, 0.2, 1.5, 0.0, dir, 0.6)
	squash = Vector2(1.15, 0.9)


func _anim_name() -> String:
	return "attack" if state == "attack" else "walk"


func _on_death() -> void:
	var w := Game.world
	w.burst(hit_center(), Color("ff5fa8"), 10, 80.0, 0.4, 2.0)
	w.burst(hit_center(), Color("ffcd75"), 6, 60.0, 0.3, 2.0)
	Sfx.play("pop", 0.15, -6.0)
