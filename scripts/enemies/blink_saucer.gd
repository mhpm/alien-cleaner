extends Enemy
## ASTRO BLINK SAUCER (world 4): a sly green alien in a pink saucer that WATCHES YOUR
## SHOTS. When one of your bullets is about to hit it, it BLINKS out of the way (a quick
## sidestep, then it can't dodge again for DODGE_CD), so shooting it from afar is a
## waste: get closer (less time to react), fire right after it has dodged, or let the
## spread / piercing shots catch it. It fires bursts of 3 pink bubbles ("attack",
## EnemyShot style "blink").
## Gets dented and falls apart into pieces (the set's "death", played once).

const ORBIT := 105.0
const DODGE_CD := 1.6
const DODGE_DIST := 34.0
const SEE_R := 60.0  # how close a bullet has to be for it to notice
const AIM_TIME := 0.5
const BURST := 3
const BURST_GAP := 0.14
const SHOT_SPEED := 110.0

var _dodge_cd := 0.0
var _left := 0
var _turn := 1.0


func _init_ai() -> void:
	state = "hover"
	state_t = randf_range(1.6, 2.6)
	_turn = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	_dodge_cd -= delta
	air = 9.0 + sin(t * 3.0 + phase) * 2.0
	var to_p := _to_player()
	if _dodge_cd <= 0.0:
		_watch_bullets()
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
				state = "burst"
				state_t = 0.0
				_left = BURST
			return Vector2.ZERO
		"burst":
			if state_t <= 0.0:
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * SHOT_SPEED, contact_damage * 0.6, "blink")
				Sfx.play("pop", 0.3, -10.0)
				_left -= 1
				state_t = BURST_GAP
				if _left <= 0:
					state = "hover"
					state_t = randf_range(2.2, 3.0)
			return Vector2.ZERO
	return Vector2.ZERO


## A bullet heading this way and close: sidestep it.
func _watch_bullets() -> void:
	var c := hit_center()
	for n in Game.world.effects.get_children():
		var b := n as Bullet
		if b == null:
			continue
		var off := c - b.global_position
		if off.length() > SEE_R or b.dir.dot(off.normalized()) < 0.85:
			continue
		var side := b.dir.orthogonal()
		if side.dot(off) < 0.0:
			side = -side  # dodge away from the bullet's line
		_blink(side)
		return


func _blink(side: Vector2) -> void:
	_dodge_cd = DODGE_CD
	var w := Game.world
	w.burst(hit_center(), Color("6fffc0"), 8, 50.0, 0.25, 2.0)
	var b := w.room.bounds().grow(-14.0)
	global_position = (global_position + side * DODGE_DIST).clamp(b.position, b.end)
	w.ring(hit_center(), 12.0, Color("ff6fc8"), 0.2, 2.0)
	squash = Vector2(1.3, 0.75)
	Sfx.play("dash", 0.3, -10.0)


func _anim_name() -> String:
	return "attack" if state in ["aim", "burst"] else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "blink_saucer", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff6fc8"), 12, 80.0, 0.4, 2.5)
	Sfx.play("explode", 0.2, -10.0)
