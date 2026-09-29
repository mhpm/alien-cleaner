extends Enemy
## BIG RED: a tough one-eyed brute that never shoots. It plods after you, and when you
## get close it frowns (angry frames, a short warning line) and lunges. Splashes a
## few drops of goo around when cleaned (its puddle is the set's "splat").

const LUNGE_SPEED := 170.0
const REACH := 80.0


func _init_ai() -> void:
	state = "chase"
	state_t = randf_range(1.2, 2.0)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	match state:
		"chase":
			if state_t <= 0.0 and to_p.length() < REACH:
				state = "angry"
				state_t = 0.55
				aim = to_p.normalized()
				Game.world.telegraph_line(global_position + Vector2(0, -2), aim, 60.0, 12.0, state_t)
				return Vector2.ZERO
			if to_p.x != 0.0:
				face = signf(to_p.x)
			return to_p.normalized() * speed
		"angry":
			sprite.position.x = sin(t * 60.0) * 0.6
			if state_t <= 0.0:
				sprite.position.x = 0.0
				state = "lunge"
				state_t = 0.35
				squash = Vector2(1.25, 0.8)
				Sfx.play("dash", 0.1, -6.0)
			return Vector2.ZERO
		"lunge":
			if state_t <= 0.0:
				state = "rest"
				state_t = 0.6
			return aim * LUNGE_SPEED
		"rest":
			if state_t <= 0.0:
				state = "chase"
				state_t = randf_range(1.4, 2.2)
			return Vector2.ZERO
	return to_p.normalized() * speed


func _anim_name() -> String:
	if hurt_t > 0.0 and state == "chase":
		return "hurt"
	return "angry" if state in ["angry", "lunge"] else "walk"


func _on_death() -> void:
	for i in 3:
		var g := GooGlob.new()
		g.from = global_position
		g.to = global_position + Vector2.from_angle(randf() * TAU) * randf_range(14.0, 28.0)
		g.height = randf_range(10.0, 18.0)
		g.dur = randf_range(0.3, 0.45)
		g.size = 0.6
		g.puddle_r = 5.0
		g.puddle_life = 3.0
		Game.world.effects.add_child(g)
