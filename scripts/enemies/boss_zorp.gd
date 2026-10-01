class_name BossZorp
extends BossBase
## World 4 final boss COMMANDER ZORP (zorp set): a cyan alien in a big saucer, fought
## inside the BossFence. Calm (above half health):
##   orb      a plasma orb grows in its dome, then it launches a big one that bursts
##            into a ring of bolts in mid-air (EnemyShot "zorp_big", "split_tex")
##   stream   turns its side cannon on you and sweeps a stream of plasma across
##   drones   launches drones that circle you, then dash at you and burst (zorp_drone)
##   warp     flattens into its teleport ring, a ring marks where you stand, and it
##            drops out of the warp right there: a shockwave and a ring of orbs
## OVERLOAD (under half health): its antennas spark, its shots vanish; bigger patterns and
##   spin     whirls with rings (armoured) and rushes you 3 times, bouncing off the
##            fence and throwing crescent blades sideways; then it is DIZZY: hit it!
## DESPERATE (under 20%): two streams at once, 4 rushes, more drones, shorter pauses.
## Cracks, weeps, and crashes into a smoking wreck that stays on the deck.

const CALM := ["orb", "stream", "drones", "warp", "stream", "orb", "warp"]
const FURY := ["spin", "orb", "stream", "warp", "drones", "spin", "stream", "orb", "warp"]
const ORB_SPEED := 60.0
const STREAM_SPEED := 115.0
const BLADE_SPEED := 95.0
const DASH_SPEED := 225.0
const WARP_R := 36.0
const FURY_ARMOR := 0.85
const DESPERATE_ARMOR := 0.75
const SPIN_ARMOR := 0.4
const STUN_ARMOR := 1.6
const DESPERATE_AT := 0.2
const MAX_DRONES := 6
const CYAN := Color("5fe6ff")
const LIME := Color("c8ff3a")

var pattern_i := 0
var furious := false
var desperate := false
var orbs := 0
var dashes := 0
var emit_t := 0.0
var sweep := 0.0
var sweep_dir := 1.0
var strafe := 1.0
var warp_at := Vector2.ZERO


