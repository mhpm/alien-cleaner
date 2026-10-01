class_name BossArchmage
extends BossBase
## World 3 final boss VOID ARCHMAGE (archmage set), fought inside the BossFence.
## Calm (above half health):
##   volley     bursts of orbs: a fan of plain ones and a homing one in the middle
##   beam       locks on (red line) and fires a sweeping eye beam: run against the sweep
##   moons      a spiral of crescent blades
##   runes      magenta rune circles marked on the floor, exploding one after the other
##   summon     Arcane Eyes that float to you and burst (never more than MAX_EYES)
##   blink      fades out and reappears somewhere else
## FURIOUS (under half health): a roar that wipes his shots; tougher hits, bigger patterns, and
##   whirl        curls into a spiky eye and rushes at you 3 times, bouncing off the fence
##                (armoured while whirling), then he is DIZZY: takes WAY more damage
##   singularity  a dark orb that drags you in for 3.4 s before bursting into blades and
##                orbs; dizzy again afterwards
## DESPERATE (under 20%): two beams, more of everything, shorter pauses.
## Dies slumping with X eyes and melts into a puddle, the void bursting round him.

const CALM := ["volley", "runes", "beam", "blink", "moons", "summon", "volley", "runes", "beam", "moons"]
const FURY := ["whirl", "volley", "singularity", "runes", "beam", "summon", "moons", "whirl", "beam", "runes", "singularity", "blink"]
const ORB_SPEED := 52.0
const BLADE_SPEED := 88.0
const BEAM_DUR := 1.1
const DASH_SPEED := 235.0
const FURY_ARMOR := 0.85
const DESPERATE_ARMOR := 0.75
const STUN_ARMOR := 1.6  # dizzy: every hit takes 60% more
const WHIRL_ARMOR := 0.4  # whirling: 60% less
const DESPERATE_AT := 0.2
const MAX_EYES := 6
const RUNE_R := 24.0

var pattern_i := 0
var furious := false
var desperate := false
var volleys := 0
var dashes := 0
var emit_t := 0.0
var spiral_k := 0
var strafe := 1.0
var beam_dir := 1.0
var sing_pos := Vector2.ZERO
var whirl: AnimatedSprite2D


