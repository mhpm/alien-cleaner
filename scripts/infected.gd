class_name Infected
extends Node2D
## Infected mode (MUTATION LAB, Game.perm.infected = mutation phase 1-5, MutationData).
## Cleaning aliens fills the infection meter (ring around the ability button); when it is
## full the ability button mutates the astronaut into the tentacle monster
## of its mutation phase (MutationData.sprite_set, e.g. assets/sprites/mutant1) for
## duration() seconds. The mutant cannot shoot: it fights up close with an automatic
## tentacle strike (it lunges at aliens within reach, 4 directions, every third strike
## of a combo is a heavy blow), is faster and tougher, and rolls on the ability button. Lives under the Player, which asks it for multipliers and animations.
## Powers by phase (MutationData constants): 2 eruptions + faster meter, 3 eye missiles +
## toxic aura, 4 double eruptions/missiles + regeneration, 5 shock roll, frenzy (kills
## extend it) and apex form (bigger, golden, triple missiles, double wave).

const TRANSFORM_TIME := 1.15
const BURST_AT := 0.32  # seconds before the end of the transformation: shockwave
const REVERT_TIME := 0.35
const SLASH_TIME := 0.25  # one strike (4 frames at 16 fps)
const SLASH_CD := 0.32  # between strikes
const SLASH_RANGE := 34.0  # strikes aliens this close...
const LUNGE_RANGE := 70.0  # ...and jumps at the ones this close
const LUNGE_TIME := 0.12
const LUNGE_SPEED := 300.0
const DASH_TIME := 0.24
const DASH_SPEED := 330.0
const DASH_CD := 0.9
const MAGENTA := Color("ff3df0")
const GOO := Color("c42bd6")

var player: Player
var level := 0
var charge := 0.0  # infection meter 0..1
var active := false
var transforming := false
var reverting := false
var state_t := 0.0  # time left in the transformation / revert
var burst_done := false
var time_left := 0.0
var slash_cd := 0.0
var slash_t := 0.0
var slash_hit := false
var atk_dir := "down"  # direction of the current strike: down / up / left / right
var atk_vec := Vector2.DOWN
var combo := 0  # strikes in a row (every 3rd is a heavy blow)
var combo_t := 0.0
var lunge_t := 0.0
var erupt_cd := 1.0
var missile_cd := 1.5
var dash_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector2.RIGHT
var dash_hits: Array[int] = []
var roll := 0.0
var ghost_t := 0.0
var goo_t := 0.0
var t := 0.0
var announced := false
var pending_erupts: Array[Dictionary] = []  # {pos, t}
var aura: Sprite2D


func setup(p: Player) -> void:
	player = p
	level = int(Game.stats.get("infected", 0))
	show_behind_parent = true
	aura = Sprite2D.new()
	aura.texture = Art.tex("glow")
	aura.modulate = Color(MAGENTA, 0.0)
	aura.position = Vector2(0, -3)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.material = m
	add_child(aura)


func unlocked() -> bool:
	return level > 0


func duration() -> float:
	return MutationData.duration(level)


## Damage multiplier of everything the mutant does.
func power() -> float:
	return MutationData.power(level)


func has(power_lv: int) -> bool:
	return level >= power_lv


func can_transform() -> bool:
	return unlocked() and charge >= 1.0 and not active and not transforming and not reverting and not player.dead


func speed_mult() -> float:
	return 1.4 if active else 1.0


func damage_taken_mult() -> float:
	return 0.5 if active else 1.0


## True while nothing can hurt the player (mutating, rolling).
func untouchable() -> bool:
	return transforming or dash_t > 0.0


## Animation the mutant must show over the normal idle/walk choice ("" = none).
func override_anim() -> String:
	if transforming or reverting:
		return "idle"
	if dash_t > 0.0:
		return "dash"
	if slash_t > 0.0:
		# combo poses (punch, uppercut, low sweep) when the set has them, in turn
		if Art.frames(player.body.form).has_animation("combo_1"):
			return "combo_%d" % ((combo - 1) % 3 + 1)
		return "attack_" + atk_dir
	return ""


