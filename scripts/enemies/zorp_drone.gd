extends Enemy
## ZORP DRONE: a little spherical drone COMMANDER ZORP launches. It circles the astronaut
## for a moment, then locks on (a line on the floor), dashes at them with its thruster
## blazing ("dash") and bursts at the end of the dash, or on hitting them.
## Shoot it first and it only pops.

const ORBIT := 55.0
const LOCK_TIME := 0.5
const DASH_SPEED := 210.0
const DASH_TIME := 0.55
const BLAST_R := 22.0

var _turn := 1.0


func _init_ai() -> void:
	state = "orbit"
	state_t = randf_range(1.2, 2.2)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 8.0 + sin(t * 5.0 + phase) * 2.0
	var to_p := _to_player()
	match state:
		"orbit":
			if state_t <= 0.0:
				state = "lock"
				state_t = LOCK_TIME
				aim = to_p.normalized()
				alert.visible = true
				Game.world.telegraph_line(global_position, aim, DASH_SPEED * DASH_TIME, 10.0, LOCK_TIME)
				Sfx.play("alert", 0.2, -10.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn
			v += to_p.normalized() * clampf((to_p.length() - ORBIT) / 25.0, -1.0, 1.0)
			return v.normalized() * speed
		"lock":
			if state_t <= 0.0:
				state = "dash"
				state_t = DASH_TIME
				alert.visible = false
				Sfx.play("dash", 0.2, -6.0)
			return -aim * 15.0
		"dash":
			var p := player()
			if not p.dead and p.global_position.distance_to(global_position) < radius + 6.0:
				_burst()
				return Vector2.ZERO
			if state_t <= 0.0 or hit_wall:
				_burst()
				return Vector2.ZERO
			return aim * DASH_SPEED
	return Vector2.ZERO


func _contact() -> void:
	pass  # it bursts instead


func _burst() -> void:
	var w := Game.world
	var c := hit_center()
	w.ring(c, BLAST_R, Color("5fe6ff"), 0.3, 2.0, true)
	w.burst(c, Color("c8ff3a"), 12, 90.0, 0.4, 2.0)
	AnimFx.spawn(w.effects, "zorp_pop", "pop", c, 0.2)
	Sfx.play("explode", 0.15, -8.0)
	var p := player()
	if not p.dead and (p.global_position + Vector2(0, Player.BODY_Y)).distance_to(c) < BLAST_R:
		p.take_damage(contact_damage * 1.2, c)
	dead = true  # burst: no reward
	targetable = false
	remove_from_group("enemies")
	queue_free()


func _anim_name() -> String:
	return "dash" if state == "dash" else "walk"


func _on_death() -> void:
	AnimFx.spawn(Game.world.effects, "zorp_pop", "pop", hit_center(), 0.14)
	Game.world.burst(hit_center(), Color("5fe6ff"), 6, 60.0, 0.3, 2.0)
