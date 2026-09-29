extends BossBase
## World 1 final boss BIG RED (the big_red set, fought inside the BossFence).
## Calm (above half health):
##   stomp   leaps onto the astronaut (shadow warning), shockwave + ring of acid blobs
##   fan     a fan of fireballs from its eye (warning lines)
##   mortar  lobs acid globs around the astronaut: they land on red circles and leave
##           burning puddles
##   summon  roars in a few slimes
## FURIOUS (under half health): a roar that shoves you away, burning aura (fury
## frames), faster, and new attacks:
##   charge  three dashes in a row, bouncing off the electric fence with a blob spray
##   spiral  spins spraying a double spiral of acid blobs
##   mega    charges up a giant fireball that bursts into a ring of blobs
## and the calm attacks get bigger (wider fans, double shockwaves, more globs).
## Dies screaming and melting, splashing goo all around.
## Tough whatever the build (BossBase: health sized to the astronaut's damage, capped
## hits) and the furious half shrugs off FURY_ARMOR of every hit.

const CALM := ["chase", "stomp", "fan", "chase", "mortar", "stomp", "fan", "summon"]
const FURY := ["charge", "spiral", "chase", "stomp", "mega", "charge", "mortar", "fan", "spiral", "summon"]
const FIRE_SPEED := 95.0
const CHARGE_SPEED := 235.0
const STOMP_R := 46.0
const JUMP_TIME := 0.6
const FURY_ARMOR := 0.75  # furious: takes 25% less damage

var pattern_i := 0
var furious := false
var dashes := 0  # dashes left in a charge chain
var spin := 0.0
var shot_t := 0.0
var fire_t := 0.0  # > 0: show the shooting pose
var jump_from := Vector2.ZERO
var jump_to := Vector2.ZERO
var aura: Sprite2D


func _init_ai() -> void:
	_size_to_player()
	state = "intro"
	state_t = 1.4
	Sfx.play("roar", 0.0)
	aura = Sprite2D.new()
	aura.texture = Art.tex("glow")
	aura.modulate = Color(1.0, 0.25, 0.45, 0.0)
	aura.scale = Vector2(radius * 3.2 / 14.0, radius * 1.6 / 24.0) * 1.6
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.material = add
	add_child(aura)
	move_child(aura, 0)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	fire_t -= delta
	var to_p := _to_player()
	if not furious and hp < max_hp * 0.5 and state not in ["jump", "charge"]:
		_enrage()
	if furious:
		aura.modulate.a = 0.35 + sin(t * 10.0) * 0.12
	match state:
		"intro", "roar":
			squash = Vector2(1.0 + sin(t * 40.0) * 0.06, 1.0)
			if state_t <= 0.0:
				_next()
			return Vector2.ZERO
		"chase":
			if state_t <= 0.0:
				_next()
			if to_p.x != 0.0:
				face = signf(to_p.x)
			return to_p.normalized() * speed * (1.45 if furious else 1.0)
		"recover":
			if state_t <= 0.0:
				_next()
			return Vector2.ZERO
		# --- stomp: crouch, leap onto the astronaut, shockwave
		"crouch":
			var k := 1.0 - state_t / 0.5
			squash = Vector2(1.0 + k * 0.25, 1.0 - k * 0.2)
			if state_t <= 0.0:
				state = "jump"
				state_t = JUMP_TIME
				jump_from = global_position
				Game.world.telegraph_circle(jump_to, STOMP_R, JUMP_TIME)
				Sfx.play("dash", 0.0)
			return Vector2.ZERO
		"jump":
			var k := 1.0 - maxf(state_t, 0.0) / JUMP_TIME
			global_position = jump_from.lerp(jump_to, k)
			air = sin(k * PI) * 55.0
			squash = Vector2(0.85, 1.2)
			if state_t <= 0.0:
				air = 0.0
				_land()
			return Vector2.ZERO
		# --- fan of fireballs
		"aim":
			sprite.position.x = sin(t * 50.0) * 0.7
			if state_t <= 0.0:
				sprite.position.x = 0.0
				_fan(aim)
				if furious:  # a second volley at where the astronaut went
					get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
						if not dead:
							_fan(_to_player().normalized()))
					_after(0.8)
				else:
					_after(0.6)
			return Vector2.ZERO
		# --- mortar
		"lob":
			squash = Vector2(1.0, 1.0 + sin(t * 30.0) * 0.08)
			if state_t <= 0.0:
				_mortar()
				_after(0.7)
			return Vector2.ZERO
		# --- summon
		"call":
			if state_t <= 0.0:
				_summon()
				_after(0.5)
			return Vector2.ZERO
		# --- charge chain (furious)
		"charge_aim":
			sprite.position.x = sin(t * 60.0) * 0.9
			if state_t <= 0.0:
				sprite.position.x = 0.0
				state = "charge"
				state_t = 0.9
				squash = Vector2(1.3, 0.75)
				Sfx.play("dash", 0.05)
			return Vector2.ZERO
		"charge":
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.03
				Game.world.burst(global_position + Vector2(0, -8), Color("ff4f9a"), 2, 10.0, 0.35, 3.0)
			var f := _fence()
			var at_fence := f != null and not f.holds(global_position, radius + 3.0)
			if (at_fence or hit_wall) and state_t < 0.8:
				_bounce()
				return Vector2.ZERO
			if state_t <= 0.0:
				_next_dash(0.45)
				return Vector2.ZERO
			return aim * CHARGE_SPEED
		# --- spiral (furious)
		"spiral":
			spin += delta * 3.4
			shot_t -= delta
			if shot_t <= 0.0:
				shot_t = 0.09
				var c := hit_center()
				for k in 2:
					var d := Vector2.from_angle(spin + PI * k)
					Game.world.spawn_enemy_shot(c + d * 10.0, d * 75.0, contact_damage * 0.45, "red_blob")
				Sfx.play("spit", 0.2, -12.0)
			if state_t <= 0.0:
				_after(0.6)
			return Vector2.ZERO
		# --- mega fireball (furious)
		"mega_charge":
			var k := 1.0 - state_t / 1.0
			squash = Vector2(1.0 + k * 0.15, 1.0 + k * 0.15)
			if randf() < 0.6:
				var c := hit_center()
				var off := Vector2.from_angle(randf() * TAU) * randf_range(18.0, 30.0)
				Game.world.burst(c + off, Color("ff4fd8"), 1, 0.0, 0.25, 2.5, 0.0, -off, 0.1)
			if state_t <= 0.0:
				var d := to_p.normalized()
				face = signf(d.x) if d.x != 0.0 else face
				var s := Game.world.spawn_enemy_shot(hit_center() + d * 14.0, d * 70.0, contact_damage * 1.1, "big_red_mega")
				s.life = 1.6
				fire_t = 0.4
				Sfx.play("roar", 0.1, -4.0)
				Game.world.shake(0.4)
				_after(0.8)
			return Vector2.ZERO
	return Vector2.ZERO


