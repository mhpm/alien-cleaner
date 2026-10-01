class_name PuddleRadar
extends Enemy
## PUDDLE RADAR SAUCER (world 4): a pink blob in a saucer with jelly legs, a spotter. It
## drifts slowly at range and every few seconds sends out a RADAR PING (a pink ring that
## sweeps out from it). If the ping reaches you, it calls a BUBBLE STRIKE on you: pink
## circles appear where you are and around you and, a moment later, bubbles rain down
## on them ("attack"). Move off the marks. It also spits a single bubble now and then.
## Its saucer cracks and it melts into a puddle (the set's "splat").

const PING_EVERY := 4.0
const PING_R := 150.0
const PING_SPEED := 160.0
const STRIKES := 3
const STRIKE_R := 18.0
const STRIKE_TIME := 1.0
const BUBBLE_SPEED := 90.0

var _ping := -1.0  # radius of the travelling ping (<0: none)
var _ring: Node2D
var _spit_t := 2.0
var _ping_t := 2.0


func _init_ai() -> void:
	state = "drift"
	_ping_t = randf_range(2.0, PING_EVERY)
	_ring = Node2D.new()
	_ring.top_level = true
	_ring.z_index = 3
	_ring.draw.connect(_draw_ping)
	add_child(_ring)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	_spit_t -= delta
	_ping_t -= delta
	air = 6.0 + sin(t * 2.0 + phase) * 2.0
	var to_p := _to_player()
	if _ping >= 0.0:
		_ping += PING_SPEED * delta
		_ring.queue_redraw()
		if to_p.length() <= _ping and to_p.length() >= _ping - PING_SPEED * delta * 1.5:
			_strike()
			_ping = -1.0
		elif _ping > PING_R:
			_ping = -1.0
			_ring.queue_redraw()
	match state:
		"drift":
			if _ping_t <= 0.0:
				_ping_t = PING_EVERY
				_ping = 0.0
				_ring.global_position = hit_center()
				Sfx.play("alert", 0.3, -10.0)
			if _spit_t <= 0.0 and to_p.length() < PING_R:
				_spit_t = randf_range(2.5, 3.5)
				state = "spit"
				state_t = 0.5
			var v := to_p.normalized() * clampf((to_p.length() - 115.0) / 30.0, -1.0, 1.0)
			v += to_p.normalized().orthogonal() * sin(t * 0.5 + phase) * 0.6
			return v * speed
		"spit", "strike":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				if state == "spit":
					var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
					Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * BUBBLE_SPEED, contact_damage * 0.7, "radar")
					Sfx.play("pop", 0.2, -8.0)
				state = "drift"
			return Vector2.ZERO
	return Vector2.ZERO


## The ping found the astronaut: marks on and around them, then bubbles rain down.
func _strike() -> void:
	var p := player()
	var b := Game.world.room.bounds().grow(-6.0)
	state = "strike"
	state_t = 0.6
	Sfx.play("charge", 0.0, -6.0)
	for i in STRIKES:
		var at := p.global_position + p.velocity * 0.3
		if i > 0:
			at = p.global_position + Vector2.from_angle(TAU * i / STRIKES + randf()) * randf_range(26.0, 50.0)
		at = at.clamp(b.position, b.end)
		var tg := Telegraph.new()
		tg.position = at
		tg.radius = STRIKE_R
		tg.dur = STRIKE_TIME + i * 0.12
		tg.color = Color("ff5fe0")
		Game.world.decals.add_child(tg)
		var dmg := contact_damage
		get_tree().create_timer(tg.dur, false).timeout.connect(func() -> void:
			if is_instance_valid(Game.world):
				PuddleRadar.bubble_drop(at, dmg))


static func bubble_drop(at: Vector2, dmg: float) -> void:
	var w := Game.world
	var c := Color("ff5fe0")
	w.ring(at, STRIKE_R, c, 0.3, 2.5, true)
	w.burst(at + Vector2(0, -4), c, 10, 70.0, 0.4, 2.5, 40.0)
	AnimFx.spawn(w.effects, "glob_pop", "pop", at + Vector2(0, -4), 0.2).self_modulate = Color(1.6, 0.6, 1.6)
	Sfx.play("pop", 0.2, -6.0)
	var p := w.player
	if not p.dead:
		var off := p.global_position - at  # the circle is drawn squashed (y * 0.75)
		if Vector2(off.x, off.y / 0.75).length() < STRIKE_R:
			p.take_damage(dmg, at)


func _draw_ping() -> void:
	if _ping < 0.0:
		return
	var a := 1.0 - _ping / PING_R
	_ring.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.75))
	_ring.draw_arc(Vector2.ZERO, _ping, 0.0, TAU, 48, Color(1.0, 0.4, 0.9, 0.6 * a), 2.0)
	_ring.draw_arc(Vector2.ZERO, maxf(_ping - 6.0, 0.0), 0.0, TAU, 48, Color(1.0, 0.4, 0.9, 0.25 * a), 4.0)


func _anim_name() -> String:
	return "attack" if state in ["spit", "strike"] else "walk"


func _on_death() -> void:
	_ping = -1.0
	_ring.queue_redraw()
	Game.world.burst(hit_center(), Color("ff5fe0"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
