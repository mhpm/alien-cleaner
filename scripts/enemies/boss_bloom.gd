class_name BossBloom
extends BossBase
## BLOOM COLOSSUS (world 8 BIODOME final boss): the greenhouse robot, overgrown, with a
## lotus on its head and one big eye. It plods round the fight and, in turn:
##   seeds     spits seeds at where you are heading: they slow down, swell into a flower
##             (a circle marks the spot) and burst into a ring of spores
##   roots     its eye glows green and a CHAIN of circles runs from it towards you; root
##             spikes erupt along it one after another (sidestep the line)
##   sprouts   calls flower pods out of the soil (marked circles): little one-eyed
##             runners (max MAX_SPROUTS of its own)
##   bud       PHOTOSYNTHESIS: it closes up into a hard bud (BUD_ARMOR) and starts healing.
##             Hit it hard enough in time (BREAK_SHARE of its health) and the bud CRACKS:
##             it is left dizzy (STUN_ARMOR). If not, it blooms: heals HEAL_SHARE and a
##             nova of spores and a ring of roots burst out of it
## WILD BLOOM (under half health): it roars, its shots vanish, a ring of roots bursts
##   under it, it glows and gets faster and pushier (it walks AT you), every PULSE_EVERY
##   seconds it lets out a ring of spores, two chains of roots, five seeds, and it adds
##   thorns    two rings of root spikes round itself, each with a gap on a different side:
##             go through the gap of the first, then of the second
##   garden    flowers planted in a ring round YOU (circles), each bursts into spores
## OVERGROWN (under 20%): three chains, a seed in the middle of the garden, shorter rests.
## Dies bursting into petals and light, leaving its overgrown wreck.

const CALM := ["seeds", "roots", "sprouts", "seeds", "bud", "roots"]
const FURY := ["roots", "thorns", "seeds", "garden", "bud", "sprouts", "roots", "garden", "thorns", "seeds"]
const SEED_TRAVEL := 1.0  # seconds a seed flies before it stops
const SEED_LIFE := 1.6  # then it blooms and bursts
const SEED_DRAG := 1.6
const SPORE_SPEED := 70.0
const ROOT_R := 18.0
const ROOT_STEP := 32.0
const ROOT_WARN := 0.65
const ROOT_GAP := 0.12  # seconds between two roots of a chain
const MAX_SPROUTS := 6
const BUD_TIME := 3.5
const BUD_ARMOR := 0.6
const BREAK_SHARE := 0.07
const HEAL_SHARE := 0.06
const GARDEN_R := 72.0
const GARDEN_WARN := 1.3
const PULSE_EVERY := 4.0
const FURY_ARMOR := 0.8
const DESPERATE_ARMOR := 0.7
const STUN_ARMOR := 1.6
const PETAL := Color("ff9ad5")
const LEAF := Color("8cff5a")

var pattern_i := 0
var furious := false
var desperate := false
var strafe := 1.0
var shots_left := 0
var fire_t := 0.0
var pulse_t := PULSE_EVERY
var bud_dmg := 0.0
var sprouts: Array[Enemy] = []


func _init_ai() -> void:
	_size_to_player()
	state = "intro"
	state_t = 1.4
	Sfx.play("roar", 0.4)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	if not furious and hp < max_hp * 0.5 and state != "bud":
		_enrage()
	elif furious and not desperate and hp < max_hp * 0.2 and state != "bud":
		_desperate()
	if state in ["intro", "drift", "seeds", "roots_wind", "summon"] and absf(to_p.x) > 2.0:
		face = signf(to_p.x)
	if furious and state == "drift":
		pulse_t -= delta
		if pulse_t <= 0.0:
			pulse_t = PULSE_EVERY
			_ring(10, randf() * TAU, SPORE_SPEED, 0.45, "bloom_spore")
			Game.world.ring(hit_center(), 26.0, LEAF, 0.3, 2.0)
	match state:
		"intro", "roar":
			if state_t <= 0.0:
				_after(0.5)
			return Vector2.ZERO
		"drift":
			if state_t <= 0.0:
				_next()
			return _drift(to_p)
		"seeds":
			fire_t -= delta
			if fire_t <= 0.0 and shots_left > 0:
				shots_left -= 1
				fire_t = 0.3
				_seed(shots_left)
			if shots_left <= 0 and fire_t <= 0.0:
				_after(0.8)
			return Vector2.ZERO
		"roots_wind", "summon", "thorns_wind", "garden_wind":
			if state_t <= 0.0:
				_after(0.9)
			return Vector2.ZERO
		"bud":
			if randf() < delta * 10.0:
				Game.world.burst(hit_center() + Vector2(randf_range(-18, 18), randf_range(-10, 6)), Color("fff3a0"), 1, 20.0, 0.6, 2.0, -40.0)
			if bud_dmg >= max_hp * BREAK_SHARE:
				_crack()
			elif state_t <= 0.0:
				_bloom()
			return Vector2.ZERO
		"stun":
			if state_t <= 0.0:
				armor = _base_armor()
				_after(0.4)
			return Vector2.ZERO
	return Vector2.ZERO


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	var before := hp
	super.take_damage(amount, dir, crit)
	if state == "bud":
		bud_dmg += maxf(0.0, before - hp)


