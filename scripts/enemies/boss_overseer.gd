class_name BossOverseer
extends BossBase
## WARP OVERSEER (world 7 WARP NEXUS final boss): a one-eyed rocket saucer that guards the
## warp gate. It hovers round the fight looking about and, in turn:
##   volley   its eye fires fireballs at where you are heading; each one GROWS as it flies
##            and bursts into a ring of sparks (dodge the ball, then the sparks)
##   cone     its rings glow green, two lines mark a WEDGE in front of it, then a cone of
##            flame fills it for a moment (get out of the wedge: to the side or behind)
##   warp     shrinks down and ZIPS across the fight three times, each zip marked by a lane
##            first (untouchable while small); when it grows back it is DIZZY (+60%)
##   summon   opens warp portals (marked circles) and drones of the nexus come out (max 4)
## OVERLOAD (under half health): a roar wipes the shots, two cones at once, longer volleys,
##   four zips, and it adds
##   nova     its eye glows white, a big ring marks the blast round it, then a nova bursts
##            out with a ring of sparks; it is left DIZZY after it (get out of the ring!)
## CRITICAL (under 20%): three cones at once, five zips, shorter pauses.
## Breaks apart in a chain of blasts, leaving its burning wreck (the set's "death").

const CALM := ["volley", "cone", "warp", "volley", "summon", "cone", "warp"]
const FURY := ["nova", "cone", "volley", "warp", "summon", "cone", "nova", "volley", "warp"]
const BALL_SPEED := 85.0
const BALL_LIFE := 1.5
const CONE_LEN := 135.0
const CONE_ARC := 0.75  # radians
const CONE_WARN := 0.85
const CONE_TIME := 0.6
const ZIP_SPEED := 300.0
const ZIP_LEN := 260.0
const ZIP_WARN := 0.5
const NOVA_R := 78.0
const NOVA_WARN := 1.2
const MAX_DRONES := 4
const DRONES := ["laser_drone", "saw_drone", "spider_bot"]
const FURY_ARMOR := 0.8
const DESPERATE_ARMOR := 0.7
const STUN_ARMOR := 1.6
const SMALL := 0.45  # its size while warping
const GLOW := Color("a7f070")
const FIRE := Color("ffb030")

var pattern_i := 0
var furious := false
var desperate := false
var strafe := 1.0
var shots_left := 0
var fire_t := 0.0
var zips_left := 0
var zip_travel := 0.0
var cone_dirs: Array[float] = []
var warping := false
var drones: Array[Enemy] = []
var _cones: Array[Polygon2D] = []
var _cone_hit := false
var _shrink := 1.0


func _init_ai() -> void:
	_size_to_player()
	state = "intro"
	state_t = 1.4
	Sfx.play("roar", 0.3)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 14.0 + sin(t * 2.0) * 3.0
	var to_p := _to_player()
	if not furious and hp < max_hp * 0.5 and not warping:
		_enrage()
	elif furious and not desperate and hp < max_hp * 0.2 and not warping:
		_desperate()
	if state in ["intro", "drift", "volley", "cone_wind", "nova_wind"] and absf(to_p.x) > 2.0:
		face = signf(to_p.x)
	match state:
		"intro", "roar":
			if state_t <= 0.0:
				_after(0.5)
			return Vector2.ZERO
		"drift":
			if state_t <= 0.0:
				_next()
			return _drift(to_p)
		"volley":
			fire_t -= delta
			if fire_t <= 0.0 and shots_left > 0:
				shots_left -= 1
				fire_t = 0.42
				_fireball()
			if shots_left <= 0 and fire_t <= 0.0:
				_after(0.9)
			return _drift(to_p) * 0.3
		"cone_wind":
			if state_t <= 0.0:
				_fire_cones()
			return Vector2.ZERO
		"cone":
			_burn_cones()
			if state_t <= 0.0:
				_clear_cones()
				_after(0.9)
			return Vector2.ZERO
		"shrink":
			_shrink = lerpf(SMALL, 1.0, clampf(state_t / 0.4, 0.0, 1.0))
			if state_t <= 0.0:
				_lock_zip()
			return Vector2.ZERO
		"zip_lock":
			if state_t <= 0.0:
				state = "zip"
				zip_travel = 0.0
				Sfx.play("dash", 0.2, -2.0)
			return Vector2.ZERO
		"zip":
			return _zip(delta)
		"grow":
			_shrink = lerpf(1.0, SMALL, clampf(state_t / 0.35, 0.0, 1.0))
			if state_t <= 0.0:
				_shrink = 1.0
				_set_warping(false)
				_dizzy(2.0)
			return Vector2.ZERO
		"nova_wind":
			squash = Vector2(1.0 + sin(t * 50.0) * 0.04, 1.0)
			if state_t <= 0.0:
				_nova()
				_dizzy(1.6)
			return Vector2.ZERO
		"stun":
			if state_t <= 0.0:
				armor = _base_armor()
				_after(0.4)
			return Vector2.ZERO
	return Vector2.ZERO


