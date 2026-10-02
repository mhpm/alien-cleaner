class_name BossDrillback
extends BossBase
## DRILLBACK (world 2 mini boss, wave 9): a rocky armadillo with a drill for a nose.
## Calm (above half health), in turn:
##   dash     spins its drill up, a lane marks where it will go, then it BORES through it,
##            leaving ghosts and flying rubble beside its path. Dodge it so it drills into a
##            wall: it gets STUCK (dizzy, +50%) while rocks come down round it
##   fault    rears up and stamps: cracks run out from its feet (the warning lanes) and
##            rock spikes erupt along them, from the boss outwards. Stand BETWEEN two cracks
##   bore     sinks into the ground and pops up three times: each time a circle marks where
##            you ARE, and it bursts up there; the warnings get shorter (0.95, 0.8, 0.65 s).
##            Then it lies winded, tongue out (+35%)
##   boulders rears up and lobs boulders round you; they ROLL after you (slower than you
##            walk) and sprout spikes and burst when they catch up
## ROCK HARD (under half health): armor and rage, its shots vanish, and it adds
##   cavein   a CAVE-IN: columns of rocks fall one after another, sweeping across the screen,
##            with a two-column lane left open that you have to slip through
##   and it chains two dashes, stamps a second ring of cracks, and the bore pops hurt more
## OVERDRIVE (under 20%): three dashes, three waves of cracks, a fourth pop, thinner cave-in lane.
## Falls apart into a heap of rocks (the set's "death").

const CALM := ["dash", "fault", "bore", "boulders", "dash", "fault", "boulders", "bore"]
const FURY := ["cavein", "dash", "bore", "fault", "boulders", "cavein", "dash", "bore", "fault"]
const FIGHT_SECS := 45.0  # mini boss: a shorter fight than the final bosses
const DASH_SPEED := 235.0
const DASH_LEN := 240.0
const DASH_HIT_R := 12.0
const POP_R := 32.0
const POP_TIMES := [0.95, 0.8, 0.65, 0.55]
const FAULT_LINES := 8
const FAULT_WARN := 0.9
const COLS := 9  # cave-in columns
const COL_GAP := 24.0
const FURY_ARMOR := 0.85
const DESPERATE_ARMOR := 0.75
const GASP_ARMOR := 1.35
const STUCK_ARMOR := 1.5
const STUN_ARMOR := 1.6
const DESPERATE_AT := 0.2
const DIRT := Color("b9803f")
const GLOW := Color("c8ff3a")
const ROCK_COLOR := Color("ff9a3c")