func _init_ai() -> void:
	_size_to_player()
	state = "intro"
	state_t = 1.6
	Sfx.play("roar", 0.0)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	if not furious and hp < max_hp * 0.5 and state != "intro":
		_enrage()
	elif furious and not desperate and hp < max_hp * DESPERATE_AT:
		_desperate()
	air = 0.0 if state in ["spin_wind", "spin_dash", "warp_hide"] else 4.0 + sin(t * 2.6 + phase) * 2.0
	if state not in ["spin_dash", "stream"] and to_p.x != 0.0:
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
		"orb_charge":
			if randf() < 0.7:  # plasma gathers in the dome
				var c := hit_center() + Vector2(0, -6)
				var q := c + Vector2.from_angle(randf() * TAU) * 22.0
				Game.world.burst(q, CYAN, 1, 30.0, 0.25, 1.5, 0.0, (c - q).normalized(), 0.2)
			if state_t <= 0.0:
				_fire_orb()
				orbs -= 1
				if orbs > 0:
					state_t = 0.55
				else:
					_after(0.7)
		"stream_aim":
			if state_t <= 0.0:
				state = "stream"
				state_t = 1.6 if not furious else 2.0
				emit_t = 0.0
		"stream":
			emit_t -= delta
			sweep += delta * sweep_dir * (1.25 if furious else 1.0)
			if absf(sweep) > 0.95:
				sweep_dir = -sweep_dir
			if emit_t <= 0.0:
				emit_t = 0.07 if furious else 0.09
				_stream_shot(aim.angle() + sweep)
				if desperate:
					_stream_shot(aim.angle() + PI - sweep)
			if state_t <= 0.0:
				_after(0.7)
		"summon":
			if state_t <= 0.0:
				_launch_drones(4 if desperate else (3 if furious else 2))
				_after(0.6)
		"warp_out":
			squash = Vector2(1.0 + (0.5 - state_t), maxf(0.2, 1.0 - (0.5 - state_t) * 1.6))
			if state_t <= 0.0:
				state = "warp_hide"
				state_t = 0.75
				sprite.visible = false
				shadow.visible = false
				targetable = false
				warp_at = _in_fence(player().global_position, 20.0)
				Game.world.telegraph_circle(warp_at, WARP_R, state_t)
				AnimFx.spawn(Game.world.decals, "zorp_warp", "pop", warp_at, 0.35)
				Sfx.play("charge", 0.0, -4.0)
		"warp_hide":
			if state_t <= 0.0:
				_warp_land()
		"warp_in":
			squash = squash.lerp(Vector2.ONE, delta * 8.0)
			if state_t <= 0.0:
				_after(0.5)
		"spin_aim":
			if state_t <= 0.0:
				armor = SPIN_ARMOR
				Game.world.burst(hit_center(), CYAN, 16, 90.0, 0.4, 2.0)
				_spin_lock()
		"spin_wind":
			if state_t <= 0.0:
				state = "spin_dash"
				state_t = 0.6
				emit_t = 0.0
				Sfx.play("dash", 0.0, -2.0)
		"spin_dash":
			emit_t -= delta
			if emit_t <= 0.0:
				emit_t = 0.12
				for s: float in [-1.0, 1.0]:  # blades thrown out to both sides
					var d := aim.orthogonal() * s
					Game.world.spawn_enemy_shot(hit_center() + d * 14.0, d * BLADE_SPEED, contact_damage * 0.45, "zorp_blade")
			_bounce()
			var p := player()
			if not p.dead and p.global_position.distance_to(global_position) < radius + 6.0:
				p.take_damage(contact_damage * 0.8, global_position)
				p.knock += aim * 160.0
			if state_t <= 0.0:
				_dash_end()
			return aim * DASH_SPEED * (1.15 if desperate else 1.0)
		"stun":
			sprite.position.x = sin(t * 14.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				armor = _base_armor()
				_after(0.4)
	return Vector2.ZERO


func _contact() -> void:
	if state in ["warp_hide", "spin_dash"]:
		return  # hidden in the warp; the rush does its own hit
	super._contact()


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	if state == "warp_hide":
		return  # inside the warp
	super.take_damage(amount, dir, crit)


func _can_target() -> bool:
	return state != "warp_hide"


func _base_armor() -> float:
	return DESPERATE_ARMOR if desperate else (FURY_ARMOR if furious else 1.0)


func _after(rest: float) -> void:
	state = "drift"
	state_t = rest * (0.7 if desperate else (0.85 if furious else 1.0))


func _drift(to_p: Vector2) -> Vector2:
	var dist := to_p.length()
	var toward := to_p.normalized() * (0.7 if dist > 130.0 else (-0.7 if dist < 85.0 else 0.0))
	var side := to_p.normalized().orthogonal() * strafe
	var v := (side * 0.7 + toward).normalized() * speed * (1.5 if furious else 1.25)
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
		"orb":
			state = "orb_charge"
			state_t = 0.9
			orbs = 3 if desperate else (2 if furious else 1)
			Sfx.play("charge", 0.0, -4.0)
		"stream":
			state = "stream_aim"
			state_t = 0.55
			aim = (player().global_position + Vector2(0, Player.BODY_Y) - hit_center()).normalized()
			sweep = -0.9
			sweep_dir = 1.0
			face = signf(aim.x) if aim.x != 0.0 else face  # the side cannon points that way
			Game.world.telegraph_line(hit_center(), aim.rotated(-0.9), 150.0, 8.0, state_t)
			Sfx.play("alert", 0.0, -4.0)
		"drones":
			if _drones() >= MAX_DRONES:
				_next()
				return
			state = "summon"
			state_t = 0.7
			Sfx.play("spawn", 0.0, -4.0)
		"warp":
			state = "warp_out"
			state_t = 0.5
			Game.world.burst(hit_center(), CYAN, 10, 60.0, 0.3, 2.0)
			Sfx.play("zap", 0.0, -4.0)
		"spin":
			dashes = 4 if desperate else 3
			state = "spin_aim"
			state_t = 0.6
			Sfx.play("roar", 0.3, -6.0)


func _drones() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).type_id == "zorp_drone":
			n += 1
	return n


# ---------------------------------------------------------------- phases

func _enrage() -> void:
	furious = true
	pattern_i = 0
	state = "roar"
	state_t = 1.3
	speed *= 1.15
	armor = FURY_ARMOR
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	Sfx.play("zap", 0.0, 2.0)
	w.shake(1.0)
	w.hud.banner("OVERLOAD!", LIME, 34, 1.2)
	w.hud.tint_flash(CYAN, 0.35, 0.7)
	w.ring(hit_center(), 70.0, CYAN, 0.5, 4.0)
	w.burst(hit_center(), LIME, 30, 140.0, 0.6, 2.5)
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	var p := player()
	var d := p.global_position - global_position
	if d.length() < 90.0:
		p.knock = d.normalized() * 240.0


func _desperate() -> void:
	desperate = true
	armor = DESPERATE_ARMOR
	speed *= 1.1
	sprite.visible = true
	var w := Game.world
	w.shake(0.8)
	w.hud.banner("RED ALERT!", Color("ff5566"), 30, 1.0)
	w.hud.tint_flash(Color("ff5566"), 0.3, 0.6)
	w.ring(hit_center(), 60.0, LIME, 0.4, 3.0)
	Sfx.play("roar", 0.0, 2.0)
	_launch_drones(3)


# ---------------------------------------------------------------- attacks

## A big orb at where the astronaut is heading; it bursts into bolts before long.
func _fire_orb() -> void:
	var p := player()
	var target := p.global_position + Vector2(0, Player.BODY_Y) + p.velocity * 0.4
	var from := hit_center() + Vector2(0, -4)
	var d := (target - from).normalized()
	var s := Game.world.spawn_enemy_shot(from + d * 16.0, d * ORB_SPEED, contact_damage * 0.9, "zorp_big")
	s.life = minf(2.4, from.distance_to(target) / ORB_SPEED + 0.3)
	squash = Vector2(0.85, 1.15)
	Game.world.shake(0.2)
	Sfx.play("zap", 0.0, -1.0)