## Velocity that overrides the joystick (rolling, lunging at an alien), or INF.
func dash_velocity() -> Vector2:
	if dash_t > 0.0:
		return dash_dir * DASH_SPEED
	if lunge_t > 0.0:
		return atk_vec * LUNGE_SPEED
	return Vector2.INF


func add_charge(v: float) -> void:
	if not unlocked() or active or transforming or reverting:
		return
	charge = minf(1.0, charge + v * (1.3 if has(MutationData.HUNGRY) else 1.0))
	if charge >= 1.0 and not announced:
		announced = true
		Game.world.hud.banner("MUTATION READY!", MAGENTA, 26, 0.7)
		Sfx.play("charge", 0.0, -4.0)


func on_kill(e: Enemy) -> void:
	if active and has(MutationData.FRENZY):
		time_left = minf(time_left + 0.4, duration() + 4.0)  # blood frenzy
	if e.is_boss:
		add_charge(0.35)
	elif e.elite:
		add_charge(0.2)
	else:
		add_charge(0.03 if Game.world.survival != null else 0.07)


# ---------------------------------------------------------------- transform / revert

func transform() -> void:
	if not can_transform():
		return
	transforming = true
	burst_done = false
	state_t = TRANSFORM_TIME
	charge = 0.0
	announced = false
	player.locked = true
	player.body.set_form(MutationData.sprite_set(level))
	player.body.play("idle")
	var w := Game.world
	Sfx.play("mutate", 0.0)
	Sfx.play("roar", 0.05, -6.0)
	w.shake(0.35)
	w.hud.tint_flash(Color(0.85, 0.1, 0.95), 0.3, 0.9)
	w.ring(_center(), 30.0, MAGENTA, 0.5, 2.0)


func _transform_burst() -> void:
	burst_done = true
	if has(MutationData.APEX):  # apex form: a second wave right after
		get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
			if active or transforming:
				_wave(1.3))
	_wave(1.0)


## Transformation shockwave (scale > 1: the apex form's second, bigger wave).
func _wave(scale_k: float) -> void:
	var w := Game.world
	var c := _center()
	var rad := 95.0 * scale_k
	w.ring(c, rad, _aura_color(), 0.55, 5.0, true)
	w.ring(c, 60.0 * scale_k, Color.WHITE, 0.3, 3.0)
	w.burst(c, MAGENTA, 44, 190.0, 0.6, 2.5)
	w.burst(c, Color.WHITE, 14, 90.0, 0.3, 2.0)
	_goo_splash(c, 16, 150.0)
	w.shake(1.0)
	w.hitstop(140)
	Sfx.play("explode", 0.05)
	Sfx.play("roar", 0.05, 0.0)
	if scale_k <= 1.0:
		w.hud.banner("APEX FORM!" if has(MutationData.APEX) else "INFECTED!", _aura_color(), 46, 0.9)
		w.hud.tint_flash(Color(1.0, 0.3, 1.0), 0.45, 0.5)
	for i in 8:
		_erupt(player.global_position + Vector2.from_angle(TAU * i / 8.0 + 0.2) * Vector2(52, 40), 0.0)
	var dmg := float(Game.stats.damage) * 3.0 * power()
	for n in w.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		var d := e.global_position - player.global_position
		if d.length() < rad + e.radius:
			e.take_damage(dmg, d.normalized() * 1.5)
			e.push(d.normalized() * 260.0)
			e.stun(0.9)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		var shot := n as EnemyShot
		if shot != null and shot.global_position.distance_to(c) < rad:
			shot.pop()


## Mutant glow: magenta, flashing gold at APEX FORM.
func _aura_color() -> Color:
	if has(MutationData.APEX):
		return MAGENTA.lerp(Color("ffcd75"), 0.5 + 0.5 * sin(t * 4.0))
	return MAGENTA