var pattern_i := 0
var furious := false
var desperate := false
var submerged := false
var strafe := 1.0
var dashes_left := 0
var dash_travel := 0.0
var ghost_t := 0.0
var rubble_t := 0.0
var pops_left := 0
var pop_i := 0
var pop_target := Vector2.ZERO
var pop_t := 0.0
var waves_left := 0
var fault_off := 0.0
var dust_t := 0.0


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
	if state in ["intro", "roar", "drift", "dash_wind", "skid", "gasp", "stun", "stuck", "fault", "boulder_wind", "cavein_roar", "cavein", "popped"] and to_p.x != 0.0:
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
		"dash_wind":
			sprite.position.x = sin(t * 70.0) * 0.9  # the drill shaking the whole body
			if randf() < delta * 20.0:
				Game.world.burst(global_position + Vector2(-face * 14.0, -2.0), DIRT, 1, 40.0, 0.3, 1.5, 60.0)
			if state_t <= 0.0:
				sprite.position.x = 0.0
				_lock_dash()
		"dash_lock":
			sprite.position.x = sin(t * 70.0) * 0.9
			if state_t <= 0.0:
				sprite.position.x = 0.0
				state = "dash"
				dash_travel = 0.0
				Sfx.play("dash", 0.0, -2.0)
		"dash":
			return _dash(delta)
		"skid":
			if state_t <= 0.0:
				_after(0.5)
			return aim * 70.0 * clampf(state_t / 0.5, 0.0, 1.0)
		"stuck", "stun":
			sprite.position.x = sin(t * 14.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				armor = _base_armor()
				_after(0.5)
		"gasp":
			squash = Vector2.ONE * (1.0 + sin(t * 9.0) * 0.03)
			if state_t <= 0.0:
				armor = _base_armor()
				_after(0.4)
		"fault":
			squash = Vector2.ONE * (1.0 + 0.1 * clampf(1.0 - state_t / FAULT_WARN, 0.0, 1.0))
			if state_t <= 0.0:
				_slam()
		"boulder_wind":
			squash = Vector2(0.95, 1.08)
			if state_t <= 0.0:
				_throw_boulders()
				_after(1.2)
		"sink":
			if state_t <= 0.0:
				_submerge()
		"bore":
			return _bore(delta)
		"popped":
			if state_t <= 0.0:
				_pop_done()
		"cavein_roar":
			squash = Vector2(1.0 + sin(t * 30.0) * 0.04, 1.0 + sin(t * 30.0) * 0.04)
			if state_t <= 0.0:
				_cavein()
				state = "cavein"
				state_t = 2.8
		"cavein":
			if state_t <= 0.0:
				_after(0.8)
	return Vector2.ZERO


func _contact() -> void:
	if submerged:
		return
	if state == "dash":
		var p := player()
		if not p.dead and (p.global_position - global_position).length() < radius + DASH_HIT_R:
			p.take_damage(contact_damage * 1.4, global_position)
			p.knock += aim * 200.0
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
	return p.global_position + p.velocity * k


func _drift(to_p: Vector2) -> Vector2:
	var dist := to_p.length()
	var toward := to_p.normalized() * (0.7 if dist > 110.0 else (-0.7 if dist < 65.0 else 0.0))
	var v := (to_p.normalized().orthogonal() * strafe * 0.7 + toward).normalized() * speed * (1.4 if furious else 1.1)
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
		"dash":
			dashes_left = 2 if desperate else (1 if furious else 0)
			state = "dash_wind"
			state_t = 0.55
			Sfx.play("charge", 0.2, -4.0)
		"fault":
			waves_left = 3 if desperate else (2 if furious else 1)
			fault_off = randf() * TAU
			state = "fault"
			_fault_wave(FAULT_WARN)
			Sfx.play("roar", 0.4, -6.0)
		"bore":
			state = "sink"
			state_t = 0.5
			Sfx.play("dash", 0.2, -4.0)
			Game.world.burst(global_position, DIRT, 12, 70.0, 0.4, 2.0, -40.0)
		"boulders":
			state = "boulder_wind"
			state_t = 0.7
			Sfx.play("charge", 0.0, -4.0)
		"cavein":
			state = "cavein_roar"
			state_t = 0.8
			Game.world.popup_text(hit_center() + Vector2(0, -34), "CAVE-IN!", ROCK_COLOR, 13)
			Sfx.play("roar", 0.0, 0.0)


# ---------------------------------------------------------------- phases

func _enrage() -> void:
	furious = true
	pattern_i = 0
	state = "roar"
	state_t = 1.2
	sprite.position.x = 0.0
	speed *= 1.15
	armor = FURY_ARMOR
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	w.shake(1.0)
	w.hud.banner("ROCK HARD!", ROCK_COLOR, 34, 1.2)
	w.hud.tint_flash(ROCK_COLOR, 0.35, 0.7)
	w.burst(hit_center(), DIRT, 30, 140.0, 0.6, 2.5, 60.0)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	_ring(10, randf() * TAU, 80.0, 0.4, "drill_chunk")
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
	w.hud.banner("OVERDRIVE!", GLOW, 32, 1.0)
	w.hud.tint_flash(GLOW, 0.3, 0.6)
	Sfx.play("roar", 0.0, 2.0)


# ---------------------------------------------------------------- dash

## Aim is fixed here: the lane stays where it is drawn.
func _lock_dash() -> void:
	var to := _lead(0.2) - global_position
	aim = to.normalized() if to.length() > 1.0 else Vector2.RIGHT
	face = signf(aim.x) if aim.x != 0.0 else face
	state = "dash_lock"
	state_t = 0.3 if desperate else (0.35 if furious else 0.45)
	Game.world.telegraph_line(global_position + Vector2(0, -8), aim, DASH_LEN + 20.0, 20.0, state_t)
	Sfx.play("alert", 0.0, -2.0)


func _dash(delta: float) -> Vector2:
	dash_travel += DASH_SPEED * delta
	ghost_t -= delta
	if ghost_t <= 0.0:
		ghost_t = 0.04
		_ghost()
	rubble_t -= delta
	if rubble_t <= 0.0:  # rubble thrown out to both sides of the path
		rubble_t = 0.09
		var side := aim.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
		var s := Game.world.spawn_enemy_shot(global_position + Vector2(0, -8), side * 55.0 + aim * 30.0, contact_damage * 0.3, "drill_chunk")
		s.life = 0.55
	Game.world.burst(global_position + Vector2(-aim.x * 10.0, 0), DIRT, 1, 40.0, 0.3, 1.5, 40.0)
	if hit_wall and dash_travel > 24.0:
		_stuck()
		return Vector2.ZERO
	if dash_travel >= DASH_LEN:
		if dashes_left > 0:
			dashes_left -= 1
			state = "dash_wind"
			state_t = 0.3
			Sfx.play("charge", 0.3, -6.0)
		else:
			state = "skid"
			state_t = 0.5
			Game.world.burst(global_position, DIRT, 10, 80.0, 0.4, 2.0, 40.0)
		return aim * 60.0
	return aim * DASH_SPEED


## A fading green copy of the body: the speed trail.
func _ghost() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.offset = sprite.offset
	g.flip_h = sprite.flip_h
	g.scale = sprite.scale
	g.global_position = sprite.global_position
	g.modulate = Color(0.8, 1.4, 0.4, 0.5)
	Game.world.effects.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)


