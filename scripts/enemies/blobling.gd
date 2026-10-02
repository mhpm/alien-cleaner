class_name Blobling
extends Enemy
## BLOBLING: one of the little floating eyes BLOBULUS splits into. It circles the astronaut at
## a distance and every few seconds blinks (a lane marks where it aims) and darts at them. If
## it is still alive when the brood is called back it flies to its parent and MERGES, healing
## it (`reunite`), so kill them before that.

const ORBIT_R := 62.0
const DART_SPEED := 200.0
const DART_TIME := 0.38
const WIND_TIME := 0.55

var boss: Enemy  # the parent it goes back to
var heal_share := 0.03
var _dir := 1.0
var _dart_v := Vector2.ZERO
var _wait := 0.0


func _init_ai() -> void:
	state = "orbit"
	_dir = 1.0 if randf() < 0.5 else -1.0
	_wait = randf_range(1.6, 3.2)
	air = 2.5


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 2.5 + sin(t * 4.0 + phase) * 1.4  # bobbing, but low enough to touch (Enemy._contact skips air > 4)
	var to_p := _to_player()
	match state:
		"orbit":
			_wait -= delta
			if _wait <= 0.0:
				state = "wind"
				state_t = WIND_TIME
				_dart_v = (to_p + player().velocity * 0.3).normalized() * DART_SPEED
				alert.visible = true
				Game.world.telegraph_line(global_position, _dart_v.normalized(), DART_SPEED * DART_TIME + 10.0, 10.0, WIND_TIME)
				Sfx.play("alert", 0.4, -10.0)
				return Vector2.ZERO
			# round the astronaut, drifting in or out to keep its distance
			var want := to_p.normalized().orthogonal() * _dir + to_p.normalized() * clampf((to_p.length() - ORBIT_R) / 40.0, -1.0, 1.0)
			return want.normalized() * speed
		"wind":
			squash = Vector2(1.0 + sin(t * 40.0) * 0.06, 1.0)
			if state_t <= 0.0:
				state = "dart"
				state_t = DART_TIME
				alert.visible = false
				Sfx.play("dash", 0.6, -10.0)
			return Vector2.ZERO
		"dart":
			if state_t <= 0.0:
				state = "orbit"
				_wait = randf_range(2.0, 3.6)
				_dir = -_dir
			return _dart_v
		"return":
			if not is_instance_valid(boss) or boss.dead:
				state = "orbit"
				return Vector2.ZERO
			var d := boss.hit_center() - global_position
			if d.length() < 14.0:
				_merge()
				return Vector2.ZERO
			return d.normalized() * 190.0
	return Vector2.ZERO


## Called by the parent when the brood is called back.
func reunite() -> void:
	state = "return"
	alert.visible = false
	Game.world.ring(global_position, 12.0, Color("5fd0ff"), 0.3, 1.5)


func _merge() -> void:
	if boss.has_method("heal"):
		boss.call("heal", boss.max_hp * heal_share)
	Game.world.burst(global_position, Color("5fd0ff"), 8, 50.0, 0.3, 2.0)
	dead = true
	remove_from_group("enemies")  # no XP, no coins: it just goes back
	queue_free()


func _contact() -> void:
	if state == "return":
		return
	super._contact()
