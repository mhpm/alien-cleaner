extends Enemy
## UFO GUNSHIP (world 4): a big purple saucer with a side cannon. It hovers at mid range,
## sliding round you, and takes turns between:
##  - a CANNON BURST: turns its cannon on you, the barrel glows ("charge"), then it fires
##    a burst of 3 plasma balls ("fire"; EnemyShot style "gunship"), recoiling a little;
##  - a RAM: tilts and lights its jets ("boost"), a line on the floor shows where it will
##    go, then it rams through that line, hurting you if you are on it.
## Tough and slow to turn. Blows up into a burning wreck (the set's "splat").

const CHARGE_TIME := 0.8
const BURST := 3
const BURST_GAP := 0.14
const SHOT_SPEED := 95.0
const RAM_WARN := 0.7
const RAM_SPEED := 190.0
const RAM_TIME := 0.55
const HOVER := 12.0

var _attacks := 0
var _shots := 0
var _ram_dir := Vector2.RIGHT
var _rammed := false


func _init_ai() -> void:
	state = "move"
	state_t = randf_range(1.6, 2.6)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = HOVER + sin(t * 2.0 + phase) * 2.5
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"move":
			if state_t <= 0.0:
				_attacks += 1
				if _attacks % 3 == 0 and d < 150.0:
					_start_ram(to_p)
				else:
					state = "charge"
					state_t = CHARGE_TIME
					alert.visible = true
					Sfx.play("charge", 0.1, -10.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * (1.0 if sin(t * 0.4 + phase) > 0.0 else -1.0)
			if d < 80.0:
				v -= to_p.normalized() * 1.2
			elif d > 125.0:
				v += to_p.normalized()
			return v.normalized() * speed
		"charge":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if randf() < 0.6:  # energy gathers in the barrel
				var m := _muzzle()
				var p := m + Vector2.from_angle(randf() * TAU) * 9.0
				Game.world.burst(p, Color("ff4fd8"), 1, 25.0, 0.2, 1.5, 0.0, (m - p).normalized(), 0.2)
			if state_t <= 0.0:
				alert.visible = false
				state = "fire"
				state_t = 0.0
				_shots = 0
			return Vector2.ZERO
		"fire":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				_fire()
				_shots += 1
				state_t = BURST_GAP
				if _shots >= BURST:
					state = "move"
					state_t = randf_range(1.8, 2.8)
			return -to_p.normalized() * 10.0  # recoil
		"ram_warn":
			face = signf(_ram_dir.x) if _ram_dir.x != 0.0 else face
			if randf() < 0.5:
				Game.world.burst(global_position - _ram_dir * 12.0 + Vector2(0, -air), Color("ff4fd8"), 1, 40.0, 0.25, 2.0, 0.0, -_ram_dir, 0.4)
			if state_t <= 0.0:
				state = "boost"
				state_t = RAM_TIME
				_rammed = false
				Sfx.play("dash", 0.1, -4.0)
			return -_ram_dir * 12.0  # backs up before the dash
		"boost":
			if not _rammed:
				var p := player()
				if not p.dead and p.global_position.distance_to(global_position) < radius + 8.0:
					_rammed = true
					p.take_damage(contact_damage * 1.3, global_position)
					p.knock += _ram_dir * 140.0
					Game.world.shake(0.3)
			if randf() < 0.7:
				Game.world.burst(global_position - _ram_dir * 14.0 + Vector2(0, -air), Color("ff4fd8"), 2, 30.0, 0.3, 2.0)
			if state_t <= 0.0 or hit_wall:
				state = "move"
				state_t = randf_range(1.6, 2.4)
				squash = Vector2(1.2, 0.85)
			return _ram_dir * RAM_SPEED
	return Vector2.ZERO


func _start_ram(to_p: Vector2) -> void:
	_ram_dir = to_p.normalized()
	state = "ram_warn"
	state_t = RAM_WARN
	alert.visible = false
	Game.world.telegraph_line(global_position, _ram_dir, RAM_SPEED * RAM_TIME + 10.0, radius * 2.0, RAM_WARN + 0.1)
	Sfx.play("alert", 0.1, -6.0)


## The cannon's barrel tip (the art faces right; flipped when facing left).
func _muzzle() -> Vector2:
	return hit_center() + Vector2(face * tex_h * base_scale * 0.5, 4.0)


func _fire() -> void:
	var from := _muzzle()
	var dir := ((player().global_position + Vector2(0, Player.BODY_Y)) - from).normalized()
	dir = dir.rotated(randf_range(-0.08, 0.08))
	Game.world.spawn_enemy_shot(from, dir * SHOT_SPEED, contact_damage * 0.8, "gunship")
	Game.world.burst(from, Color("ff4fd8"), 4, 50.0, 0.2, 2.0, 0.0, dir, 0.5)
	Sfx.play("zap", 0.15, -7.0)
	squash = Vector2(1.1, 0.92)


func _anim_name() -> String:
	match state:
		"charge":
			return "charge"
		"fire":
			return "fire"
		"ram_warn", "boost":
			return "boost"
	return "walk"


func _on_death() -> void:
	var w := Game.world
	var c := hit_center()
	w.burst(c, Color("ff4fd8"), 16, 110.0, 0.5, 3.0)
	w.burst(c, Color("ffcd75"), 12, 90.0, 0.4, 2.5)
	w.ring(c, 18.0, Color("ff4fd8"), 0.3, 3.0)
	w.shake(0.35)
	Sfx.play("explode", 0.1, -6.0)