func _finish_transform() -> void:
	transforming = false
	active = true
	time_left = duration()
	player.locked = false
	player.invuln = 0.0
	slash_cd = 0.2
	erupt_cd = 0.6
	missile_cd = 0.9
	dash_cd = 0.0
	player.body.play("idle")
	if has(MutationData.BROOD):
		_spawn_brood(4 if has(MutationData.APEX) else 3)


## BROOD BURST: spiky eyeball spawn burst out of the mutant and ram aliens while it lasts.
func _spawn_brood(n: int) -> void:
	for i in n:
		var b := InfBrood.new()
		b.inf = self
		b.slot = TAU * i / n
		b.damage = float(Game.stats.damage) * 1.5 * power()
		Game.world.effects.add_child(b)
		b.global_position = _center()
	Game.world.burst(_center(), Color("a7f070"), 14, 110.0, 0.4, 2.0)


func _clear_brood() -> void:
	for b in get_tree().get_nodes_in_group("inf_brood"):
		(b as InfBrood).pop()


func _revert() -> void:
	active = false
	_clear_brood()
	reverting = true
	state_t = REVERT_TIME
	slash_t = 0.0
	dash_t = 0.0
	player.locked = true
	var w := Game.world
	w.burst(_center(), MAGENTA, 18, 90.0, 0.4, 2.0)
	Sfx.play("charge", 0.0, -8.0)


func _finish_revert() -> void:
	reverting = false
	player.locked = false
	player.invuln = 1.0
	player.body.set_form("player")
	player.body.modulate = Color(1, 1, 1, player.body.modulate.a)
	var w := Game.world
	var c := _center()
	w.ring(c, 26.0, MAGENTA, 0.35, 2.0)
	w.burst(c, Color.WHITE, 12, 80.0, 0.3, 2.0)
	_goo_splash(c, 10, 90.0)
	Sfx.play("pop", 0.05, -2.0)


## Back to the astronaut at once (room change, death). The meter is kept.
func end_now() -> void:
	if not active and not transforming and not reverting:
		return
	active = false
	transforming = false
	reverting = false
	_clear_brood()
	slash_t = 0.0
	dash_t = 0.0
	roll = 0.0
	pending_erupts.clear()
	player.locked = false
	player.body.set_form("player")
	player.body.modulate = Color(1, 1, 1, player.body.modulate.a)
	aura.modulate.a = 0.0


# ---------------------------------------------------------------- per frame

func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		return
	t += delta
	# the glow grows brighter and wider with the mutation level
	var glow := 0.4 + 0.035 * level
	var ac := _aura_color()
	aura.modulate = Color(ac.r, ac.g, ac.b, move_toward(aura.modulate.a, (glow + sin(t * 6.0) * 0.15) if (active or transforming) else 0.0, delta * 3.0))
	aura.scale = Vector2(2.4, 1.3) * MutationData.look_scale(level) * (1.0 + sin(t * 6.0) * 0.06) * (1.6 if transforming else 1.0)
	_tick_erupts(delta)
	if transforming or reverting:
		# the body wobbles and flickers magenta while it changes
		var k := sin(t * 42.0)
		player.squash = Vector2(1.0 + k * 0.14, 1.0 - k * 0.14)
		var fl := Color(1.8, 0.6, 1.8) if fmod(t, 0.12) < 0.06 else Color.WHITE
		player.body.modulate = Color(fl.r, fl.g, fl.b, player.body.modulate.a)
	if transforming:
		state_t -= delta
		_drip(delta, 0.03)
		if not burst_done and state_t <= BURST_AT:
			_transform_burst()
		if state_t <= 0.0:
			player.body.modulate = Color(1, 1, 1, player.body.modulate.a)
			_finish_transform()
		return
	if reverting:
		state_t -= delta
		if state_t <= 0.0:
			_finish_revert()
		return
	if not active:
		return
	time_left -= delta
	if time_left <= 0.0:
		_revert()
		return
	# last seconds: the mutation flickers
	var warn := time_left < 2.0 and fmod(time_left, 0.25) < 0.12
	var tint := Color(1.6, 0.7, 1.6) if warn else Color.WHITE
	player.body.modulate = Color(tint.r, tint.g, tint.b, player.body.modulate.a)
	dash_cd = maxf(0.0, dash_cd - delta)
	_update_dash(delta)
	_update_slash(delta)
	if has(MutationData.ERUPTION):
		erupt_cd -= delta
		if erupt_cd <= 0.0:
			erupt_cd = maxf(0.7, 1.5 - 0.08 * level)
			_auto_erupt()
	if has(MutationData.MISSILES):
		missile_cd -= delta
		if missile_cd <= 0.0:
			missile_cd = maxf(1.2, 2.3 - 0.1 * level)
			_fire_missiles()
	if has(MutationData.AURA):
		_toxic_aura(delta)
	if has(MutationData.REGEN):
		Game.heal(float(Game.stats.max_hp) * 0.03 * delta)
		if randf() < delta * 4.0:
			Game.world.burst(_center() + Vector2(randf_range(-6, 6), 4), Color("a7f070"), 1, 20.0, 0.5, 2.0, -40.0)
	_drip(delta, 0.09)


