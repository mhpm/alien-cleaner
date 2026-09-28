class_name Infected
extends Node2D
## Infected mode (crew upgrade "Infected Mode" in the shop, Game.perm.infected = level 1-5).
## Cleaning aliens fills the infection meter (ring around the ability button); when it is
## full the ability button mutates the astronaut into the tentacle monster
## (assets/sprites/infected, cut by tools/slice_sprites.py) for duration() seconds:
## faster, tougher, faster plasma-comet shots, an automatic tentacle slash, tentacles
## erupting under aliens, homing eye missiles, a slime aura and a rolling dash on the
## ability button. Lives under the Player, which asks it for multipliers and animations.

const DURATION := 10.0  # + 2 s per extra level
const TRANSFORM_TIME := 1.15
const BURST_AT := 0.32  # seconds before the end of the transformation: shockwave
const REVERT_TIME := 0.35
const SLASH_TIME := 0.28
const SLASH_RANGE := 36.0
const DASH_TIME := 0.24
const DASH_SPEED := 330.0
const DASH_CD := 0.9
const MAGENTA := Color("ff3df0")
const GOO := Color("c42bd6")
## mutant plasma comets (inf_shot); damage is multiplied by power()
const SHOT_TIER := {"name": "Mutant Plasma", "art": "inf_shot", "scale": 0.085, "dmg": 1.0,
		"hit_r": 5.0, "speed": 265.0, "pierce": 1}

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
	return DURATION + 2.0 * (level - 1)


## Damage multiplier of everything the mutant does.
func power() -> float:
	return 1.6 + 0.15 * (level - 1)


func can_transform() -> bool:
	return unlocked() and charge >= 1.0 and not active and not transforming and not reverting and not player.dead


func speed_mult() -> float:
	return 1.4 if active else 1.0


func fire_mult() -> float:
	return 0.45 if active else 1.0


func damage_taken_mult() -> float:
	return 0.5 if active else 1.0


## True while nothing can hurt the player (mutating, rolling).
func untouchable() -> bool:
	return transforming or dash_t > 0.0


## Animation the mutant must show over the normal idle/walk choice ("" = none).
func override_anim() -> String:
	if transforming or reverting:
		return "transform"  # driven here (forwards / backwards)
	if dash_t > 0.0:
		return "dash"
	if slash_t > 0.0:
		return "slash"
	return ""


func dash_velocity() -> Vector2:
	return dash_dir * DASH_SPEED if dash_t > 0.0 else Vector2.INF


func add_charge(v: float) -> void:
	if not unlocked() or active or transforming or reverting:
		return
	charge = minf(1.0, charge + v)
	if charge >= 1.0 and not announced:
		announced = true
		Game.world.hud.banner("MUTATION READY!", MAGENTA, 26, 0.7)
		Sfx.play("charge", 0.0, -4.0)


func on_kill(e: Enemy) -> void:
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
	player.body.set_form("infected")
	player.body.play("transform")
	var w := Game.world
	Sfx.play("mutate", 0.0)
	Sfx.play("roar", 0.05, -6.0)
	w.shake(0.35)
	w.hud.tint_flash(Color(0.85, 0.1, 0.95), 0.3, 0.9)
	w.ring(_center(), 30.0, MAGENTA, 0.5, 2.0)


