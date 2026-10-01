extends Enemy
## DRILL NOSE ORBITER (world 4): a spiked metal pod with a spinning drill for a nose. It
## circles you, then turns its drill on you (a line on the floor) and fires a DRILL BLAST
## (a fast cone of energy, EnemyShot style "drill"); every third attack it DRILLS IN
## instead: charges at you along the line, drill first. Its nose points where it aims.
## Bursts into scrap and blue sparks (the set's "death").

const ORBIT := 80.0
const AIM_TIME := 0.6
const BLAST_SPEED := 170.0
const CHARGE_SPEED := 200.0
const CHARGE_TIME := 0.55

var _attacks := 0
var _turn := 1.0


func _init_ai() -> void:
	state = "orbit"
	state_t = randf_range(1.4, 2.4)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 7.0 + sin(t * 3.4 + phase) * 2.0
	var to_p := _to_player()
	match state:
		"orbit":
			sprite.rotation = lerp_angle(sprite.rotation, 0.0, delta * 6.0)
			if state_t <= 0.0:
				_attacks += 1
				aim = (to_p + Vector2(0, Player.BODY_Y)).normalized()
				state = "aim"
				state_t = AIM_TIME
				alert.visible = true
				var charge := _attacks % 3 == 0
				Game.world.telegraph_line(hit_center(), aim, (CHARGE_SPEED * CHARGE_TIME) if charge else 200.0, 10.0 if not charge else 18.0, AIM_TIME)
				set_meta("charge", charge)
				Sfx.play("charge", 0.2, -10.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn
			v += to_p.normalized() * clampf((to_p.length() - ORBIT) / 25.0, -1.0, 1.0)
			return v.normalized() * speed
		"aim":
			_point(aim)
			if state_t <= 0.0:
				alert.visible = false
				if bool(get_meta("charge", false)):
					state = "charge"
					state_t = CHARGE_TIME
					Sfx.play("dash", 0.1, -4.0)
				else:
					_blast()
					state = "recoil"
					state_t = 0.35
			return -aim * 8.0
		"recoil":
			if state_t <= 0.0:
				_back_to_orbit()
			return -aim * 30.0
		"charge":
			_point(aim)
			if randf() < 0.6:
				Game.world.burst(hit_center() - aim * 10.0, Color("5fb8ff"), 1, 30.0, 0.25, 2.0)
			var p := player()
			if not p.dead and p.global_position.distance_to(global_position) < radius + 7.0:
				p.take_damage(contact_damage * 1.2, global_position)
				p.knock += aim * 120.0
				_back_to_orbit()
				return Vector2.ZERO
			if state_t <= 0.0 or hit_wall:
				_back_to_orbit()
			return aim * CHARGE_SPEED
	return Vector2.ZERO


## The drill nose (the art points right) towards `dir`.
func _point(dir: Vector2) -> void:
	face = signf(dir.x) if dir.x != 0.0 else face
	sprite.rotation = dir.angle() if face > 0.0 else dir.angle() - PI


func _blast() -> void:
	var from := hit_center() + aim * 14.0
	Game.world.spawn_enemy_shot(from, aim * BLAST_SPEED, contact_damage, "drill")
	Game.world.burst(from, Color("5fb8ff"), 6, 60.0, 0.25, 2.0, 0.0, aim, 0.5)
	Sfx.play("zap", 0.1, -6.0)
	squash = Vector2(0.85, 1.1)


func _back_to_orbit() -> void:
	state = "orbit"
	state_t = randf_range(1.6, 2.4)
	if randf() < 0.35:
		_turn = -_turn


func _anim_name() -> String:
	match state:
		"aim", "charge":
			return "attack"
		"recoil":
			return "fire"
	return "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "drill_orbiter", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("5fb8ff"), 12, 90.0, 0.4, 2.5)
	w.burst(hit_center(), Color("c9d4e0"), 6, 70.0, 0.5, 2.0, 120.0)
	Sfx.play("explode", 0.2, -10.0)
