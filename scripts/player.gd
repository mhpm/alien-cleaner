class_name Player
extends CharacterBody2D
## The astronaut. Moves with the joystick, auto-aims at the nearest alien and
## fires faster while standing still. Special ability: Air Blast (or, with the shop's
## Infected Mode, mutate when the infection meter is full; see Infected).

const BLAST_RADIUS := 62.0
const BODY_Y := -10.0  # world-space height of the torso

var input_dir := Vector2.ZERO
var locked := false
var dead := false

var body: Astronaut  # reference-sheet astronaut + the equipped blaster, aimed separately
var shadow: Sprite2D
var shield_fx: Sprite2D
var mat: ShaderMaterial

var fire_t := 0.5
var invuln := 0.0
var walk_t := 0.0
var t := 0.0
var aim_dir := Vector2.UP
var knock := Vector2.ZERO
var flash_t := 0.0
var blast_t := 0.0
var shield_up := false
var shield_t := 0.0
var orbit_a := 0.0
var bots: Array[Sprite2D] = []
var bot_hits: Dictionary = {}
var dust_t := 0.0
var hurt_t := 0.0
var shoot_t := 0.0
var facing := 1.0
var squash := Vector2.ONE
var gun_angle := -PI * 0.5
var recoil := 0.0
var infected: Infected  # Infected mode: meter, mutation and its powers


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | PropData.LAYER_BODIES_ONLY
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.5
	cs.shape = c
	cs.position = Vector2(0, -2)
	add_child(cs)
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(1.3, 1.2)
	add_child(shadow)
	mat = Art.flash_material()
	body = Astronaut.new()
	add_child(body)
	body.set_layer_material(mat)
	shield_fx = Sprite2D.new()
	shield_fx.texture = Art.tex("shield")
	shield_fx.position = Vector2(0, BODY_Y)
	shield_fx.scale = Vector2(1.45, 1.45)
	shield_fx.visible = false
	add_child(shield_fx)
	infected = Infected.new()
	add_child(infected)
	move_child(infected, 0)
	infected.setup(self)
	refresh_upgrades()


## Timed power-ups (CollectibleData "buff"): kind -> seconds left. frenzy = fire rate x2.5,
## boots = speed, triple = extra diagonal shots, rage = double damage, shield = no
## damage, star = no damage + crush aliens on touch, ufo = two extra orbiting UFOs.
var buffs: Dictionary = {}
var star_hit_t := 0.0


func has_buff(k: String) -> bool:
	return float(buffs.get(k, 0.0)) > 0.0


func add_buff(k: String, secs: float) -> void:
	var was := has_buff(k)
	buffs[k] = minf(float(buffs.get(k, 0.0)) + secs, secs * 2.0)
	if k == "ufo" and not was:
		refresh_upgrades()


func _tick_buffs(delta: float) -> void:
	for k: String in buffs.keys():
		buffs[k] = float(buffs[k]) - delta
		if float(buffs[k]) <= 0.0:
			buffs.erase(k)
			if k == "ufo":
				refresh_upgrades()
			if k == "star":
				body.modulate = Color(1, 1, 1, body.modulate.a)
	if has_buff("star"):
		# rainbow flicker and crush every alien you touch
		var c := Color.from_hsv(fmod(t * 2.5, 1.0), 0.45, 1.0) * 1.3
		body.modulate = Color(c.r, c.g, c.b, body.modulate.a)
		star_hit_t -= delta
		if star_hit_t <= 0.0:
			star_hit_t = 0.12
			for n in Game.world.enemy_cache:
				if not is_instance_valid(n):
					continue
				var e := n as Enemy
				if e != null and e.targetable and e.global_position.distance_to(global_position) < e.radius + 10.0:
					e.take_damage(float(Game.stats.damage) * 2.0, (e.global_position - global_position).normalized() * 2.5)
					Game.world.burst(e.hit_center(), Color("ffcd75"), 5, 60.0, 0.3, 2.0)
	if has_buff("boots") and input_dir.length() > 0.2 and randf() < delta * 20.0:
		Game.world.burst(global_position + Vector2(randf_range(-3, 3), -1), Color("ff5566"), 1, 20.0, 0.35, 1.5, -10.0)


