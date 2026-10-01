extends Enemy
## NOVA PUFFER SAUCER (world 4): a pink puffer in a saucer. It drifts slowly towards mid
## range; every few seconds it PUFFS UP ("attack", swelling) and lets out a NOVA: a ring
## of star bubbles that float slowly outwards (EnemyShot style "nova"), the next nova
## turned half a step so the gaps move. Killing it pops its saucer and a last, smaller
## ring of bubbles bursts out: don't finish it off point-blank. (The set's "death".)

const PUFF_TIME := 0.8
const BUBBLES := 8
const BUBBLE_SPEED := 42.0
const BUBBLE_LIFE := 4.5

var _novas := 0


func _init_ai() -> void:
	state = "drift"
	state_t = randf_range(1.6, 2.6)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 6.0 + sin(t * 2.0 + phase) * 3.0
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"drift":
			if state_t <= 0.0:
				state = "puff"
				state_t = PUFF_TIME
				alert.visible = true
				Sfx.play("charge", 0.2, -10.0)
				return Vector2.ZERO
			var v := to_p.normalized() * (1.0 if d > 95.0 else (-0.7 if d < 55.0 else 0.0))
			v += to_p.normalized().orthogonal() * sin(t * 0.7 + phase) * 0.6
			return v * speed
		"puff":
			var k := 1.0 - state_t / PUFF_TIME
			squash = Vector2.ONE * (1.0 + k * 0.25)
			if state_t <= 0.0:
				alert.visible = false
				_nova(BUBBLES, (PI / BUBBLES) * (_novas % 2))
				_novas += 1
				squash = Vector2(0.8, 0.8)
				state = "drift"
				state_t = randf_range(2.4, 3.4)
			return Vector2.ZERO
	return Vector2.ZERO


func _nova(n: int, off: float, dmg_k := 0.8, spd := BUBBLE_SPEED) -> void:
	var c := hit_center()
	for i in n:
		var dir := Vector2.from_angle(off + TAU * i / n)
		var s := Game.world.spawn_enemy_shot(c + dir * 10.0, dir * spd, contact_damage * dmg_k, "nova")
		s.life = BUBBLE_LIFE
	Game.world.ring(c, 16.0, Color("ff4fd8"), 0.3, 2.0)
	Sfx.play("pop", 0.1, -4.0)


func _anim_name() -> String:
	return "attack" if state == "puff" else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "nova_puffer", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff4fd8"), 12, 80.0, 0.45, 2.5, 60.0)
	_nova(5, randf() * TAU, 0.6, BUBBLE_SPEED * 0.8)