func _animate(delta: float) -> void:
	super._animate(delta)
	sprite.scale *= _shrink


func _contact() -> void:
	if warping:
		if state == "zip":
			var p := player()
			if not p.dead and (p.global_position - global_position).length() < 16.0:
				p.take_damage(contact_damage * 1.2, global_position)
				p.knock = aim.orthogonal() * signf(aim.orthogonal().dot(p.global_position - global_position) + 0.01) * 200.0
		return
	super._contact()


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	if warping:
		return
	super.take_damage(amount, dir, crit)


func _base_armor() -> float:
	return DESPERATE_ARMOR if desperate else (FURY_ARMOR if furious else 1.0)


func _after(rest: float) -> void:
	state = "drift"
	state_t = rest * (0.65 if desperate else (0.82 if furious else 1.0))


func _dizzy(secs: float) -> void:
	state = "stun"
	state_t = secs
	armor = STUN_ARMOR
	Game.world.popup_text(hit_center() + Vector2(0, -30), "DIZZY!", GLOW, 11)


func _drift(to_p: Vector2) -> Vector2:
	var dist := to_p.length()
	var toward := to_p.normalized() * (0.6 if dist > 130.0 else (-0.7 if dist < 80.0 else 0.0))
	var v := (to_p.normalized().orthogonal() * strafe * 0.8 + toward).normalized() * speed
	var f := _fence()
	if f != null and not f.holds(global_position + v * 0.25, 30.0):
		v = (f.global_position - global_position).normalized() * speed
	return v


func _next() -> void:
	var list: Array = FURY if furious else CALM
	var step: String = list[pattern_i % list.size()]
	pattern_i += 1
	_next_move(step)


func _next_move(step: String) -> void:
	var ex: Explore = Game.world.explore
	if step == "warp" and ex != null and ex.gate_charged():
		step = "volley"  # the charged gate holds it: no warping
	strafe = -strafe
	match step:
		"volley":
			state = "volley"
			shots_left = 5 if furious else 3
			fire_t = 0.3
			alert.visible = true
			get_tree().create_timer(0.35, false).timeout.connect(func() -> void: alert.visible = false)
			Sfx.play("alert", 0.1, -6.0)
		"cone":
			_wind_cones()
		"warp":
			zips_left = 5 if desperate else (4 if furious else 3)
			_set_warping(true)
			state = "shrink"
			state_t = 0.4
			Sfx.play("charge", 0.3, -4.0)
		"summon":
			_summon()
			_after(0.8)
		"nova":
			state = "nova_wind"
			state_t = NOVA_WARN
			Game.world.telegraph_circle(global_position, NOVA_R, NOVA_WARN)
			Game.world.popup_text(hit_center() + Vector2(0, -34), "OVERLOAD!", Color.WHITE, 13)
			Sfx.play("charge", 0.0, 0.0)


# ---------------------------------------------------------------- volley

## A fireball at where the astronaut is heading: it swells as it flies, then bursts.
func _fireball() -> void:
	var p := player()
	var target := p.global_position + p.velocity * 0.5 + Vector2(0, Player.BODY_Y)
	var d := (target - hit_center()).normalized()
	var s := Game.world.spawn_enemy_shot(hit_center() + d * 18.0, d * BALL_SPEED, contact_damage * 0.7, "overseer_ball")
	s.life = BALL_LIFE
	squash = Vector2(1.15, 0.9)
	Sfx.play("spit", 0.0, -2.0)


