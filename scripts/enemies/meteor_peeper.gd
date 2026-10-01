extends Enemy
## METEOR PEEPER SAUCER (world 4): a one-eyed green alien in a saucer built from space rock.
## It hovers round you at mid range and lobs a flaming METEOR at where you are going
## ("attack", EnemyShot style "peeper"); the meteor bursts into a ring of rocks when it
## gets there (its life is timed to the distance), so dodge the spot, not just the meteor.
## Blows up into rocks and fire (the set's "death", played once).

const ORBIT := 100.0
const AIM_TIME := 0.6
const METEOR_SPEED := 80.0
const LEAD := 0.5

var _turn := 1.0


func _init_ai() -> void:
	state = "hover"
	state_t = randf_range(1.6, 2.6)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 9.0 + sin(t * 2.5 + phase) * 2.5
	var to_p := _to_player()
	match state:
		"hover":
			if state_t <= 0.0:
				state = "aim"
				state_t = AIM_TIME
				alert.visible = true
				Sfx.play("charge", 0.2, -12.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.8
			v += to_p.normalized() * clampf((to_p.length() - ORBIT) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"aim":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				_lob()
				state = "hover"
				state_t = randf_range(2.4, 3.2)
				if randf() < 0.4:
					_turn = -_turn
			return Vector2.ZERO
	return Vector2.ZERO


func _lob() -> void:
	var p := player()
	var from := hit_center() + Vector2(face * 10.0, 4.0)
	var target := p.global_position + Vector2(0, Player.BODY_Y) + p.velocity * LEAD
	var d := target - from
	var s := Game.world.spawn_enemy_shot(from, d.normalized() * METEOR_SPEED, contact_damage * 0.9, "peeper")
	s.life = clampf(d.length() / METEOR_SPEED, 0.4, 2.5)
	Game.world.telegraph_circle(target, 20.0, s.life)
	Game.world.burst(from, Color("ff8a2a"), 6, 50.0, 0.25, 2.0, 0.0, d.normalized(), 0.5)
	Sfx.play("spit", 0.1, -6.0)
	squash = Vector2(1.15, 0.9)


func _anim_name() -> String:
	return "attack" if state == "aim" else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "meteor_peeper", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff8a2a"), 12, 90.0, 0.4, 2.5)
	Sfx.play("explode", 0.2, -10.0)