var aura_t := 0.0


## TOXIC AURA: every 0.5 s aliens close to the mutant take damage; spores drift around.
func _toxic_aura(delta: float) -> void:
	if randf() < delta * 10.0:
		var a := randf() * TAU
		Game.world.burst(player.global_position + Vector2.from_angle(a) * Vector2(34, 22), Color("a7f070"), 1, 10.0, 0.6, 2.0, -15.0)
	aura_t -= delta
	if aura_t > 0.0:
		return
	aura_t = 0.5
	var dmg := float(Game.stats.damage) * 0.6 * power()
	var hit := false
	for n in Game.world.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		if e.global_position.distance_to(player.global_position) < 38.0 + e.radius:
			e.take_damage(dmg, Vector2.ZERO)
			hit = true
	if hit:
		Game.world.ring(player.global_position + Vector2(0, -4), 38.0, Color(0.65, 0.94, 0.44, 0.5), 0.3, 1.5)


func _center() -> Vector2:
	return player.global_position + Vector2(0, -11)


# ---------------------------------------------------------------- tentacle slash

func _update_slash(delta: float) -> void:
	slash_cd -= delta
	lunge_t = maxf(0.0, lunge_t - delta)
	combo_t -= delta
	if combo_t <= 0.0:
		combo = 0
	if slash_t > 0.0:
		slash_t -= delta
		if not slash_hit and slash_t <= SLASH_TIME * 0.5:  # the swing lands on frame 2-3
			_slash_hit()
		return
	if slash_cd > 0.0 or dash_t > 0.0:
		return
	var e := _nearest(LUNGE_RANGE)
	if e == null:
		return
	var to := e.global_position - player.global_position
	atk_vec = to.normalized() if to.length() > 0.1 else Vector2(player.facing, 0)
	atk_dir = _dir4(atk_vec)
	if absf(atk_vec.x) > 0.2:
		player.facing = signf(atk_vec.x)
	if to.length() > SLASH_RANGE:
		lunge_t = LUNGE_TIME  # jump at it
	slash_t = SLASH_TIME
	slash_hit = false
	slash_cd = SLASH_CD + SLASH_TIME
	combo += 1
	combo_t = 0.9
	Sfx.play("slash", 0.12, -2.0 if combo % 3 == 0 else -5.0)


