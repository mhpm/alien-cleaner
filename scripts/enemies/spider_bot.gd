extends Enemy
## QUANTUM SPIDER BOT (world 7): a little walker with antennae that skitters at you in
## quick zigzag bursts. Its trick is a QUANTUM ANCHOR: it fires a green plasma orb that
## lands next to where you are heading and stays there, ringed by a marked circle;
## ANCHOR_TIME later the spider swaps places with it (vanishes, reappears on the anchor)
## and blasts a ring of plasma from there. Keep clear of planted anchors, and shoot the
## spider before the swap. Breaks apart in smoke and green sparks (the set's "death").

const BURST_SPEED := 1.9  # times its speed while skittering
const RANGE := 95.0
const ANCHOR_TIME := 1.3
const ANCHOR_R := 26.0
const LEAD := 0.6  # seconds ahead of the astronaut the anchor lands
const RING := 7
const RING_SPEED := 78.0

var _zig := 1.0
var _anchor := Vector2.ZERO
var _orb: EnemyShot


func _init_ai() -> void:
	state = "skitter"
	state_t = randf_range(0.4, 0.8)
	_zig = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	var d := to_p.normalized()
	match state:
		"skitter":
			if state_t <= 0.0:
				state = "pause"
				state_t = randf_range(0.25, 0.45)
				_zig = -_zig
			return (d + d.orthogonal() * _zig * 0.8).normalized() * speed * BURST_SPEED
		"pause":
			if state_t <= 0.0:
				if to_p.length() < RANGE * 1.6 and randf() < 0.55:
					_plant(to_p)
				else:
					state = "skitter"
					state_t = randf_range(0.4, 0.8)
			return Vector2.ZERO
		"aim":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				_swap()
			return Vector2.ZERO
	return Vector2.ZERO


## The anchor: a slow orb that flies to just ahead of the astronaut and stops there.
func _plant(to_p: Vector2) -> void:
	var w := Game.world
	var p := player()
	_anchor = w.room.open_near(p.global_position + p.velocity * LEAD + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
	var from := hit_center()
	var go := _anchor - from
	_orb = w.spawn_enemy_shot(from, Vector2.ZERO, contact_damage * 0.5, "spider")
	_orb.vel = go / 0.35  # lands in 0.35 s, whatever the world's shot speed
	_orb.life = ANCHOR_TIME + 0.3
	get_tree().create_timer(0.35, false).timeout.connect(_stop_orb)
	w.telegraph_circle(_anchor, ANCHOR_R, ANCHOR_TIME)
	state = "aim"
	state_t = ANCHOR_TIME
	alert.visible = true
	Sfx.play("spit", 0.2, -6.0)


func _stop_orb() -> void:
	if is_instance_valid(_orb):
		_orb.vel = Vector2.ZERO
		_orb.global_position = _anchor + Vector2(0, -6)


## Swaps places with the anchor and blasts a ring of plasma there.
func _swap() -> void:
	alert.visible = false
	var w := Game.world
	if is_instance_valid(_orb):
		_orb.queue_free()
	w.burst(hit_center(), Color("a7f070"), 10, 60.0, 0.3, 2.0)
	global_position = w.room.open_near(_anchor)
	w.burst(hit_center(), Color("a7f070"), 16, 90.0, 0.35, 2.5)
	w.ring(global_position, ANCHOR_R, Color("a7f070"), 0.3, 3.0)
	var p := player()
	var off := p.global_position - global_position
	if not p.dead and Vector2(off.x, off.y / 0.75).length() < ANCHOR_R:
		p.take_damage(contact_damage * 1.1, global_position)
	var a0 := randf() * TAU
	for i in RING:
		var dir := Vector2.from_angle(a0 + TAU * i / RING)
		w.spawn_enemy_shot(hit_center() + dir * 8.0, dir * RING_SPEED, contact_damage * 0.55, "spider").life = 2.5
	Sfx.play("zap", 0.2, -4.0)
	squash = Vector2(1.3, 0.7)
	state = "skitter"
	state_t = randf_range(0.5, 0.9)


func _anim_name() -> String:
	return "attack" if state == "aim" else "walk"


func _on_death() -> void:
	if is_instance_valid(_orb):
		_orb.queue_free()
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "spider_bot", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("a7f070"), 12, 90.0, 0.4, 2.0)
	Sfx.play("explode", 0.2, -10.0)
