class_name Enemy
extends CharacterBody2D
## Base alien: health, hit reactions, knockback, freeze/stun, contact damage.
## Small aliens pick their behaviour from EnemyData `ai`; bosses override `_ai`.

var type_id := ""
var def: Dictionary = {}
var hp := 10.0
var max_hp := 10.0
var radius := 6.0
var speed := 20.0
var contact_damage := 10.0
var aggro := 1.0  # how fast the AI's timers run (world "enemy_mult")
var is_boss := false
var targetable := false
var dead := false

var sprite: AnimatedSprite2D
var shadow: Sprite2D
var alert: Sprite2D
var mat: ShaderMaterial
var flash_t := 0.0
var knock := Vector2.ZERO
var frozen_t := 0.0
var slow_t := 0.0
var stun_t := 0.0
var t := 0.0
var phase := 0.0
var state := ""
var state_t := 0.0
var aim := Vector2.ZERO
var hit_wall := false
var detour_t := 0.0  # following the Explore flow field around a wall
var anchored := false  # objectives that never move (SpecimenVat): no leash, no wipe
var spawn_t := 0.3
var tex_h := 16.0
var base_scale := 1.0
var squash := Vector2.ONE
var face := 1.0
var air := 0.0
var trail_t := 0.0
var hurt_t := 0.0
var tint := Color.WHITE
var art := ""
var _ufo_attacks := 0
var _sep := Vector2.ZERO  # separation push, set by GameWorld._separate_enemies
const DETOUR_TIME := 1.2
static var no_detour := false  # benches
const LOD_EVERY := 4
var _lod_acc := 0.0
var _far := false
var _anim_cache: Dictionary = {}  # animation name -> the sprite set has it
var _shadow_air := -1.0
var _ai_kind := ""
var elite := false  # tougher golden variant with a crown (final waves)
## Arena raiders: the DefendCore (village well, house...) this alien marches on instead
## of the astronaut, until he comes within LURE_BREAK (then it is his again for good).
var lure: DefendCore
const LURE_BREAK := 90.0
## ARMORY weapon effects: armor break (takes `vuln` x damage while vuln_t lasts),
## Cryo chill stacks (freeze at the weapon's threshold) and burn / acid damage over time
var vuln := 1.0
var vuln_t := 0.0
var chill := 0
var chill_t := 0.0
var burn_dps := 0.0
var burn_t := 0.0
var _burn_acc := 0.0


func setup(id: String) -> void:
	type_id = id
	def = EnemyData.TYPES[id]
	var mult := Game.difficulty()
	is_boss = bool(def.get("boss", false))
	var world_mult := Game.enemy_mult()  # world 2: every alien +30% HP, damage, speed, attacks
	max_hp = float(def.hp) * (1.0 if is_boss else mult) * world_mult
	hp = max_hp
	radius = float(def.radius)
	# tougher worlds hit harder and soak more; speed and attack pace grow only half as much
	speed = float(def.speed) * (1.0 + (world_mult - 1.0) * 0.5)
	aggro = 1.0 + (world_mult - 1.0) * 0.5
	contact_damage = float(def.damage) * (1.0 + (mult - 1.0) * 0.5) * world_mult
	base_scale = float(def.scale)
	art = str(def.art)
	tint = def.get("tint", Color.WHITE)


## Wave escalation: later waves are sturdier. Call before the alien enters the tree.
func toughen(hp_mult: float, speed_mult: float, dmg_mult := 1.0) -> void:
	max_hp *= hp_mult
	hp = max_hp
	speed *= speed_mult
	contact_damage *= dmg_mult


## Elite: bigger, golden, crowned, much tougher and richer. Call before add_child.
func make_elite() -> void:
	elite = true
	max_hp *= 2.2
	hp = max_hp
	speed *= 1.1
	contact_damage *= 1.25
	base_scale *= 1.3
	radius *= 1.2
	tint = Color(1.3, 1.1, 0.55)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | PropData.LAYER_BODIES_ONLY
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = maxf(radius * 0.7, 3.0)
	cs.shape = c
	cs.position = Vector2(0, -2)
	add_child(cs)
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2.ONE * (radius * 2.2 / 12.0)
	add_child(shadow)
	sprite = Art.make_anim(art, 0.0)
	sprite.play("walk")
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count("walk")
	tex_h = Art.body_height(art)
	mat = Art.flash_material()  # only on the sprite while it flashes (plain sprites batch)
	add_child(sprite)
	if elite:
		_elite_fx()
	alert = Sprite2D.new()
	alert.texture = Art.tex("alert")
	alert.visible = false
	add_child(alert)
	phase = randf() * TAU
	_init_ai()