func _init_ai() -> void:
	_size_to_player()
	state = "intro"
	state_t = 1.6
	Sfx.play("roar", 0.0)
	whirl = Art.make_anim("arch_whirl", base_scale * 0.9)
	whirl.play("spin")
	whirl.position = Vector2(0, -tex_h * base_scale * 0.5)
	whirl.visible = false
	add_child(whirl)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	if not furious and hp < max_hp * 0.5 and state != "intro":
		_enrage()
	elif furious and not desperate and hp < max_hp * DESPERATE_AT:
		_desperate()
	if state in ["whirl_wind", "whirl_dash"]:
		air = 0.0
	else:
		air = 2.5 + sin(t * 3.0 + phase)
		if to_p.x != 0.0:
			face = signf(to_p.x)
	match state:
		"intro", "roar":
			squash = Vector2(1.0 + sin(t * 40.0) * 0.05, 1.0)
			if state_t <= 0.0:
				_next()
		"drift":
			if state_t <= 0.0:
				_next()
			return _drift(to_p)
		"volley_aim":
			if state_t <= 0.0:
				_fire_volley()
				volleys -= 1
				if volleys > 0:
					state_t = 0.5
				else:
					_after(0.6)
		"beam_aim":
			sprite.position.x = sin(t * 60.0) * 0.5
			if state_t <= 0.0:
				sprite.position.x = 0.0
				_fire_beam()
		"beam_fire":
			if state_t <= 0.0:
				_after(0.7)
		"moons_aim":
			if state_t <= 0.0:
				state = "moons_fire"
				state_t = 1.5
				emit_t = 0.0
				spiral_k = 0
		"moons_fire":
			emit_t -= delta
			if emit_t <= 0.0:
				emit_t = 0.16 if furious else 0.2
				_blade_ring(8 if furious else 6, spiral_k * 0.32)
				spiral_k += 1
			if state_t <= 0.0:
				_after(0.7)
		"runes_aim":
			if state_t <= 0.0:
				_runes()
				_after(1.1)
		"summon_aim":
			if state_t <= 0.0:
				_summon(3 if not furious else 4)
				_after(0.6)
		"blink_out":
			sprite.modulate.a = clampf(state_t / 0.3, 0.0, 1.0)
			if state_t <= 0.0:
				_teleport()
				state = "blink_in"
				state_t = 0.3
		"blink_in":
			sprite.modulate.a = clampf(1.0 - state_t / 0.3, 0.0, 1.0)
			if state_t <= 0.0:
				sprite.modulate.a = 1.0
				_next()
		"whirl_aim":
			squash = Vector2(1.0 - (0.6 - state_t) * 0.5, 1.0 + (0.6 - state_t) * 0.3)
			if state_t <= 0.0:
				sprite.visible = false
				whirl.visible = true
				armor = WHIRL_ARMOR
				Game.world.burst(hit_center(), Color("ff4fd8"), 16, 90.0, 0.4, 2.0)
				_whirl_lock()
		"whirl_wind":
			whirl.rotation += delta * 6.0
			if state_t <= 0.0:
				state = "whirl_dash"
				state_t = 0.55
				Sfx.play("dash", 0.0, -2.0)
		"whirl_dash":
			whirl.rotation += delta * 16.0
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.04
				Game.world.burst(hit_center(), Color("d43cff"), 2, 10.0, 0.3, 2.5)
			_bounce()
			if state_t <= 0.0:
				_dash_end()
			return aim * (DASH_SPEED * (1.15 if desperate else 1.0))
		"sing_aim":
			if state_t <= 0.0:
				_spawn_singularity()
				state = "sing_hold"
				state_t = VoidOrb.LIFE
				emit_t = 0.6
		"sing_hold":
			emit_t -= delta
			if emit_t <= 0.0:
				emit_t = 1.0 if not desperate else 0.7
				var d := (player().global_position + Vector2(0, Player.BODY_Y) - hit_center()).normalized()
				var s := Game.world.spawn_enemy_shot(hit_center() + d * 14.0, d * ORB_SPEED, contact_damage * 0.55, "arch_orb")
				s.life = 5.0
			if state_t <= 0.0:
				_stun(2.0)
		"stun":
			sprite.position.x = sin(t * 14.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				armor = _base_armor()
				_after(0.4)
	return Vector2.ZERO


func _base_armor() -> float:
	return DESPERATE_ARMOR if desperate else (FURY_ARMOR if furious else 1.0)


func _after(rest: float) -> void:
	state = "drift"
	state_t = rest * (0.7 if desperate else (0.85 if furious else 1.0))


## Floats round the astronaut at mid range (and never out of the fence).
func _drift(to_p: Vector2) -> Vector2:
	var dist := to_p.length()
	var toward := to_p.normalized() * (0.7 if dist > 130.0 else (-0.7 if dist < 85.0 else 0.0))
	var side := to_p.normalized().orthogonal() * strafe
	var v := (side * 0.7 + toward).normalized() * speed * (1.6 if furious else 1.3)
	var f := _fence()
	if f != null and not f.holds(global_position + v * 0.25, 18.0):
		v = (f.global_position - global_position).normalized() * speed
	return v


func _next() -> void:
	var list: Array = FURY if furious else CALM
	var step: String = list[pattern_i % list.size()]
	pattern_i += 1
	strafe = -strafe
	match step:
		"volley":
			state = "volley_aim"
			state_t = 0.6
			volleys = 4 if desperate else (3 if furious else 2)
			Sfx.play("charge", 0.0, -6.0)
		"beam":
			state = "beam_aim"
			state_t = 0.95
			aim = (player().global_position + Vector2(0, Player.BODY_Y) - hit_center()).normalized()
			beam_dir = 1.0 if randf() < 0.5 else -1.0
			_tele_line(aim, state_t)
			if desperate:
				_tele_line(-aim, state_t)
			Sfx.play("charge", 0.0, -2.0)
		"moons":
			state = "moons_aim"
			state_t = 0.7
			Sfx.play("charge", 0.0, -6.0)
		"runes":
			state = "runes_aim"
			state_t = 0.6
			Sfx.play("charge", 0.0, -6.0)
		"summon":
			if _eyes() >= MAX_EYES:
				_next()  # enough eyes around: do something else
				return
			state = "summon_aim"
			state_t = 0.8
			Sfx.play("roar", 0.2, -8.0)
		"blink":
			state = "blink_out"
			state_t = 0.3
			Game.world.burst(hit_center(), Color("d43cff"), 10, 60.0, 0.3, 2.0)
		"whirl":
			dashes = 4 if desperate else 3
			state = "whirl_aim"
			state_t = 0.6
			Sfx.play("roar", 0.3, -6.0)
		"singularity":
			state = "sing_aim"
			state_t = 0.8
			_pick_singularity()
			Sfx.play("roar", 0.1, -4.0)


func _eyes() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).type_id == "arcane_eye":
			n += 1
	return n


