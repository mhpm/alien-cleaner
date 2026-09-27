class_name Player
extends CharacterBody2D
## The astronaut. Moves with the joystick, auto-aims at the nearest alien and
## fires faster while standing still. Special ability: Air Blast.

const BLAST_RADIUS := 62.0
const SUIT_SCALE := 0.08  # suit canvas pixels -> world units (~25 units tall)
const BODY_Y := -10.0  # world-space height of the torso

var input_dir := Vector2.ZERO
var locked := false
var dead := false

var body: SuitRig  # astronaut built from the equipped gear
var gun: Sprite2D  # the equipped weapon part, aimed separately
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
var gun_behind := false
var recoil := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
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
	body = SuitRig.new(false)
	body.scale = Vector2.ONE * SUIT_SCALE
	add_child(body)
	body.set_layer_material(mat)
	gun = Sprite2D.new()
	gun.texture = Art.suit_tex(SuitRig.variant("weapon"), "weapon")
	gun.centered = false
	gun.offset = -SuitRig.GUN_PIVOT  # rotate around the grip
	gun.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	gun.material = mat
	add_child(gun)
	shield_fx = Sprite2D.new()
	shield_fx.texture = Art.tex("shield")
	shield_fx.position = Vector2(0, BODY_Y)
	shield_fx.scale = Vector2(1.45, 1.45)
	shield_fx.visible = false
	add_child(shield_fx)
	refresh_upgrades()


func reset_for_room(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	knock = Vector2.ZERO
	input_dir = Vector2.ZERO
	fire_t = 0.5
	invuln = 0.4
	locked = false
	aim_dir = Vector2.UP
	gun_angle = -PI * 0.5
	if bool(Game.stats.shield):
		shield_up = true


func refresh_upgrades() -> void:
	var n := int(Game.stats.orbiters)
	while bots.size() < n:
		var b := Sprite2D.new()
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
	flash_t = maxf(flash_t - delta, 0.0)

	var dir := Vector2.ZERO if locked else input_dir.limit_length(1.0)
	velocity = dir * float(s.move_speed) + knock
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
			fire_t = float(s.fire_interval)
	else:
		fire_t = maxf(fire_t - delta, 0.08)

	if bool(s.shield) and not shield_up:
		shield_t += delta
		if shield_t >= 8.0:
			shield_up = true
			shield_t = 0.0
			Sfx.play("shield", 0.0, -8.0)
	shield_fx.visible = shield_up
	shield_fx.modulate.a = 0.75 + sin(t * 4.0) * 0.2

	_update_bots(delta)
	_animate(delta, moving, dir)


func _muzzle_base() -> Vector2:
	return global_position + Vector2(0, BODY_Y)


func _gun_pivot_local() -> Vector2:
	var p := (SuitRig.GUN_PIVOT - SuitRig.ANCHOR) * SUIT_SCALE
	return Vector2(p.x * facing, p.y + body.position.y)


func _gun_pivot() -> Vector2:
	return global_position + _gun_pivot_local()


func _gun_dir() -> Vector2:
	return Vector2.from_angle(gun_angle)


func _find_target() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	var los: Enemy = null
	var los_d := INF
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or not e.targetable:
			continue
		var d := global_position.distance_to(e.global_position)
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
	var origin := _gun_pivot() + d * SuitRig.gun_length() * SUIT_SCALE
	var perp := d.orthogonal()
	var shots := int(s.shots)
	for i in shots:
		var off := (i - (shots - 1) * 0.5) * 5.0
		_spawn_bullet(origin + perp * off, d)
	for k in int(s.spread):
		var a := 0.3 * (k + 1)
		_spawn_bullet(origin, d.rotated(a))
		_spawn_bullet(origin, d.rotated(-a))
	shoot_t = 0.45
	recoil = 2.5
	var lvl := int(s.weapon)
	Sfx.play("shoot", 0.12, -7.0 + lvl)
	var flash := AnimFx.spawn(Game.world.effects, "muzzle", "flash", origin, 0.2 + lvl * 0.03)
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, 0.06)
	Game.world.burst(origin, Color("9fe8ff"), 2 + lvl, 45.0, 0.15, 1.5, 0.0, d, 0.5)


func _spawn_bullet(pos: Vector2, d: Vector2) -> void:
	var s := Game.stats
	var tier := WeaponData.tier(int(s.weapon))
	var b := Bullet.new()
	b.tier = tier
	b.dir = d
	b.speed = float(s.bullet_speed) * float(tier.speed) / 220.0
	b.damage = float(s.damage) * float(tier.dmg)
	b.pierce = int(s.pierce) + int(tier.pierce)
	b.bounces = int(s.ricochet)
	Game.world.effects.add_child(b)
	b.global_position = pos


func blast() -> void:
	if dead or locked or blast_t > 0.0:
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
	if dead or invuln > 0.0:
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
	dead = true
	shield_fx.visible = false
	gun.visible = false
	for b in bots:
		b.visible = false
	Sfx.play("hurt", 0.0)
	var w := Game.world
	w.burst(global_position + Vector2(0, BODY_Y), Color("f4f4f4"), 24, 110.0, 0.7, 2.5)
	w.shake(0.8)
	# topple over backwards and fade a little
	var tw := create_tween()
	tw.tween_property(body, "position:y", -8.0, 0.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body, "rotation", -facing * 1.5, 0.45).set_trans(Tween.TRANS_BACK)
	tw.tween_property(body, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "modulate", Color(0.7, 0.7, 0.8, 0.8), 0.3)
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
	# walk: the suit bobs and leans while the boots stay planted
	var body_y := 0.0
	if moving:
		walk_t += delta * 16.0
		body_y = -absf(sin(walk_t)) * 1.3
		body.rotation = sin(walk_t) * 0.06 * facing
		dust_t -= delta
		if dust_t <= 0.0:
			dust_t = 0.22
			AnimFx.spawn(Game.world.decals, "dust", "puff", global_position + Vector2(-dir.x * 4.0, 0), 0.09)
	else:
		walk_t = 0.0
		body.rotation = lerpf(body.rotation, 0.0, delta * 12.0)
	if hurt_t > 0.0:
		body.rotation = sin(hurt_t * 60.0) * 0.08
	body.position.y = lerpf(body.position.y, body_y, delta * 20.0)
	(body.parts["legs"] as Sprite2D).position.y = -body.position.y / SUIT_SCALE
	var breathe := sin(t * 3.0) * 0.02
	squash = squash.lerp(Vector2.ONE, delta * 10.0)
	body.scale = Vector2((1.0 + breathe) * squash.x * facing, (1.0 - breathe) * squash.y) * SUIT_SCALE
	mat.set_shader_parameter("flash", clampf(flash_t / 0.15, 0.0, 1.0))
	# blaster: held at the grip, points where the shots go, kicks back on fire
	recoil = move_toward(recoil, 0.0, delta * 18.0)
	var gd := _gun_dir()
	var base := SuitRig.gun_base_angle()
	gun.position = _gun_pivot_local() - gd * recoil
	if gd.x >= 0.0:
		gun.scale = Vector2(SUIT_SCALE, SUIT_SCALE)
		gun.rotation = gun_angle - base
	else:
		gun.scale = Vector2(SUIT_SCALE, -SUIT_SCALE)
		gun.rotation = gun_angle + base
	gun.modulate.a = body.modulate.a
	var behind := gd.y < -0.5
	if behind != gun_behind:
		gun_behind = behind
		if behind:
			move_child(gun, body.get_index())
		else:
			move_child(body, gun.get_index())
