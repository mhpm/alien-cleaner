extends Enemy
## NEBULA SCOUT POD (world 4): a grumpy green alien in a purple saucer. It flies in quick
## ZIPS: holds still a moment, then darts sideways in a straight burst (never quite
## where you aimed). After every couple of zips its dome lights up ("attack") and it
## fires a quick TRIPLE BURST of nebula orbs at you (EnemyShot style "nebula").
## Cracks, smokes and falls apart into purple rubble (the set's "death", played once).

const ORBIT := 95.0
const ZIP_SPEED := 170.0
const ZIP_TIME := 0.28
const AIM_TIME := 0.45
const BURST := 3
const BURST_GAP := 0.13
const ORB_SPEED := 120.0

var _zips := 0
var _left := 0
var _zip_v := Vector2.ZERO


func _init_ai() -> void:
	state = "hold"
	state_t = randf_range(0.4, 0.9)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 9.0 + sin(t * 3.0 + phase) * 2.0
	var to_p := _to_player()
	match state:
		"hold":
			if state_t <= 0.0:
				if _zips >= 2:
					_zips = 0
					state = "aim"
					state_t = AIM_TIME
					alert.visible = true
					Sfx.play("charge", 0.2, -12.0)
				else:
					_zip(to_p)
			return Vector2.ZERO
		"zip":
			if randf() < 0.6:
				Game.world.burst(hit_center() - _zip_v.normalized() * 10.0, Color("ff4fd8"), 1, 20.0, 0.25, 2.0)
			if state_t <= 0.0 or hit_wall:
				state = "hold"
				state_t = randf_range(0.35, 0.6)
				squash = Vector2(1.2, 0.85)
			return _zip_v
		"aim":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				state = "burst"
				state_t = 0.0
				_left = BURST
			return Vector2.ZERO
		"burst":
			if state_t <= 0.0:
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized().rotated(randf_range(-0.08, 0.08))
				Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * ORB_SPEED, contact_damage * 0.6, "nebula")
				Sfx.play("zap", 0.2, -10.0)
				_left -= 1
				state_t = BURST_GAP
				if _left <= 0:
					state = "hold"
					state_t = 0.5
			return Vector2.ZERO
	return Vector2.ZERO


## A dart across the astronaut's line of fire, drifting back to ORBIT range.
func _zip(to_p: Vector2) -> void:
	var side := to_p.normalized().orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	var keep := to_p.normalized() * clampf((to_p.length() - ORBIT) / 60.0, -0.8, 0.8)
	_zip_v = (side + keep).normalized() * ZIP_SPEED
	state = "zip"
	state_t = ZIP_TIME
	_zips += 1
	Sfx.play("dash", 0.3, -14.0)


func _anim_name() -> String:
	return "attack" if state in ["aim", "burst"] else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "nebula_pod", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("b05cff"), 12, 80.0, 0.4, 2.5)
	w.burst(hit_center(), Color(0.35, 0.3, 0.45, 0.8), 6, 30.0, 0.8, 3.5, -30.0)
	Sfx.play("explode", 0.2, -10.0)
