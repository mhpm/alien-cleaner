class_name BossMagma
extends BossBase
## MAGMA DRAKE (world 4 mini boss, wave 11): a little lava dragon with bat wings.
## Calm (above half health), in turn:
##   breath    turns to you ("breath") and SWEEPS a stream of fireballs across a wide arc
##   crescents ("cast") a fan of lava crescent waves, then a second fan through the gaps
##   dive      flaps up out of reach (shadow only), its shadow HUNTS you for a moment, then
##             it slams down where the shadow is: magma shockwave + ring of fireballs
##   mines     ("summon") drops lava mines round you that throb, then ERUPT one after
##             another (the last ones nearest you)
## ERUPTION (under half health): blazing ("fury"), its shots vanish; every dive leaves a
##   burning lava pool and leaves it DIZZY (stars, takes +60%), and it adds
##   meteor    a huge burning meteor falls on a marked spot and bursts into fireballs
## INFERNO (under 20%): two breath streams at once, more mines, a meteor after each dive.
## Collapses, smoking, into a lava pool that crumbles to embers (the set's "death").

const CALM := ["breath", "crescents", "dive", "mines", "crescents", "breath", "dive"]
const FURY := ["dive", "meteor", "breath", "mines", "dive", "crescents", "meteor", "breath"]
const FIGHT_SECS := 45.0  # mini boss: a shorter fight than the final bosses
const FIRE_SPEED := 120.0
const CRESCENT_SPEED := 95.0
const DIVE_HEIGHT := 120.0
const SLAM_R := 42.0
const MINE_R := 26.0
const FURY_ARMOR := 0.85
const DESPERATE_ARMOR := 0.75
const STUN_ARMOR := 1.6
const DESPERATE_AT := 0.2
const LAVA := Color("ff8a2a")

var pattern_i := 0
var furious := false
var desperate := false
var emit_t := 0.0
var sweep := 0.0
var sweep_dir := 1.0
var strafe := 1.0
var dive_to := Vector2.ZERO
var mark: Telegraph


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
	if state not in ["rise", "hunt", "slam"]:
		air = 6.0 + sin(t * 3.5) * 3.0  # wings flapping
		if state != "breath" and to_p.x != 0.0:
			face = signf(to_p.x)
	if randf() < delta * 6.0:  # embers dripping off it
		Game.world.burst(global_position + Vector2(randf_range(-12, 12), -air - 8.0), LAVA, 1, 15.0, 0.6, 1.5, 40.0)
	match state:
		"intro", "roar":
			squash = Vector2(1.0 + sin(t * 40.0) * 0.05, 1.0)
			if state_t <= 0.0:
				_next()
		"drift":
			if state_t <= 0.0:
				_next()
			return _drift(to_p)
		"breath_aim":
			if state_t <= 0.0:
				state = "breath"
				state_t = 1.5 if not furious else 1.9
				emit_t = 0.0
		"breath":
			emit_t -= delta
			sweep += delta * sweep_dir * (1.3 if furious else 1.0)
			if absf(sweep) > 0.9:
				sweep_dir = -sweep_dir
			face = signf(aim.x) if aim.x != 0.0 else face
			if emit_t <= 0.0:
				emit_t = 0.07
				_fire(aim.angle() + sweep)
				if desperate:
					_fire(aim.angle() - sweep)
			if state_t <= 0.0:
				_after(0.7)
		"cast":
			if state_t <= 0.0:
				_crescents(0.0)
				state = "cast2"
				state_t = 0.45
		"cast2":
			if state_t <= 0.0:
				_crescents(0.5)
				_after(0.8)
		"rise":
			air = minf(DIVE_HEIGHT, air + delta * 320.0)
			targetable = false
			if state_t <= 0.0:
				state = "hunt"
				state_t = 1.3 if not desperate else 1.0
				mark = Telegraph.new()
				mark.radius = SLAM_R
				mark.dur = state_t + 0.15
				mark.color = LAVA
				Game.world.decals.add_child(mark)
		"hunt":
			# the shadow chases the astronaut, slowing as the slam nears
			var k := clampf(state_t / 1.3, 0.2, 1.0)
			var v := to_p.normalized() * minf(to_p.length() / delta, 150.0 * k)
			if is_instance_valid(mark):
				mark.global_position = global_position
			if state_t <= 0.0:
				state = "slam"
				state_t = 0.18
				Sfx.play("dash", 0.0, -2.0)
				return Vector2.ZERO
			return v
		"slam":
			air = DIVE_HEIGHT * clampf(state_t / 0.18, 0.0, 1.0)
			if state_t <= 0.0:
				_land()
		"mines":
			if state_t <= 0.0:
				_drop_mines()
				_after(1.0)
		"meteor_aim":
			if state_t <= 0.0:
				_meteor()
				_after(0.9)
		"stun":
			sprite.position.x = sin(t * 14.0) * 0.8
			if state_t <= 0.0:
				sprite.position.x = 0.0
				armor = _base_armor()
				_after(0.4)
	return Vector2.ZERO


