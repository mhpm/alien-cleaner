class_name Player
extends CharacterBody2D
## The astronaut. Moves with the joystick, auto-aims at the nearest alien and
## fires faster while standing still. Special ability: Air Blast (or, with the shop's
## Infected Mode, mutate when the infection meter is full; see Infected).

const BLAST_RADIUS := 62.0
const BODY_Y := -10.0  # world-space height of the torso
const DOME_Y := -13.0  # centre of the whole astronaut (feet 0, helmet top ~-25): the Ion Shield sits here

var input_dir := Vector2.ZERO
var locked := false
var dead := false

var body: Astronaut  # reference-sheet astronaut + the equipped blaster, aimed separately
var shadow: Sprite2D
var shield_fx: Sprite2D  # the Shield power-up bubble
var dome: Sprite2D  # Ion Shield upgrade: coloured by the hits it has left
var martian: MartianAlly  # Martian UFO upgrade
var scrub: ScrubBot  # Scrub-Bots upgrade (the helper drone)
var hunter: HunterDrone  # Hunter Drone upgrade (boomerang blades)
var bomber: BomberDrone  # Bomber Drone upgrade
var magnet_t := UpgradeData.MAGNET_PULSE_EVERY  # Coin Magnet level 5 vacuum pulse
var mat: ShaderMaterial

var fire_t := 0.5
var invuln := 0.0
var walk_t := 0.0
var t := 0.0
var aim_dir := Vector2.UP
var knock := Vector2.ZERO
var flash_t := 0.0
var blast_t := 0.0
var shield_hits := 0  # Ion Shield: hits it can still block
var shield_max := 0
var shield_t := 0.0
var dome_hits: Dictionary = {}  # alien id -> msec of the last shove/burn
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
var nova_t := 1.0  # OVERDRIVE level 5: seconds to the next Rocket Nova


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
	shield_fx.scale = Vector2(0.9, 0.9)  # ~21 units of radius: wraps the whole astronaut
	shield_fx.visible = false
	add_child(shield_fx)
	dome = Sprite2D.new()
	dome.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	dome.position = Vector2(0, DOME_Y)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # glows, the astronaut stays visible
	dome.material = add
	dome.visible = false
	add_child(dome)
	infected = Infected.new()
	add_child(infected)
	move_child(infected, 0)
	infected.setup(self)
	refresh_upgrades()


## Timed power-ups (CollectibleData "buff"): kind -> seconds left. frenzy = fire rate x2.5,
## boots = speed, triple = extra diagonal shots, rage = double damage, shield = no
## damage, star = no damage + crush aliens on touch, ufo = two extra orbiting UFOs.
var buffs: Dictionary = {}
var sticky_t := 0.0  # > 0: slowed by sticky goo (Bean Cruiser), see stick()
const STICKY_SLOW := 0.55
var sticky_mult := STICKY_SLOW  # speed kept while stuck (arena hazards pick their own)
var star_hit_t := 0.0


## Sticky goo on the boots: slower for `secs` (it doesn't stack, it refreshes).
func stick(secs: float) -> void:
	sticky_t = maxf(sticky_t, secs)
	sticky_mult = STICKY_SLOW


## Slowed to `mult` of the normal speed for `secs` (arena HazardArea slow percentage).
func slow_down(mult: float, secs: float) -> void:
	sticky_t = maxf(sticky_t, secs)
	sticky_mult = clampf(mult, 0.05, 1.0)


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
	shield_hits = shield_max
	shield_t = 0.0
	if not buffs.is_empty():
		buffs.clear()
		body.modulate = Color(1, 1, 1, body.modulate.a)
		refresh_upgrades()


