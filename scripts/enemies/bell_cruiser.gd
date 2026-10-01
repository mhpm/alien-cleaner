extends Enemy
## TENTACLE BELL CRUISER (world 4): a one-eyed jellyfish bell. It glides after you in
## slow pulses and, when you are in range, opens its eye ("attack") and fires a CHAIN
## of bubbles, one after another along the same line (EnemyShot style "bell"), so the
## line stays dangerous for a moment. If you get right under it the tentacles sting.
## Collapses into a pink puddle with its eye still blinking (the set's "splat").

const RANGE := 130.0
const AIM_TIME := 0.55
const CHAIN := 5
const CHAIN_GAP := 0.1
const BUBBLE_SPEED := 120.0

var _left := 0


func _init_ai() -> void:
	state = "glide"
	state_t = randf_range(1.6, 2.6)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 6.0 + sin(t * 1.8 + phase) * 3.0
	var to_p := _to_player()
	match state:
		"glide":
			if state_t <= 0.0 and to_p.length() < RANGE:
				aim = (to_p + Vector2(0, Player.BODY_Y)).normalized()
				state = "aim"
				state_t = AIM_TIME
				alert.visible = true
				Game.world.telegraph_line(hit_center(), aim, 160.0, 8.0, AIM_TIME)
				Sfx.play("charge", 0.2, -12.0)
				return Vector2.ZERO
			var pulse := maxf(0.0, sin(t * 2.6 + phase))
			return to_p.normalized() * speed * (0.3 + pulse * 1.4)
		"aim":
			face = signf(aim.x) if aim.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				state = "chain"
				state_t = 0.0
				_left = CHAIN
			return Vector2.ZERO
		"chain":
			if state_t <= 0.0:
				Game.world.spawn_enemy_shot(hit_center() + aim * 10.0, aim * BUBBLE_SPEED, contact_damage * 0.6, "bell")
				Sfx.play("pop", 0.3, -12.0)
				_left -= 1
				state_t = CHAIN_GAP
				if _left <= 0:
					state = "glide"
					state_t = randf_range(2.2, 3.0)
			return Vector2.ZERO
	return Vector2.ZERO


func _anim_name() -> String:
	return "attack" if state in ["aim", "chain"] else "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("ff5fe0"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