# ---------------------------------------------------------------- phases

## Half health: a roar, his shots vanish, the void opens.
func _enrage() -> void:
	furious = true
	pattern_i = 0
	state = "roar"
	state_t = 1.3
	speed *= 1.15
	armor = FURY_ARMOR
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	w.shake(1.0)
	w.hud.banner("THE VOID OPENS!", Color("d43cff"), 26, 1.2)
	w.hud.tint_flash(Color("d43cff"), 0.35, 0.7)
	w.ring(hit_center(), 70.0, Color("d43cff"), 0.5, 4.0)
	w.burst(hit_center(), Color("ff4fd8"), 30, 140.0, 0.6, 2.5)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	var p := player()
	var d := p.global_position - global_position
	if d.length() < 90.0:
		p.knock = d.normalized() * 240.0


## Under 20%: two beams, shorter pauses, and a fresh batch of eyes.
func _desperate() -> void:
	desperate = true
	armor = DESPERATE_ARMOR
	speed *= 1.1
	var w := Game.world
	sprite.visible = true
	whirl.visible = false
	w.shake(0.8)
	w.hud.banner("NO ESCAPE!", Color("ff4fd8"), 28, 1.0)
	w.hud.tint_flash(Color("ff4fd8"), 0.3, 0.6)
	w.ring(hit_center(), 60.0, Color("ff4fd8"), 0.4, 3.0)
	Sfx.play("roar", 0.0, 2.0)
	_summon(2)


# ---------------------------------------------------------------- attacks

func _tele_line(dir: Vector2, dur: float) -> void:
	var tg := Telegraph.new()
	tg.kind = "line"
	tg.position = hit_center()
	tg.dir = dir
	tg.length = 280.0
	tg.width = 10.0
	tg.dur = dur
	tg.color = Color("d43cff")
	Game.world.decals.add_child(tg)


## A fan of plain orbs with a homing one in the middle, at where the astronaut is heading.
func _fire_volley() -> void:
	var p := player()
	var target := p.global_position + Vector2(0, Player.BODY_Y) + p.velocity * 0.3
	var d := (target - hit_center()).normalized()
	var n := 7 if desperate else (5 if furious else 3)
	for i in n:
		var a := (i - (n - 1) * 0.5) * 0.26
		var mid := i == (n - 1) / 2
		var s := Game.world.spawn_enemy_shot(hit_center() + d * 14.0, d.rotated(a) * ORB_SPEED * (1.0 if mid else 1.3), contact_damage * 0.55, "arch_orb" if mid else "arch_star")
		s.life = 5.0
	squash = Vector2(0.85, 1.15)
	Sfx.play("zap", 0.0, -2.0)


func _beam_origin() -> Variant:
	return null if dead else hit_center() + Vector2(face * 5.0, 0.0)


