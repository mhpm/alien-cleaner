extends Enemy
## SLIME PEARL FLYER (world 4): a slime blob riding an open clam. It fights back when
## you focus it: after HITS_TO_CLOSE hits in a short window it SNAPS ITS SHELL SHUT
## (shown with a pearly glint; takes only CLOSED_ARMOR damage) and, when it opens again,
## answers with a fan of pearls aimed at you ("attack", EnemyShot style "pearl") — more
## pearls the harder you hit it. Otherwise it drifts at mid range and spits one pearl
## now and then. Tip: spread your fire, or wait for it to open.
## Its shell breaks and the slime melts out (the set's "splat").

const HITS_TO_CLOSE := 4
const HIT_WINDOW := 1.2
const CLOSED_TIME := 1.6
const CLOSED_ARMOR := 0.2
const PEARL_SPEED := 100.0

var _hits: Array[float] = []
var _stored := 0.0  # damage soaked while closed: makes the answer bigger
var _spit_t := 2.0


func _init_ai() -> void:
	state = "drift"


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	if state == "closed":
		_stored += amount
		super.take_damage(amount * CLOSED_ARMOR, Vector2.ZERO, false)
		Game.world.burst(hit_center(), Color("e8fff0"), 2, 40.0, 0.2, 1.5)
		return
	super.take_damage(amount, dir, crit)
	if dead:
		return
	_hits.append(t)
	while _hits.size() > 0 and t - _hits[0] > HIT_WINDOW:
		_hits.remove_at(0)
	if _hits.size() >= HITS_TO_CLOSE and state == "drift":
		_close()


func _close() -> void:
	state = "closed"
	state_t = CLOSED_TIME
	_stored = 0.0
	_hits.clear()
	tint = Color(1.5, 1.5, 1.3)
	squash = Vector2(1.2, 0.8)
	Sfx.play("shield", 0.1, -4.0)
	Game.world.ring(hit_center(), 14.0, Color("e8fff0"), 0.25, 2.0)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	_spit_t -= delta
	air = 8.0 + sin(t * 2.2 + phase) * 2.5
	var to_p := _to_player()
	match state:
		"drift":
			if _spit_t <= 0.0 and to_p.length() < 150.0:
				_spit_t = randf_range(2.6, 3.4)
				_fan(to_p, 1)
			var v := to_p.normalized() * clampf((to_p.length() - 100.0) / 30.0, -1.0, 1.0)
			v += to_p.normalized().orthogonal() * sin(t * 0.6 + phase) * 0.7
			return v * speed
		"closed":
			sprite.position.x = sin(t * 30.0) * 0.6
			if state_t <= 0.0:
				sprite.position.x = 0.0
				tint = Color.WHITE
				state = "answer"
				state_t = 0.3
				alert.visible = true
			return Vector2.ZERO
		"answer":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				_fan(to_p, clampi(3 + int(_stored / maxf(max_hp * 0.15, 1.0)), 3, 7))
				state = "drift"
				_spit_t = 2.5
			return Vector2.ZERO
	return Vector2.ZERO


func _fan(to_p: Vector2, n: int) -> void:
	var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
	for i in n:
		var a := (i - (n - 1) * 0.5) * 0.22
		Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d.rotated(a) * PEARL_SPEED, contact_damage * 0.65, "pearl")
	Sfx.play("spit", 0.15, -6.0 if n > 1 else -10.0)
	squash = Vector2(1.15, 0.9)


func _anim_name() -> String:
	return "attack" if state in ["answer", "closed"] else "walk"


func _on_death() -> void:
	tint = Color.WHITE
	Game.world.burst(hit_center(), Color("c8ff3a"), 12, 70.0, 0.45, 2.5, 50.0)
	Sfx.play("pop", 0.15, -4.0)
