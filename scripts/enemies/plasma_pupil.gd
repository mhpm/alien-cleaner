extends Enemy
## PLASMA PUPIL HOPPER (world 4): a floating eyeball pod with jets. It reads where you are
## going and HOPS INTO YOUR PATH: its jets flare, it vanishes, a pink ring marks the spot
## ahead of you where it will pop out, and it reappears there already aiming, firing a
## fan of 3 plasma balls at you ("attack", EnemyShot style "pupil"). Standing still makes
## it hop beside you instead. Then it backs off to recharge.
## Its shell cracks and the eye melts into a puddle (the set's "splat").

const HOP_EVERY := 3.2
const OUT_TIME := 0.35
const MARK_TIME := 0.55
const AHEAD := 70.0
const PLASMA_SPEED := 105.0

var _target := Vector2.ZERO


func _init_ai() -> void:
	state = "drift"
	state_t = randf_range(1.5, HOP_EVERY)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 9.0 + sin(t * 3.0 + phase) * 2.0
	var to_p := _to_player()
	match state:
		"drift":
			if state_t <= 0.0:
				state = "out"
				state_t = OUT_TIME
				Game.world.burst(global_position + Vector2(0, -air * 0.5), Color("ff4fd8"), 10, 60.0, 0.3, 2.0, 0.0, Vector2.DOWN, 0.6)
				Sfx.play("dash", 0.2, -8.0)
				return Vector2.ZERO
			var v := to_p.normalized() * clampf((to_p.length() - 110.0) / 30.0, -1.0, 1.0)
			v += to_p.normalized().orthogonal() * 0.5
			return v.normalized() * speed * 0.8
		"out":
			sprite.modulate.a = clampf(state_t / OUT_TIME, 0.0, 1.0)
			if state_t <= 0.0:
				_pick_spot()
				state = "marked"
				state_t = MARK_TIME
				targetable = false
			return Vector2.ZERO
		"marked":
			if state_t <= 0.0:
				global_position = _target
				targetable = true
				sprite.modulate.a = 1.0
				squash = Vector2(1.3, 0.75)
				Game.world.ring(hit_center(), 14.0, Color("ff4fd8"), 0.25, 2.0)
				state = "fire"
				state_t = 0.25
			return Vector2.ZERO
		"fire":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				for a: float in [-0.25, 0.0, 0.25]:
					Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d.rotated(a) * PLASMA_SPEED, contact_damage * 0.6, "pupil")
				Sfx.play("zap", 0.15, -6.0)
				state = "drift"
				state_t = HOP_EVERY
			return Vector2.ZERO
	return Vector2.ZERO


## Where you will be in a moment, a little to the side so it doesn't land on you.
func _pick_spot() -> void:
	var p := player()
	var dir := p.velocity.normalized() if p.velocity.length() > 10.0 else Vector2.from_angle(randf() * TAU)
	var side := dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	_target = p.global_position + dir * AHEAD + side * 25.0
	var b := Game.world.room.bounds().grow(-14.0)
	_target = _target.clamp(b.position, b.end)
	var tg := Telegraph.new()
	tg.position = _target
	tg.radius = 12.0
	tg.dur = MARK_TIME
	tg.color = Color("ff4fd8")
	Game.world.decals.add_child(tg)


func _contact() -> void:
	if state in ["out", "marked"]:
		return  # gone in the hop
	super._contact()


func _anim_name() -> String:
	return "attack" if state in ["fire", "out"] else "walk"


func _on_death() -> void:
	sprite.modulate.a = 1.0
	Game.world.burst(hit_center(), Color("ff4fd8"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