func _base_armor() -> float:
	return DESPERATE_ARMOR if desperate else (FURY_ARMOR if furious else 1.0)


func _after(rest: float) -> void:
	state = "drift"
	state_t = rest * (0.6 if desperate else (0.8 if furious else 1.0))


func _drift(to_p: Vector2) -> Vector2:
	var dist := to_p.length()
	var v: Vector2
	if furious:  # wild bloom: it walks at you
		v = (to_p.normalized() * 0.8 + to_p.normalized().orthogonal() * strafe * 0.4).normalized() * speed * 1.2
	else:
		var toward := to_p.normalized() * (0.6 if dist > 120.0 else (-0.6 if dist < 75.0 else 0.0))
		v = (to_p.normalized().orthogonal() * strafe * 0.7 + toward).normalized() * speed
	var f := _fence()
	if f != null and not f.holds(global_position + v * 0.25, 30.0):
		v = (f.global_position - global_position).normalized() * speed
	return v


func _lead(k: float) -> Vector2:
	var p := player()
	return p.global_position + p.velocity * k


func _next() -> void:
	var list: Array = FURY if furious else CALM
	var step: String = list[pattern_i % list.size()]
	pattern_i += 1
	_next_move(step)


func _next_move(step: String) -> void:
	strafe = -strafe
	var w := Game.world
	match step:
		"seeds":
			state = "seeds"
			shots_left = 5 if furious else 3
			fire_t = 0.25
			Sfx.play("charge", 0.3, -6.0)
		"roots":
			state = "roots_wind"
			state_t = 0.9
			var chains := 3 if desperate else (2 if furious else 1)
			var a := (_lead(0.4) - global_position).angle()
			for i in chains:
				_root_chain(a + (i - (chains - 1) * 0.5) * 0.55)
			Sfx.play("roar", 0.5, -8.0)
		"sprouts":
			state = "summon"
			state_t = 0.8
			_summon(4 if furious else 3)
		"bud":
			state = "bud"
			state_t = BUD_TIME * (0.85 if furious else 1.0)
			bud_dmg = 0.0
			armor = BUD_ARMOR
			w.popup_text(hit_center() + Vector2(0, -40), "BREAK THE BUD!", PETAL, 12)
			w.telegraph_circle(global_position, 56.0, state_t)
			Sfx.play("charge", 0.0, -2.0)
		"thorns":
			state = "thorns_wind"
			state_t = 1.6
			var g := randf() * TAU
			_thorn_ring(48.0, g, 0.75)
			_thorn_ring(92.0, g + PI, 1.3)
			Sfx.play("roar", 0.3, -4.0)
		"garden":
			state = "garden_wind"
			state_t = 1.0
			_garden()


# ---------------------------------------------------------------- seeds

## A seed thrown to just ahead of the astronaut: it stops there and blooms.
func _seed(k: int) -> void:
	var w := Game.world
	var spread := (k - 2) * 26.0 if furious else (k - 1) * 30.0
	var p := player()
	var side := p.velocity.normalized().orthogonal() if p.velocity.length() > 5.0 else Vector2.RIGHT
	var target := w.room.open_near(_in_fence(_lead(0.6) + side * spread, 14.0))
	var from := hit_center()
	var d := target - from
	var s := w.spawn_enemy_shot(from, Vector2.ZERO, contact_damage * 0.7, "bloom_seed")
	# fixed after spawning: lands on the spot whatever the world's shot speed
	s.vel = d.normalized() * d.length() * SEED_DRAG / (1.0 - exp(-SEED_DRAG * SEED_TRAVEL))
	s.life = SEED_LIFE
	w.telegraph_circle(target, 22.0, SEED_LIFE)
	squash = Vector2(1.12, 0.9)
	Sfx.play("spit", 0.2, -4.0)


