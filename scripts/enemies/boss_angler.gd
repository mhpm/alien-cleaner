class_name BossAngler
extends BossBase
## TOXIC ANGLER (world 3 mini boss, wave 8): a lantern pufferfish swollen with lab toxin.
## Calm (above half health), in turn:
##   bubbles  ("inflate", then "spit") spits big bubbles aimed where you are going; each
##            swells and bursts in mid air into a ring of droplets, so the danger is the
##            ring that arrives, not the bubble
##   lure     winks and its lantern PULLS you in (you can still walk away from it, only
##            slower) while its belly fills up; then it goes NOVA where it floats. Surviving
##            leaves it gasping (+35% damage)
##   dive     sinks into the floor and swims below it, untouchable, at speed, weaving round
##            you; every ripple it leaves behind turns into a GEYSER a moment later (the trail
##            is the danger). Then it stops under you: a circle marks where it SURFACES in a
##            big geyser, and it is left winded (dizzy, +60%, when furious)
##   mines    ("channel") orbits itself with spore mines, then hurls them round you; they
##            land, swell and burst, and leave a pool of toxic goo
## BLOATED (under half health): its shots vanish, and it adds
##   storm    swells up and spins, spewing two arms of droplets in a spiral while it drifts
##            at you: slip between the arms
## MELTDOWN (under 20%): three storm arms, more mines, faster dives, and the lure pulls
##   a second time before the nova goes off.
## Deflates and melts into a puddle of spines (the set's "death").

const CALM := ["bubbles", "lure", "dive", "mines", "bubbles", "dive", "lure"]
const FURY := ["storm", "lure", "dive", "mines", "bubbles", "dive", "storm", "mines"]
const FIGHT_SECS := 45.0  # mini boss: a shorter fight than the final bosses
const BUBBLE_SPEED := 75.0
const PULL_R := 200.0
const PULL_SPEED := 52.0  # the astronaut walks at 80: leaning away is slower, not impossible
const PULL_TIME := 1.8
const NOVA_R := 62.0
const SWIM_TIME := 2.6
const SURF_R := 36.0
const GEYSER_R := 17.0
const MINE_R := 28.0
const MINE_FLIGHT := 0.6
const ARM_TIME := 1.2
const FURY_ARMOR := 0.85
const DESPERATE_ARMOR := 0.75
const GASP_ARMOR := 1.35
const STUN_ARMOR := 1.6
const DESPERATE_AT := 0.2
const TOXIC := Color("a7f070")
const GLOW := Color("e6ff6a")

