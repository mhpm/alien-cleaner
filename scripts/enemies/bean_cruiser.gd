class_name BeanCruiser
extends Enemy
## MARTIAN BEAN CRUISER (world 4): an orange bean in a green cruiser that CUTS YOU OFF.
## It doesn't shoot at you: it lobs globs of STICKY GOO in an arc onto the floor AHEAD of
## where you are running (a line of 3 marks across your path), and each glob leaves a
## StickyGoo patch that slows you right down. Alone it's harmless; with the horde round
## you it's a trap. Change direction when you see the marks.
## Its dome cracks and it melts into green goo (the set's "splat").

const ORBIT := 110.0
const AIM_TIME := 0.55
const GLOBS := 3
const AHEAD := 55.0  # how far ahead of you the line of goo lands
const SPREAD := 26.0
const GOO_LIFE := 5.0
const HIT_R := 12.0

var _turn := 1.0


func _init_ai() -> void:
	state = "cruise"
	state_t = randf_range(1.6, 2.6)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 8.0 + sin(t * 2.4 + phase) * 2.0
	var to_p := _to_player()
	match state:
		"cruise":
			if state_t <= 0.0:
				state = "aim"
				state_t = AIM_TIME
				alert.visible = true
				Sfx.play("charge", 0.2, -12.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.7
			v += to_p.normalized() * clampf((to_p.length() - ORBIT) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"aim":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				_lob()
				state = "cruise"
				state_t = randf_range(2.6, 3.4)
				if randf() < 0.4:
					_turn = -_turn
			return Vector2.ZERO
	return Vector2.ZERO


## A line of globs across the astronaut's path, a little ahead of them.
func _lob() -> void:
	var p := player()
	var dir := p.velocity.normalized() if p.velocity.length() > 10.0 else (p.global_position - global_position).normalized()
	var centre := p.global_position + dir * AHEAD
	var across := dir.orthogonal()
	var b := Game.world.room.bounds().grow(-8.0)
	for i in GLOBS:
		var to := (centre + across * (i - (GLOBS - 1) * 0.5) * SPREAD).clamp(b.position, b.end)
		var g := GooGlob.new()
		g.style = "hive"
		g.from = hit_center()
		g.to = to
		g.height = 50.0
		g.dur = 0.7 + i * 0.06
		var dmg := contact_damage * 0.6
		g.on_land = func(at: Vector2) -> void:
			BeanCruiser.splat_goo(at, dmg)
		Game.world.effects.add_child(g)
		Game.world.telegraph_circle(to, 13.0, g.dur)
	Sfx.play("spit", 0.1, -6.0)
	squash = Vector2(1.15, 0.9)


static func splat_goo(at: Vector2, dmg: float) -> void:
	var w := Game.world
	var goo := StickyGoo.new()
	goo.position = at
	goo.life = GOO_LIFE
	w.decals.add_child(goo)
	w.burst(at, Color("a7f070"), 8, 50.0, 0.35, 2.0, 60.0)
	Sfx.play("land", 0.3, -14.0)
	var p := w.player
	if not p.dead and p.global_position.distance_to(at) < HIT_R:
		p.take_damage(dmg, at)
		p.stick(1.2)


func _anim_name() -> String:
	return "attack" if state == "aim" else "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("a7f070"), 12, 70.0, 0.45, 2.5, 60.0)
	Sfx.play("pop", 0.15, -4.0)
