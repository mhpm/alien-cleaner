extends Enemy
## SPIKE MINE (world 4): a spiked mine floating in space with one red eye. It rolls
## slowly after you, bobbing, and every few seconds its eye flashes and spits a small
## fireball (EnemyShot style "mine"). If it gets close it ARMS: stops, beeps faster and
## faster with its core flaring ("charge") and a warning circle on the floor, then blows
## up, hurting you and every alien in the blast. Shot to death it also blows up (it
## hurts the aliens round it, not you), so popping one inside a crowd pays off, and
## mines set each other off in a chain. Leaves burnt scrap (the set's "splat").

const ARM_RANGE := 34.0
const ARM_TIME := 1.1
const BLAST_R := 34.0
const BLAST_ENEMY_DMG := 60.0
const SHOT_SPEED := 85.0

var _armed := false


func _init_ai() -> void:
	state = "roll"
	state_t = randf_range(2.0, 3.2)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 6.0 + sin(t * 2.2 + phase) * 3.0
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"roll":
			sprite.rotation += delta * 1.6 * face
			if d < ARM_RANGE:
				_arm()
				return Vector2.ZERO
			if state_t <= 0.0 and d < 170.0:
				_spit(to_p)
				state_t = randf_range(2.4, 3.4)
			return to_p.normalized() * speed
		"charge":
			sprite.rotation = lerp_angle(sprite.rotation, 0.0, delta * 8.0)
			var k := 1.0 - state_t / ARM_TIME
			var beep := 0.25 - 0.18 * k  # beeps faster as it gets ready
			if fmod(state_t, beep) < delta:
				Sfx.play("alert", 0.0, -10.0 + k * 6.0)
			squash = Vector2.ONE * (1.0 + sin(t * (20.0 + 30.0 * k)) * 0.08 * k)
			if state_t <= 0.0:
				_armed = true
				die()
			return Vector2.ZERO
	return Vector2.ZERO


func _arm() -> void:
	state = "charge"
	state_t = ARM_TIME
	alert.visible = true
	var tg := Telegraph.new()
	tg.position = global_position
	tg.radius = BLAST_R
	tg.dur = ARM_TIME
	tg.color = Color("ff7a2a")
	Game.world.decals.add_child(tg)


func _spit(to_p: Vector2) -> void:
	var from := hit_center()
	Game.world.spawn_enemy_shot(from, to_p.normalized() * SHOT_SPEED, contact_damage * 0.7, "mine")
	Game.world.burst(from, Color("ff7a2a"), 4, 40.0, 0.2, 1.5, 0.0, to_p.normalized(), 0.5)
	Sfx.play("spit", 0.15, -8.0)
	squash = Vector2(1.15, 0.9)


func _anim_name() -> String:
	return "charge" if state == "charge" else "walk"


## Blows up either way; only an armed mine (it reached you) hurts the astronaut.
func _on_death() -> void:
	var w := Game.world
	var c := global_position
	w.explosion(c, BLAST_R, BLAST_ENEMY_DMG, contact_damage * 1.6 if _armed else 0.0)
	w.burst(hit_center(), Color("ff7a2a"), 14, 120.0, 0.45, 2.5)
	w.burst(hit_center(), Color("c9d4e0"), 8, 90.0, 0.5, 2.0, 120.0)  # metal shards