func _contact() -> void:
	if state in ["rise", "hunt", "slam"]:
		return
	super._contact()


func _base_armor() -> float:
	return DESPERATE_ARMOR if desperate else (FURY_ARMOR if furious else 1.0)


func _after(rest: float) -> void:
	state = "drift"
	state_t = rest * (0.7 if desperate else (0.85 if furious else 1.0))


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
		"breath":
			state = "breath_aim"
			state_t = 0.5
			aim = (player().global_position + Vector2(0, Player.BODY_Y) - hit_center()).normalized()
			sweep = -0.85
			sweep_dir = 1.0
			face = signf(aim.x) if aim.x != 0.0 else face
			Game.world.telegraph_line(hit_center(), aim.rotated(-0.85), 150.0, 8.0, state_t)
			Sfx.play("charge", 0.0, -4.0)
		"crescents":
			state = "cast"
			state_t = 0.55
			Sfx.play("charge", 0.1, -6.0)
		"dive":
			state = "rise"
			state_t = 0.45
			Sfx.play("dash", 0.2, -4.0)
			Game.world.burst(global_position, LAVA, 12, 70.0, 0.4, 2.0, -40.0)
		"mines":
			state = "mines"
			state_t = 0.7
			Sfx.play("roar", 0.3, -8.0)
		"meteor":
			state = "meteor_aim"
			state_t = 0.4
			Sfx.play("roar", 0.1, -4.0)


# ---------------------------------------------------------------- phases

func _enrage() -> void:
	furious = true
	pattern_i = 0
	state = "roar"
	state_t = 1.2
	speed *= 1.15
	armor = FURY_ARMOR
	air = 6.0
	targetable = true
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	w.shake(1.0)
	w.hud.banner("ERUPTION!", LAVA, 34, 1.2)
	w.hud.tint_flash(LAVA, 0.35, 0.7)
	_fx("magma_ring", global_position, 0.6, 0.5)
	w.burst(hit_center(), Color("ffcd75"), 30, 140.0, 0.6, 2.5)
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
	var w := Game.world
	w.shake(0.8)
	w.hud.banner("INFERNO!", Color("ff5566"), 32, 1.0)
	w.hud.tint_flash(Color("ff5566"), 0.3, 0.6)
	Sfx.play("roar", 0.0, 2.0)


# ---------------------------------------------------------------- attacks

func _fire(angle: float) -> void:
	var d := Vector2.from_angle(angle)
	Game.world.spawn_enemy_shot(hit_center() + d * 18.0, d * FIRE_SPEED, contact_damage * 0.4, "magma")
	if randf() < 0.3:
		Sfx.play("spit", 0.3, -14.0)


## A fan of crescent waves at the astronaut (`half` = turned half a gap: the second fan).
func _crescents(half: float) -> void:
	var n := 7 if desperate else (6 if furious else 5)
	var d := (player().global_position + Vector2(0, Player.BODY_Y) - hit_center()).normalized()
	var gap := 0.28
	for i in n:
		var a := (i - (n - 1) * 0.5 + half) * gap
		var dir := d.rotated(a)
		Game.world.spawn_enemy_shot(hit_center() + dir * 16.0, dir * CRESCENT_SPEED, contact_damage * 0.5, "magma_crescent")
	squash = Vector2(0.85, 1.15)
	Sfx.play("slash", 0.1, -4.0)


## Down out of the dive: shockwave, fireballs, and once furious a lava pool and a daze.
func _land() -> void:
	air = 0.0
	targetable = true
	if is_instance_valid(mark):
		mark.queue_free()
	var w := Game.world
	var c := global_position
	squash = Vector2(1.5, 0.6)
	w.shake(0.8)
	Sfx.play("explode", 0.0, 0.0)
	_fx("magma_ring", c, 0.5, 0.45)
	w.burst(c, LAVA, 24, 140.0, 0.5, 2.5, 60.0)
	var p := player()
	if not p.dead:
		var off := p.global_position - c  # the circle is drawn squashed (y * 0.75)
		if Vector2(off.x, off.y / 0.75).length() < SLAM_R:
			p.take_damage(contact_damage * 1.3, c)
			p.knock += off.normalized() * 220.0
	_ring(12 if furious else 8, randf() * TAU, 85.0, 0.45, "magma")
	if furious:
		var pd := GooPuddle.new()
		pd.style = "lava"
		pd.acid = true
		pd.radius = 26.0
		pd.life = 6.0
		pd.damage = contact_damage * 0.4
		pd.position = c
		w.decals.add_child(pd)
		if desperate:
			_meteor()
		_stun(2.0)
	else:
		_after(0.6)