func reset_for_room(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	knock = Vector2.ZERO
	input_dir = Vector2.ZERO
	fire_t = 0.5
	invuln = 0.4
	locked = false
	infected.end_now()
	aim_dir = Vector2.UP
	gun_angle = -PI * 0.5
	if bool(Game.stats.shield):
		shield_up = true
	if not buffs.is_empty():
		buffs.clear()
		body.modulate = Color(1, 1, 1, body.modulate.a)
		refresh_upgrades()


func refresh_upgrades() -> void:
	var own := int(Game.stats.orbiters)
	var n := own + (2 if has_buff("ufo") else 0)
	while bots.size() > n:
		bots.pop_back().queue_free()
	while bots.size() < n:
		var b := Sprite2D.new()
		if bots.size() >= own:
			# UFO buddies (power-up)
			b.texture = CollectibleData.tex("ufo")
			b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			b.scale = Vector2.ONE * (11.0 / b.texture.get_width())
		else:
			b.texture = Art.tex("bot")
		add_child(b)
		bots.append(b)
	if bool(Game.stats.shield) and shield_t == 0.0:
		shield_up = true


func _physics_process(delta: float) -> void:
	if dead:
		return
	t += delta
	var s := Game.stats
	if invuln > 0.0:
		invuln -= delta
		body.modulate.a = 0.35 if fmod(invuln, 0.12) < 0.06 else 1.0
	else:
		body.modulate.a = 1.0
	blast_t = maxf(blast_t - delta, 0.0)
	_tick_buffs(delta)
	if has_buff("frenzy"):
		if randf() < delta * 14.0:
			Game.world.burst(global_position + Vector2(randf_range(-5, 5), -6), Color("ffcd75"), 1, 25.0, 0.3, 1.5, -40.0)
	flash_t = maxf(flash_t - delta, 0.0)

	var dir := Vector2.ZERO if locked else input_dir.limit_length(1.0)
	var slow := Game.world.room.slow_factor(global_position)  # sticky alien creep
	velocity = dir * float(s.move_speed) * slow * (1.45 if has_buff("boots") else 1.0) * infected.speed_mult() + knock
	var dash_v := infected.dash_velocity()
	if dash_v != Vector2.INF:
		velocity = dash_v
	if slow < 1.0 and dir.length() > 0.15 and randf() < delta * 10.0:
		Game.world.burst(global_position, Color("c75bd6"), 1, 12.0, 0.4, 1.5, -10.0)
	knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	var moving := dir.length() > 0.15

	var target := _find_target()
	if target != null:
		aim_dir = (target.hit_center() - _gun_pivot()).normalized()
	elif moving:
		aim_dir = dir.normalized()
	# the blaster swings quickly toward the aim; shots always leave along the barrel
	gun_angle = lerp_angle(gun_angle, aim_dir.angle(), 1.0 - exp(-28.0 * delta))

	if target != null and not locked:
		fire_t -= delta * (1.0 if not moving else 0.6)
		if fire_t <= 0.0:
			_shoot()
			fire_t = float(s.fire_interval) * (0.4 if has_buff("frenzy") else 1.0) * infected.fire_mult()
	else:
		fire_t = maxf(fire_t - delta, 0.08)

	if bool(s.shield) and not shield_up:
		shield_t += delta
		if shield_t >= float(s.get("shield_cd", 8.0)):
			shield_up = true
			shield_t = 0.0
			Sfx.play("shield", 0.0, -8.0)
	shield_fx.visible = shield_up or has_buff("shield")
	shield_fx.modulate.a = 0.75 + sin(t * 4.0) * 0.2

	_update_bots(delta)
	_animate(delta, moving, dir)


func _muzzle_base() -> Vector2:
	return global_position + Vector2(0, BODY_Y)


func _gun_pivot() -> Vector2:
	return body.to_global(body.grip_pos())


func _gun_dir() -> Vector2:
	return Vector2.from_angle(gun_angle)


func _find_target() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	var los: Enemy = null
	var los_d := INF
	var reach := Game.world.aim_range()  # big rooms: only aliens on screen
	for n in Game.world.enemy_cache:
		if not is_instance_valid(n):  # freed since the cache was refreshed
			continue
		var e := n as Enemy
		if e == null or not e.targetable:
			continue
		var d := global_position.distance_to(e.global_position)
		if d > reach and not e.is_boss:
			continue
		if d < best_d:
			best_d = d
			best = e
		if d < los_d and _has_los(e):
			los_d = d
			los = e
	return los if los != null else best


func _has_los(e: Enemy) -> bool:
	var q := PhysicsRayQueryParameters2D.create(_muzzle_base(), e.hit_center(), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider is Barrel


func _shoot() -> void:
	var s := Game.stats
	var d := _gun_dir()
	var origin := body.to_global(body.muzzle_pos())
	var perp := d.orthogonal()
	var shots := int(s.shots)
	for i in shots:
		var off := (i - (shots - 1) * 0.5) * 5.0
		_spawn_bullet(origin + perp * off, d)
	for k in int(s.spread) + (1 if has_buff("triple") else 0):
		var a := 0.3 * (k + 1)
		_spawn_bullet(origin, d.rotated(a))
		_spawn_bullet(origin, d.rotated(-a))
	shoot_t = 0.45
	recoil = 2.5
	var lvl := int(s.weapon)
	Sfx.play("shoot", 0.12, -7.0 + lvl)
	var st := WeaponData.style(Astronaut.weapon_variant())
	var flash := AnimFx.spawn(Game.world.effects, "muzzle", "flash", origin, 0.2 + lvl * 0.03)
	if infected.active:
		flash.material = Art.shot_material(Infected.MAGENTA)
		flash.scale *= 1.4
		Game.world.burst(origin, Infected.MAGENTA, 3, 50.0, 0.18, 2.0, 0.0, d, 0.5)
		return
	if st.color != null:
		flash.material = Art.shot_material(Color(str(st.color)))
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, 0.06)
	Game.world.burst(origin, Color(str(st.flash)), 2 + lvl, 45.0, 0.15, 1.5, 0.0, d, 0.5)


func _spawn_bullet(pos: Vector2, d: Vector2) -> void:
	var s := Game.stats
	var tier := WeaponData.tier(int(s.weapon))
	var st := WeaponData.style(Astronaut.weapon_variant())
	var b := Bullet.new()
	var mult := 1.0
	if infected.active:
		# mutant plasma comets instead of the blaster's shots
		tier = Infected.SHOT_TIER
		st = WeaponData.style("standard")
		mult = infected.power() * float(WeaponData.tier(int(s.weapon)).dmg)
		b.pop_art = "inf_burst"
		b.pop_color = Infected.MAGENTA
	b.tier = tier
	b.style = st
	b.dir = d
	b.speed = float(s.bullet_speed) * float(tier.speed) / 220.0 * float(st.speed)
	b.damage = float(s.damage) * float(tier.dmg) * mult * (2.0 if has_buff("rage") else 1.0)
	b.pierce = int(s.pierce) + int(tier.pierce) + int(st.pierce)
	b.bounces = int(s.ricochet)
	Game.world.effects.add_child(b)
	b.global_position = pos


func blast() -> void:
	if dead or locked:
		return
	if infected.can_transform():
		infected.transform()
		return
	if infected.active:
		infected.dash()
		return
	if blast_t > 0.0:
		return
	var s := Game.stats
	blast_t = float(s.blast_cooldown)
	var w := Game.world
	var c := global_position + Vector2(0, BODY_Y)
	w.ring(c, BLAST_RADIUS, Color("c0f4ff"), 0.35, 4.0, true)
	w.ring(c, BLAST_RADIUS * 0.6, Color.WHITE, 0.25, 2.0)
	w.burst(c, Color(1, 1, 1, 0.9), 22, 160.0, 0.4, 2.0)
	Sfx.play("blast", 0.05)
	w.shake(0.35)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or not e.targetable:
			continue
		var d := e.global_position - global_position
		var l := d.length()
		if l < BLAST_RADIUS + e.radius:
			var dn := d.normalized() if l > 0.1 else Vector2.UP
			e.push(dn * (230.0 + float(s.knockback) * 1.5) * (1.0 - l / (BLAST_RADIUS * 1.6)))
			e.stun(0.6)
			e.take_damage(float(s.damage) * 0.5, Vector2.ZERO)
	if bool(s.get("surge", false)):
		# Energy Surge (full gear set): the blast also fires a ring of plasma
		for i in 12:
			_spawn_bullet(c, Vector2.from_angle(TAU * i / 12.0))
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		var shot := n as EnemyShot
		if shot != null and shot.global_position.distance_to(c) < BLAST_RADIUS:
			shot.pop()
	squash = Vector2(1.3, 0.75)


func take_damage(amount: float, from := Vector2.INF, hazard := false) -> void:
	if dead or invuln > 0.0 or has_buff("shield") or has_buff("star") or infected.untouchable():
		return
	var w := Game.world
	if shield_up and not hazard:
		shield_up = false
		shield_t = 0.0
		invuln = 0.6
		Sfx.play("shield")
		w.burst(global_position + Vector2(0, BODY_Y), Color("73eff7"), 16, 90.0, 0.4, 2.0)
		w.ring(global_position + Vector2(0, BODY_Y), 20.0, Color("73eff7"), 0.25, 2.0)
		return
	var s := Game.stats
	if hazard:
		amount *= float(s.get("hazard_mult", 1.0))
	amount *= infected.damage_taken_mult()
	s.hp = maxf(0.0, float(s.hp) - amount)
	Game.hp_changed.emit()
	flash_t = 0.15
	invuln = 0.6 if hazard else 1.0
	Sfx.play("hurt")
	w.shake(0.5)
	w.hitstop(70)
	w.popup_text(global_position + Vector2(0, -26), "-%d" % roundi(amount), Color("ff5566"), 16)
	w.burst(global_position + Vector2(0, BODY_Y), Color("f4f4f4"), 8, 70.0, 0.3, 2.0)
	hurt_t = 0.3
	if from != Vector2.INF:
		knock = (global_position - from).normalized() * 150.0
	if float(s.hp) <= 0.0:
		_die()


func _die() -> void:
	infected.end_now()
	dead = true
	shield_fx.visible = false
	for b in bots:
		b.visible = false
	Sfx.play("hurt", 0.0)
	var w := Game.world
	w.burst(global_position + Vector2(0, BODY_Y), Color("f4f4f4"), 24, 110.0, 0.7, 2.5)
	w.shake(0.8)
	# collapse (death animation from the sheet) and fade a little
	body.rotation = 0.0
	body.play("death")
	body.create_tween().tween_property(body, "modulate", Color(0.7, 0.7, 0.8, 0.8), 0.6)
	w.on_player_died()


func _update_bots(delta: float) -> void:
	if bots.is_empty():
		return
	orbit_a += delta * 3.4
	var n := bots.size()
	var now := Time.get_ticks_msec()
	var dmg := float(Game.stats.damage) * 0.7
	for i in n:
		var a := orbit_a + TAU * i / n
		var p := Vector2(cos(a) * 22.0, sin(a) * 15.0 + BODY_Y)
		bots[i].position = p
		bots[i].z_index = 1 if sin(a) > 0.0 else 0
		var wp := global_position + p
		for node in get_tree().get_nodes_in_group("enemies"):
			var e := node as Enemy
			if e == null or not e.targetable:
				continue
			if wp.distance_to(e.hit_center()) < e.radius + 4.0:
				var id := e.get_instance_id()
				if now - int(bot_hits.get(id, 0)) > 400:
					bot_hits[id] = now
					e.take_damage(dmg, (e.global_position - global_position).normalized() * 0.4)
					Game.world.burst(wp, Color("73eff7"), 4, 40.0, 0.2, 1.5)
					Sfx.play("hit", 0.2, -8.0)


func _animate(delta: float, moving: bool, dir: Vector2) -> void:
	hurt_t = maxf(0.0, hurt_t - delta)
	shoot_t = maxf(0.0, shoot_t - delta)
	if shoot_t > 0.0 and absf(aim_dir.x) > 0.05:
		facing = signf(aim_dir.x)
	elif moving and absf(dir.x) > 0.1:
		facing = signf(dir.x)
	# sprite animation: walking away from the camera shows the back view
	var mutant := infected.override_anim()
	if mutant != "":
		body.play(mutant)
	elif body.form != "player":
		# the mutant has no hurt frames; it shows its arm cannon while firing in place
		if moving:
			body.play("walk_up" if dir.y < -0.6 and absf(dir.x) < 0.5 and shoot_t <= 0.0 else "walk")
		else:
			body.play("shoot" if shoot_t > 0.25 else "idle")
	elif hurt_t > 0.0:
		body.play("hurt")
	elif moving:
		body.play("walk_up" if dir.y < -0.6 and absf(dir.x) < 0.5 and shoot_t <= 0.0 else "walk")
	else:
		body.play("idle")
	if moving:
		walk_t += delta * 11.0
		body.walk_amount = minf(1.0, body.walk_amount + delta * 8.0)
		dust_t -= delta
		if dust_t <= 0.0:
			dust_t = 0.22
			AnimFx.spawn(Game.world.decals, "dust", "puff", global_position + Vector2(-dir.x * 4.0, 0), 0.09)
	else:
		body.walk_amount = maxf(0.0, body.walk_amount - delta * 8.0)
	body.walk_phase = walk_t
	body.rotation = sin(hurt_t * 60.0) * 0.08 if hurt_t > 0.0 else 0.0
	if infected.roll != 0.0:
		body.rotation = infected.roll
		body.position = Vector2(0, -8.0) - Vector2(0, -8.0).rotated(infected.roll)  # roll around the torso
	else:
		body.position = Vector2.ZERO
	squash = squash.lerp(Vector2.ONE, delta * 10.0)
	body.scale = squash
	body.facing = facing
	mat.set_shader_parameter("flash", clampf(flash_t / 0.15, 0.0, 1.0))
	# blaster: points where the shots go, kicks back on fire
	recoil = move_toward(recoil, 0.0, delta * 18.0)
	body.aim = gun_angle - body.rotation
	body.recoil = recoil / Astronaut.BODY_SCALE
