class_name GunFx
extends RefCounted
## Hits and effects of the ARMORY weapons (GunFire): damage with the run's crit / freeze /
## chain upgrades, splash blasts, the Graviton implosion, Tesla lightning chains, the
## Toxic glob (Lob) and its acid Pool, and the Solar Lance (Beam).


## One weapon hit on `e`, with the run's crits, freeze and chain-lightning upgrades.
static func hit(e: Enemy, dmg: float, dir: Vector2, force_crit := false) -> void:
	if not is_instance_valid(e) or e.dead:
		return
	var s := Game.stats
	var crit := force_crit or randf() < float(s.crit)
	if crit:
		dmg *= float(s.crit_mult)
	e.take_damage(dmg, dir, crit)
	if float(s.freeze) > 0.0 and randf() < float(s.freeze) and is_instance_valid(e):
		e.freeze(1.6)
	if int(s.chain) > 0:
		Game.world.chain_lightning(e, dmg * 0.5, int(s.chain))
	Sfx.play("hit", 0.15, -4.0)


## Every alien within `r` of `pos` takes `dmg` (rockets, the toxic splash).
static func blast(pos: Vector2, r: float, dmg: float, col: Color, art := "") -> void:
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e != null and e.targetable and e.global_position.distance_to(pos) < r + e.radius:
			hit(e, dmg, (e.global_position - pos).normalized() * 0.7)
	if art != "":
		flash(GunFire.tex(art), pos, r * 2.0, 0.3, randf() * TAU, 1.25)
	Game.world.ring(pos, r, col, 0.22, 2.5)
	Game.world.burst(pos, col, 10, 90.0, 0.35, 2.0)
	Game.world.shake(0.12)
	Sfx.play("explode", 0.15, -12.0)


## Graviton Core collapse: the black hole art shrinks into the orb while it squeezes
## everything around it.
static func implode(pos: Vector2, r: float, dmg: float, col: Color) -> void:
	var s := flash(GunFire.tex("hole"), pos, r * 2.4, 0.35, 0.0, 0.2)
	s.modulate = Color(1.2, 1.0, 1.3)
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e != null and e.targetable and e.global_position.distance_to(pos) < r + e.radius:
			hit(e, dmg, (pos - e.global_position).normalized() * 0.5)
	Game.world.ring(pos, r, col, 0.3, 3.0, true)
	Game.world.burst(pos, col, 18, 120.0, 0.4, 2.0)
	Game.world.burst(pos, Color.WHITE, 6, 60.0, 0.25, 1.5)
	Game.world.shake(0.25)
	Sfx.play("explode", 0.1, -8.0)


## A one-off sprite of weapon art `size` units wide at `pos` that scales by `grow` and fades.
static func flash(tex: Texture2D, pos: Vector2, size: float, dur: float, rot := 0.0, grow := 1.35) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.rotation = rot
	var k := size / float(tex.get_width())
	s.scale = Vector2(k, k)
	Game.world.effects.add_child(s)
	s.global_position = pos
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2(k, k) * grow, dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)
	return s


## Cryo Sprayer: an ice spike where an alien froze; it stays `secs`, hurts and slows
## the aliens touching it, then shatters. At most MAX_ICE at once (the oldest breaks).
const MAX_ICE := 14


static func ice(pos: Vector2, size: float, secs: float, dps: float) -> void:
	var tree := Game.world.get_tree()
	var all := tree.get_nodes_in_group("ice_spikes")
	for n in all:
		if (n as Node2D).global_position.distance_to(pos) < size * 0.3:
			(n as Ice).life = maxf((n as Ice).life, secs)  # refreshed, not stacked
			return
	if all.size() >= MAX_ICE:
		(all[0] as Ice).shatter()
	var c := Ice.new()
	c.size = size
	c.life = secs
	c.dps = dps
	Game.world.entities.add_child(c)
	c.global_position = pos