# ---------------------------------------------------------------- roots

## Root spikes erupting one after another from the boss along angle `a`.
func _root_chain(a: float) -> void:
	var w := Game.world
	var n := 7 if furious else 6
	for i in n:
		var at := global_position + Vector2.from_angle(a) * (40.0 + i * ROOT_STEP)
		if not w.room.bounds().has_point(at):
			break
		var warn := ROOT_WARN * (0.8 if desperate else 1.0) + i * ROOT_GAP
		w.telegraph_circle(at, ROOT_R, warn)
		get_tree().create_timer(warn, false).timeout.connect(BossBloom.root_burst.bind(at, ROOT_R, contact_damage * 1.1))


## A root spike bursting up at `at`: hurts the astronaut inside r (also used by thorns).
static func root_burst(at: Vector2, r: float, dmg: float) -> void:
	var w := Game.world
	if w == null or w.player == null:
		return
	AnimFx.spawn(w.effects, "bloom_roots", "pop", at, r / 60.0)
	w.burst(at, Color("b97a45"), 6, 50.0, 0.4, 2.0, 80.0)
	w.burst(at + Vector2(0, -10), PETAL, 4, 40.0, 0.5, 2.0)
	var off := w.player.global_position - at
	if not w.player.dead and Vector2(off.x, off.y / 0.75).length() < r:
		w.player.take_damage(dmg, at)
	Sfx.play("slash", 0.3, -12.0)


## A ring of root spikes round the boss with a gap (3 spikes left out) facing `gap`.
func _thorn_ring(r: float, gap: float, warn: float) -> void:
	var w := Game.world
	var n := int(TAU * r / 30.0)
	for i in n:
		var a := TAU * i / n
		if absf(angle_difference(a, gap)) < 0.5 * (40.0 / r) * 1.6:
			continue  # the way out
		var at := global_position + Vector2.from_angle(a) * r
		w.telegraph_circle(at, ROOT_R, warn)
		get_tree().create_timer(warn, false).timeout.connect(BossBloom.root_burst.bind(at, ROOT_R, contact_damage * 1.1))


# ---------------------------------------------------------------- sprouts, garden

func _summon(n: int) -> void:
	sprouts.assign(sprouts.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as Enemy).dead))
	n = mini(n, MAX_SPROUTS - sprouts.size())
	var w := Game.world
	var m := _minion_mults()
	for i in n:
		var at := w.room.open_near(_in_fence(global_position + Vector2.from_angle(TAU * i / maxi(n, 1) + randf()) * randf_range(40.0, 70.0), 20.0))
		w.telegraph_circle(at, 14.0, 0.7)
		get_tree().create_timer(0.7, false).timeout.connect(func() -> void:
			if dead or w != Game.world or w.player.dead:
				return
			w.burst(at, LEAF, 10, 60.0, 0.4, 2.0, 60.0)
			var e := w.spawn_enemy("bloom_sprout", at, m.x, 1.0, false, true, m.y)
			if e != null:
				sprouts.append(e))
	Sfx.play("spawn", 0.2, -4.0)


## Flowers planted in a ring round the astronaut (and one on him when overgrown).
func _garden() -> void:
	var w := Game.world
	var c := player().global_position
	var spots: Array[Vector2] = []
	var a0 := randf() * TAU
	for i in 6:
		spots.append(w.room.open_near(c + Vector2.from_angle(a0 + TAU * i / 6.0) * GARDEN_R))
	if desperate:
		spots.append(c)
	for p: Vector2 in spots:
		w.telegraph_circle(p, 20.0, GARDEN_WARN)
		get_tree().create_timer(GARDEN_WARN, false).timeout.connect(BossBloom.flower_burst.bind(p, contact_damage))
	Sfx.play("charge", 0.4, -4.0)


## A flower bursting open at `at`: hurts inside its circle and lets out 5 spores.
static func flower_burst(at: Vector2, dmg: float) -> void:
	var w := Game.world
	if w == null or w.player == null:
		return
	AnimFx.spawn(w.effects, "bloom_burst", "pop", at + Vector2(0, -8), 0.2)
	var off := w.player.global_position - at
	if not w.player.dead and Vector2(off.x, off.y / 0.75).length() < 20.0:
		w.player.take_damage(dmg, at)
	var a0 := randf() * TAU
	for i in 5:
		var d := Vector2.from_angle(a0 + TAU * i / 5.0)
		w.spawn_enemy_shot(at + Vector2(0, -8) + d * 6.0, d * SPORE_SPEED, dmg * 0.45, "bloom_spore").life = 2.0
	Sfx.play("pop", 0.3, -8.0)