func _next() -> void:
	var list: Array = FURY if furious else CALM
	var step: String = list[pattern_i % list.size()]
	pattern_i += 1
	var to_p := _to_player()
	match step:
		"chase":
			state = "chase"
			state_t = 0.8 if furious else 1.3
		"stomp":
			state = "crouch"
			state_t = 0.5
			jump_to = player().global_position
			var f := _fence()
			if f != null and not f.holds(jump_to, radius):
				jump_to = f.global_position + (jump_to - f.global_position).limit_length(f.radius - radius - 2.0)
		"fan":
			state = "aim"
			state_t = 0.55 if furious else 0.7
			aim = to_p.normalized()
			face = signf(aim.x) if aim.x != 0.0 else face
			for a in _fan_angles():
				Game.world.telegraph_line(hit_center(), aim.rotated(a), 170.0, 8.0, state_t)
			Sfx.play("charge", 0.0, -4.0)
		"mortar":
			state = "lob"
			state_t = 0.45
			Sfx.play("charge", 0.0, -6.0)
		"summon":
			state = "call"
			state_t = 0.7
			Sfx.play("roar", 0.1, -6.0)
		"charge":
			dashes = 3
			_aim_dash(0.55)
		"spiral":
			state = "spiral"
			state_t = 2.6
			shot_t = 0.3
			spin = randf() * TAU
			Sfx.play("charge", 0.0, -2.0)
		"mega":
			state = "mega_charge"
			state_t = 1.0
			Sfx.play("charge", 0.0, 0.0)


func _after(rest: float) -> void:
	state = "recover"
	state_t = rest * (0.75 if furious else 1.0)


## Half health: a roar that shoves the astronaut away and wipes the shots, then fury.
func _enrage() -> void:
	furious = true
	armor = FURY_ARMOR
	pattern_i = 0
	state = "roar"
	state_t = 1.3
	air = 0.0
	tint = Color(1.2, 0.9, 1.0)
	speed *= 1.15
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	w.shake(1.0)
	w.hud.banner("BIG RED IS FURIOUS!", Color("ff3344"), 26, 1.0)
	w.hud.tint_flash(Color("ff1f3a"), 0.3, 0.6)
	w.ring(hit_center(), 70.0, Color("ff4f9a"), 0.5, 4.0)
	w.burst(hit_center(), Color("ff4fd8"), 40, 150.0, 0.6, 2.5)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	var p := player()
	var d := p.global_position - global_position
	if d.length() < 90.0:
		p.knock = d.normalized() * 260.0


## Stomp landing: shockwave that hurts nearby, and a ring (two when furious) of blobs.
func _land() -> void:
	var w := Game.world
	w.shake(0.8)
	w.hitstop(50)
	Sfx.play("land", 0.0, 2.0)
	squash = Vector2(1.45, 0.65)
	w.ring(global_position, STOMP_R, Color("ff4f9a"), 0.35, 4.0, true)
	w.burst(global_position, Color("ff4fd8"), 24, 110.0, 0.45, 2.5)
	var p := player()
	if not p.dead and p.global_position.distance_to(global_position) < STOMP_R:
		p.take_damage(contact_damage, global_position)
	_ring(10 if not furious else 14, randf() * TAU, 70.0)
	if furious:
		get_tree().create_timer(0.3, false).timeout.connect(func() -> void:
			if not dead:
				_ring(14, randf() * TAU, 90.0))
	_after(0.7)