## Drilled into the wall: stuck and dizzy while the ceiling lets go of some rocks.
func _stuck() -> void:
	state = "stuck"
	state_t = 2.0 if furious else 1.6
	armor = STUCK_ARMOR + (0.1 if furious else 0.0)
	knock = Vector2.ZERO
	var w := Game.world
	w.shake(0.9)
	Sfx.play("explode", 0.0, -2.0)
	w.burst(hit_center(), DIRT, 20, 120.0, 0.5, 2.5, 60.0)
	w.ring(hit_center(), 30.0, GLOW, 0.4, 3.0)
	w.popup_text(hit_center() + Vector2(0, -30), "STUCK! HIT IT!", GLOW, 12)
	for i in (5 if furious else 3):
		var at := global_position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0)
		BossDrillback.drop_rock(at, contact_damage * 0.9, 0.9 + i * 0.15)


# ---------------------------------------------------------------- fault lines

## A set of cracks round the boss (`warn` s of warning, then the spikes).
func _fault_wave(warn: float) -> void:
	var angles: Array[float] = []
	for i in FAULT_LINES:
		var a := fault_off + TAU * i / FAULT_LINES
		angles.append(a)
		Game.world.telegraph_line(global_position, Vector2.from_angle(a), FaultWave.LENGTH + 10.0, 12.0, warn)
	var wave := FaultWave.new()
	wave.angles = angles
	wave.damage = contact_damage * 1.0
	wave.warn = warn
	wave.position = global_position
	Game.world.effects.add_child(wave)
	state_t = warn


func _slam() -> void:
	squash = Vector2(1.45, 0.65)
	var w := Game.world
	w.shake(0.7)
	Sfx.play("explode", 0.0, -3.0)
	w.burst(global_position, DIRT, 14, 100.0, 0.45, 2.5, 60.0)
	waves_left -= 1
	if waves_left > 0:
		fault_off += TAU / (FAULT_LINES * 2.0)  # the next ring cracks through the gaps
		_fault_wave(0.75)
	else:
		state = "gasp"
		state_t = 1.1
		armor = GASP_ARMOR
		w.popup_text(hit_center() + Vector2(0, -30), "WINDED!", GLOW, 11)


# ---------------------------------------------------------------- bore

func _submerge() -> void:
	submerged = true
	targetable = false
	collision_layer = 0
	shadow.visible = false
	squash = Vector2.ONE
	pop_i = 0
	pops_left = 4 if desperate else 3
	_next_pop()
	Game.world.burst(global_position, DIRT, 14, 90.0, 0.4, 2.0, 60.0)


## Aims the next pop at where the astronaut is right now; the time to dodge shrinks.
func _next_pop() -> void:
	pop_t = float(POP_TIMES[mini(pop_i, POP_TIMES.size() - 1)])
	if desperate:
		pop_t *= 0.9
	pop_target = _lead(0.3)
	var tg := Telegraph.new()
	tg.position = pop_target
	tg.radius = POP_R
	tg.dur = pop_t
	tg.color = DIRT
	Game.world.decals.add_child(tg)
	state = "bore"
	Sfx.play("alert", 0.0, -4.0)


## Under the floor, in a straight line to the marked spot, arriving as the warning ends.
func _bore(delta: float) -> Vector2:
	pop_t -= delta
	dust_t -= delta
	if dust_t <= 0.0:
		dust_t = 0.08
		Game.world.burst(global_position, DIRT, 2, 50.0, 0.35, 2.0, 60.0)
	if pop_t <= 0.04:
		_pop()
		return Vector2.ZERO
	return ((pop_target - global_position) / maxf(pop_t, 0.06)).limit_length(340.0)


func _pop() -> void:
	global_position = pop_target
	submerged = false
	targetable = true
	collision_layer = 4
	shadow.visible = true
	var w := Game.world
	BossDrillback.spike_burst(pop_target, 0.34, contact_damage * (1.4 if furious else 1.2), POP_R)
	w.shake(0.6)
	Sfx.play("explode", 0.1, -3.0)
	_ring(6, randf() * TAU, 75.0, 0.3, "drill_chunk")
	squash = Vector2(0.7, 1.4)
	state = "popped"
	state_t = 0.3 if not furious else 0.22


func _pop_done() -> void:
	pops_left -= 1
	pop_i += 1
	var w := Game.world
	if pops_left > 0:
		submerged = true
		targetable = false
		collision_layer = 0
		shadow.visible = false
		_next_pop()
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
		state_t = 1.2
		armor = GASP_ARMOR
		w.popup_text(hit_center() + Vector2(0, -30), "WINDED!", GLOW, 11)


