class_name BossCrab
extends BossBase
## CLAWDOZER (world 4 mini boss, wave 8): a bulldozer crab with a cannon turret on its head.
## Calm (above half health), in turn:
##   cannon  its mouth cannon charges (a lane marks where you are heading) and spits orbs
##           that swell in flight and BURST into droplets half way: the danger is the burst
##   quake   braces and stamps: rings of spikes erupt outwards, one after another (each spike
##           shows a circle first). Every ring has the same GAP in it, aimed at you: run
##           through the gap, outwards. Then it is winded (+35%)
##   pods    lobs little crab-pods round you: they land, BURROW and tunnel after you leaving
##           a trail of dirt (slower than you walk), then stop, mark a circle and pop up in
##           a burst of spikes. Keep walking
##   plow    lowers its claws, a lane marks the way and it BULLDOZES down it; every spot it
##           crosses sprouts spikes a moment later, so do not follow it. If it hits a wall
##           it gets STUCK (dizzy, +50%)
## OVERCLOCK (under half health): its turret glows, its shots vanish, and it adds
##   sentry  strafes while the turret rains fans of droplets at where you are going
## MELTDOWN (under 20%): faster, four orbs, more rings, more pods.
## Melts into a puddle with its turret (the set's "death").

const CALM := ["cannon", "quake", "pods", "plow", "cannon", "quake", "plow", "pods"]
const FURY := ["sentry", "quake", "plow", "cannon", "pods", "sentry", "plow", "quake", "pods"]
const FIGHT_SECS := 45.0  # mini boss: a shorter fight than the final bosses
const ORB_SPEED := 125.0
const SPIKE_R := 11.0
const RING_STEP := 32.0
const PLOW_LEN := 230.0
const PLOW_SPEED := 210.0
const MAX_PODS := 6
const FURY_ARMOR := 0.85
const DESPERATE_ARMOR := 0.75
const GASP_ARMOR := 1.35
const STUCK_ARMOR := 1.5
const DESPERATE_AT := 0.2
const GREEN := Color("7dff9a")
const DIRT := Color("b9803f")

var pattern_i := 0
var furious := false
var desperate := false
var strafe := 1.0
var orbs_left := 0
var emit_t := 0.0
var plow_travel := 0.0
var mark_t := 0.0
var gap_angle := 0.0


