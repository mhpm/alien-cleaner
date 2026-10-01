class_name GunShot
extends Bullet
## A projectile of an ARMORY weapon (GunFire): a Bullet drawn with the weapon's own art
## (assets/guns/<art>.png, `base_len` world units long) plus the extras its kind uses:
## knockback (Nova), armor break (Drill), jumps to the next alien (Spark), chill (Cryo),
## pull + implosion (Graviton), homing + explosion (Rockets).

var art := "shot_pulse"
var base_len := 14.0
var force_crit := false
var push := 0.0  # extra knockback on hit
var shred := 0.0  # armor break: hit aliens take +shred damage for shred_t seconds
var shred_t := 0.0
var hops := 0  # jumps to the nearest alien within hop_r after a hit
var hop_r := 90.0
var chill := 0  # Cryo: chill stacks that freeze (0 = none)
var ice_t := 2.0  # Cryo: seconds the ice spike of a freeze stays (GunFx.Ice)
var ice_dps := 10.0  # ...and the damage per second it deals to aliens touching it
var spin := 0.0  # rad/s the art turns (flakes, the graviton orb)
var drag := 0.0  # speed lost per second (fraction)
var pull_r := 0.0  # Graviton: drags aliens within this radius
var boom_r := 0.0  # explodes when it ends (radius, damage, art, colour)
var boom_dmg := 0.0
var boom_tex := ""
var boom_col := Color.WHITE
var home: Enemy = null  # Rockets: steers toward this alien
var accel := 0.0
var top_speed := 0.0
var smoke := false
var trail := Color(0, 0, 0, 0)  # sparkle trail colour (alpha 0 = none)
var pop_tex := ""  # single-frame art flashed where it ends ("" = default impact)
var _ring_t := 0.0

static var _frames: Dictionary = {}


func _ready() -> void:
	var tex := GunFire.tex(art)
	if not _frames.has(art):
		var sf := SpriteFrames.new()
		sf.add_animation("fly")
		sf.add_frame("fly", tex)
		_frames[art] = sf
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _frames[art]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.animation = "fly"
	base_scale = base_len / float(tex.get_width())
	sprite.scale = Vector2.ONE * base_scale
	sprite.rotation = dir.angle()
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if drag > 0.0:
		speed *= maxf(0.0, 1.0 - drag * delta)
	if accel > 0.0:
		speed = minf(speed + accel * delta, top_speed)
	if home != null:
		if is_instance_valid(home) and not home.dead:
			var want := (home.hit_center() - global_position).angle()
			dir = Vector2.from_angle(rotate_toward(dir.angle(), want, 7.0 * delta))
		else:
			home = GunFire._target_near(global_position, 140.0)
	if spin != 0.0:
		sprite.rotation += spin * delta
	elif home != null or accel > 0.0:
		sprite.rotation = dir.angle()
	if pull_r > 0.0:
		_pull(delta)
	if smoke and randf() < delta * 30.0:
		Game.world.burst(global_position - dir * 5.0, Color(0.75, 0.7, 0.7, 0.7), 1, 12.0, 0.35, 2.0, -15.0)
	if trail.a > 0.0 and randf() < delta * 25.0:
		Game.world.burst(global_position, trail, 1, 8.0, 0.25, 1.5)
	super._physics_process(delta)


## Graviton: aliens around the orb are dragged toward it (bosses barely move).
func _pull(delta: float) -> void:
	_ring_t -= delta
	if _ring_t <= 0.0:
		_ring_t = 0.3
		var r := RingFx.new()
		r.position = global_position
		r.radius = pull_r
		r.color = Color(boom_col, 0.5)
		r.dur = 0.3
		r.width = 1.5
		Game.world.effects.add_child(r)
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e == null or not e.targetable or e.is_boss:
			continue
		var to := global_position - e.global_position
		var dd := to.length()
		if dd < pull_r and dd > 3.0:
			e.knock = e.knock.lerp(to / dd * 80.0, minf(1.0, 12.0 * delta))


func _hit_enemy(e: Enemy) -> void:
	GunFx.hit(e, damage, dir, force_crit)
	if push > 0.0:
		e.push(dir * push)
	if shred > 0.0:
		e.shred(shred, shred_t)
		Game.world.burst(e.hit_center(), Color("5fe6ff"), 3, 40.0, 0.25, 1.5)
	if chill > 0 and is_instance_valid(e) and not e.dead and e.add_chill(chill):
		GunFx.ice(e.global_position + Vector2(0, 2), maxf(18.0, e.radius * 3.2), ice_t, ice_dps)
	if boom_r > 0.0:
		life = 0.0  # rockets: explode on contact (Bullet pops it)
		pierce = 0
	if hops > 0:
		var next := _next_hop(e)
		if next != null:
			hops -= 1
			dir = (next.hit_center() - global_position).normalized()
			sprite.rotation = dir.angle()
			damage *= 0.9
			pierce += 1  # Bullet takes one away: the spark keeps flying
			GunFx.flash(GunFire.tex("hit_spark"), global_position, 10.0, 0.15)


func _next_hop(from: Enemy) -> Enemy:
	var best: Enemy = null
	var bd := hop_r
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e == null or e == from or not e.targetable or hit_list.has(e.get_instance_id()):
			continue
		var dd := global_position.distance_to(e.hit_center())
		if dd < bd:
			bd = dd
			best = e
	return best


func _pop() -> void:
	if Game.world == null:
		queue_free()
		return
	if boom_r > 0.0:
		if boom_tex == "hole":
			GunFx.implode(global_position, boom_r, boom_dmg, boom_col)
		else:
			GunFx.blast(global_position, boom_r, boom_dmg, boom_col, boom_tex)
	else:
		var fx := pop_tex
		if fx == "":
			fx = {"shot_pulse": "hit_pulse", "shot_nova": "hit_pulse", "bolt_drill": "hit_drill",
				"flake": "", "shot_spark": "hit_spark"}.get(art, "")
		if fx != "":
			GunFx.flash(GunFire.tex(fx), global_position, 6.0 + hit_r * 2.0, 0.16, randf() * TAU)
		var col := trail if trail.a > 0.0 else Color("9fe8ff")
		Game.world.burst(global_position, col, 4, 40.0, 0.25, 1.5)
	queue_free()
