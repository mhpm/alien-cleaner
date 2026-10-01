extends Enemy
## TENTACLE PLANT: a carnivorous plant that creeps after you on its tentacles. Within
## range it roots itself and opens its maw ("open" frames, a short warning), then either
## lashes its tongue (PlantTongue: damages and yanks you in) if you are close, or spits
## a fan of 3 sticky globs if you are not. Rooted it cannot be pushed. Dies wilting into a
## puddle (the set's "splat").

const RANGE := 105.0
const LASH_DIST := 52.0
const LASH_REACH := 66.0
const GLOB_SPEED := 68.0


func _init_ai() -> void:
	state = "creep"
	state_t = randf_range(1.2, 2.2)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	match state:
		"creep":
			if to_p.x != 0.0:
				face = signf(to_p.x)
			if state_t <= 0.0 and to_p.length() < RANGE:
				state = "root"
				state_t = 0.7
				alert.visible = true
				Sfx.play("alert", 0.1, -8.0)
				return Vector2.ZERO
			return to_p.normalized() * speed * (0.8 + 0.3 * sin(t * 3.0 + phase))
		"root":
			knock = Vector2.ZERO
			face = signf(to_p.x) if to_p.x != 0.0 else face
			sprite.position.x = sin(t * 45.0) * 0.5
			if state_t <= 0.0:
				sprite.position.x = 0.0
				alert.visible = false
				if to_p.length() < LASH_DIST:
					_lash()
					state = "lash"
				else:
					_spit()
					state = "spit"
				state_t = 0.45
			return Vector2.ZERO
		"lash", "spit":
			knock = Vector2.ZERO
			if state_t <= 0.0:
				state = "rest"
				state_t = 0.6
			return Vector2.ZERO
		"rest":
			if state_t <= 0.0:
				state = "creep"
				state_t = randf_range(1.8, 2.8)
			return Vector2.ZERO
	return to_p.normalized() * speed


func _mouth() -> Vector2:
	return hit_center() + Vector2(face * 9.0, 2.0)


func _lash() -> void:
	var tg := PlantTongue.new()
	tg.position = _mouth()
	tg.dir = ((player().global_position + Vector2(0, Player.BODY_Y)) - tg.position).normalized()
	tg.length = LASH_REACH
	tg.damage = contact_damage * 1.2
	Game.world.effects.add_child(tg)
	Sfx.play("dash", 0.1, -4.0)
	squash = Vector2(1.2, 0.85)


func _spit() -> void:
	var from := _mouth()
	var dir := ((player().global_position + Vector2(0, Player.BODY_Y)) - from).normalized()
	for a: float in [-0.3, 0.0, 0.3]:
		Game.world.spawn_enemy_shot(from + dir * 4.0, dir.rotated(a) * GLOB_SPEED, contact_damage, "plant")
	Sfx.play("spit", 0.1, -4.0)
	squash = Vector2(0.85, 1.15)


func _anim_name() -> String:
	if state in ["root", "lash", "spit"]:
		return "open"
	return "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("ff3c6e"), 10, 70.0, 0.4, 2.0, 60.0)
	Game.world.burst(hit_center(), Color("a7f070"), 6, 50.0, 0.4, 2.0, 60.0)
