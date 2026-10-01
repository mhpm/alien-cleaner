extends Enemy
## SATURN RING BUG (world 4): a crystal-winged bug wearing a planet ring. It hovers round
## you at mid range and, every few seconds, winds up ("attack") and THROWS ITS RING like a
## boomerang (RingShot): it spins out to where you were, stops and comes back, hurting you
## on the way out and on the way back. While the ring is out the bug keeps its distance;
## it catches it and starts again. Shatters into crystals (the set's "death").

const ORBIT := 90.0
const WIND_TIME := 0.5
const RING_TIMEOUT := 3.5

var _turn := 1.0


func _init_ai() -> void:
	state = "hover"
	state_t = randf_range(1.2, 2.2)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 10.0 + sin(t * 3.0 + phase) * 3.0
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"hover", "wait":
			if state == "hover" and state_t <= 0.0:
				state = "wind"
				state_t = WIND_TIME
				alert.visible = true
				Sfx.play("charge", 0.2, -12.0)
				return Vector2.ZERO
			if state == "wait" and state_t <= 0.0:
				catch_ring()  # the ring got lost: carry on
			var v := to_p.normalized().orthogonal() * _turn * 0.9
			v += to_p.normalized() * clampf((d - ORBIT) / 30.0, -1.0, 1.0)
			return v.normalized() * speed * (0.6 if state == "wait" else 1.0)
		"wind":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				_throw(to_p)
			return Vector2.ZERO
	return Vector2.ZERO


func _throw(to_p: Vector2) -> void:
	alert.visible = false
	var r := RingShot.new()
	r.tex_id = "ring"
	r.bug = self
	r.damage = contact_damage * 0.9
	var dist := clampf(to_p.length() + 20.0, 60.0, 170.0)
	r.vel = to_p.normalized() * RingShot.OUT_SPEED
	r.out_t = dist / RingShot.OUT_SPEED + 0.2
	r.life = 6.0
	r.position = hit_center()
	Game.world.effects.add_child(r)
	state = "wait"
	state_t = RING_TIMEOUT
	Sfx.play("dash", 0.2, -6.0)
	squash = Vector2(1.2, 0.85)


## The ring is back (RingShot calls this).
func catch_ring() -> void:
	if dead:
		return
	state = "hover"
	state_t = randf_range(1.4, 2.2)
	if randf() < 0.4:
		_turn = -_turn
	Game.world.burst(hit_center(), Color("ffb030"), 5, 30.0, 0.2, 1.5)


func _anim_name() -> String:
	return "attack" if state == "wind" else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "ring_bug", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff4fd8"), 10, 80.0, 0.4, 2.0)
	w.burst(hit_center(), Color("7fe0ff"), 6, 60.0, 0.4, 2.0, 80.0)
	Sfx.play("pop", 0.15, -6.0)
