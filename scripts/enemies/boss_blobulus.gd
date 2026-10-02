class_name BossBlobulus
extends BossBase
## BLOBULUS (world 1 mini boss, wave 8): a one-eyed king of slime that floats on its own jelly.
## Calm (above half health), in turn:
##   bombs    ("charge") lobs swell bombs round you: they land, their cores SWELL (a circle on
##            the floor shows the blast) and burst, leaving sticky goo that slows you. They
##            come down in a ring, so the way out is between two of them
##   geysers  sinks into its own puddle and a CHAIN of geysers runs from it towards you, one
##            pool after another (each warns with a ring before it erupts), and each leaves
##            a patch of goo
##   split    cracks and breaks into little floating eyes (bloblings): while any is alive its
##            body is hard (-50% damage taken). Kill them all and it is left DIZZY (+60%); leave
##            them and, after a while, they fly back and MERGE into it, healing it
##   flop     bounces three times after you, each landing where you stood a moment ago (a
##            circle marks it), with a splash of droplets; the last one is the biggest and
##            leaves a pool, and then it lies there tired (+35%)
## OVERCHARGED (under half health): sparks crawl over it, its shots vanish, its goo burns, and
##   reaction every patch of goo on the floor flashes and ERUPTS in a geyser: the more of it you
##            walked through, the more there is to get out of
## MELTDOWN (under 20%): more of everything and its babies are bigger.
## Melts into a puddle (the set's "death").

const CALM := ["bombs", "geysers", "split", "flop", "bombs", "geysers", "flop", "split"]
const FURY := ["reaction", "bombs", "flop", "geysers", "split", "reaction", "bombs", "flop", "geysers"]
const FIGHT_SECS := 45.0  # mini boss: a shorter fight than the final bosses
const CHAIN_STEP := 26.0
const CHAIN_WARN := 0.9
const GEYSER_R := 15.0
const BROOD_TIME := 9.0
const BROOD_ARMOR := 0.5
const MAX_BABIES := 8
const FLOP_TIME := 0.6
const FLOP_R := 30.0
const FURY_ARMOR := 0.85
const DESPERATE_ARMOR := 0.75
const GASP_ARMOR := 1.35
const STUN_ARMOR := 1.6
const DESPERATE_AT := 0.2
const SLIME := Color("5fd0ff")
const GLOW := Color("b8ff3a")

var pattern_i := 0
var furious := false
var desperate := false
var submerged := false
var strafe := 1.0
var babies: Array[Blobling] = []
var flops_left := 0
var flop_from := Vector2.ZERO
var flop_to := Vector2.ZERO
var flop_t := 0.0