## Tesla Arc: lightning from the muzzle to `first`, then on through the nearest aliens,
## stunning each; the damage fades a little per jump.
static func tesla(from: Vector2, first: Enemy, dmg: float, prm: Dictionary) -> void:
	var hit_set: Array[Enemy] = []
	var cur := first
	var a := from
	var d := dmg
	for i in int(prm.chains) + 1:
		var arc := Arc.new()
		arc.a = a
		arc.b = cur.hit_center()
		arc.width = 3.0 if i == 0 else 2.0
		Game.world.effects.add_child(arc)
		flash(GunFire.tex("spark_tesla"), cur.hit_center(), 16.0, 0.2, randf() * TAU)
		hit(cur, d, (cur.hit_center() - a).normalized() * 0.3)
		if is_instance_valid(cur):
			cur.stun(float(prm.stun))
		hit_set.append(cur)
		a = cur.hit_center()
		d *= float(prm.chain_k)
		var next: Enemy = null
		var bd := float(prm.chain_r)
		for node in Game.world.enemy_cache:
			if not is_instance_valid(node):
				continue
			var e := node as Enemy
			if e == null or not e.targetable or hit_set.has(e):
				continue
			var dd := a.distance_to(e.hit_center())
			if dd < bd:
				bd = dd
				next = e
		if next == null:
			break
		cur = next


## Ice spike left by a Cryo freeze (y-sorted with the aliens, base at its origin).
class Ice extends Node2D:
	const TICK := 0.35
	var size := 20.0
	var life := 2.0
	var dps := 10.0
	var t := 0.0
	var tick := 0.0
	var gone := false
	var sprite: Sprite2D

	func _ready() -> void:
		add_to_group("ice_spikes")
		sprite = Sprite2D.new()
		sprite.texture = GunFire.tex("crystal")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.centered = false
		var ts := sprite.texture.get_size()
		sprite.offset = Vector2(-ts.x * 0.5, -ts.y * 0.9)
		add_child(sprite)
		_scale(0.0)
		var tw := create_tween()
		tw.tween_method(_scale, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("freeze", 0.15, -10.0)

	func _scale(k: float) -> void:
		var s := size / sprite.texture.get_width()
		sprite.scale = Vector2(s, s * k)

	func _physics_process(delta: float) -> void:
		if gone:
			return
		t += delta
		life -= delta
		# a shimmer, and a shiver in its last second
		var shake := randf_range(-0.6, 0.6) if life < 1.0 else 0.0
		sprite.position = Vector2(shake, 0)
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.5, 1.7, 2.0), 0.5 + 0.5 * sin(t * 5.0)) if life >= 1.0 else Color(1.2, 1.3, 1.5, 0.75 + 0.25 * sin(t * 30.0))
		if life <= 0.0:
			shatter()
			return
		tick -= delta
		if tick > 0.0:
			return
		tick = TICK
		var r := size * 0.42
		for node in Game.world.enemy_cache:
			if not is_instance_valid(node):
				continue
			var e := node as Enemy
			if e == null or not e.targetable or e.dead:
				continue
			if e.global_position.distance_to(global_position) < r + e.radius:
				e.take_damage(dps * TICK, (e.global_position - global_position).normalized() * 0.2)
				if is_instance_valid(e):
					e.slow_t = maxf(e.slow_t, 0.6)
				Game.world.burst(e.hit_center(), Color("c0f4ff"), 2, 30.0, 0.25, 1.5)

	## Breaks into ice shards and disappears.
	func shatter() -> void:
		if gone:
			return
		gone = true
		remove_from_group("ice_spikes")
		var at := global_position + Vector2(0, -size * 0.35)
		Game.world.burst(at, Color("c0f4ff"), 12, 80.0, 0.4, 2.0, 60.0)
		Game.world.burst(at, Color.WHITE, 5, 50.0, 0.25, 1.5)
		Sfx.play("freeze", 0.2, -12.0)
		var tw := create_tween().set_parallel()
		tw.tween_property(sprite, "scale", sprite.scale * Vector2(1.3, 0.5), 0.15)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.15)
		tw.chain().tween_callback(queue_free)


