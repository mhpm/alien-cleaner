extends Enemy
## RING-EYE SHUTTLE (world 4): a blue one-eyed shuttle, the horde's SNIPER. It keeps far
## away and, every few seconds, STARES at you: a thin aim line follows you for a moment
## ("attack"), then locks (it flashes) and it fires one very fast orb along it
## (EnemyShot style "ring_eye"). Once locked it can't turn: step off the line. Getting
## close makes it flee. Bursts and melts into a blue puddle with its eye (the set's "splat").

const RANGE := 160.0
const TRACK_TIME := 1.0
const LOCK_TIME := 0.25
const SHOT_SPEED := 260.0

var _turn := 1.0
var _line: Line2D


func _init_ai() -> void:
	state = "drift"
	state_t = randf_range(2.0, 3.0)
	_turn = 1.0 if randf() < 0.5 else -1.0
	_line = Line2D.new()
	_line.width = 1.5
	_line.top_level = true
	_line.z_index = 4
	_line.visible = false
	add_child(_line)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 10.0 + sin(t * 2.4 + phase) * 2.5
	var to_p := _to_player()
	match state:
		"drift":
			if state_t <= 0.0 and to_p.length() < RANGE * 1.5:
				state = "track"
				state_t = TRACK_TIME
				alert.visible = true
				_line.visible = true
				Sfx.play("charge", 0.0, -10.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.6
			v += to_p.normalized() * clampf((to_p.length() - RANGE) / 25.0, -1.6, 1.0)
			return v.normalized() * speed
		"track", "lock":
			if state == "track":
				aim = (to_p + Vector2(0, Player.BODY_Y)).normalized()
				face = signf(aim.x) if aim.x != 0.0 else face
				_draw_line(Color(0.4, 0.85, 1.0, 0.35 + 0.3 * sin(t * 30.0)))
				if state_t <= 0.0:
					state = "lock"
					state_t = LOCK_TIME
					Sfx.play("alert", 0.0, -6.0)
			else:
				_draw_line(Color(1.0, 1.0, 1.0, 0.9))
				if state_t <= 0.0:
					alert.visible = false
					_line.visible = false
					var from := hit_center() + aim * 12.0
					Game.world.spawn_enemy_shot(from, aim * SHOT_SPEED, contact_damage * 1.3, "ring_eye")
					Game.world.burst(from, Color("5fd0ff"), 8, 70.0, 0.25, 2.0, 0.0, aim, 0.4)
					Sfx.play("zap", 0.0, -2.0)
					squash = Vector2(0.8, 1.1)
					state = "drift"
					state_t = randf_range(2.6, 3.4)
					if randf() < 0.4:
						_turn = -_turn
			return Vector2.ZERO
	return Vector2.ZERO


func _draw_line(c: Color) -> void:
	var a := hit_center() + aim * 12.0
	_line.points = PackedVector2Array([a, a + aim * 320.0])
	_line.default_color = c


func _anim_name() -> String:
	return "attack" if state in ["track", "lock"] else "walk"


func _on_death() -> void:
	_line.visible = false
	Game.world.burst(hit_center(), Color("5fd0ff"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