var pattern_i := 0
var furious := false
var desperate := false
var submerged := false
var strafe := 1.0
var emit_t := 0.0
var bubbles_left := 0
var storm_a := 0.0
var swim_t := 0.0
var weave := 0.0
var second_pull := false


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
	if not submerged:
		air = 5.0 + sin(t * 3.0) * 2.5  # drifting in the air like a balloon
		if state not in ["bubbles", "bubble_aim"] and to_p.x != 0.0:
			face = signf(to_p.x)
	if not submerged and randf() < delta * 5.0:  # toxin dripping off it
		Game.world.burst(global_position + Vector2(randf_range(-12, 12), -air - 8.0), TOXIC, 1, 15.0, 0.6, 1.5, 40.0)
	match state:
		"intro", "roar":
			squash = Vector2(1.0 + sin(t * 40.0) * 0.05, 1.0)
			if state_t <= 0.0:
				_next()
		"drift":
			if state_t <= 0.0:
				_next()
			return _drift(to_p)
		"bubble_aim":
			aim = (_lead(0.35) - hit_center()).normalized()
			face = signf(aim.x) if aim.x != 0.0 else face
			squash = Vector2.ONE * (1.0 + 0.12 * (1.0 - state_t / 0.55))
			if state_t <= 0.0:
				state = "bubbles"
				emit_t = 0.0
		"bubbles":
			emit_t -= delta
			if emit_t <= 0.0:
				_bubble()
				bubbles_left -= 1
				emit_t = 0.5 if not furious else (0.38 if not desperate else 0.3)
				if bubbles_left <= 0:
					_after(0.8)
		"lure_wink":
			if state_t <= 0.0:
				state = "lure_pull"
				state_t = PULL_TIME if not second_pull else 1.0
				Sfx.play("charge", 0.0, -2.0)
		"lure_pull":
			_pull(delta)
			var k := 1.0 - clampf(state_t / PULL_TIME, 0.0, 1.0)
			squash = Vector2.ONE * (1.0 + 0.3 * k + sin(t * 30.0) * 0.02)
			if state_t <= 0.0:
				_nova()
		"gasp":
			sprite.position.x = sin(t * 14.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				armor = _base_armor()
				_after(0.4)
		"stun":
			sprite.position.x = sin(t * 14.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				armor = _base_armor()
				_after(0.4)
		"sink":
			if state_t <= 0.0:
				_submerge()
		"swim":
			return _swim(delta, to_p)
		"surface_warn":
			squash = Vector2(1.0 + sin(t * 30.0) * 0.1, 1.0 - sin(t * 30.0) * 0.1)
			if randf() < 0.5:
				Game.world.burst(global_position + Vector2(randf_range(-SURF_R, SURF_R) * 0.6, 0), TOXIC, 1, 30.0, 0.4, 1.5, -60.0)
			if state_t <= 0.0:
				_surface()
		"mines":
			if randf() < delta * 14.0:
				Game.world.burst(hit_center() + Vector2.from_angle(randf() * TAU) * 28.0, TOXIC, 1, 20.0, 0.4, 2.0)
			if state_t <= 0.0:
				_throw_mines()
				_after(1.1)
		"storm_charge":
			var k := 1.0 - clampf(state_t / 0.9, 0.0, 1.0)
			squash = Vector2.ONE * (1.0 + 0.3 * k)
			if state_t <= 0.0:
				state = "storm"
				state_t = 2.6 if not desperate else 3.2
				emit_t = 0.0
				Sfx.play("roar", 0.4, -6.0)
		"storm":
			squash = Vector2.ONE * 1.3
			emit_t -= delta
			storm_a += delta * 2.3 * (1.0 if state_t > 1.3 else -1.0)  # turns back half way
			if emit_t <= 0.0:
				emit_t = 0.13
				_storm_tick()
			if state_t <= 0.0:
				_after(0.9)
			return to_p.normalized() * speed * 0.55 if to_p.length() > 40.0 else Vector2.ZERO
	return Vector2.ZERO


func _contact() -> void:
	if submerged or state in ["lure_wink", "lure_pull"]:
		return
	super._contact()


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	if submerged:
		return
	super.take_damage(amount, dir, crit)


func _base_armor() -> float:
	return DESPERATE_ARMOR if desperate else (FURY_ARMOR if furious else 1.0)


func _after(rest: float) -> void:
	state = "drift"
	state_t = rest * (0.7 if desperate else (0.85 if furious else 1.0))
	squash = Vector2.ONE


func _lead(k: float) -> Vector2:
	var p := player()
	return p.global_position + Vector2(0, Player.BODY_Y) + p.velocity * k


func _drift(to_p: Vector2) -> Vector2:
	var dist := to_p.length()
	var toward := to_p.normalized() * (0.7 if dist > 120.0 else (-0.7 if dist < 75.0 else 0.0))
	var v := (to_p.normalized().orthogonal() * strafe * 0.7 + toward).normalized() * speed * (1.5 if furious else 1.2)
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
		"bubbles":
			state = "bubble_aim"
			state_t = 0.55
			bubbles_left = 6 if desperate else (5 if furious else 4)
			aim = (_lead(0.35) - hit_center()).normalized()
			Game.world.telegraph_line(hit_center(), aim, 120.0, 10.0, state_t)
			Sfx.play("charge", 0.0, -4.0)
		"lure":
			state = "lure_wink"
			state_t = 0.6
			second_pull = false
			Game.world.telegraph_circle(global_position, NOVA_R, 0.6 + PULL_TIME + 0.2)
			Sfx.play("alert", 0.0, -2.0)
			Game.world.ring(_lure_pos(), 22.0, GLOW, 0.5, 2.0)
		"dive":
			state = "sink"
			state_t = 0.45
			Sfx.play("dash", 0.2, -4.0)
			Game.world.burst(global_position, TOXIC, 12, 70.0, 0.4, 2.0, -40.0)
		"mines":
			state = "mines"
			state_t = 1.0
			Sfx.play("roar", 0.4, -8.0)
		"storm":
			state = "storm_charge"
			state_t = 0.9
			Game.world.telegraph_circle(global_position, 52.0, 0.9)
			Sfx.play("charge", 0.2, -2.0)


# ---------------------------------------------------------------- phases

func _enrage() -> void:
	furious = true
	pattern_i = 0
	state = "roar"
	state_t = 1.2
	speed *= 1.15
	armor = FURY_ARMOR
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	w.shake(1.0)
	w.hud.banner("BLOATED!", TOXIC, 34, 1.2)
	w.hud.tint_flash(TOXIC, 0.35, 0.7)
	_fx("angler_pop", global_position + Vector2(0, -20), 0.9, 0.5)
	w.burst(hit_center(), GLOW, 30, 140.0, 0.6, 2.5)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	_ring(12, randf() * TAU, 70.0, 0.4, "angler_drop")
	var p := player()
	var d := p.global_position - global_position
	if d.length() < 90.0:
		p.knock = d.normalized() * 240.0


func _desperate() -> void:
	desperate = true
	armor = DESPERATE_ARMOR
	speed *= 1.1
	var w := Game.world
	w.shake(0.8)
	w.hud.banner("MELTDOWN!", Color("ff5566"), 32, 1.0)
	w.hud.tint_flash(Color("c8ff3a"), 0.3, 0.6)
	Sfx.play("roar", 0.0, 2.0)


# ---------------------------------------------------------------- bubbles

## One bubble at where the astronaut is heading. Its life is shorter than the flight, so it
## swells and bursts into droplets somewhere between the two of you.
func _bubble() -> void:
	var to := _lead(0.35)
	var d := to - hit_center()
	var dir := d.normalized().rotated(randf_range(-0.12, 0.12) + (strafe * 0.3 if desperate else 0.0))
	var s := Game.world.spawn_enemy_shot(hit_center() + Vector2(face * 14.0, 4.0), dir * BUBBLE_SPEED, contact_damage * 0.5, "angler")
	s.life = clampf(d.length() / s.vel.length() * randf_range(0.5, 0.8), 0.7, 1.7)
	squash = Vector2(0.88, 1.12)
	Sfx.play("spit", 0.2, -4.0)


# ---------------------------------------------------------------- lure + nova

func _lure_pos() -> Vector2:
	return hit_center() + Vector2(face * 14.0, -24.0)


## The lantern drags the astronaut in (slowly: walking away still works).
func _pull(delta: float) -> void:
	var lp := _lure_pos()
	if fmod(t, 0.3) < delta:
		Game.world.ring(lp, 30.0, GLOW, 0.3, 1.5)
	var p := player()
	var d := global_position - p.global_position
	if p.dead or d.length() > PULL_R or d.length() < 14.0:
		return
	p.knock = d.normalized() * PULL_SPEED
	if randf() < 0.6:  # specks streaming into the lantern
		var q := p.global_position + Vector2(randf_range(-30, 30), -10.0 + randf_range(-20, 20))
		Game.world.burst(q, GLOW, 1, 60.0, 0.35, 1.5, 0.0, (lp - q).normalized(), 0.1)


func _nova() -> void:
	var w := Game.world
	var c := global_position
	w.shake(0.9)
	Sfx.play("explode", 0.0, 0.0)
	_fx("angler_pop", hit_center(), 0.85, 0.45)
	w.ring(c, NOVA_R, GLOW, 0.4, 3.0)
	w.burst(hit_center(), TOXIC, 28, 150.0, 0.55, 2.5, 40.0)
	var p := player()
	if not p.dead:
		var off := p.global_position - c
		if Vector2(off.x, off.y / 0.75).length() < NOVA_R:  # the circle is drawn squashed
			p.take_damage(contact_damage * 1.4, c)
			p.knock += off.normalized() * 240.0
	_ring(14 if furious else 10, randf() * TAU, 80.0, 0.4, "angler_drop")
	squash = Vector2(1.5, 0.6)
	if desperate and not second_pull:
		second_pull = true
		state = "lure_wink"
		state_t = 0.3
		Game.world.telegraph_circle(global_position, NOVA_R, 0.3 + 1.0 + 0.2)
		return
	state = "gasp"
	state_t = 1.1
	armor = GASP_ARMOR
	w.popup_text(hit_center() + Vector2(0, -30), "EXHAUSTED! HIT IT!", GLOW, 11)
	Sfx.play("freeze", 0.0, -2.0)


# ---------------------------------------------------------------- dive

func _submerge() -> void:
	submerged = true
	state = "swim"
	swim_t = SWIM_TIME * (0.85 if desperate else 1.0)
	trail_t = 0.0
	weave = randf() * TAU
	targetable = false
	collision_layer = 0
	shadow.visible = false
	air = 0.0
	squash = Vector2.ONE
	_fx("angler_ring", global_position, 0.5, 0.4)
	Game.world.burst(global_position, TOXIC, 14, 90.0, 0.4, 2.0, 60.0)


## Fast, weaving round the astronaut; every ripple left behind is a geyser in waiting.
func _swim(delta: float, to_p: Vector2) -> Vector2:
	swim_t -= delta
	trail_t -= delta
	weave += delta * 3.4
	if trail_t <= 0.0:
		trail_t = 0.17
		_trail_mark(global_position)
	if swim_t <= 0.0:
		state = "surface_warn"
		state_t = 0.85
		Game.world.telegraph_circle(global_position, SURF_R, state_t)
		Sfx.play("alert", 0.0, -2.0)
		return Vector2.ZERO
	var want := to_p.normalized().rotated(sin(weave) * 0.9)
	if swim_t < 0.9:  # last stretch: straight at where the astronaut is going
		want = (_lead(0.5) - global_position).normalized()
	var v := want * speed * (3.6 if furious else 3.2)
	var f := _fence()
	if f != null and not f.holds(global_position + v * 0.25, 18.0):
		v = (f.global_position - global_position).normalized() * speed * 2.0
	return v


## A ripple that marks the floor, then a geyser where it was.
func _trail_mark(at: Vector2) -> void:
	var tg := Telegraph.new()
	tg.position = at
	tg.radius = GEYSER_R
	tg.dur = 0.75
	tg.color = TOXIC
	Game.world.decals.add_child(tg)
	_fx("angler_ring", at, 0.18, 0.5)
	var dmg := contact_damage * 0.7
	get_tree().create_timer(0.75, false).timeout.connect(func() -> void:
		if is_instance_valid(Game.world):
			BossAngler.geyser(at, dmg, GEYSER_R))


## Up out of the floor under the astronaut's feet.
func _surface() -> void:
	submerged = false
	targetable = true
	collision_layer = 4
	shadow.visible = true
	var w := Game.world
	var c := global_position
	squash = Vector2(0.6, 1.5)
	w.shake(0.8)
	BossAngler.geyser(c, contact_damage * 1.2, SURF_R)
	var p := player()
	if not p.dead:
		var off := p.global_position - c
		if Vector2(off.x, off.y / 0.75).length() < SURF_R:
			p.knock += off.normalized() * 220.0
	_ring(12 if furious else 8, randf() * TAU, 85.0, 0.4, "angler_drop")
	if furious:
		state = "stun"
		state_t = 2.0
		armor = STUN_ARMOR
		w.ring(hit_center(), 34.0, GLOW, 0.4, 3.0)
		w.popup_text(hit_center() + Vector2(0, -30), "DIZZY! HIT IT!", GLOW, 12)
		Sfx.play("freeze", 0.0, 2.0)
	else:
		state = "gasp"
		state_t = 1.0
		armor = GASP_ARMOR
		w.popup_text(hit_center() + Vector2(0, -30), "WINDED!", GLOW, 11)


## A burst of toxic water from the floor at `at`: shockwave, droplets, damage.
static func geyser(at: Vector2, dmg: float, r: float) -> void:
	var w := Game.world
	AnimFx.spawn(w.effects, "angler_geyser", "pop", at, r * 2.0 / 130.0)
	w.burst(at, TOXIC, 8 + int(r * 0.2), 90.0, 0.45, 2.0, 70.0)
	w.shake(0.15 + r * 0.01)
	Sfx.play("explode", 0.3, -9.0 + r * 0.05)
	var p := w.player
	if not p.dead:
		var off := p.global_position - at
		if Vector2(off.x, off.y / 0.75).length() < r:
			p.take_damage(dmg, at)


# ---------------------------------------------------------------- mines

## Spore mines out of the channelling cloud, landing round the astronaut.
func _throw_mines() -> void:
	var p := player()
	var n := 7 if desperate else (6 if furious else 4)
	for i in n:
		var at := p.global_position + p.velocity * 0.5 if i == 0 else p.global_position + Vector2.from_angle(TAU * i / n + randf()) * randf_range(26.0, 85.0)
		_throw_mine(at, i * 0.1)
	Game.world.burst(hit_center(), TOXIC, 14, 90.0, 0.4, 2.0)
	Sfx.play("slash", 0.0, -4.0)


func _throw_mine(at: Vector2, delay: float) -> void:
	var w := Game.world
	var from := hit_center()
	var mine := Art.make_anim("angler_mine", 0.22)
	mine.position = from
	mine.visible = false
	mine.add_to_group("angler_mines")
	w.effects.add_child(mine)
	var dmg := contact_damage
	var rest := at + Vector2(0, -6)
	var tw := mine.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		mine.visible = true
		mine.play("fly"))
	tw.tween_method(func(k: float) -> void: BossAngler._fly_mine(mine, from, rest, k), 0.0, 1.0, MINE_FLIGHT)
	tw.tween_callback(func() -> void:
		mine.rotation = 0.0
		mine.play("arm")
		mine.speed_scale = 1.0 / ARM_TIME  # its 4 frames (4 fps) span the fuse
		var tg := Telegraph.new()
		tg.position = at
		tg.radius = MINE_R
		tg.dur = ARM_TIME
		tg.color = TOXIC
		Game.world.decals.add_child(tg))
	tw.tween_interval(ARM_TIME)
	tw.tween_callback(func() -> void:
		BossAngler.mine_blast(at, dmg)
		mine.queue_free())


## A mine in its lobbed arc, spinning (k = 0..1 along the throw).
static func _fly_mine(mine: AnimatedSprite2D, from: Vector2, rest: Vector2, k: float) -> void:
	mine.position = from.lerp(rest, k) + Vector2(0, -sin(k * PI) * 38.0)
	mine.rotation = k * TAU


static func mine_blast(at: Vector2, dmg: float) -> void:
	var w := Game.world
	_fx_static("angler_boom", at + Vector2(0, -8), 0.5, 0.4)
	w.burst(at, TOXIC, 14, 100.0, 0.45, 2.5, 80.0)
	w.shake(0.3)
	Sfx.play("explode", 0.2, -7.0)
	var p := w.player
	if not p.dead:
		var off := p.global_position - at
		if Vector2(off.x, off.y / 0.75).length() < MINE_R:
			p.take_damage(dmg, at)
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0 + randf() * 0.5)
		w.spawn_enemy_shot(at + Vector2(0, -6) + d * 8.0, d * 70.0, dmg * 0.3, "angler_drop")
	var pd := GooPuddle.new()
	pd.style = "hive"
	pd.acid = true
	pd.radius = 20.0
	pd.life = 3.0
	pd.damage = dmg * 0.3
	pd.position = at
	w.decals.add_child(pd)