## Bright jagged electric arc (Tesla), thicker and longer lived than Lightning.
class Arc extends Node2D:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var width := 2.0
	var dur := 0.16
	var t := 0.0
	var color := Color("6fd8ff")

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array()
		var n := maxi(3, int(a.distance_to(b) / 7.0))
		var perp := (b - a).orthogonal().normalized()
		for i in n + 1:
			var k := float(i) / n
			var off := 0.0 if i == 0 or i == n else randf_range(-5.0, 5.0)
			pts.append(a.lerp(b, k) + perp * off)
		var alpha := 1.0 - t / dur
		draw_polyline(pts, Color(color, alpha * 0.35), width * 3.0)
		draw_polyline(pts, Color(color, alpha), width)
		draw_polyline(pts, Color(1, 1, 1, alpha), maxf(1.0, width * 0.4))


## Toxic Goo Launcher glob: flies in an arc to `to`, splashes, leaves an acid Pool.
class Lob extends Node2D:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var dmg := 10.0
	var unit := 10.0
	var prm := {}
	var t := 0.0
	var dur := 0.4
	var sprite: Sprite2D

	func _ready() -> void:
		dur = clampf(from.distance_to(to) / 260.0, 0.22, 0.55)
		sprite = Sprite2D.new()
		sprite.texture = GunFire.tex("glob")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.scale = Vector2.ONE * (9.0 / sprite.texture.get_width())
		add_child(sprite)
		global_position = from

	func _physics_process(delta: float) -> void:
		t += delta
		var k := minf(t / dur, 1.0)
		var h := sin(k * PI) * minf(40.0, from.distance_to(to) * 0.35)
		global_position = from.lerp(to, k) - Vector2(0, h)
		sprite.rotation += delta * 10.0
		if randf() < delta * 30.0:
			Game.world.burst(global_position, Color("7dff3a"), 1, 10.0, 0.3, 1.5, 30.0)
		if k >= 1.0:
			_land()

	func _land() -> void:
		GunFx.blast(to, float(prm.splash), dmg, Color("7dff3a"), "splash")
		var pool := Pool.new()
		pool.radius = float(prm.pool_r)
		pool.dur = float(prm.pool_t)
		pool.dps = unit * float(prm.pool_dps)
		pool.position = to
		Game.world.decals.add_child(pool)
		Sfx.play("spit", 0.15, -8.0)
		queue_free()