func _transform_burst() -> void:
	burst_done = true
	var w := Game.world
	var c := _center()
	w.ring(c, 95.0, MAGENTA, 0.55, 5.0, true)
	w.ring(c, 60.0, Color.WHITE, 0.3, 3.0)
	w.burst(c, MAGENTA, 44, 190.0, 0.6, 2.5)
	w.burst(c, Color.WHITE, 14, 90.0, 0.3, 2.0)
	_goo_splash(c, 16, 150.0)
	w.shake(1.0)
	w.hitstop(140)
	Sfx.play("explode", 0.05)
	Sfx.play("roar", 0.05, 0.0)
	w.hud.banner("INFECTED!", MAGENTA, 46, 0.9)
	w.hud.tint_flash(Color(1.0, 0.3, 1.0), 0.45, 0.5)
	for i in 8:
		_erupt(player.global_position + Vector2.from_angle(TAU * i / 8.0 + 0.2) * Vector2(52, 40), 0.0)
	var dmg := float(Game.stats.damage) * 3.0 * power()
	for n in w.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		var d := e.global_position - player.global_position
		if d.length() < 95.0 + e.radius:
			e.take_damage(dmg, d.normalized() * 1.5)
			e.push(d.normalized() * 260.0)
			e.stun(0.9)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		var shot := n as EnemyShot
		if shot != null and shot.global_position.distance_to(c) < 95.0:
			shot.pop()


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


func _revert() -> void:
	active = false
	reverting = true
	state_t = REVERT_TIME
	slash_t = 0.0
	dash_t = 0.0
	player.locked = true
	var spr := player.body.body
	spr.play_backwards("transform")
	spr.frame = 2
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
	aura.modulate.a = move_toward(aura.modulate.a, (0.55 + sin(t * 6.0) * 0.15) if (active or transforming) else 0.0, delta * 3.0)
	aura.scale = Vector2(2.4, 1.3) * (1.0 + sin(t * 6.0) * 0.06) * (1.6 if transforming else 1.0)
	_tick_erupts(delta)
	if transforming:
		state_t -= delta
		_drip(delta, 0.03)
		if not burst_done and state_t <= BURST_AT:
			_transform_burst()
		if state_t <= 0.0:
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
	erupt_cd -= delta
	if erupt_cd <= 0.0:
		erupt_cd = maxf(0.7, 1.4 - 0.1 * (level - 1))
		_auto_erupt()
	missile_cd -= delta
	if missile_cd <= 0.0:
		missile_cd = 2.2 - 0.15 * (level - 1)
		_fire_missiles()
	_drip(delta, 0.09)


func _center() -> Vector2:
	return player.global_position + Vector2(0, -11)


# ---------------------------------------------------------------- tentacle slash

func _update_slash(delta: float) -> void:
	slash_cd -= delta
	if slash_t > 0.0:
		slash_t -= delta
		if not slash_hit and slash_t <= SLASH_TIME - 0.1:
			_slash_hit()
		return
	if slash_cd > 0.0 or dash_t > 0.0:
		return
	var e := _nearest(SLASH_RANGE)
	if e == null:
		return
	slash_t = SLASH_TIME
	slash_hit = false
	slash_cd = 0.75
	var dx := e.global_position.x - player.global_position.x
	if absf(dx) > 1.0:
		player.facing = signf(dx)
	player.shoot_t = 0.0
	Sfx.play("slash", 0.1, -3.0)


func _slash_hit() -> void:
	slash_hit = true
	var w := Game.world
	var f := player.facing
	var c := player.global_position + Vector2(f * 16.0, -10.0)
	var dmg := float(Game.stats.damage) * 2.2 * power()
	var hit := false
	for n in w.enemy_cache:
		var e := n as Enemy
		if e == null or not is_instance_valid(e) or not e.targetable:
			continue
		var d := e.hit_center() - c
		if d.length() < 26.0 + e.radius:
			var dir := Vector2(f, 0).lerp(d.normalized(), 0.5).normalized()
			e.take_damage(dmg, dir * 1.5)
			e.push(dir * 180.0)
			w.burst(e.hit_center(), MAGENTA, 8, 90.0, 0.3, 2.0)
			hit = true
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		var shot := n as EnemyShot
		if shot != null and shot.global_position.distance_to(c) < 26.0:
			shot.pop()
	if hit:
		w.hitstop(30)
		w.shake(0.25)
		Sfx.play("hit", 0.1, 0.0)


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
	var count := 1 + (1 if level >= 3 else 0) + (1 if level >= 5 else 0)
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
	var n := 2 if level >= 4 else 1
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