# ---------------------------------------------------------------- storm

## Two arms of droplets (three when desperate) wound into a spiral by the spin.
func _storm_tick() -> void:
	var arms := 3 if desperate else 2
	for i in arms:
		var d := Vector2.from_angle(storm_a + TAU * i / arms)
		Game.world.spawn_enemy_shot(hit_center() + d * 14.0, d * 70.0, contact_damage * 0.35, "angler_drop")
	if randf() < 0.3:
		Sfx.play("spit", 0.4, -14.0)


# ---------------------------------------------------------------- effects

## A one-frame effect sprite that grows and fades.
func _fx(set_id: String, pos: Vector2, s: float, dur: float) -> void:
	BossAngler._fx_static(set_id, pos, s, dur)


static func _fx_static(set_id: String, pos: Vector2, s: float, dur: float) -> void:
	var sp := Sprite2D.new()
	sp.texture = Art.frames(set_id).get_frame_texture("pop", 0)
	sp.position = pos
	sp.scale = Vector2.ONE * s * 0.6
	Game.world.effects.add_child(sp)
	var tw := sp.create_tween().set_parallel()
	tw.tween_property(sp, "scale", Vector2.ONE * s, dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(sp.queue_free)


func _anim_name() -> String:
	if hurt_t > 0.0 and state in ["drift", "intro"]:
		return "hurt"
	match state:
		"bubble_aim":
			return "inflate"
		"bubbles":
			return "spit"
		"lure_wink":
			return "wink"
		"lure_pull":
			return "charge"
		"gasp", "stun":
			return "stun"
		"sink":
			return "sink"
		"swim", "surface_warn":
			return "ripple"
		"mines":
			return "channel"
		"storm_charge", "storm", "roar":
			return "fury"
	return "fury" if furious else "walk"


func _on_death() -> void:
	var w := Game.world
	submerged = false
	var fx := AnimFx.spawn(w.decals, "toxic_angler", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	for n in get_tree().get_nodes_in_group("angler_mines"):
		n.queue_free()
	var c := hit_center()
	for i in 6:
		get_tree().create_timer(0.2 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(w):
				var at := c + Vector2(randf_range(-24, 24), randf_range(-14, 14))
				BossAngler._fx_static("angler_pop", at, 0.3, 0.4)
				w.burst(at, TOXIC, 12, 100.0, 0.5, 2.5, 60.0)
				w.shake(0.4)
				Sfx.play("explode", 0.2, -6.0))
	Sfx.play("roar", 0.2, -2.0)