func _fan_angles() -> Array[float]:
	var out: Array[float] = []
	var n := 5 if furious else 3
	for i in n:
		out.append((i - (n - 1) * 0.5) * 0.28)
	return out


func _fan(dir: Vector2) -> void:
	var c := hit_center() + dir * 14.0
	for a in _fan_angles():
		Game.world.spawn_enemy_shot(c, dir.rotated(a) * FIRE_SPEED, contact_damage * 0.8, "big_red")
	fire_t = 0.35
	face = signf(dir.x) if dir.x != 0.0 else face
	squash = Vector2(0.85, 1.15)
	Sfx.play("roar", 0.2, -8.0)
	Game.world.burst(c, Color("ff4fd8"), 8, 60.0, 0.25, 2.0, 0.0, dir, 0.5)


## Acid globs lobbed at and around the astronaut (red circles show where they fall).
func _mortar() -> void:
	var p := player().global_position
	var n := 8 if furious else 5
	var f := _fence()
	for i in n:
		var to := p if i == 0 else p + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0)
		if f != null and not f.holds(to, 8.0):
			to = f.global_position + (to - f.global_position).limit_length(f.radius - 10.0)
		var g := GooGlob.new()
		g.from = hit_center()
		g.to = to
		g.height = randf_range(60.0, 90.0)
		g.dur = 1.0 + i * 0.08
		g.acid = true
		g.damage = contact_damage * 0.8
		g.puddle_r = 13.0
		g.puddle_life = 4.5 if furious else 3.5
		Game.world.effects.add_child(g)
		Game.world.telegraph_circle(to, 13.0, g.dur)
	fire_t = 0.3
	Sfx.play("spit", 0.0, 2.0)


## A few slimes (runners too when furious) called in around the boss.
func _summon() -> void:
	var w := Game.world
	var hm := w.survival._hp_mult() if w.survival != null else 1.0
	var dm := w.survival._dmg_mult() if w.survival != null else 1.0
	var n := 6 if furious else 4
	for i in n:
		var id := "runner" if furious and i % 2 == 0 else "slime"
		var pos := global_position + Vector2.from_angle(TAU * i / n + randf() * 0.4) * 50.0
		var f := _fence()
		if f != null and not f.holds(pos, 10.0):
			pos = f.global_position + (pos - f.global_position).limit_length(f.radius - 12.0)
		w.spawn_with_marker(id, pos, 0.6 + i * 0.05, hm, 1.0, false, dm)
	w.ring(hit_center(), 30.0, Color("ff4f9a"), 0.4, 3.0)


func _aim_dash(windup: float) -> void:
	state = "charge_aim"
	state_t = windup
	aim = _to_player().normalized()
	face = signf(aim.x) if aim.x != 0.0 else face
	Game.world.telegraph_line(global_position + Vector2(0, -4), aim, 240.0, 26.0, state_t)
	Sfx.play("charge", 0.0, -4.0)


## A charge slams into the fence (or a wall): spray of blobs, then the next dash.
func _bounce() -> void:
	var w := Game.world
	w.shake(0.7)
	Sfx.play("land", 0.1)
	w.burst(global_position, Color(1, 1, 1, 0.8), 14, 80.0, 0.35, 2.0)
	_ring(8, randf() * TAU, 65.0)
	var f := _fence()
	if f != null:  # step back inside
		global_position = f.global_position + (global_position - f.global_position).limit_length(f.radius - radius - 6.0)
	_next_dash(0.6)


func _next_dash(rest: float) -> void:
	dashes -= 1
	if dashes > 0:
		_aim_dash(0.35)
	else:
		_after(rest)


func _anim_name() -> String:
	if fire_t > 0.0:
		return "shoot"
	match state:
		"intro", "roar", "call", "lob":
			return "roar"
		"crouch", "jump", "aim", "charge_aim":
			return "angry"
		"charge", "spiral", "mega_charge":
			return "fury"
	return "fury" if furious else "walk"


func _on_death() -> void:
	var w := Game.world
	# screams and melts into a puddle...
	var fx := AnimFx.spawn(w.decals, "big_red", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	var pos := global_position
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		var pd := GooPuddle.new()
		pd.big = true
		pd.radius = 34.0
		pd.life = 14.0
		pd.position = pos
		w.decals.add_child(pd))
	# ...splashing goo all around
	for i in 16:
		var g := GooGlob.new()
		g.from = hit_center()
		g.to = pos + Vector2.from_angle(TAU * i / 16.0 + randf_range(-0.2, 0.2)) * randf_range(35.0, 95.0)
		g.height = randf_range(30.0, 70.0)
		g.dur = randf_range(0.5, 0.9)
		g.size = randf_range(0.9, 1.4)
		g.puddle_r = randf_range(8.0, 14.0)
		g.puddle_life = 10.0
		w.effects.add_child(g)
	Sfx.play("explode", 0.0, 2.0)