func _init_ai() -> void:
	_size_to_player(FIGHT_SECS)
	state = "intro"
	state_t = 1.4
	Sfx.play("roar", 0.0)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	if not furious and hp < max_hp * 0.5 and state != "intro" and not submerged:
		_enrage()
	elif furious and not desperate and hp < max_hp * DESPERATE_AT and not submerged:
		_desperate()
	if state not in ["flop_air", "sink", "pool"] and to_p.x != 0.0:
		face = signf(to_p.x)
	if state not in ["flop_air", "flop_prep"]:
		air = 3.0 + sin(t * 3.0) * 1.5  # floating on its jelly
	match state:
		"intro", "roar":
			squash = Vector2(1.0 + sin(t * 40.0) * 0.05, 1.0)
			if state_t <= 0.0:
				_next()
		"drift":
			if state_t <= 0.0:
				_next()
			return _drift(to_p, 1.0)
		"bomb_aim":
			squash = Vector2.ONE * (1.0 + 0.1 * (1.0 - clampf(state_t / 0.6, 0.0, 1.0)))
			if state_t <= 0.0:
				_throw_bombs()
				_after(1.0)
		"sink":
			if state_t <= 0.0:
				state = "pool"
				state_t = CHAIN_WARN + 0.14 * _chain_len() + 0.3
		"pool":
			if state_t <= 0.0:
				_rise()
		"split_wind":
			sprite.position.x = sin(t * 55.0) * 1.0  # the shell about to give
			if state_t <= 0.0:
				sprite.position.x = 0.0
				_split()
		"brood":
			return _brood(delta, to_p)
		"reunite":
			squash = Vector2.ONE * (1.0 + sin(t * 30.0) * 0.05)
			if state_t <= 0.0:
				_after(0.8)
		"flop_prep":
			squash = Vector2(1.2, 0.8)
			if state_t <= 0.0:
				_flop_jump()
		"flop_air":
			return _flop(delta)
		"gasp", "stun":
			sprite.position.x = sin(t * 14.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				armor = _base_armor()
				_after(0.5)
		"react":
			squash = Vector2.ONE * (1.0 + sin(t * 36.0) * 0.05)
			if state_t <= 0.0:
				_after(0.7)
	return Vector2.ZERO


func _contact() -> void:
	if submerged:
		return
	super._contact()


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	if submerged:
		return
	super.take_damage(amount, dir, crit)


## Healing from a merging blobling.
func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	Game.world.popup_text(hit_center() + Vector2(randf_range(-8, 8), -22), "+%d" % int(amount), GLOW, 10)
	squash = Vector2(1.15, 0.9)


func _base_armor() -> float:
	if _brood_alive() > 0:
		return BROOD_ARMOR
	return DESPERATE_ARMOR if desperate else (FURY_ARMOR if furious else 1.0)


func _after(rest: float) -> void:
	state = "drift"
	state_t = rest * (0.7 if desperate else (0.85 if furious else 1.0))
	squash = Vector2.ONE


func _lead(k: float) -> Vector2:
	var p := player()
	return p.global_position + p.velocity * k


func _drift(to_p: Vector2, k: float) -> Vector2:
	var dist := to_p.length()
	var toward := to_p.normalized() * (0.7 if dist > 115.0 else (-0.7 if dist < 70.0 else 0.0))
	var v := (to_p.normalized().orthogonal() * strafe * 0.7 + toward).normalized() * speed * (1.4 if furious else 1.1) * k
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
		"bombs":
			state = "bomb_aim"
			state_t = 0.6
			Sfx.play("charge", 0.0, -4.0)
		"geysers":
			_start_chain()
		"split":
			if _brood_alive() > 0 or get_tree().get_nodes_in_group("enemies").size() > 90:
				_next()
				return
			state = "split_wind"
			state_t = 0.8
			Sfx.play("roar", 0.5, -6.0)
		"flop":
			flops_left = 4 if desperate else 3
			state = "flop_prep"
			state_t = 0.35
			Sfx.play("charge", 0.3, -6.0)
		"reaction":
			_reaction()


# ---------------------------------------------------------------- phases

func _enrage() -> void:
	furious = true
	pattern_i = 0
	state = "roar"
	state_t = 1.2
	sprite.position.x = 0.0
	speed *= 1.15
	armor = _base_armor()
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	w.shake(1.0)
	w.hud.banner("OVERCHARGED!", GLOW, 34, 1.2)
	w.hud.tint_flash(GLOW, 0.35, 0.7)
	w.burst(hit_center(), SLIME, 30, 140.0, 0.6, 2.5, 60.0)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	_ring(10, randf() * TAU, 80.0, 0.4, "blob_drop")
	var p := player()
	var d := p.global_position - global_position
	if d.length() < 90.0:
		p.knock = d.normalized() * 240.0


func _desperate() -> void:
	desperate = true
	armor = _base_armor()
	speed *= 1.1
	var w := Game.world
	w.shake(0.8)
	w.hud.banner("MELTDOWN!", Color("ff5566"), 32, 1.0)
	w.hud.tint_flash(Color("ff5566"), 0.3, 0.6)
	Sfx.play("roar", 0.0, 2.0)


# ---------------------------------------------------------------- bombs

## Swell bombs in a ring round the astronaut (the first one where they are heading).
func _throw_bombs() -> void:
	var n := 5 if desperate else (4 if furious else 3)
	var from := hit_center()
	var c := _lead(0.4)
	for i in n:
		var b := BlobBomb.new()
		b.from = from
		b.land = c if i == 0 else c + Vector2.from_angle(TAU * i / n + randf() * 0.4) * randf_range(48.0, 72.0)
		b.damage = contact_damage
		b.burn = furious
		b.delay = i * 0.18
		Game.world.effects.add_child(b)
	squash = Vector2(0.88, 1.12)
	Sfx.play("slash", 0.0, -4.0)


# ---------------------------------------------------------------- geysers

func _chain_len() -> int:
	return 9 if desperate else 7


## Sinks into its puddle and lays out the chain(s): rings first, eruptions one after another.
func _start_chain() -> void:
	state = "sink"
	state_t = 0.4
	submerged = true
	shadow.visible = false
	Sfx.play("dash", 0.2, -4.0)
	Game.world.burst(global_position, SLIME, 12, 70.0, 0.4, 2.0, -40.0)
	var base_dir := (_lead(0.4) - global_position).normalized()
	var spread := [0.0]
	if furious:
		spread = [-0.55, 0.0, 0.55]
	for a in spread:
		_lay_chain(base_dir.rotated(float(a)))


func _lay_chain(dir: Vector2) -> void:
	var n := _chain_len()
	var dmg := contact_damage * 0.9
	for i in n:
		var at := global_position + dir * (CHAIN_STEP * (i + 1))
		var delay := CHAIN_WARN + 0.14 * i
		var tg := Telegraph.new()
		tg.position = at
		tg.radius = GEYSER_R
		tg.dur = delay
		tg.color = SLIME
		Game.world.decals.add_child(tg)
		var burn := contact_damage * 0.25 if furious else 0.0
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_instance_valid(Game.world):
				BossBlobulus.geyser(at, dmg, GEYSER_R)
				BossBlobulus.goo(at, 15.0, 4.0, burn))


