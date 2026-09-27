extends Enemy
## Final boss THE SLIME KING: hops, giant jump with a landing warning circle,
## slime puddles, summons, ground slam shockwave and (enraged) glob sprays.

const PATTERN := ["hop", "hop", "jump", "summon", "hop", "slam", "jump", "spray", "hop", "jump"]
const JUMP_H := 150.0
const LAND_R := 30.0
const SLAM_R := 58.0

var pattern_i := 0
var hop_dur := 0.5
var land_pos := Vector2.ZERO
var locked := false
var volleys := 0


func _ready() -> void:
	super._ready()
	# pixel crown sits between the antennae (sprite-local units = source pixels)
	var crown := Sprite2D.new()
	crown.texture = Art.tex("crown")
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.scale = Vector2(3.4, 3.4)
	crown.position = Vector2(0, -tex_h * 0.9)
	sprite.add_child(crown)


func _init_ai() -> void:
	state = "intro"
	state_t = 1.0


func _enraged() -> bool:
	return hp < max_hp * 0.5


func _tempo() -> float:
	return 0.75 if _enraged() else 1.0


func _can_target() -> bool:
	return air < 4.0


func _ai(delta: float) -> Vector2:
	state_t -= delta
	match state:
		"intro", "idle":
			if state_t <= 0.0:
				_next()
			return Vector2.ZERO
		"hop":
			var k := 1.0 - state_t / hop_dur
			air = sin(clampf(k, 0.0, 1.0) * PI) * 12.0
			if state_t <= 0.0:
				air = 0.0
				squash = Vector2(1.3, 0.7)
				Game.world.shake(0.25)
				Sfx.play("land", 0.1, -6.0)
				Game.world.burst(global_position, Color("a7f070"), 8, 50.0, 0.35, 2.0)
				state = "idle"
				state_t = 0.3 * _tempo()
			return aim * 55.0
		"jump_up":
			var k := 1.0 - state_t / 0.45
			air = k * k * JUMP_H
			if state_t <= 0.0:
				state = "airborne"
				state_t = 1.3 * _tempo()
				locked = false
			return Vector2.ZERO
		"airborne":
			air = JUMP_H
			if not locked and state_t <= 0.6:
				locked = true
				land_pos = player().global_position
				Game.world.telegraph_circle(land_pos, LAND_R, state_t + 0.25)
			if not locked:
				var to_p := _to_player()
				return to_p.normalized() * minf(140.0, to_p.length() * 6.0)
			var to_l := land_pos - global_position
			return to_l.normalized() * minf(200.0, to_l.length() * 8.0)
		"fall":
			air = JUMP_H * pow(maxf(state_t, 0.0) / 0.25, 2.0)
			if state_t <= 0.0:
				_land()
			return Vector2.ZERO
		"slam_wind":
			var k := 1.0 - state_t / (1.0 * _tempo())
			squash = Vector2(1.0 + k * 0.3, 1.0 - k * 0.2)
			sprite.position.x = sin(t * 50.0) * k
			if state_t <= 0.0:
				sprite.position.x = 0.0
				_slam()
			return Vector2.ZERO
		"summon":
			if state_t <= 0.0:
				_summon()
				state = "idle"
				state_t = 0.8 * _tempo()
			return Vector2.ZERO
		"spray":
			if state_t <= 0.0:
				_spray_volley()
				volleys -= 1
				state_t = 0.35
				if volleys <= 0:
					state = "idle"
					state_t = 0.6 * _tempo()
			return Vector2.ZERO
	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not dead:
		targetable = spawn_t <= 0.0 and air < 4.0
		# vanish off the top of the screen while airborne; the shadow is the tell
		sprite.modulate.a = clampf(1.0 - (air - 50.0) / 50.0, 0.0, 1.0)
		if state == "airborne" and state_t <= 0.0:
			state = "fall"
			state_t = 0.25


func _next() -> void:
	var step: String = PATTERN[pattern_i % PATTERN.size()]
	pattern_i += 1
	if step == "spray" and not _enraged():
		step = "hop"
	match step:
		"hop":
			state = "hop"
			hop_dur = 0.5 * _tempo()
			state_t = hop_dur
			aim = _to_player().normalized()
			squash = Vector2(0.8, 1.2)
		"jump":
			state = "jump_up"
			state_t = 0.45
			squash = Vector2(0.7, 1.35)
			Sfx.play("dash", 0.0)
		"summon":
			state = "summon"
			state_t = 0.7
			squash = Vector2(1.3, 0.8)
			Sfx.play("roar", 0.05)
			Game.world.shake(0.4)
		"slam":
			state = "slam_wind"
			state_t = 1.0 * _tempo()
			Game.world.telegraph_circle(global_position, SLAM_R, state_t)
			Sfx.play("charge", 0.0)
		"spray":
			state = "spray"
			state_t = 0.3
			volleys = 3


func _land() -> void:
	air = 0.0
	state = "idle"
	state_t = 0.7 * _tempo()
	squash = Vector2(1.5, 0.6)
	var w := Game.world
	w.shake(0.9)
	w.hitstop(60)
	Sfx.play("land", 0.0, 2.0)
	w.ring(global_position, LAND_R + 6.0, Color("a7f070"), 0.35, 3.0, true)
	w.burst(global_position, Color("a7f070"), 26, 110.0, 0.5, 2.5, 150.0)
	var p := player()
	if not p.dead and p.global_position.distance_to(global_position) < LAND_R:
		p.take_damage(22.0, global_position)
	w.add_puddle(global_position, 18.0)
	if _enraged():
		_ring(10, randf() * TAU, 65.0)


func _slam() -> void:
	state = "idle"
	state_t = 0.9 * _tempo()
	squash = Vector2(1.6, 0.55)
	var w := Game.world
	w.shake(1.0)
	w.hitstop(80)
	Sfx.play("explode", 0.0, -2.0)
	w.ring(global_position, SLAM_R + 8.0, Color("ffcd75"), 0.4, 4.0, true)
	w.ring(global_position, SLAM_R * 0.6, Color.WHITE, 0.3, 2.0)
	var p := player()
	if not p.dead and p.global_position.distance_to(global_position) < SLAM_R:
		p.take_damage(25.0, global_position)
	_ring(16, 0.0, 70.0)


func _summon() -> void:
	var count := get_tree().get_nodes_in_group("enemies").size()
	if count > 6:
		return
	var types: Array[String] = ["mini_slime", "mini_slime", "mini_slime"]
	if _enraged():
		types = ["mini_slime", "runner", "spitter"]
	for i in types.size():
		var pos := global_position + Vector2.from_angle(TAU * i / types.size() + randf()) * 34.0
		var bb := Game.world.room.bounds()
		pos = pos.clamp(bb.position + Vector2(12, 12), bb.end - Vector2(12, 40))
		Game.world.spawn_with_marker(types[i], pos, 0.5 + i * 0.1)


func _spray_volley() -> void:
	var dir := (player().global_position + Vector2(0, -6) - hit_center()).normalized()
	for i in 5:
		var a := (i - 2) * 0.22
		Game.world.spawn_enemy_shot(hit_center(), dir.rotated(a) * 85.0, 12.0, "glob_green")
	squash = Vector2(0.85, 1.2)
	Sfx.play("spit", 0.1)


func _ring(n: int, offset: float, spd: float) -> void:
	var c := global_position + Vector2(0, -6)
	for i in n:
		Game.world.spawn_enemy_shot(c, Vector2.from_angle(offset + TAU * i / n) * spd, 12.0, "glob_green")