# ---------------------------------------------------------------- bud

## Hit hard enough while closed: the bud cracks and it is left dizzy.
func _crack() -> void:
	var w := Game.world
	w.popup_text(hit_center() + Vector2(0, -36), "BUD CRACKED!", Color.WHITE, 13)
	w.burst(hit_center(), PETAL, 24, 120.0, 0.5, 2.5)
	w.shake(0.4)
	Sfx.play("explode", 0.4, -4.0)
	state = "stun"
	state_t = 2.6
	armor = STUN_ARMOR


## Nobody stopped it: it heals and blooms in a nova of spores and a ring of roots.
func _bloom() -> void:
	var w := Game.world
	hp = minf(max_hp, hp + max_hp * HEAL_SHARE)
	armor = _base_armor()
	w.popup_text(hit_center() + Vector2(0, -36), "+%d%%" % roundi(HEAL_SHARE * 100.0), LEAF, 13)
	AnimFx.spawn(w.decals, "bloom_ring", "pop", global_position + Vector2(0, 4), 0.42)
	_ring(16, randf() * TAU, SPORE_SPEED * 1.1, 0.5, "bloom_spore")
	_thorn_ring(56.0, randf() * TAU, 0.5)
	w.shake(0.4)
	Sfx.play("roar", 0.6, -2.0)
	_after(0.9)


# ---------------------------------------------------------------- phases

func _enrage() -> void:
	furious = true
	pattern_i = 0
	armor = FURY_ARMOR
	speed *= 1.25
	state = "roar"
	state_t = 1.2
	tint = Color(1.15, 1.05, 0.95)
	var w := Game.world
	Sfx.play("roar", 0.2, 3.0)
	w.shake(1.0)
	w.hud.banner("WILD BLOOM!", PETAL, 32, 1.2)
	w.hud.tint_flash(LEAF, 0.35, 0.7)
	AnimFx.spawn(w.decals, "bloom_ring", "pop", global_position + Vector2(0, 4), 0.5)
	w.burst(hit_center(), PETAL, 40, 150.0, 0.7, 2.5)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	var p := player()
	var d := p.global_position - global_position
	if d.length() < 100.0:
		p.knock = d.normalized() * 240.0


func _desperate() -> void:
	desperate = true
	armor = DESPERATE_ARMOR
	speed *= 1.1
	var w := Game.world
	w.shake(0.8)
	w.hud.banner("OVERGROWN!", LEAF, 32, 1.0)
	w.hud.tint_flash(LEAF, 0.3, 0.6)
	Sfx.play("roar", 0.0, 2.0)


func _anim_name() -> String:
	match state:
		"intro", "roar":
			return "fury" if furious else "angry"
		"seeds":
			return "shoot"
		"roots_wind", "thorns_wind", "garden_wind":
			return "fury" if furious else "angry"
		"summon":
			return "summon"
		"bud":
			return "bud"
		"stun":
			return "stun"
	return "fury" if furious and int(t * 2.0) % 4 == 0 else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.decals, "bloom", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	get_tree().create_timer(1.0, false).timeout.connect(BossBloom.leave_wreck.bind(global_position, base_scale, face < 0.0))
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	var c := hit_center()
	for i in 6:
		get_tree().create_timer(0.15 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(w):
				var at := c + Vector2(randf_range(-28, 28), randf_range(-16, 16))
				w.burst(at, PETAL, 16, 110.0, 0.6, 2.5)
				w.burst(at, Color("fff3a0"), 8, 70.0, 0.4, 2.0)
				w.shake(0.4)
				Sfx.play("explode", 0.3, -6.0))
	Sfx.play("roar", 0.5, -2.0)


## The overgrown wreck stays on the floor.
static func leave_wreck(at: Vector2, s: float, flip: bool) -> void:
	var w := Game.world
	if w == null:
		return
	var spr := Sprite2D.new()
	spr.texture = Art.frames("bloom_wreck").get_frame_texture("pop", 0)
	spr.centered = false
	spr.offset = Vector2(-spr.texture.get_width() * 0.5, -spr.texture.get_height())
	spr.scale = Vector2.ONE * s
	spr.flip_h = flip
	spr.position = at
	w.decals.add_child(spr)
