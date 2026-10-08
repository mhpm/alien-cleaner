extends Enemy
## ALIEN TROOPER (worlds 1-2): the little green martian with the pink plasma gun, the
## horde's infantry. Walks at mid range strafing around you with the gun up ("walk" =
## walk-and-shoot cycle). Every few seconds it plants its feet and AIMS WHERE YOU ARE
## GOING (your velocity × `LEAD`): a firing lane locks on that spot while the gun charges
## ("charge"), then it fires a BURST of 3 plasma orbs down the lane ("attack", muzzle flash
## and recoil). Running straight keeps you on the lane: stop or turn. When you focus it
## (`ROLL_HITS` hits within `ROLL_WINDOW` s) it DODGE-ROLLS sideways and answers with a
## quicker snap aim. Falls over and melts into a green puddle (the set's "splat").

const RANGE := 105.0
const AIM_TIME := 0.8
const SNAP_AIM := 0.5
const LEAD := 0.55
const BURST := 3
const BURST_GAP := 0.11
const SHOT_SPEED := 135.0
const LANE := 230.0
const ROLL_HITS := 2
const ROLL_WINDOW := 1.0
const ROLL_TIME := 0.32
const ROLL_SPEED := 3.2  # × walking speed
const ROLL_CD := 3.0

var _turn := 1.0
var _shots := 0
var _hits: Array[float] = []
var _roll_cd := 0.0
var _roll_dir := Vector2.ZERO


func _init_ai() -> void:
	state = "move"
	state_t = randf_range(1.6, 2.6)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	_roll_cd -= delta
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"move":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0 and d < RANGE * 2.0:
				_start_aim(AIM_TIME)
				return Vector2.ZERO
			# keep mid range and circle around, gun on you
			var v := to_p.normalized() * clampf((d - RANGE) / 30.0, -1.0, 1.0)
			v += to_p.normalized().orthogonal() * _turn * 0.75
			return v.normalized() * speed
		"roll":
			squash = Vector2(1.15, 0.8)
			if state_t <= 0.0:
				_start_aim(SNAP_AIM)
				return Vector2.ZERO
			return _roll_dir * speed * ROLL_SPEED
		"charge":
			if state_t <= 0.0:
				alert.visible = false
				state = "attack"
				state_t = 0.0
				_shots = 0
			return Vector2.ZERO
		"attack":
			if state_t <= 0.0:
				if _shots < BURST:
					_fire()
					_shots += 1
					state_t = BURST_GAP
				else:
					state = "move"
					state_t = randf_range(2.2, 3.2)
					_turn = -_turn  # sidestep the other way after the burst
	return Vector2.ZERO


## Plants and aims at where you'll be: the lane locks now, the burst follows it.
func _start_aim(dur: float) -> void:
	var p := player()
	var target := p.global_position + p.velocity * LEAD + Vector2(0, Player.BODY_Y)
	var from := _muzzle()
	aim = (target - from).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2(face, 0.0)
	face = signf(aim.x) if aim.x != 0.0 else face
	state = "charge"
	state_t = dur
	alert.visible = true
	Game.world.telegraph_line(_muzzle(), aim, LANE, 10.0, dur / aggro)
	Sfx.play("charge", 0.25, -12.0)


func _fire() -> void:
	var from := _muzzle()
	var dir := aim.rotated(randf_range(-0.05, 0.05))
	Game.world.spawn_enemy_shot(from, dir * SHOT_SPEED, contact_damage * 0.7, "trooper")
	Game.world.burst(from, Color("ff4fd8"), 5, 60.0, 0.2, 2.0, 0.0, dir, 0.5)
	Sfx.play("zap", 0.2, -8.0)
	squash = Vector2(0.88, 1.08)


## The gun's muzzle in the world (the art holds it at chest height, pointing ahead).
func _muzzle() -> Vector2:
	var h := tex_h * base_scale
	return global_position + Vector2(face * h * 0.31, -h * 0.38 - air)


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	super.take_damage(amount, dir, crit)
	if dead or state != "move" or _roll_cd > 0.0:
		return
	_hits.append(t)
	while not _hits.is_empty() and t - _hits[0] > ROLL_WINDOW:
		_hits.pop_front()
	if _hits.size() >= ROLL_HITS:
		_hits.clear()
		_roll()


## Combat roll: dives to the side (away from the line of fire), then snap-aims.
func _roll() -> void:
	var to_p := _to_player().normalized()
	_roll_dir = to_p.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	_roll_dir = (_roll_dir - to_p * 0.3).normalized()
	_roll_cd = ROLL_CD
	state = "roll"
	state_t = ROLL_TIME
	Game.world.burst(global_position, Color(0.85, 0.85, 0.8, 0.8), 6, 40.0, 0.3, 2.0)
	Sfx.play("dash", 0.2, -10.0)


func _anim_name() -> String:
	match state:
		"charge":
			return "charge"
		"attack":
			return "attack"
	return "walk"


func _on_death() -> void:
	alert.visible = false
	Game.world.burst(hit_center(), Color("a7f070"), 10, 60.0, 0.4, 2.5, 50.0)
	Sfx.play("pop", 0.1, -4.0)
