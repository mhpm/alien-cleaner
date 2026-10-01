extends Enemy
## CARGO CRAB DRONE (world 4): a crab-legged cargo robot with a rocket pod on its back. It
## scuttles sideways round you on the deck (no hovering) and, every few seconds, plants
## its legs, opens the pod ("attack") and fires a salvo of ROCKETS that curve in after
## you (EnemyShot style "rocket", "home"). Sturdy. Blows up into crates, scrap and smoke
## (the set's "death").

const ORBIT := 105.0
const OPEN_TIME := 0.7
const SALVO := 3
const SALVO_GAP := 0.18
const ROCKET_SPEED := 85.0

var _turn := 1.0
var _left := 0


func _init_ai() -> void:
	state = "scuttle"
	state_t = randf_range(2.0, 3.0)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 0.0
	var to_p := _to_player()
	match state:
		"scuttle":
			if state_t <= 0.0:
				state = "open"
				state_t = OPEN_TIME
				alert.visible = true
				Sfx.play("door", 0.2, -10.0)
				return Vector2.ZERO
			# sideways like a crab, with a little skitter
			var v := to_p.normalized().orthogonal() * _turn * (1.0 + 0.4 * sin(t * 9.0 + phase))
			v += to_p.normalized() * clampf((to_p.length() - ORBIT) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"open":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				state = "salvo"
				state_t = 0.0
				_left = SALVO
			return Vector2.ZERO
		"salvo":
			if state_t <= 0.0:
				_rocket(to_p)
				_left -= 1
				state_t = SALVO_GAP
				if _left <= 0:
					state = "scuttle"
					state_t = randf_range(2.6, 3.6)
					if randf() < 0.4:
						_turn = -_turn
			return Vector2.ZERO
	return Vector2.ZERO


## Rockets leave the pod upwards and to the sides, then home in.
func _rocket(to_p: Vector2) -> void:
	var from := hit_center() + Vector2(-face * 6.0, -8.0)
	var up := Vector2(randf_range(-0.6, 0.6), -1.0).normalized()
	var dir := up.lerp(to_p.normalized(), 0.35).normalized()
	var s := Game.world.spawn_enemy_shot(from, dir * ROCKET_SPEED, contact_damage * 0.8, "rocket")
	s.life = 3.5
	Game.world.burst(from, Color(0.4, 0.4, 0.45, 0.8), 4, 30.0, 0.5, 2.5, -20.0)
	Sfx.play("dash", 0.2, -10.0)
	squash = Vector2(1.1, 0.92)


func _anim_name() -> String:
	return "attack" if state in ["open", "salvo"] else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "crab_drone", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff9a3a"), 12, 90.0, 0.4, 2.5)
	w.burst(hit_center(), Color(0.3, 0.3, 0.35, 0.8), 8, 40.0, 0.8, 4.0, -30.0)
	Sfx.play("explode", 0.2, -8.0)
