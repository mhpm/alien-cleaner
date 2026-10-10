extends Enemy
## GRAVITY CORE SENTINEL (world 7): a dark core in golden rings with little moons orbiting
## it. It hangs back behind the horde and turns the horde into its weapon: it drops a
## GRAVITY WELL (a slow dark orb that stops between you and it, marked by a ring) that
## pulls every alien around it into a clump for PULL_TIME, then bursts: the clump is flung
## AT YOU and the well spits a ring of moons. Thin out the crowd near the well or keep
## out of its line; the sentinel itself is slow and sturdy. Breaks apart (its "death").

const RANGE := 140.0
const CHARGE_TIME := 0.7
const WELL_R := 70.0  # pulls aliens within this
const PULL := 85.0
const PULL_TIME := 1.6
const FLING := 230.0
const MOONS := 8
const MOON_SPEED := 70.0
const MAX_FLUNG := 14

var _turn := 1.0
var _well: Sprite2D
var _well_at := Vector2.ZERO


func _init_ai() -> void:
	state = "float"
	state_t = randf_range(2.5, 3.5)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 10.0 + sin(t * 1.6 + phase) * 3.0
	var to_p := _to_player()
	match state:
		"float":
			if state_t <= 0.0 and to_p.length() < RANGE * 1.6:
				state = "charge"
				state_t = CHARGE_TIME
				alert.visible = true
				Sfx.play("charge", 0.0, -6.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.6
			v += to_p.normalized() * clampf((to_p.length() - RANGE) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"charge":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				_drop_well(to_p)
		"pull":
			_pull(delta)
			if state_t <= 0.0:
				_burst_well()
				state = "float"
				state_t = randf_range(3.5, 4.5)
	return Vector2.ZERO


## The well stops a little short of the astronaut, between the two.
func _drop_well(to_p: Vector2) -> void:
	var w := Game.world
	_well_at = w.room.open_near(global_position + to_p * 0.55)
	_well = Sprite2D.new()
	_well.texture = Art.frames("gravity_well").get_frame_texture("fly", 0)
	_well.position = _well_at + Vector2(0, -10)
	_well.scale = Vector2.ONE * 0.05
	_well.z_index = 3
	w.effects.add_child(_well)
	_well.create_tween().tween_property(_well, "scale", Vector2.ONE * 0.32, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	w.telegraph_circle(_well_at, WELL_R, PULL_TIME)
	state = "pull"
	state_t = PULL_TIME
	Sfx.play("grav", 0.0, -4.0)


## Every alien round the well slides into it (bosses and rooted ones stay put).
func _pull(delta: float) -> void:
	if is_instance_valid(_well):
		_well.rotation += delta * 4.0
	for e in Game.world.enemies_near(_well_at, WELL_R):
		if e == self or e.dead or e.is_boss or e.anchored:
			continue
		var d := _well_at - e.global_position
		if d.length() > 10.0 and d.length() < WELL_R:
			e.knock = d.normalized() * PULL
	if randf() < delta * 20.0:
		var a := randf() * TAU
		Game.world.burst(_well_at + Vector2.from_angle(a) * WELL_R * 0.8, Color("5fd0ff"), 1, 40.0, 0.4, 2.0, 0.0, -Vector2.from_angle(a), 0.2)


## The clump is flung at the astronaut; the well spits its moons.
func _burst_well() -> void:
	var w := Game.world
	var p := player().global_position
	var n := 0
	for e in w.enemies_near(_well_at, WELL_R * 0.7):
		if e == self or e.dead or e.is_boss or e.anchored or n >= MAX_FLUNG:
			continue
		e.knock = (p - e.global_position).normalized() * FLING
		n += 1
	var a0 := randf() * TAU
	for i in MOONS:
		var dir := Vector2.from_angle(a0 + TAU * i / MOONS)
		w.spawn_enemy_shot(_well_at + Vector2(0, -10) + dir * 8.0, dir * MOON_SPEED, contact_damage * 0.55, "gravity").life = 3.0
	w.ring(_well_at, WELL_R * 0.6, Color("5fd0ff"), 0.35, 3.0)
	w.shake(0.25)
	Sfx.play("explode", 0.3, -8.0)
	if is_instance_valid(_well):
		_well.queue_free()


func _anim_name() -> String:
	return "attack" if state in ["charge", "pull"] else "walk"


func _on_death() -> void:
	if is_instance_valid(_well):
		_well.queue_free()
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "gravity_sentinel", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("5fd0ff"), 14, 90.0, 0.4, 2.0)
	Sfx.play("explode", 0.2, -8.0)