## Golden aura under the elite and a little crown on its head.
func _elite_fx() -> void:
	var g := Sprite2D.new()
	g.texture = Art.tex("glow")
	g.modulate = Color(1.0, 0.8, 0.25, 0.45)
	g.scale = Vector2(radius * 2.6 / 14.0, radius * 1.4 / 24.0) * 1.6
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = add
	add_child(g)
	move_child(g, 0)
	var crown := Sprite2D.new()
	crown.texture = Art.tex("crown")
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.scale = Vector2.ONE * (0.8 / base_scale)
	crown.position = Vector2(0, -tex_h * 0.95)
	sprite.add_child(crown)


func hit_center() -> Vector2:
	return global_position + Vector2(0, -tex_h * base_scale * 0.5 - air)


func player() -> Player:
	return Game.world.player


## Mazes (Explore.flow_dir, world 5): an alien that bumped into a wall while coming for
## the astronaut follows the way around it for DETOUR_TIME instead of pushing on.
func _detour(vel: Vector2, delta: float) -> Vector2:
	if hit_wall:
		detour_t = DETOUR_TIME
	detour_t -= delta
	var ex := Game.world.explore
	if is_boss or ex == null or ex.forge == null:
		return vel
	var sp := vel.length()
	if sp < 1.0 or vel.dot(player().global_position - global_position) <= 0.0:
		return vel
	var f := ex.flow_dir(global_position)
	return vel if f == Vector2.ZERO else f * sp


func _physics_process(delta: float) -> void:
	if dead:
		return
	# Level of detail (bosses always run in full):
	# - far off screen (open maps): think and move only every LOD_EVERY frames, with the
	#   time saved up, and skip the looks;
	# - a big crowd on screen (GameWorld.crowd_every): think, animate and touch every few
	#   frames, staggered, and only glide with the last velocity in between.
	var w := Game.world
	var far := w.lod_on and not is_boss and not w.lod_rect.has_point(global_position)
	var every := 1 if is_boss else (LOD_EVERY if far else w.crowd_every)
	var glided := _lod_acc > 0.0 and not _far  # the frames saved up were already moved
	if every > 1 or _lod_acc > 0.0:
		_lod_acc += delta
		if every > 1 and (Engine.get_physics_frames() + get_instance_id()) % every != 0:
			if not far:
				_glide()
			return
		delta = _lod_acc
		_lod_acc = 0.0
	_far = far
	t += delta
	flash_t = maxf(0.0, flash_t - delta)
	if spawn_t > 0.0:
		spawn_t -= delta
		if spawn_t <= 0.0:
			targetable = _can_target()
	var vel := Vector2.ZERO
	if frozen_t > 0.0:
		frozen_t -= delta
		if frozen_t <= 0.0:
			Game.world.burst(hit_center(), Color("c0f4ff"), 8, 50.0, 0.3, 2.0)
	elif stun_t > 0.0:
		stun_t -= delta
	elif spawn_t <= 0.0:
		vel = _ai(delta * aggro)  # aggro > 1: attack timers and windups run faster
		if (hit_wall or detour_t > 0.0) and not no_detour:
			vel = _detour(vel, delta)
	if slow_t > 0.0:
		slow_t -= delta
		vel *= 0.5
	if vuln_t > 0.0 or chill_t > 0.0 or burn_t > 0.0:
		_tick_status(delta)
		if dead:
			return
	# crowds: GameWorld pushes overlapping aliens apart (its grid, every other frame)
	vel += _sep
	velocity = vel + knock
	knock = knock.move_toward(Vector2.ZERO, 520.0 * delta)
	var fast_knock := knock.length() > 140.0
	if not glided:
		velocity *= delta / get_physics_process_delta_time()  # the frames it skipped (if any)
	if is_boss or w.near_solid(global_position):
		move_and_slide()
		hit_wall = get_slide_collision_count() > 0
	else:
		# in the open (nothing solid around): a full move_and_slide would change nothing
		global_position += velocity * get_physics_process_delta_time()
		hit_wall = false
	if hit_wall and fast_knock and not is_boss:
		# slammed into a wall by knockback: bonus damage
		knock = Vector2.ZERO
		take_damage(float(Game.stats.damage) * 0.5, Vector2.ZERO)
		Game.world.burst(global_position, Color(1, 1, 1, 0.8), 6, 50.0, 0.25, 2.0)
		Game.world.shake(0.2)
		if dead:
			return
	if absf(vel.x) > 1.0:
		face = signf(vel.x)
	if _far:
		return  # nobody sees it and the astronaut is far away
	_animate(delta)
	_contact()


