extends Enemy
## BUBBLE BRAIN SCOUT (world 4): a brain with one eye under a glass dome. It keeps away
## from you (backing off when you close in) and every few seconds puffs out a pair of
## slow bubbles that home in on you (EnemyShot style "brain", "home"): they turn hard,
## so outrun them sideways or shoot the brain first. Its dome cracks, the brain pops
## and it sinks into a puddle (the set's "splat").

const RANGE := 120.0
const PUFF_TIME := 0.6
const BUBBLE_SPEED := 55.0

var _turn := 1.0


func _init_ai() -> void:
	state = "float"
	state_t = randf_range(1.8, 2.8)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 10.0 + sin(t * 2.2 + phase) * 3.0
	var to_p := _to_player()
	match state:
		"float":
			if state_t <= 0.0:
				state = "puff"
				state_t = PUFF_TIME
				alert.visible = true
				Sfx.play("charge", 0.2, -12.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.6
			v += to_p.normalized() * clampf((to_p.length() - RANGE) / 25.0, -1.4, 1.0)
			return v.normalized() * speed
		"puff":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				var from := hit_center() + Vector2(face * 10.0, 6.0)
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				for a: float in [-0.5, 0.5]:
					var s := Game.world.spawn_enemy_shot(from, d.rotated(a) * BUBBLE_SPEED, contact_damage * 0.7, "brain")
					s.life = 4.5
				Sfx.play("pop", 0.2, -6.0)
				squash = Vector2(0.9, 1.1)
				state = "float"
				state_t = randf_range(2.6, 3.4)
			return Vector2.ZERO
	return Vector2.ZERO


func _anim_name() -> String:
	return "attack" if state == "puff" else "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("5fd0ff"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