func refresh_upgrades() -> void:
	var own := 0  # Scrub-Bots is the ScrubBot drone now; these sprites are the UFO buddies
	var n := own + (2 if has_buff("ufo") else 0)
	while bots.size() > n:
		bots.pop_back().queue_free()
	while bots.size() < n:
		var b := Sprite2D.new()
		if bots.size() >= own:
			# UFO buddies (power-up)
			b.texture = CollectibleData.tex("ufo")
			b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			b.scale = Vector2.ONE * (22.0 / b.texture.get_width())
		else:
			b.texture = Art.tex("bot")
		add_child(b)
		bots.append(b)
	# Ion Shield: a new level refills it (bigger and one more hit)
	var sl := UpgradeData.shield_level(Game.stats)
	var new_max := int(UpgradeData.SHIELD_LV[sl - 1].hits) if sl > 0 else 0
	if new_max != shield_max:
		shield_max = new_max
		shield_hits = shield_max
		shield_t = 0.0
		if shield_max > 0:
			_dome_pop()
	# Martian UFO ally
	var ml := int(Game.stats.get("martian", 0))
	if ml > 0:
		if martian == null:
			martian = MartianAlly.new()
			add_child(martian)
			martian.lv = ml
			martian.setup(self)
		martian.set_level(ml)
	elif martian != null:  # taken back to 0 (playground testing)
		martian.queue_free()
		martian = null
	# Scrub-Bots: the helper drone
	var sb := int(Game.stats.get("orbiters", 0))
	if sb > 0:
		if scrub == null:
			scrub = ScrubBot.new()
			add_child(scrub)
			scrub.lv = sb
			scrub.setup(self)
		scrub.set_level(sb)
	elif scrub != null:  # taken back to 0 (playground testing)
		scrub.queue_free()
		scrub = null
	# Hunter Drone: the boomerang blades
	var hl := int(Game.stats.get("hunter", 0))
	if hl > 0:
		if hunter == null:
			hunter = HunterDrone.new()
			add_child(hunter)
			hunter.lv = hl
			hunter.setup(self)
		hunter.set_level(hl)
	elif hunter != null:  # taken back to 0 (playground testing)
		hunter.queue_free()
		hunter = null
	# Bomber Drone
	var bl := int(Game.stats.get("bomber", 0))
	if bl > 0:
		if bomber == null:
			bomber = BomberDrone.new()
			add_child(bomber)
			bomber.lv = bl
			bomber.setup(self)
		bomber.set_level(bl)
	elif bomber != null:  # taken back to 0 (playground testing)
		bomber.queue_free()
		bomber = null


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
	sticky_t = maxf(sticky_t - delta, 0.0)
	if sticky_t > 0.0:
		slow *= sticky_mult  # stuck in Bean Cruiser goo (or an arena hazard)
	velocity = dir * float(s.move_speed) * slow * (1.45 if has_buff("boots") else 1.0) * infected.speed_mult() + knock
	var dash_v := infected.dash_velocity()
	if dash_v != Vector2.INF:
		velocity = dash_v
	if slow < 1.0 and dir.length() > 0.15 and randf() < delta * 10.0:
		Game.world.burst(global_position, Color("a7f070") if sticky_t > 0.0 else Color("c75bd6"), 1, 12.0, 0.4, 1.5, -10.0)
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

	var mutated := infected.active or infected.transforming or infected.reverting
	var can_fire := not mutated or (infected.active and infected.dash_t <= 0.0)
	if target != null and not locked and can_fire:
		fire_t -= delta * (1.0 if not moving else 0.6)
		if fire_t <= 0.0:
			var frenzy := 0.4 if has_buff("frenzy") else 1.0
			if infected.active:  # the mutant fires its mutation gun
				_shoot_mutant()
				fire_t = float(infected.gun().rate) * frenzy
			else:
				_shoot(target)
				fire_t = GunFire.interval(s) * frenzy
	else:
		fire_t = maxf(fire_t - delta, 0.08)
	if int(s.get("overdrive", 0)) >= 5 and not mutated and not locked:
		nova_t -= delta
		if nova_t <= 0.0 and target != null:
			nova_t = GunFire.NOVA_EVERY
			GunFire.rocket_nova(self)
	_overdrive_glow(int(s.get("overdrive", 0)), mutated)

	_update_dome(delta)
	shield_fx.visible = has_buff("shield")
	shield_fx.modulate.a = 0.75 + sin(t * 4.0) * 0.2

	_update_bots(delta)
	if int(Game.stats.get("magnet_lvl", 0)) >= 5:
		magnet_t -= delta
		if magnet_t <= 0.0:
			magnet_t = UpgradeData.MAGNET_PULSE_EVERY
			_magnet_pulse()
	_animate(delta, moving, dir)


## OVERDRIVE: the weapon in hand pulses in its colour, harder each level, and from
## level 3 sheds sparks from the muzzle.
func _overdrive_glow(od: int, mutated: bool) -> void:
	if od <= 0 or mutated:
		body.gun.self_modulate = Color.WHITE
		return
	var col := GunData.color(str(Game.stats.gun))
	var k := 0.5 + 0.5 * sin(t * (5.0 + od))
	body.gun.self_modulate = Color.WHITE.lerp(Color(col.r * 1.8, col.g * 1.8, col.b * 1.8), 0.08 * od * k)
	if od >= 3 and randf() < 0.05 * od:
		Game.world.burst(body.to_global(body.muzzle_pos()), col.lightened(0.4), 1, 18.0, 0.25, 1.2)


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


