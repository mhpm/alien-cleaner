extends Enemy
## SLIME COMET SHIP (world 4): an orange blob in a spiky green slime-comet. It makes
## STRAFING RUNS: lines up beside you, then blasts straight past you (not at you) leaving
## a TRAIL of acid slime puddles behind it (GooPuddle), and at the end of the run spits a
## glob back at you ("attack", EnemyShot style "comet_slime"). Each run lays a new wall
## of slime, so the floor round you fills up: keep moving out of the closing lanes.
## Cracks and melts into slime (the set's "splat").

const RUN_SPEED := 150.0
const RUN_TIME := 1.1
const LINE_UP := 1.0
const PASS_OFFSET := 38.0  # how far from you the run passes
const DROP_EVERY := 0.11
const PUDDLE_R := 9.0
const PUDDLE_LIFE := 3.5
const GLOB_SPEED := 110.0

var _run_v := Vector2.ZERO
var _drop_t := 0.0


func _init_ai() -> void:
	state = "line_up"
	state_t = randf_range(0.8, 1.6)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 6.0 + sin(t * 5.0 + phase) * 1.5
	var to_p := _to_player()
	match state:
		"line_up":
			# get to ~110 from the astronaut, then plan a run that passes beside them
			var v := to_p.normalized() * clampf((to_p.length() - 110.0) / 25.0, -1.0, 1.0)
			v += to_p.normalized().orthogonal() * 0.5
			if state_t <= 0.0:
				_plan_run(to_p)
				return Vector2.ZERO
			return v.normalized() * speed
		"run":
			face = signf(_run_v.x) if _run_v.x != 0.0 else face
			_drop_t -= delta
			if _drop_t <= 0.0:
				_drop_t = DROP_EVERY
				_puddle()
			if state_t <= 0.0 or hit_wall:
				state = "spit"
				state_t = 0.35
				alert.visible = true
				return Vector2.ZERO
			return _run_v
		"spit":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * GLOB_SPEED, contact_damage * 0.7, "comet_slime")
				Sfx.play("spit", 0.15, -6.0)
				state = "line_up"
				state_t = LINE_UP
			return Vector2.ZERO
	return Vector2.ZERO


## Aims at a point beside the astronaut, so the slime trail runs past them.
func _plan_run(to_p: Vector2) -> void:
	var side := to_p.normalized().orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	var aim_at := player().global_position + side * PASS_OFFSET
	_run_v = (aim_at - global_position).normalized() * RUN_SPEED
	state = "run"
	state_t = RUN_TIME
	_drop_t = 0.0
	Game.world.telegraph_line(global_position, _run_v.normalized(), RUN_SPEED * RUN_TIME, 14.0, 0.35)
	Sfx.play("dash", 0.1, -6.0)
	squash = Vector2(1.25, 0.8)


func _puddle() -> void:
	var pd := GooPuddle.new()
	pd.style = "hive"
	pd.acid = true
	pd.radius = PUDDLE_R
	pd.life = PUDDLE_LIFE
	pd.damage = contact_damage * 0.35
	pd.position = global_position
	Game.world.decals.add_child(pd)


func _anim_name() -> String:
	return "attack" if state in ["run", "spit"] else "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("a7f070"), 12, 70.0, 0.45, 2.5, 60.0)
	Sfx.play("pop", 0.15, -4.0)