## Acid pool on the floor: aliens inside keep corroding (Enemy.ignite) while they stand in it.
class Pool extends Node2D:
	var radius := 18.0
	var dur := 2.5
	var dps := 16.0
	var t := 0.0
	var tick := 0.0
	var seed_a := randf() * TAU

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		tick -= delta
		if tick <= 0.0:
			tick = 0.25
			for node in Game.world.enemy_cache:
				if not is_instance_valid(node):
					continue
				var e := node as Enemy
				if e != null and e.targetable and e.global_position.distance_to(global_position) < radius + e.radius * 0.5:
					e.ignite(dps, 0.6)
			if randf() < 0.7:
				var p := global_position + Vector2.from_angle(randf() * TAU) * randf() * radius * 0.8
				Game.world.burst(p, Color("a7ff5a"), 1, 6.0, 0.4, 2.0, -20.0)
		queue_redraw()

	func _draw() -> void:
		var fade := clampf(t / 0.15, 0.0, 1.0) * clampf((dur - t) / 0.5, 0.0, 1.0)
		var r := radius * (0.85 + 0.15 * clampf(t / 0.3, 0.0, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
		draw_circle(Vector2.ZERO, r, Color(0.25, 0.75, 0.1, 0.45 * fade))
		draw_circle(Vector2.ZERO, r * 0.72, Color(0.45, 1.0, 0.2, 0.35 * fade))
		for i in 4:
			var a := seed_a + i * 1.7 + t * 0.6
			var bp := Vector2.from_angle(a) * r * (0.3 + 0.12 * i)
			draw_circle(bp, 1.6 + sin(t * 6.0 + i) * 0.6, Color(0.8, 1.0, 0.5, 0.7 * fade))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(0.6, 1.0, 0.3, 0.6 * fade), 1.0)


## Solar Lance: a sun orb charges at the muzzle, then a laser fires along `dir`, stopped
## only by walls, hitting every alien on it and setting them on fire. It leaves a Scorch
## line on the floor, and every alien it kills bursts into a solar flare (area damage).
## The ray art is feathered at both ends and dressed with glow, sparks and embers so it
## never shows a hard cut.
class Beam extends Node2D:
	const FADE := 0.32
	var player: Player
	var dir := Vector2.RIGHT
	var off := 0.0  # angle from the aim (extra beams of OVERDRIVE / Triple)
	var dmg := 40.0
	var unit := 10.0
	var prm := {}
	var t := 0.0
	var fired := false
	var length := 0.0
	var orb: Sprite2D
	var ray: Sprite2D
	var core := 0.0

	func _ready() -> void:
		orb = Sprite2D.new()
		orb.texture = GunFire.tex("orb_solar")
		orb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		orb.scale = Vector2.ZERO
		add_child(orb)

	func _physics_process(delta: float) -> void:
		t += delta
		var charge := float(prm.charge)
		if not fired:
			# the orb rides the muzzle while it charges
			if is_instance_valid(player) and not player.dead:
				global_position = player.body.to_global(player.body.muzzle_pos())
				dir = Vector2.from_angle(player.gun_angle + off)
			var k := t / charge
			orb.scale = Vector2.ONE * (12.0 * k / orb.texture.get_width())
			orb.rotation += delta * 8.0
			if randf() < delta * 40.0:
				var p := global_position + Vector2.from_angle(randf() * TAU) * 12.0
				Game.world.burst(p, Color("ffd36a"), 1, 0.0, 0.2, 1.5, 0.0, global_position - p, 0.1)
			if t >= charge:
				_fire()
			return
		var f := 1.0 - (t - charge) / FADE
		if f <= 0.0:
			queue_free()
			return
		ray.modulate.a = f
		orb.modulate.a = f
		orb.scale = Vector2.ONE * ((14.0 + 6.0 * f) / orb.texture.get_width())
		core = f
		# embers drift off the ray while it fades
		if randf() < delta * 50.0 * f:
			var at := global_position + dir * randf() * length
			Game.world.burst(at, Color("ffcf5a"), 1, 20.0, 0.35, 1.5, -25.0)
		queue_redraw()

	func _fire() -> void:
		fired = true
		var max_len := float(prm.len)
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * max_len, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		length = max_len if hit.is_empty() else global_position.distance_to(hit.position)
		var w := float(prm.width)
		ray = Sprite2D.new()
		ray.texture = GunFire.tex("beam_solar")
		ray.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ray.centered = false
		ray.offset = Vector2(0, -ray.texture.get_height() * 0.5)
		ray.rotation = dir.angle()
		# starts a little behind the muzzle (hidden in its flare) and overshoots the end
		ray.position = -dir * 4.0
		ray.scale = Vector2((length + 10.0) / ray.texture.get_width(), w * 1.8 / ray.texture.get_height())
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ray.material = add
		add_child(ray)
		move_child(ray, 0)
		var end := global_position + dir * length
		GunFx.flash(GunFire.tex("hit_solar"), end, 30.0 + w * 2.0, 0.3, dir.angle())
		GunFx.flash(GunFire.tex("hit_pulse"), global_position, 18.0 + w, 0.18).modulate = Color(1.6, 1.2, 0.5)
		# sparks spray out of both sides along the whole ray
		var n := int(length / 14.0)
		for i in n:
			var at := global_position + dir * (length * (i + randf()) / n)
			var side := dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
			Game.world.burst(at, Color("ffd36a") if i % 2 == 0 else Color.WHITE, 1, 45.0, 0.25, 1.5, 0.0, side, 0.6)
		var scorch := Scorch.new()
		scorch.a = global_position + dir * 6.0
		scorch.b = end
		scorch.dur = float(prm.scorch_t)
		scorch.dps = unit * float(prm.scorch_dps)
		Game.world.decals.add_child(scorch)
		var burn := unit * float(prm.burn_dps)
		var flares: Array[Vector2] = []
		for node in Game.world.enemy_cache:
			if not is_instance_valid(node):
				continue
			var e := node as Enemy
			if e == null or not e.targetable:
				continue
			var c := e.hit_center()
			var along := (c - global_position).dot(dir)
			if along < -4.0 or along > length + e.radius:
				continue
			if absf((c - global_position).cross(dir)) <= e.radius + w * 0.5:
				GunFx.hit(e, dmg, dir * 0.6)
				if not is_instance_valid(e) or e.dead:
					flares.append(c)
				else:
					e.ignite(burn, float(prm.burn_t))
				Game.world.burst(c, Color("ffb020"), 4, 50.0, 0.3, 1.5)
		# SOLAR FLARE: every alien the ray kills bursts and burns the ones around it
		for i in mini(flares.size(), 4):
			GunFx.blast(flares[i], float(prm.flare_r), unit * float(prm.flare_k), Color("ffb030"), "hit_solar")
		Sfx.play("laser", 0.08, -5.0)
		Game.world.shake(0.2)
		if is_instance_valid(player):
			player.recoil = 6.0

	func _draw() -> void:
		if core <= 0.0:
			return
		var w := float(prm.width)
		var end := dir * length
		# soft glow under the ray, white core over it, round caps at both ends
		draw_line(Vector2.ZERO, end, Color(1.0, 0.65, 0.15, 0.22 * core), w * 2.6)
		draw_line(Vector2.ZERO, end, Color(1, 1, 0.85, core), maxf(1.0, w * 0.3))
		draw_circle(Vector2.ZERO, w * 0.9 * core + 2.0, Color(1.0, 0.85, 0.4, 0.7 * core))
		draw_circle(end, w * 1.1 * core + 2.0, Color(1.0, 0.75, 0.3, 0.5 * core))


## Burning line the Solar Lance leaves on the floor: aliens crossing it catch fire.
class Scorch extends Node2D:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var dur := 1.6
	var dps := 8.0
	var t := 0.0
	var tick := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t >= dur:
			queue_free()
			return
		tick -= delta
		if tick <= 0.0:
			tick = 0.25
			var seg := b - a
			var l2 := maxf(seg.length_squared(), 1.0)
			for node in Game.world.enemy_cache:
				if not is_instance_valid(node):
					continue
				var e := node as Enemy
				if e == null or not e.targetable:
					continue
				var k := clampf((e.global_position - a).dot(seg) / l2, 0.0, 1.0)
				if e.global_position.distance_to(a + seg * k) < 5.0 + e.radius:
					e.ignite(dps, 0.5)
			if randf() < 0.9:
				var p := a.lerp(b, randf())
				Game.world.burst(p, Color("ff9a3a"), 1, 10.0, 0.4, 1.5, -30.0)
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((dur - t) / 0.5, 0.0, 1.0)
		var flick := 0.8 + 0.2 * sin(t * 25.0)
		draw_line(a, b, Color(0.35, 0.08, 0.02, 0.45 * fade), 6.0)
		draw_line(a, b, Color(1.0, 0.45, 0.1, 0.55 * fade * flick), 3.0)
		draw_line(a, b, Color(1.0, 0.85, 0.4, 0.5 * fade * flick), 1.0)
