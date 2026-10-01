extends Enemy
## TENTACLE ORBITER (world 4): a purple octopus in a saucer. Its tentacles gather a
## GRAVITY ORB ("attack") and it lobs it to a spot just past you; the orb slows to a stop
## (EnemyShot style "orbiter", "drag") and PULLS you towards it for a moment (you can
## walk out of it, slowly), then bursts into a ring of 8 bubbles. While its orb is
## pulling, the octopus closes in to make the most of it.
## Its saucer flips over and it melts into a purple puddle (the set's "splat").

const RANGE := 115.0
const AIM_TIME := 0.7
const ORB_LIFE := 3.0
const PULL := 340.0  # how hard the stopped orb pulls (knock/s)
const PULL_R := 90.0

var _orb: EnemyShot


func _init_ai() -> void:
	state = "drift"
	state_t = randf_range(1.8, 2.8)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 7.0 + sin(t * 2.0 + phase) * 2.5
	var to_p := _to_player()
	match state:
		"drift":
			if state_t <= 0.0:
				state = "aim"
				state_t = AIM_TIME
				alert.visible = true
				Sfx.play("charge", 0.1, -8.0)
				return Vector2.ZERO
			var v := to_p.normalized() * clampf((to_p.length() - RANGE) / 30.0, -1.0, 1.0)
			v += to_p.normalized().orthogonal() * sin(t * 0.6 + phase) * 0.6
			return v * speed
		"aim":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				# parks beside you (not on you, or it would just pop): with "drag" 2.0 an orb
				# travels speed / 2, so its speed is sized to the distance to that spot
				var side := to_p.normalized().orthogonal() * (1.0 if randf() < 0.5 else -1.0)
				var spot := player().global_position + side * 34.0 + to_p.normalized() * 10.0
				var from := hit_center()
				var spd := from.distance_to(spot) * 2.0
				_orb = Game.world.spawn_enemy_shot(from, (spot - from).normalized() * spd, contact_damage, "orbiter")
				_orb.vel = (spot - from).normalized() * spd  # exact: no world speed-up, or it overshoots
				_orb.life = ORB_LIFE
				state = "pull"
				state_t = ORB_LIFE
				Sfx.play("spit", 0.0, -4.0)
			return Vector2.ZERO
		"pull":
			_pull(delta)
			if state_t <= 0.0 or not is_instance_valid(_orb):
				_orb = null
				state = "drift"
				state_t = randf_range(2.4, 3.2)
			return to_p.normalized() * speed * 0.8
	return Vector2.ZERO


## Once the orb has (nearly) stopped it drags the astronaut in.
func _pull(delta: float) -> void:
	if not is_instance_valid(_orb) or _orb.vel.length() > 25.0:
		return
	if fmod(t, 0.35) < delta:  # a pulsing vortex shows the pull
		Game.world.ring(_orb.global_position, 34.0, Color("c060ff"), 0.3, 1.5)
	var p := player()
	var d := _orb.global_position - p.global_position
	if p.dead or d.length() > PULL_R or d.length() < 4.0:
		return
	p.knock += d.normalized() * PULL * delta
	if randf() < 0.4:
		var q := _orb.global_position + Vector2.from_angle(randf() * TAU) * 30.0
		Game.world.burst(q, Color("c060ff"), 1, 40.0, 0.3, 1.5, 0.0, (_orb.global_position - q).normalized(), 0.1)


func _anim_name() -> String:
	return "attack" if state == "aim" else "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("c060ff"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