## Crowd frames between two full updates: keep sliding with the last velocity (a
## move_and_slide only near walls; in the open just the position).
func _glide() -> void:
	if dead or frozen_t > 0.0 or stun_t > 0.0:
		return
	var w := Game.world
	if w.near_solid(global_position):
		move_and_slide()
	else:
		global_position += velocity * get_physics_process_delta_time()


func _can_target() -> bool:
	return true


func _contact() -> void:
	if air > 4.0 or spawn_t > 0.0 or frozen_t > 0.0:
		return
	var p := player()
	if p.dead:
		return
	if (p.global_position - global_position).length() < radius + 5.0:
		p.take_damage(contact_damage, global_position)


## Animation to show now: "hurt" right after a hit, the AI state's own animation when
## the set has one (the droid's "charge", the UFO's "attack"), else "walk".
func _anim_name() -> String:
	if hurt_t > 0.0 and sprite.sprite_frames.has_animation("hurt"):
		return "hurt"
	if _has_state_anim(state):
		return state
	return "walk"


## sprite_frames.has_animation, remembered per state name (asked every frame).
func _has_state_anim(s: String) -> bool:
	var known: Variant = _anim_cache.get(s)
	if known == null:
		known = sprite.sprite_frames.has_animation(s)
		_anim_cache[s] = known
	return known


func _animate(delta: float) -> void:
	var wob := sin(t * 9.0 + phase) * 0.05
	var still := frozen_t > 0.0 or stun_t > 0.0
	if still:
		wob = 0.0
	hurt_t = maxf(0.0, hurt_t - delta)
	var anim := _anim_name()
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.speed_scale = 0.0 if still else (0.6 if slow_t > 0.0 else 1.0)
	var target := Vector2(base_scale * (1.0 + wob), base_scale * (1.0 - wob)) * squash
	squash = squash.lerp(Vector2.ONE, delta * 10.0)
	if spawn_t > 0.0:
		var k := 1.0 - spawn_t / 0.3
		target *= clampf(k * 1.3, 0.0, 1.2)
	sprite.scale = target
	sprite.flip_h = face < 0.0
	sprite.position.y = -air
	if flash_t > 0.0:
		sprite.material = mat
		mat.set_shader_parameter("flash", clampf(flash_t / 0.12, 0.0, 1.0))
	elif sprite.material != null:
		sprite.material = null
	if frozen_t > 0.0:
		sprite.self_modulate = Color(0.6, 0.85, 1.4)
	elif slow_t > 0.0:
		sprite.self_modulate = Color(0.8, 0.95, 1.2)
	elif stun_t > 0.0:
		sprite.self_modulate = Color(1.1, 1.1, 0.8)
	else:
		sprite.self_modulate = tint
	if alert.visible:
		alert.position = Vector2(0, -tex_h * base_scale - 4.0 - air)
	if air != _shadow_air:  # most aliens never leave the floor: no transform update
		_shadow_air = air
		shadow.scale = Vector2.ONE * (radius * 2.2 / 12.0) * clampf(1.0 - air / 150.0, 0.4, 1.0)


# ---------------------------------------------------------------- damage & status

