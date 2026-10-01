extends Enemy
## BUBBLE TENTACLE POD (world 4): a one-eyed jelly in a dome on blue tentacles. Its eye
## glows ("attack") and it blows ONE BIG BUBBLE that drifts after you, slowly turning to
## follow (EnemyShot style "pod_big", "home"). Leave it be and it BURSTS into a ring of
## 8 little bubbles after a few seconds; let it touch you and it just pops. So: keep it
## at a distance or kill the pod. The pod itself hides behind other aliens when it can.
## Melts into a pink puddle (the set's "splat").

const BLOW_EVERY := 3.8
const CHARGE := 0.7
const BIG_SPEED := 38.0
const BIG_LIFE := 4.0


func _init_ai() -> void:
	state = "drift"
	state_t = randf_range(1.5, BLOW_EVERY)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 7.0 + sin(t * 1.6 + phase) * 3.0
	var to_p := _to_player()
	match state:
		"drift":
			if state_t <= 0.0:
				state = "charge"
				state_t = CHARGE
				alert.visible = true
				Sfx.play("charge", 0.2, -10.0)
				return Vector2.ZERO
			return _cover(to_p) * speed
		"charge":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			squash = Vector2.ONE * (1.0 + (CHARGE - state_t) * 0.25)
			if state_t <= 0.0:
				alert.visible = false
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				var s := Game.world.spawn_enemy_shot(hit_center() + d * 14.0, d * BIG_SPEED, contact_damage, "pod_big")
				s.life = BIG_LIFE
				Sfx.play("pop", 0.0, -2.0)
				squash = Vector2(0.8, 1.2)
				state = "drift"
				state_t = BLOW_EVERY
			return Vector2.ZERO
	return Vector2.ZERO


## Keeps ~120 away and slides behind the nearest other alien (between it and you).
func _cover(to_p: Vector2) -> Vector2:
	var p := player().global_position
	var best: Enemy = null
	var bd := 90.0
	for n in Game.world.enemy_cache:
		var e := n as Enemy
		if e == self or not is_instance_valid(e) or e.dead:
			continue
		var d := e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	var want: Vector2
	if best != null:
		want = best.global_position + (best.global_position - p).normalized() * 26.0
	else:
		want = p - to_p.normalized() * 120.0
	var v := want - global_position
	return v.normalized() if v.length() > 6.0 else Vector2.ZERO


func _anim_name() -> String:
	return "attack" if state == "charge" else "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("7fc8ff"), 10, 70.0, 0.45, 2.5, 40.0)
	Game.world.burst(hit_center(), Color("ff5fe0"), 8, 60.0, 0.4, 2.0)
	Sfx.play("pop", 0.15, -4.0)