func _stream_shot(angle: float) -> void:
	var d := Vector2.from_angle(angle)
	var from := hit_center() + d * 18.0
	Game.world.spawn_enemy_shot(from, d * STREAM_SPEED, contact_damage * 0.4, "zorp_orb")
	if randf() < 0.4:
		Sfx.play("zap", 0.2, -12.0)


func _launch_drones(n: int) -> void:
	var w := Game.world
	var m := _minion_mults()
	n = mini(n, MAX_DRONES - _drones())
	for i in n:
		var pos := _in_fence(global_position + Vector2.from_angle(TAU * i / maxf(n, 1.0) + randf()) * 30.0, 14.0)
		w.spawn_enemy("zorp_drone", pos, m.x, 1.0, false, true, m.y)
		w.burst(pos, CYAN, 8, 50.0, 0.35, 2.0)
	Sfx.play("spawn", 0.0, -2.0)


## Out of the warp onto the marked spot: a shockwave and a ring of orbs.
func _warp_land() -> void:
	global_position = warp_at
	sprite.visible = true
	shadow.visible = true
	targetable = true
	state = "warp_in"
	state_t = 0.5
	squash = Vector2(1.5, 0.4)
	var w := Game.world
	w.ring(warp_at, WARP_R, CYAN, 0.35, 4.0, true)
	w.burst(warp_at + Vector2(0, -6), CYAN, 20, 120.0, 0.45, 2.5)
	w.burst(warp_at + Vector2(0, -6), LIME, 10, 80.0, 0.35, 2.0)
	w.shake(0.6)
	Sfx.play("explode", 0.0, -2.0)
	var p := player()
	if not p.dead:
		var off := p.global_position - warp_at  # the circle is drawn squashed (y * 0.75)
		if Vector2(off.x, off.y / 0.75).length() < WARP_R:
			p.take_damage(contact_damage * 1.2, warp_at)
			p.knock += off.normalized() * 200.0
	_ring(12 if furious else 8, randf() * TAU, 70.0, 0.4, "zorp_orb")


func _spin_lock() -> void:
	state = "spin_wind"
	state_t = 0.45
	aim = (player().global_position - global_position).normalized()
	Game.world.telegraph_line(global_position + Vector2(0, -4), aim, 170.0, 18.0, state_t)
	Sfx.play("alert", 0.0, -4.0)


func _bounce() -> void:
	var f := _fence()
	if f != null and not f.holds(global_position, 16.0):
		var out := (global_position - f.global_position).normalized()
		global_position = f.global_position + out * (f.radius - 17.0)
		aim = aim.bounce(out)
		Game.world.burst(global_position, CYAN, 6, 50.0, 0.25, 2.0)
	elif hit_wall and get_slide_collision_count() > 0:
		aim = aim.bounce(get_slide_collision(0).get_normal())


func _dash_end() -> void:
	_ring(10 if desperate else 8, randf() * TAU, BLADE_SPEED, 0.45, "zorp_blade")
	Game.world.ring(hit_center(), 26.0, CYAN, 0.3, 3.0)
	Game.world.shake(0.3)
	dashes -= 1
	if dashes > 0:
		_spin_lock()
		return
	_stun(2.4)


func _stun(secs: float) -> void:
	state = "stun"
	state_t = secs
	armor = STUN_ARMOR
	var w := Game.world
	w.ring(hit_center(), 34.0, Color("ffcd75"), 0.4, 3.0)
	w.popup_text(hit_center() + Vector2(0, -30), "DIZZY! HIT HIM!", Color("ffcd75"), 12)
	Sfx.play("freeze", 0.0, 2.0)


func _anim_name() -> String:
	match state:
		"intro":
			return "angry"
		"roar":
			return "fury"
		"orb_charge":
			return "charge"
		"stream_aim", "stream":
			return "fire"
		"summon":
			return "summon"
		"warp_out", "warp_hide":
			return "warp"
		"spin_aim", "spin_wind", "spin_dash":
			return "spin"
		"stun":
			return "stun"
	return "fury" if desperate else ("angry" if furious else "walk")


func _on_death() -> void:
	var w := Game.world
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and e != self and e.type_id == "zorp_drone":
			e.take_damage(99999.0)
	# sparks and blasts all over the saucer, then one big burst of plasma
	var c := hit_center()
	for i in 7:
		get_tree().create_timer(0.2 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(w):
				var at := c + Vector2(randf_range(-26, 26), randf_range(-20, 14))
				AnimFx.spawn(w.effects, "zorp_pop", "pop", at, randf_range(0.2, 0.35))
				w.burst(at, CYAN, 12, 100.0, 0.5, 2.5, 60.0)
				w.shake(0.4)
				Sfx.play("explode", 0.2, -6.0))
	get_tree().create_timer(1.5, false).timeout.connect(func() -> void:
		if is_instance_valid(w):
			w.ring(c, 80.0, CYAN, 0.6, 4.0)
			w.burst(c, LIME, 40, 160.0, 0.8, 2.5, 100.0)
			Sfx.play("explode", 0.0, 2.0))
	Sfx.play("hurt", 0.0)