func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	if Game.playground_active and (PlaygroundSession.boss_invincible if is_boss else PlaygroundSession.enemies_invincible):
		return
	if dead or (not targetable and spawn_t <= 0.0 and air > 4.0):
		return
	amount *= vuln
	hp -= amount
	flash_t = 0.12
	hurt_t = 0.18
	squash = Vector2(1.2, 0.85)
	if dir != Vector2.ZERO:
		knock += dir.normalized() * float(Game.stats.knockback) * float(def.kb) * minf(1.0, dir.length())
	Game.world.popup_damage(hit_center() + Vector2(randf_range(-4, 4), -6), amount, crit)
	if hp <= 0.0:
		die()


func _tick_status(delta: float) -> void:
	vuln_t -= delta
	if vuln_t <= 0.0:
		vuln = 1.0
	chill_t -= delta
	if chill_t <= 0.0:
		chill = 0
	if burn_t > 0.0:
		burn_t -= delta
		_burn_acc += burn_dps * delta
		if _burn_acc >= burn_dps * 0.3 or burn_t <= 0.0:
			var d := _burn_acc
			_burn_acc = 0.0
			take_damage(d)


## Armor break: every hit for `secs` deals x(1 + amount).
func shred(amount: float, secs: float) -> void:
	vuln = maxf(vuln, 1.0 + amount)
	vuln_t = maxf(vuln_t, secs)


## Damage over time (Solar burn, toxic acid): the strongest one running wins.
func ignite(dps: float, secs: float) -> void:
	if dps >= burn_dps or burn_t <= 0.0:
		burn_dps = dps
	burn_t = maxf(burn_t, secs)


## Cryo: slows; `limit` stacks within 2.5 s freeze the alien.
func add_chill(limit: int) -> bool:
	slow_t = maxf(slow_t, 1.2)
	chill += 1
	chill_t = 2.5
	if chill >= limit:
		chill = 0
		freeze(1.5)
		return true
	return false


func push(v: Vector2) -> void:
	knock += v * float(def.kb) * (0.3 if is_boss else 1.0)


func stun(dur: float) -> void:
	if is_boss:
		return
	stun_t = maxf(stun_t, dur)


func freeze(dur: float) -> void:
	if is_boss:
		slow_t = maxf(slow_t, dur)
	else:
		if frozen_t <= 0.0:
			Sfx.play("freeze", 0.1, -6.0)
		frozen_t = maxf(frozen_t, dur)
	Game.world.burst(hit_center(), Color("c0f4ff"), 6, 40.0, 0.3, 1.5)


func die() -> void:
	if dead:
		return
	dead = true
	targetable = false
	remove_from_group("enemies")
	_on_death()
	Game.world.enemy_killed(self)
	queue_free()


func _on_death() -> void:
	pass


# ---------------------------------------------------------------- AI

func _init_ai() -> void:
	_ai_kind = str(def.ai)
	match _ai_kind:
		"runner":
			state = "wander"
			state_t = randf_range(1.0, 1.6)
			aim = Vector2.from_angle(randf() * TAU)
		"spitter":
			state = "move"
			state_t = randf_range(1.2, 2.0)
		"droid":
			state = "move"
			state_t = randf_range(1.4, 2.2)
		"ufo":
			state = "move"
			state_t = randf_range(1.2, 2.0)
		"octopus":
			state = "move"
			state_t = randf_range(1.6, 2.4)
		_:
			state = "chase"


func _ai(delta: float) -> Vector2:
	match _ai_kind:
		"runner":
			return _ai_runner(delta)
		"spitter":
			return _ai_spitter(delta)
		"droid":
			return _ai_droid(delta)
		"ufo":
			return _ai_ufo(delta)
		"octopus":
			return _ai_octopus(delta)
	return _ai_chaser()


func _to_player() -> Vector2:
	var p := player().global_position
	if lure != null:
		if is_instance_valid(lure) and not lure.is_resolved() and p.distance_to(global_position) > LURE_BREAK:
			return lure.global_position - global_position
		lure = null
	return p - global_position


func _ai_chaser() -> Vector2:
	var to_p := _to_player()
	return to_p.normalized() * speed * (0.8 + 0.25 * sin(t * 5.0 + phase))