func _init_ai() -> void:
	_size_to_player(FIGHT_SECS)
	state = "intro"
	state_t = 1.4
	Sfx.play("roar", 0.0)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	if not furious and hp < max_hp * 0.5 and state != "intro":
		_enrage()
	elif furious and not desperate and hp < max_hp * DESPERATE_AT:
		_desperate()
	if state not in ["plow", "skid"] and to_p.x != 0.0:
		face = signf(to_p.x)
	air = 0.0
	match state:
		"intro", "roar":
			squash = Vector2(1.0 + sin(t * 40.0) * 0.05, 1.0)
			if state_t <= 0.0:
				_next()
		"drift":
			if state_t <= 0.0:
				_next()
			return _drift(to_p)
		"cannon_aim":
			aim = (_lead(0.35) - hit_center()).normalized()
			face = signf(aim.x) if aim.x != 0.0 else face
			if state_t <= 0.0:
				state = "cannon"
				emit_t = 0.0
		"cannon":
			emit_t -= delta
			if emit_t <= 0.0:
				_orb()
				orbs_left -= 1
				emit_t = 0.3
				if orbs_left <= 0:
					_after(1.0)
		"quake_wind":
			squash = Vector2(1.0 + 0.05 * sin(t * 30.0), 1.0 - 0.08 * clampf(1.0 - state_t / 0.8, 0.0, 1.0))
			if state_t <= 0.0:
				_stamp()
		"quake":
			if state_t <= 0.0:
				_winded()
		"pod_wind":
			squash = Vector2(0.95, 1.08)
			if state_t <= 0.0:
				_throw_pods()
				_after(1.4)
		"plow_wind":
			sprite.position.x = sin(t * 60.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				state = "plow"
				plow_travel = 0.0
				mark_t = 0.0
				Sfx.play("dash", 0.0, -2.0)
		"plow":
			return _plow(delta)
		"skid":
			if state_t <= 0.0:
				_winded()
			return aim * 70.0 * clampf(state_t / 0.5, 0.0, 1.0)
		"gasp", "stuck":
			sprite.position.x = sin(t * 14.0) * 0.8 if state == "stuck" else 0.0
			if state_t <= 0.0:
				sprite.position.x = 0.0
				armor = _base_armor()
				_after(0.5)
		"sentry_wind":
			squash = Vector2.ONE * (1.0 + 0.06 * sin(t * 30.0))
			if state_t <= 0.0:
				state = "sentry"
				state_t = 3.0 if not desperate else 3.6
				emit_t = 0.0
		"sentry":
			emit_t -= delta
			if emit_t <= 0.0:
				emit_t = 0.4 if not desperate else 0.3
				_fan()
			if state_t <= 0.0:
				_after(0.9)
			return _drift(to_p, 0.8)
	return Vector2.ZERO


func _contact() -> void:
	if state == "plow":
		var p := player()
		if not p.dead and (p.global_position - global_position).length() < radius + 12.0:
			p.take_damage(contact_damage * 1.4, global_position)
			p.knock += aim * 200.0
		return
	super._contact()


func _base_armor() -> float:
	return DESPERATE_ARMOR if desperate else (FURY_ARMOR if furious else 1.0)


func _after(rest: float) -> void:
	state = "drift"
	state_t = rest * (0.7 if desperate else (0.85 if furious else 1.0))
	squash = Vector2.ONE


func _winded() -> void:
	state = "gasp"
	state_t = 1.1
	armor = GASP_ARMOR
	Game.world.popup_text(hit_center() + Vector2(0, -30), "WINDED!", GREEN, 11)


func _lead(k: float) -> Vector2:
	var p := player()
	return p.global_position + Vector2(0, Player.BODY_Y) + p.velocity * k


func _drift(to_p: Vector2, k := 1.0) -> Vector2:
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
		"cannon":
			state = "cannon_aim"
			state_t = 0.8
			orbs_left = 4 if desperate else (3 if furious else 2)
			aim = (_lead(0.35) - hit_center()).normalized()
			Game.world.telegraph_line(hit_center(), aim, 150.0, 12.0, state_t)
			Sfx.play("charge", 0.0, -4.0)
		"quake":
			_quake_warn()
		"pods":
			if get_tree().get_nodes_in_group("claw_pods").size() > MAX_PODS - 3:
				_after(0.3)
				return
			state = "pod_wind"
			state_t = 0.7
			Sfx.play("charge", 0.3, -6.0)
		"plow":
			_plow_warn()
		"sentry":
			state = "sentry_wind"
			state_t = 0.7
			Game.world.ring(hit_center(), 26.0, GREEN, 0.5, 2.0)
			Sfx.play("charge", 0.5, -4.0)


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
	w.hud.banner("OVERCLOCK!", GREEN, 34, 1.2)
	w.hud.tint_flash(GREEN, 0.35, 0.7)
	w.burst(hit_center(), GREEN, 30, 140.0, 0.6, 2.5)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	_ring(10, randf() * TAU, 80.0, 0.4, "claw_drop")
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
	w.hud.tint_flash(Color("ff5566"), 0.3, 0.6)
	Sfx.play("roar", 0.0, 2.0)


# ---------------------------------------------------------------- cannon

## One orb at where the astronaut is heading; it bursts into droplets part way there.
func _orb() -> void:
	var to := _lead(0.35)
	var d := to - hit_center()
	var dir := d.normalized().rotated(randf_range(-0.1, 0.1))
	var s := Game.world.spawn_enemy_shot(hit_center() + dir * 16.0, dir * ORB_SPEED, contact_damage * 0.5, "claw_orb")
	s.life = clampf(d.length() / s.vel.length() * 0.8, 0.7, 1.6)
	squash = Vector2(0.9, 1.1)
	Sfx.play("spit", 0.1, -4.0)


## A fan of droplets (the turret on its head) at where the astronaut is going.
func _fan() -> void:
	var d := (_lead(0.4) - hit_center()).normalized()
	var n := 5 if desperate else 3
	for i in n:
		var a := (i - (n - 1) * 0.5) * 0.28
		Game.world.spawn_enemy_shot(hit_center() + Vector2(0, -8), d.rotated(a) * 105.0, contact_damage * 0.35, "claw_drop")
	Sfx.play("spit", 0.5, -10.0)


# ---------------------------------------------------------------- quake

func _ring_radii() -> Array[float]:
	var out: Array[float] = []
	for i in (4 if (furious or desperate) else 3):
		out.append(36.0 + RING_STEP * i)
	return out


func _gap() -> float:
	return 0.75 if desperate else 0.95


func _quake_warn() -> void:
	state = "quake_wind"
	state_t = 0.8
	Sfx.play("roar", 0.4, -6.0)
	gap_angle = (player().global_position - global_position).angle()  # the gap, aimed at you
	var i := 0
	for r in _ring_radii():
		var n := int(round(TAU * r / 24.0))
		var delay := 0.9 + 0.4 * i
		for k in n:
			var a := TAU * k / n
			if absf(angle_difference(a, gap_angle)) < _gap() * 0.5:
				continue
			var tg := Telegraph.new()
			tg.position = global_position + Vector2.from_angle(a) * r
			tg.radius = SPIKE_R
			tg.dur = delay
			tg.color = GREEN
			Game.world.decals.add_child(tg)
		i += 1


func _stamp() -> void:
	var w := Game.world
	squash = Vector2(1.45, 0.65)
	w.shake(0.7)
	Sfx.play("explode", 0.0, -3.0)
	var dmg := contact_damage
	var center := global_position
	var i := 0
	for r in _ring_radii():
		var n := int(round(TAU * r / 24.0))
		var delay := 0.1 + 0.4 * i
		for k in n:
			var a := TAU * k / n
			if absf(angle_difference(a, gap_angle)) < _gap() * 0.5:
				continue
			var at := center + Vector2.from_angle(a) * r
			get_tree().create_timer(delay, false).timeout.connect(func() -> void:
				if is_instance_valid(Game.world):
					BossCrab.spike(at, dmg, SPIKE_R))
		i += 1
	state = "quake"
	state_t = 0.2 + 0.4 * i + 0.3


## Spikes out of the floor at `at`: the visual and the damage.
static func spike(at: Vector2, dmg: float, r: float) -> void:
	var w := Game.world
	AnimFx.spawn(w.effects, "claw_spike", "pop", at, r * 2.0 / 190.0)
	w.burst(at, DIRT, 3, 60.0, 0.3, 2.0, 70.0)
	Sfx.play("pop", 0.4, -10.0)
	var p := w.player
	if dmg > 0.0 and not p.dead:
		var off := p.global_position - at
		if Vector2(off.x, off.y / 0.75).length() < r:
			p.take_damage(dmg, at)


# ---------------------------------------------------------------- pods

func _throw_pods() -> void:
	var n := 5 if desperate else (4 if furious else 3)
	n = mini(n, MAX_PODS - get_tree().get_nodes_in_group("claw_pods").size())
	var c := player().global_position
	for i in n:
		var b := ClawPod.new()
		b.from = hit_center()
		b.land = _in_fence(c + Vector2.from_angle(TAU * i / maxf(n, 1.0) + randf() * 0.5) * randf_range(45.0, 85.0), 14.0)
		b.damage = contact_damage
		b.delay = i * 0.18
		Game.world.effects.add_child(b)
	squash = Vector2(0.9, 1.1)
	Sfx.play("slash", 0.0, -4.0)


# ---------------------------------------------------------------- plow

func _plow_warn() -> void:
	state = "plow_wind"
	state_t = 0.65 if not furious else 0.5
	var to := _lead(0.2) - global_position
	aim = to.normalized() if to.length() > 1.0 else Vector2.RIGHT
	face = signf(aim.x) if aim.x != 0.0 else face
	Game.world.telegraph_line(global_position + Vector2(0, -8), aim, PLOW_LEN + 20.0, 22.0, state_t)
	Sfx.play("alert", 0.0, -2.0)


func _plow(delta: float) -> Vector2:
	plow_travel += PLOW_SPEED * delta
	mark_t -= delta
	if mark_t <= 0.0:  # a spike spot behind it every few units
		mark_t = 0.1
		var at := global_position - aim * 14.0
		var tg := Telegraph.new()
		tg.position = at
		tg.radius = SPIKE_R + 2.0
		tg.dur = 0.6
		tg.color = GREEN
		Game.world.decals.add_child(tg)
		var dmg := contact_damage * 0.9
		get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
			if is_instance_valid(Game.world):
				BossCrab.spike(at, dmg, SPIKE_R + 2.0))
	Game.world.burst(global_position + Vector2(-aim.x * 10.0, 0), DIRT, 1, 40.0, 0.3, 1.5, 40.0)
	if hit_wall and plow_travel > 24.0:
		state = "stuck"
		state_t = 2.0
		armor = STUCK_ARMOR
		knock = Vector2.ZERO
		var w := Game.world
		w.shake(0.9)
		Sfx.play("explode", 0.0, -2.0)
		w.ring(hit_center(), 30.0, GREEN, 0.4, 3.0)
		w.popup_text(hit_center() + Vector2(0, -30), "STUCK! HIT IT!", GREEN, 12)
		return Vector2.ZERO
	if plow_travel >= PLOW_LEN:
		state = "skid"
		state_t = 0.5
		return aim * 60.0
	return aim * PLOW_SPEED


# ---------------------------------------------------------------- effects

func _anim_name() -> String:
	if hurt_t > 0.0 and state in ["drift", "intro"]:
		return "hurt"
	match state:
		"cannon_aim", "cannon":
			return "charge"
		"quake_wind", "plow_wind", "pod_wind":
			return "brace"
		"quake":
			return "stomp"
		"plow", "skid":
			return "plow"
		"gasp":
			return "tired"
		"stuck":
			return "stun"
		"sentry_wind", "sentry", "roar":
			return "fury"
	return "fury" if furious else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.decals, "clawdozer", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	for n in get_tree().get_nodes_in_group("claw_pods"):
		n.queue_free()
	var c := hit_center()
	for i in 6:
		get_tree().create_timer(0.2 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(w):
				var at := c + Vector2(randf_range(-24, 24), randf_range(-8, 14))
				BossCrab.spike(at, 0.0, 8.0)
				w.burst(at, GREEN, 12, 100.0, 0.5, 2.5, 60.0)
				w.shake(0.4))
	Sfx.play("roar", 0.2, -2.0)