static func _dir4(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return "right" if v.x >= 0.0 else "left"
	return "down" if v.y >= 0.0 else "up"


func _slash_hit() -> void:
	slash_hit = true
	var w := Game.world
	var heavy := combo % 3 == 0
	var reach := 26.0 * (1.35 if heavy else 1.0)
	var c := player.global_position + Vector2(0, -8) + atk_vec * 15.0
	var dmg := float(Game.stats.damage) * 2.0 * power() * (2.0 if heavy else 1.0)
	var hit := false
	for n in w.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		var d := e.hit_center() - c
		if d.length() < reach + e.radius:
			var dir := atk_vec.lerp(d.normalized(), 0.4).normalized()
			e.take_damage(dmg, dir * (2.5 if heavy else 1.5))
			e.push(dir * (320.0 if heavy else 170.0))
			if heavy:
				e.stun(0.5)
			w.burst(e.hit_center(), MAGENTA, 12 if heavy else 7, 110.0, 0.3, 2.0, 0.0, dir, 0.8)
			hit = true
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		var shot := n as EnemyShot
		if shot != null and shot.global_position.distance_to(c) < reach:
			shot.pop()
	if heavy:
		w.ring(c, reach, MAGENTA, 0.22, 3.0)
	if hit:
		w.hitstop(55 if heavy else 25)
		w.shake(0.4 if heavy else 0.18)
		Sfx.play("hit", 0.1, 2.0 if heavy else 0.0)


# ---------------------------------------------------------------- rolling dash

## Ability button while mutated: roll in the move direction, through aliens.
func dash() -> void:
	if not active or dash_t > 0.0 or dash_cd > 0.0:
		return
	var d := player.input_dir
	dash_dir = d.normalized() if d.length() > 0.2 else Vector2(player.facing, 0.0)
	if absf(dash_dir.x) > 0.1:
		player.facing = signf(dash_dir.x)
	dash_t = DASH_TIME
	dash_cd = DASH_CD
	slash_t = 0.0
	dash_hits.clear()
	Sfx.play("dash", 0.1, 0.0)
	AnimFx.spawn(Game.world.decals, "dust", "puff", player.global_position, 0.12)
	Game.world.burst(_center(), MAGENTA, 10, 80.0, 0.3, 2.0, 0.0, -dash_dir, 0.6)


func _update_dash(delta: float) -> void:
	if dash_t <= 0.0:
		roll = 0.0
		return
	dash_t -= delta
	# "rueda": a full forward roll over the dash
	roll = (1.0 - maxf(dash_t, 0.0) / DASH_TIME) * TAU * player.facing
	ghost_t -= delta
	if ghost_t <= 0.0:
		ghost_t = 0.025
		_ghost()
	var w := Game.world
	var dmg := float(Game.stats.damage) * 1.8 * power()
	for n in w.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		var id := e.get_instance_id()
		if dash_hits.has(id):
			continue
		if e.global_position.distance_to(player.global_position) < 14.0 + e.radius:
			dash_hits.append(id)
			e.take_damage(dmg, dash_dir * 1.5)
			e.push(dash_dir * 220.0)
			w.burst(e.hit_center(), MAGENTA, 10, 100.0, 0.3, 2.0)
			Sfx.play("hit", 0.15, 0.0)
	if dash_t <= 0.0:
		roll = 0.0
		w.shake(0.15)
		if has(MutationData.SHOCK_ROLL):  # shock roll: a ring of spikes where the roll ends
			for i in 6:
				_erupt(player.global_position + Vector2.from_angle(TAU * i / 6.0) * Vector2(30, 22), float(Game.stats.damage) * 1.5 * power())


## Fading magenta copy of the current frame (dash trail).
func _ghost() -> void:
	var src := player.body.body
	var g := Sprite2D.new()
	g.texture = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	g.offset = src.offset
	g.flip_h = src.flip_h
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.modulate = Color(1.0, 0.3, 1.0, 0.85)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	Game.world.effects.add_child(g)
	g.global_transform = src.global_transform
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.3)
	tw.tween_callback(g.queue_free)


# ---------------------------------------------------------------- eruptions

func _auto_erupt() -> void:
	var w := Game.world
	var reach := w.aim_range()
	var pool: Array[Enemy] = []
	for n in w.enemy_cache:
		var e := n as Enemy
		if e != null and is_instance_valid(e) and e.targetable and e.global_position.distance_to(player.global_position) < reach:
			pool.append(e)
	if pool.is_empty():
		return
	var count := (2 if has(MutationData.BROOD) else 1) + (1 if has(MutationData.FRENZY) else 0)
	pool.shuffle()
	for i in mini(count, pool.size()):
		var pos := pool[i].global_position
		w.telegraph_circle(pos, 14.0, 0.3)
		pending_erupts.append({"pos": pos, "t": 0.3})


