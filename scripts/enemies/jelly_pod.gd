extends Enemy
## JELLY POD (world 4): a jellyfish riding a saucer. It drifts slowly towards mid range,
## bobbing, and takes turns between:
##  - SPORES: its tentacles glow ("attack") and it lets out a fan of spores that shoot
##    out, slow down and hang in the air like mines for a few seconds (EnemyShot style
##    "jelly": "drag"), so the area around it fills with things to dodge;
##  - STING: if you get close, its tentacles charge up (a magenta circle on the floor)
##    and it discharges an electric pulse that hurts anyone inside.
## Dies with its dome cracking, melting into a magenta puddle (the set's "splat").

const SPORE_TIME := 0.7
const SPORES := 5
const SPORE_SPEED := 90.0
const SPORE_LIFE := 5.0
const STING_RANGE := 42.0
const STING_R := 36.0
const STING_TIME := 0.65

var _sting_at := Vector2.ZERO


func _init_ai() -> void:
	state = "drift"
	state_t = randf_range(1.5, 2.5)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 8.0 + sin(t * 1.8 + phase) * 4.0
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"drift":
			if d < STING_RANGE:
				_start_sting()
				return Vector2.ZERO
			if state_t <= 0.0:
				state = "spores"
				state_t = SPORE_TIME
				alert.visible = true
				Sfx.play("charge", 0.2, -12.0)
				return Vector2.ZERO
			# pulses forward like a jellyfish: quick push, then glide
			var pulse := maxf(0.0, sin(t * 3.0 + phase))
			var v := to_p.normalized() * (1.0 if d > 90.0 else (-0.6 if d < 60.0 else 0.0))
			v += to_p.normalized().orthogonal() * sin(t * 0.5 + phase) * 0.5
			return v * speed * (0.4 + pulse * 1.3)
		"spores":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if randf() < 0.4:
				Game.world.burst(hit_center() + Vector2(randf_range(-8, 8), 8), Color("ff3cf0"), 1, 20.0, 0.3, 1.5, 20.0)
			if state_t <= 0.0:
				alert.visible = false
				_release_spores(to_p)
				state = "drift"
				state_t = randf_range(2.2, 3.2)
			return Vector2.ZERO
		"sting":
			if randf() < 0.6:  # sparks crawl down the tentacles
				Game.world.burst(global_position + Vector2(randf_range(-10, 10), -air), Color("ff9cf8"), 1, 40.0, 0.2, 1.5)
			if state_t <= 0.0:
				_discharge()
				state = "drift"
				state_t = randf_range(1.2, 1.8)
			return Vector2.ZERO
	return Vector2.ZERO


## A fan of spores towards the astronaut, fanned wider the more there are.
func _release_spores(to_p: Vector2) -> void:
	var from := hit_center() + Vector2(0, 6)
	var base := to_p.angle()
	for i in SPORES:
		var a := base + (i - (SPORES - 1) * 0.5) * 0.38
		var s := Game.world.spawn_enemy_shot(from, Vector2.from_angle(a) * SPORE_SPEED * randf_range(0.85, 1.15), contact_damage * 0.8, "jelly")
		s.life = SPORE_LIFE + randf_range(-0.5, 0.5)
	Sfx.play("spit", 0.2, -6.0)
	squash = Vector2(0.85, 1.2)


func _start_sting() -> void:
	state = "sting"
	state_t = STING_TIME
	_sting_at = global_position
	var tg := Telegraph.new()
	tg.position = _sting_at
	tg.radius = STING_R
	tg.dur = STING_TIME
	tg.color = Color("ff3cf0")
	Game.world.decals.add_child(tg)
	Sfx.play("charge", 0.1, -8.0)


func _discharge() -> void:
	var w := Game.world
	var c := Color("ff3cf0")
	w.ring(_sting_at, STING_R, c, 0.3, 3.0, true)
	w.ring(_sting_at, STING_R * 0.6, Color("ffffff"), 0.2, 2.0)
	w.burst(_sting_at + Vector2(0, -6), c, 14, 100.0, 0.35, 2.0)
	Sfx.play("zap", 0.1, -3.0)
	w.shake(0.2)
	var p := player()
	if not p.dead:
		var off := p.global_position - _sting_at  # the circle is drawn squashed (y * 0.75)
		if Vector2(off.x, off.y / 0.75).length() < STING_R:
			p.take_damage(contact_damage * 1.2, _sting_at)
	squash = Vector2(1.25, 0.8)


func _anim_name() -> String:
	return "attack" if state == "spores" or state == "sting" else "walk"


func _on_death() -> void:
	var w := Game.world
	w.burst(hit_center(), Color("ff3cf0"), 14, 80.0, 0.45, 2.5, 60.0)
	w.burst(hit_center(), Color("8fd0ff"), 6, 60.0, 0.3, 2.0)
	Sfx.play("pop", 0.15, -4.0)