func _rise() -> void:
	submerged = false
	shadow.visible = true
	squash = Vector2(0.7, 1.4)
	Game.world.burst(global_position, SLIME, 10, 80.0, 0.4, 2.0, 40.0)
	_after(0.9)


## A burst of slime from the floor at `at`: the visual and the damage.
static func geyser(at: Vector2, dmg: float, r: float) -> void:
	var w := Game.world
	AnimFx.spawn(w.effects, "blob_geyser", "pop", at, r * 2.4 / 170.0)
	w.burst(at, SLIME, 6 + int(r * 0.2), 90.0, 0.45, 2.0, 70.0)
	w.shake(0.12 + r * 0.008)
	Sfx.play("pop", 0.3, -7.0)
	if dmg <= 0.0:
		return
	var p := w.player
	if not p.dead:
		var off := p.global_position - at
		if Vector2(off.x, off.y / 0.75).length() < r:  # the circles are drawn squashed
			p.take_damage(dmg, at)


## A patch of BLOBULUS's goo (it can set them off later).
static func goo(at: Vector2, r: float, life: float, burn: float) -> StickyGoo:
	var g := StickyGoo.new()
	g.slime_colors()
	g.radius = r
	g.life = life
	g.damage = burn
	g.tag = "blobulus"
	g.position = at
	Game.world.decals.add_child(g)
	return g


# ---------------------------------------------------------------- split / brood

func _brood_alive() -> int:
	var n := 0
	for b in babies:
		if is_instance_valid(b) and not b.dead:
			n += 1
	return n


func _split() -> void:
	var w := Game.world
	var n := 6 if desperate else (5 if furious else 4)
	n = mini(n, MAX_BABIES)
	var m := _minion_mults()
	babies.clear()
	for i in n:
		var pos := global_position + Vector2.from_angle(TAU * i / n + randf() * 0.5) * 26.0
		var b := w.spawn_enemy("blobling", pos, m.x, 1.0, false, true, m.y) as Blobling
		b.boss = self
		b.heal_share = 0.04 if desperate else 0.03
		b.knock = (pos - global_position).normalized() * 160.0
		babies.append(b)
		w.burst(pos, SLIME, 8, 60.0, 0.35, 2.0, -20.0)
	w.shake(0.5)
	w.ring(hit_center(), 30.0, SLIME, 0.4, 3.0)
	Sfx.play("explode", 0.4, -5.0)
	armor = BROOD_ARMOR
	tint = Color(0.7, 0.85, 1.4)  # its body has gone hard
	state = "brood"
	state_t = BROOD_TIME
	w.popup_text(hit_center() + Vector2(0, -30), "KILL THE BROOD!", SLIME, 11)


func _brood(delta: float, to_p: Vector2) -> Vector2:
	if _brood_alive() == 0:
		_brood_cleared()
		return Vector2.ZERO
	if state_t <= 0.0:
		_reunite()
		return Vector2.ZERO
	return _drift(to_p, 0.6)


## Every blobling dead: the shell is open and the boss is dizzy.
func _brood_cleared() -> void:
	tint = Color.WHITE
	state = "stun"
	state_t = 2.0
	armor = STUN_ARMOR
	var w := Game.world
	w.ring(hit_center(), 34.0, GLOW, 0.4, 3.0)
	w.popup_text(hit_center() + Vector2(0, -30), "BROOD CLEARED! HIT IT!", GLOW, 11)
	Sfx.play("freeze", 0.0, 2.0)


## Time is up: whatever is left flies back and merges (each heals the boss).
func _reunite() -> void:
	tint = Color.WHITE
	for b in babies:
		if is_instance_valid(b) and not b.dead:
			b.reunite()
	state = "reunite"
	state_t = 1.4
	armor = DESPERATE_ARMOR if desperate else (FURY_ARMOR if furious else 1.0)
	Game.world.popup_text(hit_center() + Vector2(0, -30), "THEY MERGE!", SLIME, 11)
	Sfx.play("charge", 0.5, -4.0)


# ---------------------------------------------------------------- flop

## Up for a bounce: it lands where the astronaut is heading (a circle marks the spot).
func _flop_jump() -> void:
	flop_from = global_position
	flop_to = _lead(0.45)
	flop_t = FLOP_TIME
	state = "flop_air"
	var big := flops_left == 1
	var tg := Telegraph.new()
	tg.position = flop_to
	tg.radius = FLOP_R * (1.35 if big else 1.0)
	tg.dur = FLOP_TIME
	tg.color = SLIME
	Game.world.decals.add_child(tg)
	squash = Vector2(0.8, 1.25)
	Sfx.play("dash", 0.4, -8.0)