func _ai_runner(delta: float) -> Vector2:
	state_t -= delta
	match state:
		"wander":
			if state_t <= 0.0:
				state = "windup"
				state_t = 0.55
				aim = _to_player().normalized()
				alert.visible = true
				Sfx.play("alert", 0.1, -6.0)
			return aim * speed
		"windup":
			sprite.position.x = sin(t * 60.0) * 0.8
			face = signf(aim.x) if aim.x != 0.0 else face
			if state_t <= 0.0:
				state = "dash"
				state_t = 0.5
				alert.visible = false
				sprite.position.x = 0.0
				squash = Vector2(1.3, 0.7)
				Sfx.play("dash", 0.1, -6.0)
			return Vector2.ZERO
		"dash":
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.04
				Game.world.burst(global_position + Vector2(0, -3), Color("ef7d57"), 1, 5.0, 0.25, 2.0)
			if state_t <= 0.0 or (hit_wall and state_t < 0.45):
				if hit_wall:
					Game.world.burst(global_position, Color(1, 1, 1, 0.7), 5, 40.0, 0.25, 2.0)
				state = "rest"
				state_t = 0.45
			return aim * 150.0
		"rest":
			if state_t <= 0.0:
				state = "wander"
				state_t = randf_range(0.9, 1.6)
				aim = _to_player().normalized().rotated(randf_range(-1.2, 1.2))
			return Vector2.ZERO
	return Vector2.ZERO


func _ai_spitter(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"move":
			if state_t <= 0.0:
				state = "windup"
				state_t = 0.45
			var v := Vector2.ZERO
			if d < 55.0:
				v = -to_p.normalized()
			elif d > 95.0:
				v = to_p.normalized()
			else:
				v = to_p.normalized().orthogonal() * (1.0 if sin(phase) > 0.0 else -1.0) * 0.6
			return v * speed
		"windup":
			squash = Vector2(1.0 + (0.45 - state_t), 1.0 + (0.45 - state_t) * 0.6)
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				var dir := (player().global_position + Vector2(0, -6) - hit_center()).normalized()
				Game.world.spawn_enemy_shot(hit_center(), dir * 75.0, contact_damage)
				Sfx.play("spit", 0.1, -4.0)
				squash = Vector2(0.8, 1.2)
				state = "move"
				state_t = randf_range(1.8, 2.6)
			return Vector2.ZERO
	return Vector2.ZERO


## Droid: hovers at mid range, strafes, then charges its eye and fires a double
## plasma shot. Floats a little above the floor (still hurts on contact).
func _ai_droid(delta: float) -> Vector2:
	state_t -= delta
	air = 3.0 + sin(t * 3.2 + phase) * 1.5
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"move":
			if state_t <= 0.0:
				state = "charge"
				state_t = 0.6
				alert.visible = true
				Sfx.play("alert", 0.1, -8.0)
			var v := Vector2.ZERO
			if d < 60.0:
				v = -to_p.normalized()
			elif d > 100.0:
				v = to_p.normalized()
			else:
				v = to_p.normalized().orthogonal() * (1.0 if sin(t * 0.7 + phase) > 0.0 else -1.0) * 0.7
			return v * speed
		"charge":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			sprite.position.x = sin(t * 70.0) * 0.5
			if randf() < 0.5:
				Game.world.burst(hit_center(), Color("73eff7"), 1, 18.0, 0.2, 1.5)
			if state_t <= 0.0:
				sprite.position.x = 0.0
				alert.visible = false
				var dir := (player().global_position + Vector2(0, -6) - hit_center()).normalized()
				Game.world.spawn_enemy_shot(hit_center() + dir * 5.0, dir * 95.0, contact_damage, "droid")
				Sfx.play("shoot", 0.15, -6.0)
				knock -= dir * 60.0
				squash = Vector2(0.85, 1.15)
				state = "move"
				state_t = randf_range(1.8, 2.8)
			return Vector2.ZERO
	return Vector2.ZERO


## UFO: flies high (no contact damage) circling the player, zaps a green laser, and
## every third attack opens a floor portal that drops a Greenie (max 3 alive).
func _ai_ufo(delta: float) -> Vector2:
	state_t -= delta
	air = 10.0 + sin(t * 2.4 + phase) * 2.0
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"move":
			if state_t <= 0.0:
				_ufo_attacks += 1
				var summon := _ufo_attacks % 3 == 0 and _greenies() < 3
				state = "summon" if summon else "attack"
				state_t = 0.8 if summon else 0.45
				if summon:
					_ufo_portal()
				else:
					alert.visible = true
					Sfx.play("alert", 0.1, -8.0)
			var v := to_p.normalized().orthogonal() * (1.0 if sin(phase) > 0.0 else -1.0)
			if d < 70.0:
				v -= to_p.normalized()
			elif d > 110.0:
				v += to_p.normalized()
			return v.normalized() * speed
		"attack":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0:
				alert.visible = false
				var dir := (player().global_position + Vector2(0, -6) - hit_center()).normalized()
				Game.world.spawn_enemy_shot(hit_center() + dir * 6.0, dir * 110.0, contact_damage, "ufo")
				Sfx.play("zap", 0.15, -6.0)
				squash = Vector2(1.15, 0.9)
				state = "move"
				state_t = randf_range(1.6, 2.4)
			return Vector2.ZERO
		"summon":
			if state_t <= 0.0:
				state = "move"
				state_t = randf_range(1.4, 2.0)
			return Vector2.ZERO
	return Vector2.ZERO


func _greenies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).type_id == "ufo_alien":
			n += 1
	return n