## The equipped ARMORY weapon (GunFire: every weapon fires its own way).
func _shoot(target: Enemy) -> void:
	var d := _gun_dir()
	var origin := body.to_global(body.muzzle_pos())
	recoil = GunFire.fire(self, origin, d, target)
	shoot_t = 0.45
	body.fire_flash()


## The mutant's mutation gun (MutationData): its own bolt, plus the run's extra shots.
func _shoot_mutant() -> void:
	var g := infected.gun()
	var d := _gun_dir()
	var origin := body.to_global(body.muzzle_pos())
	var dirs: Array[Vector2] = [d]
	for k in int(Game.stats.spread) + (1 if has_buff("triple") else 0):
		dirs.append(d.rotated(0.25 * (k + 1)))
		dirs.append(d.rotated(-0.25 * (k + 1)))
	for sd in dirs:
		var b := InfShot.new()
		b.lv = infected.level
		b.dir = sd
		b.speed = float(g.speed)
		b.damage = float(Game.stats.damage) * float(g.dmg) * (2.0 if has_buff("rage") else 1.0)
		b.pierce = int(g.pierce) + int(Game.stats.pierce)
		b.hit_r = float(g.hit)
		b.color = Color(str(g.color))
		Game.world.effects.add_child(b)
		b.global_position = origin
	shoot_t = 0.45
	recoil = 3.5
	body.fire_flash()
	Sfx.play("shoot", 0.12, -5.0 + infected.level)
	Game.world.burst(origin, Color(str(g.color)), 3 + infected.level, 55.0, 0.15, 2.0, 0.0, d, 0.5)
	Game.world.ring(origin, 3.0 + infected.level, Color(str(g.color)), 0.1, 1.5)


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
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		var shot := n as EnemyShot
		if shot != null and shot.global_position.distance_to(c) < BLAST_RADIUS:
			shot.pop()
	squash = Vector2(1.3, 0.75)


func take_damage(amount: float, from := Vector2.INF, hazard := false) -> void:
	if dead or invuln > 0.0 or has_buff("shield") or has_buff("star") or infected.untouchable():
		return
	var w := Game.world
	if shield_hits > 0 and not hazard:
		var col: Color = UpgradeData.SHIELD_COLORS[shield_hits - 1]
		shield_hits -= 1
		shield_t = 0.0
		invuln = 0.6
		Sfx.play("shield")
		var c := global_position + Vector2(0, DOME_Y)
		w.ring(c, _dome_radius(), col, 0.25, 2.0)
		if shield_hits == 0:  # shattered
			w.burst(c, col, 22, 110.0, 0.45, 2.0)
			w.ring(c, _dome_radius() * 1.4, col, 0.35, 3.0)
		else:
			w.burst(c, col, 10, 80.0, 0.35, 2.0)
			_dome_pop()
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
	dome.visible = false
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


func _dome_radius() -> float:
	var sl := UpgradeData.shield_level(Game.stats)
	return float(UpgradeData.SHIELD_LV[sl - 1].r) if sl > 0 else 0.0


## Ion Shield: recharge one hit every "cd" seconds, colour = hits left (red = 5, the
## strongest), size = level. From level 3 it shoves aliens off, at 5 it burns them.
func _update_dome(delta: float) -> void:
	var sl := UpgradeData.shield_level(Game.stats)
	if sl <= 0:
		dome.visible = false
		return
	var def: Dictionary = UpgradeData.SHIELD_LV[sl - 1]
	if shield_hits < shield_max:
		shield_t += delta
		if shield_t >= float(def.cd):
			shield_t = 0.0
			shield_hits += 1
			Sfx.play("shield", 0.0, -8.0)
			_dome_pop()
	dome.visible = shield_hits > 0
	if not dome.visible:
		return
	dome.texture = UpgradeData.shield_bubble(shield_hits)
	var k := float(def.r) * 2.0 / dome.texture.get_width()
	dome.scale = dome.scale.lerp(Vector2.ONE * k, 1.0 - exp(-12.0 * delta))
	dome.modulate = Color(1, 1, 1, 0.8 + sin(t * 4.0) * 0.12)
	if sl < 3:
		return
	var now := Time.get_ticks_msec()
	var c := global_position + Vector2(0, DOME_Y)
	var col: Color = UpgradeData.SHIELD_COLORS[shield_hits - 1]
	for n in Game.world.enemy_cache:
		if not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e == null or not e.targetable:
			continue
		var d := e.hit_center() - c
		if d.length() > float(def.r) + e.radius:
			continue
		var id := e.get_instance_id()
		if now - int(dome_hits.get(id, 0)) < 350:
			continue
		dome_hits[id] = now
		e.push(d.normalized() * 110.0)
		if sl >= 5:
			e.take_damage(float(Game.stats.damage) * 0.4, Vector2.ZERO)
		Game.world.burst(c + d.normalized() * float(def.r), col, 4, 50.0, 0.25, 1.5)


