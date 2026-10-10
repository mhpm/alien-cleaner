extends Enemy
## PLASMA SAW DRONE (world 7): a drone with two plasma saws spinning at its sides. It
## closes in fast and throws a PINCER: both saws fly out to either side of you and hang
## there spinning, a line marks the cut between them, and PINCER_WAIT later they slam
## shut towards each other through where the line was, then fly back home. Step off the
## line (forwards or back). Without its saws it is slower and only rams. Breaks apart
## into saws and scrap (the set's "death").

const CLOSE := 80.0
const SPREAD := 62.0  # each saw this far to the side of the astronaut
const FLY_TIME := 0.35
const PINCER_WAIT := 0.75
const SLAM_SPEED := 260.0
const SAW_HIT := 9.0

var _saws: Array[Sprite2D] = []
var _ends: Array[Vector2] = []
var _hit := false
var _turn := 1.0


func _init_ai() -> void:
	state = "chase"
	state_t = randf_range(1.8, 2.8)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 8.0 + sin(t * 4.0 + phase) * 2.0
	var to_p := _to_player()
	match state:
		"chase":
			if state_t <= 0.0 and to_p.length() < CLOSE * 1.6:
				_throw(to_p)
				return Vector2.ZERO
			var v := to_p.normalized() + to_p.normalized().orthogonal() * _turn * 0.35
			return v.normalized() * speed * 1.2
		"thrown":
			for i in _saws.size():
				_saws[i].rotation += delta * 18.0
			if state_t <= 0.0:
				state = "slam"
				state_t = (_ends[0].distance_to(_ends[1]) * 0.5) / SLAM_SPEED
				_hit = false
				Sfx.play("slash", 0.1, -4.0)
			return -to_p.normalized() * speed * 0.4
		"slam":
			_slam(delta)
			if state_t <= 0.0:
				_recall()
			return Vector2.ZERO
		"bare":
			if state_t <= 0.0:
				_home()
			return to_p.normalized() * speed * 0.8
	return Vector2.ZERO


## Both saws fly out to either side of the astronaut, across the line to the drone.
func _throw(to_p: Vector2) -> void:
	var w := Game.world
	var c := player().global_position + Vector2(0, Player.BODY_Y)
	var side := to_p.normalized().orthogonal()
	_ends = [w.room.open_near(c + side * SPREAD), w.room.open_near(c - side * SPREAD)]
	for i in 2:
		var s := Sprite2D.new()
		s.texture = Art.frames("plasma_saw").get_frame_texture("fly", 0)
		s.scale = Vector2.ONE * 0.26
		s.global_position = hit_center()
		s.z_index = 3
		w.effects.add_child(s)
		s.create_tween().tween_property(s, "global_position", _ends[i], FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_saws.append(s)
	w.telegraph_line(_ends[0], (_ends[1] - _ends[0]).normalized(), _ends[0].distance_to(_ends[1]), 14.0, FLY_TIME + PINCER_WAIT)
	state = "thrown"
	state_t = FLY_TIME + PINCER_WAIT
	alert.visible = true
	Sfx.play("dash", 0.2, -6.0)


## The saws race to the middle of the line; hurts once if the astronaut is on it.
func _slam(delta: float) -> void:
	var mid := (_ends[0] + _ends[1]) * 0.5
	var p := player()
	for s in _saws:
		if not is_instance_valid(s):
			continue
		s.rotation += delta * 24.0
		s.global_position = s.global_position.move_toward(mid, SLAM_SPEED * delta)
		var c := p.global_position + Vector2(0, Player.BODY_Y)
		if not _hit and not p.dead and s.global_position.distance_to(c) < SAW_HIT + 6.0:
			_hit = true
			p.take_damage(contact_damage * 1.3, s.global_position)
			Game.world.burst(c, Color("ff4fd8"), 10, 70.0, 0.25, 2.0)
	if state_t <= 0.0:
		Game.world.burst(mid, Color("ff4fd8"), 14, 90.0, 0.3, 2.0)
		Game.world.shake(0.15)


## The saws fly back; until they are home it only rams.
func _recall() -> void:
	alert.visible = false
	state = "bare"
	state_t = 0.6
	for s in _saws:
		if is_instance_valid(s):
			var tw := s.create_tween()
			tw.tween_property(s, "global_position", hit_center(), 0.5)
			tw.tween_callback(s.queue_free)
	_saws.clear()


func _home() -> void:
	state = "chase"
	state_t = randf_range(2.2, 3.0)
	if randf() < 0.5:
		_turn = -_turn


func _anim_name() -> String:
	return "attack" if state in ["thrown", "slam"] else "walk"


func _on_death() -> void:
	for s in _saws:
		if is_instance_valid(s):
			s.queue_free()
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "saw_drone", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff4fd8"), 12, 90.0, 0.4, 2.0)
	Sfx.play("explode", 0.2, -10.0)