func _tick_erupts(delta: float) -> void:
	for i in range(pending_erupts.size() - 1, -1, -1):
		var pe: Dictionary = pending_erupts[i]
		pe.t = float(pe.t) - delta
		if float(pe.t) <= 0.0:
			pending_erupts.remove_at(i)
			_erupt(pe.pos, float(Game.stats.damage) * 2.5 * power())


## Tentacles and spikes burst out of the floor at pos, hurting aliens around it.
func _erupt(pos: Vector2, dmg: float) -> void:
	var w := Game.world
	var f := AnimFx.spawn(w.entities, "inf_erupt", "erupt", pos, 0.14)
	f.flip_h = randf() < 0.5
	f.animation_finished.disconnect(f.queue_free)
	f.animation_finished.connect(func() -> void:
		var tw := f.create_tween()
		tw.tween_property(f, "modulate:a", 0.0, 0.2)
		tw.tween_callback(f.queue_free))
	w.add_stain(pos, GOO, 1.4)
	w.burst(pos + Vector2(0, -4), MAGENTA, 8, 70.0, 0.35, 2.0, 120.0, Vector2.UP, 0.8)
	Sfx.play("land", 0.15, -10.0)
	if dmg <= 0.0:
		return
	for n in w.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		if e.global_position.distance_to(pos) < 18.0 + e.radius:
			e.take_damage(dmg, Vector2.ZERO)
			e.stun(0.7)
	w.shake(0.12)


# ---------------------------------------------------------------- eye missiles

func _fire_missiles() -> void:
	if _nearest(Game.world.aim_range()) == null:
		return
	var n := 3 if has(MutationData.APEX) else (2 if has(MutationData.BROOD) else 1)
	for i in n:
		var m := InfMissile.new()
		m.damage = float(Game.stats.damage) * 3.0 * power()
		m.vel = Vector2(randf_range(-0.8, 0.8) + (i - (n - 1) * 0.5), -1.0).normalized() * 130.0
		Game.world.effects.add_child(m)
		m.global_position = player.global_position + Vector2(-player.facing * 5.0, -20.0)
	Sfx.play("spit", 0.1, -2.0)


# ---------------------------------------------------------------- slime

func _drip(delta: float, every: float) -> void:
	goo_t -= delta
	if goo_t > 0.0:
		return
	goo_t = every
	var g := Sprite2D.new()
	var sf := Art.frames("inf_goo")
	g.texture = sf.get_frame_texture("bits", randi() % sf.get_frame_count("bits"))
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.scale = Vector2.ONE * randf_range(0.12, 0.2)
	g.rotation = randf() * TAU
	Game.world.effects.add_child(g)
	g.global_position = player.global_position + Vector2(randf_range(-7, 7), randf_range(-20, -6))
	var tw := g.create_tween()
	tw.tween_property(g, "position:y", g.position.y + randf_range(8, 14), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(g, "modulate:a", 0.0, 0.4).set_delay(0.15)
	tw.tween_callback(g.queue_free)


func _goo_splash(c: Vector2, count: int, speed: float) -> void:
	var sf := Art.frames("inf_goo")
	for i in count:
		var g := Sprite2D.new()
		g.texture = sf.get_frame_texture("bits", randi() % sf.get_frame_count("bits"))
		g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		g.scale = Vector2.ONE * randf_range(0.15, 0.28)
		g.rotation = randf() * TAU
		Game.world.effects.add_child(g)
		g.global_position = c
		var to := c + Vector2.from_angle(randf() * TAU) * randf_range(0.4, 1.0) * speed * 0.35
		var tw := g.create_tween()
		tw.tween_property(g, "global_position", to, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(g, "rotation", g.rotation + randf_range(-4, 4), 0.45)
		tw.tween_property(g, "modulate:a", 0.0, 0.25)
		tw.tween_callback(g.queue_free)


func _nearest(max_d: float) -> Enemy:
	var best: Enemy = null
	var best_d := max_d
	for n in Game.world.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		var d := e.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