## A green portal opens on the floor below the UFO and a Greenie (or `id`) pops out.
func _ufo_portal(id := "ufo_alien", at := Vector2.INF) -> void:
	var pos := global_position + Vector2(randf_range(-10.0, 10.0), 8.0) if at == Vector2.INF else at
	var bb := Game.world.room.bounds().grow(-12.0)
	pos = pos.clamp(bb.position, bb.end)
	var w := Game.world
	var fx := AnimFx.spawn(w.decals, "ufo_portal", "open", pos, 0.2, PI * 0.5)
	fx.animation_finished.disconnect(fx.queue_free)  # the tween below frees it
	fx.scale = Vector2(0.05, 0.2)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector2(0.16, 0.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(fx, "scale", Vector2(0.0, 0.2), 0.2)
	tw.tween_callback(fx.queue_free)
	Sfx.play("spawn", 0.1, -6.0)
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if not dead and not w.player.dead:
			w.spawn_enemy(id, pos))


## Octopus: swims in pulses (a push, then a glide) keeping mid range, then puffs up
## and fires a fan of 3 slow energy orbs. Leaves a blue puddle when cleaned.
func _ai_octopus(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	var d := to_p.length()
	match state:
		"move":
			if state_t <= 0.0:
				state = "attack"
				state_t = 0.55
				alert.visible = true
				Sfx.play("alert", 0.1, -8.0)
			# jellyfish stroke: squeeze on the push, stretch while gliding
			var pulse := maxf(0.0, sin(t * 4.0 + phase))
			squash = Vector2(1.0 + pulse * 0.12, 1.0 - pulse * 0.1)
			var v := to_p.normalized()
			if d < 55.0:
				v = -v
			elif d < 90.0:
				v = v.orthogonal() * (1.0 if sin(t * 0.5 + phase) > 0.0 else -1.0)
			return v * speed * (0.3 + pulse * 1.4)
		"attack":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			squash = Vector2(1.0 + (0.55 - state_t) * 0.35, 1.0 + (0.55 - state_t) * 0.2)
			if state_t <= 0.0:
				alert.visible = false
				var dir := (player().global_position + Vector2(0, -6) - hit_center()).normalized()
				for a: float in [-0.35, 0.0, 0.35]:
					Game.world.spawn_enemy_shot(hit_center() + dir * 5.0, dir.rotated(a) * 70.0, contact_damage, "octopus")
				Sfx.play("spit", 0.1, -4.0)
				squash = Vector2(0.8, 1.2)
				state = "move"
				state_t = randf_range(2.2, 3.0)
			return Vector2.ZERO
	return Vector2.ZERO
