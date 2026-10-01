extends Enemy
## COMET BABY SKIFF (world 4): a little green goo pod with a big orange eye, always in a
## hurry. It zooms straight at you leaving a trail of goo, spits a glob when it is at
## mid range (EnemyShot style "baby") and, if it gets to you, it RAMS. Worst of all, it
## bursts when it dies: it leaves an acid PUDDLE (GooPuddle) that burns, so don't kill it
## right under your feet. Melts with a squint (the set's "splat").

const SPIT_RANGE := 90.0
const GLOB_SPEED := 110.0
const PUDDLE_R := 14.0
const PUDDLE_LIFE := 3.0

var _spit_t := 1.0
var _trail_t := 0.0


func _init_ai() -> void:
	state = "rush"


func _ai(delta: float) -> Vector2:
	_spit_t -= delta
	_trail_t -= delta
	air = 5.0 + sin(t * 8.0 + phase) * 1.5
	var to_p := _to_player()
	match state:
		"rush":
			if _trail_t <= 0.0:
				_trail_t = 0.12
				Game.world.burst(global_position + Vector2(-face * 6.0, -2.0), Color("a7f070"), 1, 10.0, 0.5, 2.5, 10.0)
			if _spit_t <= 0.0 and to_p.length() < SPIT_RANGE and to_p.length() > 30.0:
				state = "spit"
				state_t = 0.3
				return Vector2.ZERO
			return to_p.normalized() * speed * (1.0 + 0.25 * sin(t * 6.0 + phase))
		"spit":
			state_t -= delta
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				Game.world.spawn_enemy_shot(hit_center() + d * 8.0, d * GLOB_SPEED, contact_damage * 0.7, "baby")
				Sfx.play("spit", 0.2, -10.0)
				_spit_t = randf_range(2.0, 3.0)
				state = "rush"
			return Vector2.ZERO
	return Vector2.ZERO


func _anim_name() -> String:
	return "attack" if state == "spit" else "walk"


func _on_death() -> void:
	var w := Game.world
	w.burst(hit_center(), Color("a7f070"), 12, 70.0, 0.45, 2.5, 60.0)
	Sfx.play("pop", 0.15, -4.0)
	var pd := GooPuddle.new()
	pd.style = "hive"
	pd.acid = true
	pd.radius = PUDDLE_R
	pd.life = PUDDLE_LIFE
	pd.damage = contact_damage * 0.5
	pd.position = global_position
	w.decals.add_child(pd)