# ---------------------------------------------------------------- cones

func _wind_cones() -> void:
	var a := (_to_player() + Vector2(0, Player.BODY_Y)).angle()
	cone_dirs.clear()
	var n := 3 if desperate else (2 if furious else 1)
	for i in n:
		cone_dirs.append(a + (i - (n - 1) * 0.5) * (CONE_ARC + 0.35))
	var w := Game.world
	for c in cone_dirs:
		w.telegraph_line(hit_center(), Vector2.from_angle(c - CONE_ARC * 0.5), CONE_LEN, 6.0, CONE_WARN)
		w.telegraph_line(hit_center(), Vector2.from_angle(c + CONE_ARC * 0.5), CONE_LEN, 6.0, CONE_WARN)
	state = "cone_wind"
	state_t = CONE_WARN
	Sfx.play("charge", 0.2, -4.0)


func _fire_cones() -> void:
	state = "cone"
	state_t = CONE_TIME
	_cone_hit = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for c in cone_dirs:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array([Vector2.ZERO])
		var cols := PackedColorArray([Color(1.0, 0.85, 0.45, 0.9)])
		for k in 9:
			pts.append(Vector2.from_angle(c - CONE_ARC * 0.5 + CONE_ARC * k / 8.0) * CONE_LEN)
			cols.append(Color(1.0, 0.35, 0.05, 0.6))
		poly.polygon = pts
		poly.vertex_colors = cols
		poly.material = mat
		poly.top_level = true
		poly.z_index = 3
		poly.global_position = hit_center()
		add_child(poly)
		_cones.append(poly)
	Sfx.play("laser", 0.0, -2.0)
	Game.world.shake(0.3)


## Hurts once if the astronaut is inside any of the cones.
func _burn_cones() -> void:
	var flick := 0.8 + randf() * 0.2
	for poly in _cones:
		poly.modulate.a = flick
		poly.global_position = hit_center()
	if _cone_hit:
		return
	var p := player()
	if p.dead:
		return
	var off := p.global_position + Vector2(0, Player.BODY_Y) - hit_center()
	if off.length() > CONE_LEN:
		return
	for c in cone_dirs:
		if absf(angle_difference(off.angle(), c)) < CONE_ARC * 0.5:
			_cone_hit = true
			p.take_damage(contact_damage * 1.3, hit_center())
			Game.world.burst(p.global_position + Vector2(0, Player.BODY_Y), FIRE, 10, 70.0, 0.3, 2.0)
			return


func _clear_cones() -> void:
	for poly in _cones:
		if is_instance_valid(poly):
			poly.queue_free()
	_cones.clear()


# ---------------------------------------------------------------- warp

func _set_warping(on: bool) -> void:
	warping = on
	targetable = not on
	collision_layer = 0 if on else 4


## Each zip goes past the astronaut, marked by a lane first.
func _lock_zip() -> void:
	var to := player().global_position - global_position
	aim = to.normalized() if to.length() > 1.0 else Vector2.RIGHT
	face = signf(aim.x) if aim.x != 0.0 else face
	state = "zip_lock"
	state_t = ZIP_WARN * (0.75 if desperate else 1.0)
	Game.world.telegraph_line(global_position, aim, ZIP_LEN, 20.0, state_t)
	Sfx.play("alert", 0.0, -4.0)


func _zip(delta: float) -> Vector2:
	zip_travel += ZIP_SPEED * delta
	if randf() < delta * 40.0:
		Game.world.burst(global_position + Vector2(0, -air), FIRE, 1, 30.0, 0.35, 2.0, 0.0, -aim, 0.4)
	var f := _fence()
	var out := f != null and not f.holds(global_position + aim * 20.0, 10.0)
	if zip_travel >= ZIP_LEN or out or hit_wall:
		zips_left -= 1
		if zips_left > 0:
			_lock_zip()
		else:
			state = "grow"
			state_t = 0.35
		return Vector2.ZERO
	return aim * ZIP_SPEED