## Lava mines round the astronaut; they throb and erupt one after another, the ones
## closest to the astronaut last.
func _drop_mines() -> void:
	var p := player().global_position
	var n := 7 if desperate else (6 if furious else 4)
	var spots: Array[Vector2] = []
	for i in n:
		var r := randf_range(30.0, 90.0) if i > 0 else 0.0
		spots.append(_in_fence(p + Vector2.from_angle(TAU * i / n + randf()) * r, 14.0))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(p) > b.distance_to(p))
	for i in spots.size():
		var at := spots[i]
		var delay := 1.4 + i * 0.25
		var mine := Sprite2D.new()
		mine.texture = Art.frames("magma_mine").get_frame_texture("fly", 0)
		mine.position = at + Vector2(0, -6)
		mine.scale = Vector2.ONE * 0.18
		Game.world.effects.add_child(mine)
		var tw := mine.create_tween().set_loops(int(delay / 0.3))
		tw.tween_property(mine, "scale", Vector2.ONE * 0.22, 0.15)
		tw.tween_property(mine, "scale", Vector2.ONE * 0.18, 0.15)
		var tg := Telegraph.new()
		tg.position = at
		tg.radius = MINE_R
		tg.dur = delay
		tg.color = LAVA
		Game.world.decals.add_child(tg)
		var dmg := contact_damage
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_instance_valid(mine):
				mine.queue_free()
			if is_instance_valid(Game.world):
				BossMagma.erupt(at, dmg))
	Game.world.burst(hit_center(), LAVA, 12, 80.0, 0.4, 2.0)


static func erupt(at: Vector2, dmg: float) -> void:
	var w := Game.world
	_fx_static("magma_erupt", at + Vector2(0, -8), 0.32, 0.5)
	w.burst(at, LAVA, 14, 100.0, 0.45, 2.5, 80.0)
	w.shake(0.25)
	Sfx.play("explode", 0.2, -8.0)
	var p := w.player
	if not p.dead:
		var off := p.global_position - at
		if Vector2(off.x, off.y / 0.75).length() < MINE_R:
			p.take_damage(dmg, at)


## A huge meteor dropping on the astronaut's spot; it bursts into fireballs.
func _meteor() -> void:
	var p := player()
	var to := _in_fence(p.global_position + p.velocity * 0.6, 14.0)
	Game.world.telegraph_circle(to, 30.0, 1.1)
	var from := to + Vector2(-140.0, -260.0)
	var s := Game.world.spawn_enemy_shot(from, (to - from) / 1.1, contact_damage * 1.2, "magma_meteor")
	s.vel = (to - from) / 1.1
	s.life = 1.1
	Sfx.play("charge", 0.0, -2.0)


func _stun(secs: float) -> void:
	state = "stun"
	state_t = secs
	armor = STUN_ARMOR
	var w := Game.world
	w.ring(hit_center(), 34.0, Color("ffcd75"), 0.4, 3.0)
	w.popup_text(hit_center() + Vector2(0, -30), "DIZZY! HIT IT!", Color("ffcd75"), 12)
	Sfx.play("freeze", 0.0, 2.0)


## A one-frame effect sprite that grows and fades.
func _fx(set_name: String, pos: Vector2, s: float, dur: float) -> void:
	_fx_static(set_name, pos, s, dur)


static func _fx_static(set_name: String, pos: Vector2, s: float, dur: float) -> void:
	var sp := Sprite2D.new()
	sp.texture = Art.frames(set_name).get_frame_texture("pop", 0)
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
		"breath_aim", "breath":
			return "breath"
		"cast", "cast2", "meteor_aim":
			return "cast"
		"mines":
			return "summon"
		"stun":
			return "stun"
		"roar":
			return "fury"
	return "fury" if furious else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.decals, "magma_drake", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	var c := hit_center()
	for i in 6:
		get_tree().create_timer(0.2 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(w):
				var at := c + Vector2(randf_range(-24, 24), randf_range(-14, 14))
				BossMagma._fx_static("magma_erupt", at, 0.25, 0.4)
				w.burst(at, LAVA, 12, 100.0, 0.5, 2.5, 60.0)
				w.shake(0.4)
				Sfx.play("explode", 0.2, -6.0))
	Sfx.play("roar", 0.2, -2.0)