## Spikes erupting out of the floor at `at`: the visual and the damage.
static func spike_burst(at: Vector2, s: float, dmg: float, r: float) -> void:
	var w := Game.world
	AnimFx.spawn(w.effects, "drill_spike", "pop", at, s)
	w.burst(at, DIRT, 4, 70.0, 0.35, 2.0, 80.0)
	if dmg <= 0.0:
		return
	var p := w.player
	if not p.dead:
		var off := p.global_position - at
		if Vector2(off.x, off.y / 0.75).length() < r:  # the circles are drawn squashed
			p.take_damage(dmg, at)


# ---------------------------------------------------------------- boulders

func _throw_boulders() -> void:
	var n := 4 if desperate else (3 if furious else 2)
	if get_tree().get_nodes_in_group("drill_boulders").size() + n > 7:
		return
	var from := hit_center() + Vector2(face * 12.0, -8.0)
	for i in n:
		var b := DrillBoulder.new()
		b.from = from
		b.land = _lead(0.3) + Vector2.from_angle(TAU * i / n + randf()) * randf_range(25.0, 75.0)
		b.damage = contact_damage
		b.delay = i * 0.22
		Game.world.effects.add_child(b)
	squash = Vector2(1.15, 0.9)
	Sfx.play("slash", 0.0, -4.0)


# ---------------------------------------------------------------- cave-in

## Columns of rocks across the screen, one after another, with an open lane.
func _cavein() -> void:
	var p := player().global_position
	var gap := randi() % (COLS - 1)
	var dir := 1 if randf() < 0.5 else -1
	var lane := 1 if desperate else 2  # columns left open
	var rows := [-36.0, 0.0, 36.0] if not desperate else [-48.0, -16.0, 16.0, 48.0]
	for c in COLS:
		if c >= gap and c < gap + lane:
			continue
		var order := c if dir > 0 else COLS - 1 - c
		var x := (c - (COLS - 1) * 0.5) * COL_GAP
		for dy in rows:
			BossDrillback.drop_rock(p + Vector2(x, dy), contact_damage * 0.9, 1.1 + order * 0.1)
	Sfx.play("roar", 0.5, -6.0)
	Game.world.shake(0.5)


## A rock from above onto `at`: a circle warns, then it falls and bursts into spikes.
static func drop_rock(at: Vector2, dmg: float, delay: float, r := 13.0) -> void:
	var w := Game.world
	var tg := Telegraph.new()
	tg.position = at
	tg.radius = r
	tg.dur = delay
	tg.color = DIRT
	w.decals.add_child(tg)
	var rock := Sprite2D.new()
	rock.texture = Art.frames("drill_rock").get_frame_texture("fly", 0)
	rock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rock.scale = Vector2.ONE * 0.3
	rock.position = at + Vector2(0, -120.0)
	rock.visible = false
	w.effects.add_child(rock)
	var tw := rock.create_tween()
	tw.tween_interval(maxf(delay - 0.22, 0.0))
	tw.tween_callback(rock.show)
	tw.tween_property(rock, "position", at + Vector2(0, -6.0), 0.22).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		BossDrillback.spike_burst(at, 0.2, dmg, r)
		Sfx.play("pop", 0.3, -8.0)
		rock.queue_free())


# ---------------------------------------------------------------- effects

func _anim_name() -> String:
	if hurt_t > 0.0 and state in ["drift", "intro"]:
		return "hurt"
	match state:
		"dash_wind":
			return "crouch" if state_t > 0.3 else "spin"
		"dash_lock":
			return "spin"
		"dash":
			return "dash"
		"skid", "popped":
			return "crouch"
		"stuck", "stun":
			return "stun"
		"gasp":
			return "gasp"
		"fault", "boulder_wind":
			return "rear"
		"sink":
			return "sink"
		"bore":
			return "mound"
		"cavein_roar", "roar":
			return "angry"
	return "angry" if furious else "walk"


func _on_death() -> void:
	var w := Game.world
	submerged = false
	var fx := AnimFx.spawn(w.decals, "drillback", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	for n in get_tree().get_nodes_in_group("drill_boulders"):
		n.queue_free()
	var c := hit_center()
	for i in 6:
		get_tree().create_timer(0.2 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(w):
				var at := c + Vector2(randf_range(-24, 24), randf_range(-8, 14))
				BossDrillback.spike_burst(at, 0.2, 0.0, 0.0)
				w.burst(at, DIRT, 12, 100.0, 0.5, 2.5, 60.0)
				w.shake(0.4)
				Sfx.play("explode", 0.2, -6.0))
	Sfx.play("roar", 0.2, -2.0)