func _fire_beam() -> void:
	state = "beam_fire"
	state_t = BEAM_DUR
	var spin := 0.85 * beam_dir * (1.3 if furious else 1.0)
	_spawn_beam(aim.angle(), spin)
	if desperate:
		_spawn_beam(aim.angle() + PI, spin)
	Game.world.shake(0.3)
	Sfx.play("zap", 0.0, 2.0)


func _spawn_beam(angle: float, spin: float) -> void:
	var b := ArchBeam.new()
	b.origin = Callable(self, "_beam_origin")
	b.angle = angle
	b.spin = spin
	b.dur = BEAM_DUR
	b.damage = contact_damage * 0.6
	Game.world.effects.add_child(b)


## A ring of crescent blades (`off` turns it, so successive rings make a spiral).
func _blade_ring(n: int, off: float) -> void:
	var c := hit_center()
	for i in n:
		var d := Vector2.from_angle(off + TAU * i / n)
		Game.world.spawn_enemy_shot(c + d * 12.0, d * BLADE_SPEED, contact_damage * 0.5, "arch_blade")
	Sfx.play("spit", 0.05, -4.0)


## Rune circles on and around the astronaut, exploding one after another.
func _runes() -> void:
	var p := player()
	var n := 8 if desperate else (6 if furious else 4)
	for i in n:
		var at := p.global_position + p.velocity * 0.45
		if i > 0:
			at = p.global_position + Vector2.from_angle(TAU * i / n + randf()) * randf_range(28.0, 70.0)
		at = _in_fence(at, 12.0)
		var delay := 0.95 + i * 0.14
		var tg := Telegraph.new()
		tg.position = at
		tg.radius = RUNE_R
		tg.dur = delay
		tg.color = Color("d43cff")
		Game.world.decals.add_child(tg)
		var dmg := contact_damage * 1.1
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_instance_valid(Game.world):
				BossArchmage.rune_blast(at, dmg))


static func rune_blast(at: Vector2, dmg: float) -> void:
	var w := Game.world
	var c := Color("d43cff")
	w.ring(at, RUNE_R, c, 0.35, 3.0, true)
	w.burst(at + Vector2(0, -4), c, 14, 90.0, 0.45, 2.5, 30.0)
	AnimFx.spawn(w.effects, "arch_boom", "pop", at + Vector2(0, -6), 0.26)
	w.shake(0.25)
	Sfx.play("explode", 0.15, -8.0)
	var p := w.player
	if not p.dead:
		var off := p.global_position - at  # the circle is drawn squashed (y * 0.75)
		if Vector2(off.x, off.y / 0.75).length() < RUNE_R:
			p.take_damage(dmg, at)


func _summon(n: int) -> void:
	var w := Game.world
	var m := _minion_mults()
	n = mini(n, MAX_EYES - _eyes())
	for i in n:
		var pos := _in_fence(global_position + Vector2.from_angle(TAU * i / maxf(n, 1.0) + randf()) * 28.0, 14.0)
		w.spawn_enemy("arcane_eye", pos, m.x, 1.0, false, true, m.y)
		w.ring(pos, 12.0, Color("d43cff"), 0.3, 2.0)
		w.burst(pos, Color("ff4fd8"), 8, 50.0, 0.35, 2.0, -30.0)
	Sfx.play("spawn", 0.0, -2.0)


## Reappears 70+ from the astronaut, inside the fence.
func _teleport() -> void:
	var f := _fence()
	var c := f.global_position if f != null else global_position
	var r := f.radius if f != null else 130.0
	var p := player().global_position
	for i in 12:
		var q := c + Vector2.from_angle(randf() * TAU) * randf_range(0.25, 0.7) * r
		if q.distance_to(p) > 90.0:
			global_position = q
			break
	Game.world.burst(hit_center(), Color("d43cff"), 10, 60.0, 0.3, 2.0)
	Game.world.ring(hit_center(), 16.0, Color("ff4fd8"), 0.25, 2.0)
	Sfx.play("spawn", 0.15, -8.0)