func _flop(delta: float) -> Vector2:
	flop_t -= delta
	var k := 1.0 - clampf(flop_t / FLOP_TIME, 0.0, 1.0)
	air = sin(k * PI) * 70.0
	face = signf(flop_to.x - flop_from.x) if absf(flop_to.x - flop_from.x) > 1.0 else face
	if flop_t <= 0.0:
		_land()
		return Vector2.ZERO
	return (flop_to - global_position) / maxf(flop_t, 0.05)


func _land() -> void:
	air = 0.0
	var w := Game.world
	var big := flops_left == 1
	var r := FLOP_R * (1.35 if big else 1.0)
	squash = Vector2(1.5, 0.6)
	w.shake(0.7 if big else 0.45)
	Sfx.play("explode", 0.1, -3.0 if big else -6.0)
	AnimFx.spawn(w.effects, "blob_geyser", "pop", global_position, r * 2.4 / 170.0)
	w.burst(global_position, SLIME, 18 if big else 10, 120.0, 0.45, 2.5, 60.0)
	var p := player()
	if not p.dead:
		var off := p.global_position - global_position
		if Vector2(off.x, off.y / 0.75).length() < r:
			p.take_damage(contact_damage * (1.4 if big else 1.0), global_position)
			p.knock += off.normalized() * 200.0
	_ring(10 if big else 6, randf() * TAU, 80.0, 0.35, "blob_drop")
	if big:
		BossBlobulus.goo(global_position, 34.0, 6.0, contact_damage * 0.25 if furious else 0.0)
	flops_left -= 1
	if flops_left > 0:
		state = "flop_prep"
		state_t = 0.18
		return
	if furious:
		state = "stun"
		state_t = 2.0
		armor = STUN_ARMOR
		w.ring(hit_center(), 34.0, GLOW, 0.4, 3.0)
		w.popup_text(hit_center() + Vector2(0, -30), "DIZZY! HIT IT!", GLOW, 12)
		Sfx.play("freeze", 0.0, 2.0)
	else:
		state = "gasp"
		state_t = 1.1
		armor = GASP_ARMOR
		w.popup_text(hit_center() + Vector2(0, -30), "TIRED!", GLOW, 11)


# ---------------------------------------------------------------- reaction

## Spits a few patches round the astronaut if the floor is bare, then sets every patch off.
func _reaction() -> void:
	var w := Game.world
	var mine: Array[StickyGoo] = []
	for n in get_tree().get_nodes_in_group("sticky_goo"):
		var g := n as StickyGoo
		if g != null and g.tag == "blobulus":
			mine.append(g)
	var p := player().global_position
	var burn := contact_damage * 0.25
	while mine.size() < 5:
		mine.append(BossBlobulus.goo(p + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 80.0), 18.0, 6.0, burn))
	var dmg := contact_damage * 1.0
	for g in mine:
		g.life = maxf(g.life, g.t + 2.5)
		g.detonate(1.0 + randf() * 0.4, dmg)
	state = "react"
	state_t = 1.6
	w.popup_text(hit_center() + Vector2(0, -30), "GET OFF THE GOO!", GLOW, 11)
	Sfx.play("roar", 0.4, -2.0)
	w.shake(0.3)


# ---------------------------------------------------------------- effects

func _anim_name() -> String:
	if hurt_t > 0.0 and state in ["drift", "intro"]:
		return "hurt"
	match state:
		"bomb_aim":
			return "charge"
		"sink", "pool":
			return "sink"
		"split_wind":
			return "crack"
		"brood":
			return "angry"
		"flop_prep", "flop_air":
			return "hop"
		"gasp":
			return "tired"
		"stun":
			return "stun"
		"react", "roar":
			return "fury"
	return "fury" if furious else "walk"


func _on_death() -> void:
	var w := Game.world
	submerged = false
	var fx := AnimFx.spawn(w.decals, "blobulus", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	for n in get_tree().get_nodes_in_group("blob_bombs"):
		n.queue_free()
	for b in babies:
		if is_instance_valid(b) and not b.dead:
			w.burst(b.global_position, SLIME, 8, 60.0, 0.3, 2.0)
			b.dead = true
			b.remove_from_group("enemies")
			b.queue_free()
	var c := hit_center()
	for i in 6:
		get_tree().create_timer(0.2 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(w):
				var at := c + Vector2(randf_range(-24, 24), randf_range(-8, 14))
				BossBlobulus.geyser(at, 0.0, 12.0)
				w.shake(0.4))
	Sfx.play("roar", 0.2, -2.0)
