extends Enemy
## ORBIT TADPOLE SAUCER (world 4): a dark tadpole in a saucer. It blows bubbles one by one
## that ORBIT round it ("attack", EnemyShot style "tadpole" held in place each frame): a
## spinning ring that hurts if you touch it, so getting close is costly. With the ring
## full it FLINGS them all at once, each at where you are going, then starts again.
## While it holds bubbles it keeps its distance; empty, it comes closer to load up.
## If it dies the held bubbles fly off outwards. Melts into a teal puddle (the set's "splat").

const ORBIT_R := 22.0
const SPIN := 2.6
const MAX_BUBBLES := 4
const BLOW_EVERY := 0.6
const FLING_SPEED := 120.0
const KEEP := 95.0

var _held: Array[EnemyShot] = []
var _blow_t := 1.0
var _spin := 0.0
var _turn := 1.0


func _init_ai() -> void:
	state = "load"
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	_blow_t -= delta
	air = 8.0 + sin(t * 2.4 + phase) * 2.0
	_spin += delta * SPIN * _turn
	var to_p := _to_player()
	_hold_bubbles()
	match state:
		"load":
			if _blow_t <= 0.0:
				_blow_t = BLOW_EVERY
				_blow()
				if _held.size() >= MAX_BUBBLES:
					state = "aim"
					state_t = 0.5
					alert.visible = true
			var want := KEEP * (0.6 + 0.4 * _held.size() / float(MAX_BUBBLES))
			var v := to_p.normalized().orthogonal() * _turn * 0.7
			v += to_p.normalized() * clampf((to_p.length() - want) / 25.0, -1.0, 1.0)
			return v.normalized() * speed
		"aim":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				_fling()
				state = "load"
				_blow_t = 1.2
			return Vector2.ZERO
	return Vector2.ZERO


func _blow() -> void:
	var s := Game.world.spawn_enemy_shot(hit_center(), Vector2.ZERO, contact_damage * 0.6, "tadpole")
	s.life = 30.0
	_held.append(s)
	squash = Vector2(0.9, 1.1)
	Sfx.play("pop", 0.3, -12.0)


## Keeps the held bubbles spinning round the saucer (drops any that popped).
func _hold_bubbles() -> void:
	var i := 0
	while i < _held.size():
		if not is_instance_valid(_held[i]):
			_held.remove_at(i)
			continue
		i += 1
	var c := hit_center()
	for k in _held.size():
		var b := _held[k]
		b.vel = Vector2.ZERO
		b.global_position = c + Vector2.from_angle(_spin + TAU * k / maxf(_held.size(), 1.0)) * Vector2(ORBIT_R, ORBIT_R * 0.8)


## All the bubbles at once, each aimed a little differently at where you are going.
func _fling() -> void:
	var p := player()
	var target := p.global_position + Vector2(0, Player.BODY_Y) + p.velocity * 0.35
	for k in _held.size():
		var b := _held[k]
		var d := (target - b.global_position).normalized().rotated((k - (_held.size() - 1) * 0.5) * 0.12)
		b.vel = d * FLING_SPEED
		b.life = 3.0
	_held.clear()
	Sfx.play("spit", 0.1, -4.0)
	squash = Vector2(1.2, 0.85)


func _anim_name() -> String:
	return "attack" if state == "aim" or _blow_t > BLOW_EVERY - 0.2 else "walk"


func _on_death() -> void:
	var c := hit_center()
	for b in _held:
		if is_instance_valid(b):
			b.vel = (b.global_position - c).normalized() * FLING_SPEED * 0.7
			b.life = 2.0
	_held.clear()
	Game.world.burst(c, Color("5fe6ff"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