# ---------------------------------------------------------------- summon & nova

func _summon() -> void:
	drones.assign(drones.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as Enemy).dead))
	var n := mini(MAX_DRONES - drones.size(), 3 if furious else 2)
	if n <= 0:
		return
	var w := Game.world
	var m := _minion_mults()
	for i in n:
		var id: String = DRONES[randi() % DRONES.size()]
		var at := w.room.open_near(_in_fence(player().global_position + Vector2.from_angle(TAU * i / n + randf()) * randf_range(80.0, 120.0), 20.0))
		w.telegraph_circle(at, 16.0, 0.7)
		get_tree().create_timer(0.7, false).timeout.connect(func() -> void:
			if dead or w != Game.world or w.player.dead:
				return
			w.burst(at, Color("5fd0ff"), 14, 70.0, 0.4, 2.0)
			var e := w.spawn_enemy(id, at, m.x, 1.0, false, true, m.y)
			if e != null:
				drones.append(e))
	Sfx.play("spawn", 0.1, -4.0)


func _nova() -> void:
	var w := Game.world
	var c := global_position
	w.ring(c, NOVA_R, Color.WHITE, 0.4, 4.0, true)
	w.burst(hit_center(), FIRE, 30, 160.0, 0.5, 2.5)
	w.shake(0.8)
	Sfx.play("explode", 0.0, 0.0)
	var p := player()
	var off := p.global_position - c
	if not p.dead and Vector2(off.x, off.y / 0.75).length() < NOVA_R:
		p.take_damage(contact_damage * 1.6, c)
		p.knock = off.normalized() * 240.0
	_ring(16, randf() * TAU, 90.0, 0.5, "overseer_spark")


# ---------------------------------------------------------------- phases

func _enrage() -> void:
	furious = true
	pattern_i = 0
	armor = FURY_ARMOR
	speed *= 1.15
	state = "roar"
	state_t = 1.1
	_clear_cones()
	var w := Game.world
	Sfx.play("roar", 0.0, 3.0)
	w.shake(1.0)
	w.hud.banner("OVERLOAD!", FIRE, 32, 1.2)
	w.hud.tint_flash(FIRE, 0.35, 0.7)
	w.ring(hit_center(), 70.0, GLOW, 0.5, 4.0)
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
	w.hud.banner("CRITICAL!", Color("ff3344"), 32, 1.0)
	w.hud.tint_flash(Color("ff3344"), 0.3, 0.6)
	Sfx.play("alert", 0.0, 2.0)


## The burnt-out wreck stays on the floor after the blasts.
static func leave_wreck(at: Vector2, s: float) -> void:
	var w := Game.world
	if w == null:
		return
	var spr := Sprite2D.new()
	spr.texture = Art.frames("overseer_wreck").get_frame_texture("pop", 0)
	spr.centered = false
	spr.offset = Vector2(-spr.texture.get_width() * 0.5, -spr.texture.get_height())
	spr.scale = Vector2.ONE * s
	spr.position = at
	w.decals.add_child(spr)


func _anim_name() -> String:
	match state:
		"volley":
			return "fire"
		"cone_wind":
			return "charge"
		"cone", "nova_wind":
			return "glow"
		"shrink", "grow":
			return "blink"
		"zip_lock", "zip":
			return "zip"
		"stun":
			return "stun"
	return "walk"


func _on_death() -> void:
	_clear_cones()
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "overseer", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	get_tree().create_timer(0.8, false).timeout.connect(BossOverseer.leave_wreck.bind(global_position, base_scale))
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	var c := hit_center()
	for i in 6:
		get_tree().create_timer(0.15 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(w):
				var at := c + Vector2(randf_range(-28, 28), randf_range(-16, 16))
				w.burst(at, FIRE, 16, 110.0, 0.5, 2.5)
				w.burst(at, GLOW, 8, 70.0, 0.4, 2.0)
				w.shake(0.5)
				Sfx.play("explode", 0.2, -4.0))