func _dome_pop() -> void:
	var sl := UpgradeData.shield_level(Game.stats)
	if sl <= 0 or dome == null:
		return
	dome.scale = Vector2.ONE * float(UpgradeData.SHIELD_LV[sl - 1].r) * 2.6 / 154.0


## Coin Magnet level 5: a blue vortex pulse sucks in every gem and coin nearby.
func _magnet_pulse() -> void:
	var n := 0
	for node in get_tree().get_nodes_in_group("pickups"):
		var pk := node as Pickup
		if pk != null and pk.kind in ["xp", "coin", "gold"] and pk.global_position.distance_to(global_position) < UpgradeData.MAGNET_PULSE_R:
			pk.magnet = true
			n += 1
	Game.world.ring(global_position, 46.0, Color("41c8ff"), 0.45, 3.0)
	Game.world.ring(global_position, 26.0, Color("bdf3ff"), 0.3, 2.0)
	Game.world.burst(global_position + Vector2(0, BODY_Y), Color("73eff7"), 14, 90.0, 0.4, 2.0)
	if n > 0:
		Sfx.play("shield", 0.1, -6.0)


func _update_bots(delta: float) -> void:
	if bots.is_empty():
		return
	orbit_a += delta * 3.4
	var n := bots.size()
	var now := Time.get_ticks_msec()
	var dmg := float(Game.stats.damage) * 0.7
	var own := 0  # all sprite bots are UFO buddies (Scrub-Bots = ScrubBot)
	for i in n:
		var a := orbit_a + TAU * i / n
		var ufo := i >= own  # UFO buddies are bigger: a wider orbit and reach
		var p := Vector2(cos(a) * (42.0 if ufo else 22.0), sin(a) * (30.0 if ufo else 15.0) + BODY_Y)
		bots[i].position = p
		bots[i].z_index = 1 if sin(a) > 0.0 else 0
		var wp := global_position + p
		for e in Game.world.enemies_near(wp, 20.0):
			if not e.targetable:
				continue
			if wp.distance_to(e.hit_center()) < e.radius + (9.0 if ufo else 4.0):
				var id := e.get_instance_id()
				if now - int(bot_hits.get(id, 0)) > 400:
					bot_hits[id] = now
					e.take_damage(dmg, (e.global_position - global_position).normalized() * 0.4)
					Game.world.burst(wp, Color("73eff7"), 4, 40.0, 0.2, 1.5)
					Sfx.play("hit", 0.2, -8.0)


func _animate(delta: float, moving: bool, dir: Vector2) -> void:
	hurt_t = maxf(0.0, hurt_t - delta)
	shoot_t = maxf(0.0, shoot_t - delta)
	var mutant := infected.override_anim()
	body.shooting = shoot_t > 0.0
	if body.directional:
		# the mutant: its own frames for each direction (no flip); faces what it shoots
		if shoot_t > 0.0 and absf(aim_dir.x) > 0.05 and mutant == "":
			facing = signf(aim_dir.x)
		elif moving and absf(dir.x) > 0.1 and mutant == "":
			facing = signf(dir.x)
		if mutant.begins_with("attack_") or mutant.begins_with("combo_") or mutant == "idle":
			body.play(mutant)
		elif moving or mutant == "dash":
			var mv := dir if dir.length() > 0.15 else infected.dash_dir
			body.play("walk_" + Infected._dir4(mv))
		else:
			body.play("idle")
	else:
		if shoot_t > 0.0 and absf(aim_dir.x) > 0.05:
			facing = signf(aim_dir.x)
		elif moving and absf(dir.x) > 0.1:
			facing = signf(dir.x)
		# sprite animation: walking away from the camera shows the back view
		if hurt_t > 0.0:
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
	body.recoil = recoil / body.px