func _whirl_lock() -> void:
	state = "whirl_wind"
	state_t = 0.45
	aim = (player().global_position - global_position).normalized()
	Game.world.telegraph_line(global_position + Vector2(0, -4), aim, 170.0, 16.0, state_t)
	Sfx.play("alert", 0.0, -4.0)


## Keeps the rush inside the fence and off the walls: bounces.
func _bounce() -> void:
	var f := _fence()
	if f != null and not f.holds(global_position, 14.0):
		var out := (global_position - f.global_position).normalized()
		global_position = f.global_position + out * (f.radius - 15.0)
		aim = aim.bounce(out)
		Game.world.burst(global_position, Color("5fe6ff"), 6, 50.0, 0.25, 2.0)
	elif hit_wall and get_slide_collision_count() > 0:
		aim = aim.bounce(get_slide_collision(0).get_normal())


func _dash_end() -> void:
	_blade_ring(8 if not desperate else 10, randf() * TAU)
	Game.world.ring(hit_center(), 26.0, Color("d43cff"), 0.3, 3.0)
	Game.world.shake(0.3)
	dashes -= 1
	if dashes > 0:
		_whirl_lock()
		return
	sprite.visible = true
	whirl.visible = false
	_stun(2.6)


## Dizzy: X eyes, halo, takes far more damage.
func _stun(secs: float) -> void:
	state = "stun"
	state_t = secs
	armor = STUN_ARMOR
	var w := Game.world
	w.ring(hit_center(), 34.0, Color("ffcd75"), 0.4, 3.0)
	w.popup_text(hit_center() + Vector2(0, -26), "DIZZY! HIT HIM!", Color("ffcd75"), 12)
	Sfx.play("freeze", 0.0, 2.0)


func _pick_singularity() -> void:
	var f := _fence()
	var c := f.global_position if f != null else global_position
	var p := player().global_position
	var off := c - p
	sing_pos = p + (off.limit_length(85.0) if off.length() > 40.0 else Vector2.from_angle(randf() * TAU) * 60.0)
	sing_pos = _in_fence(sing_pos, 20.0)
	Game.world.telegraph_circle(sing_pos, 16.0, state_t)


func _spawn_singularity() -> void:
	var o := VoidOrb.new()
	o.position = sing_pos
	o.damage = contact_damage * 0.9
	Game.world.effects.add_child(o)
	Game.world.shake(0.3)


func _anim_name() -> String:
	match state:
		"intro":
			return "charge"
		"roar":
			return "fury"
		"volley_aim", "beam_aim":
			return "cast"
		"beam_fire":
			return "fire"
		"moons_aim", "moons_fire":
			return "moons"
		"runes_aim", "summon_aim", "sing_aim":
			return "summon"
		"sing_hold":
			return "charge"
		"stun":
			return "stun"
	return "fury" if furious else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.decals, "archmage", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and e != self and e.type_id == "arcane_eye":
			e.take_damage(99999.0)
	# the void collapses around him: stars bursting all over the body, then a big ring
	var c := hit_center()
	for i in 8:
		get_tree().create_timer(0.18 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(w):
				var at := c + Vector2(randf_range(-22, 22), randf_range(-20, 16))
				AnimFx.spawn(w.effects, "arch_boom", "pop", at, randf_range(0.3, 0.5))
				w.burst(at, Color("d43cff"), 12, 100.0, 0.5, 2.5, 60.0)
				w.shake(0.4)
				Sfx.play("explode", 0.2, -6.0))
	get_tree().create_timer(1.5, false).timeout.connect(func() -> void:
		if is_instance_valid(w):
			w.ring(c, 80.0, Color("ff4fd8"), 0.6, 4.0)
			w.burst(c, Color("ff4fd8"), 40, 160.0, 0.8, 2.5, 100.0)
			Sfx.play("explode", 0.0, 2.0))
	Sfx.play("freeze", 0.1)
