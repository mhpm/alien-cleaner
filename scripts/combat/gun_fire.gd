class_name GunFire
extends RefCounted
## Fires the equipped ARMORY weapon (GunData, Game.stats.gun / gun_lv) for the Player.
## Every `kind` shoots its own way: straight projectiles are GunShot (a Bullet), the
## Toxic glob is lobbed (GunFx.Lob), Tesla and Solar hit instantly (GunFx.Arc / Beam).
## Run extras (spread upgrades, the Triple power-up) fan the whole weapon out.

const BASE_INTERVAL := 0.42  # stats.fire_interval of a fresh run: weapon rates scale with it
const SOUNDS := {
	"pulse": ["shoot", -7.0], "nova": ["shotgun", -6.0], "drill": ["drill", -7.0],
	"spark": ["shoot", -6.0], "cryo": ["spray", -9.0], "goo": ["goo", -4.0],
	"graviton": ["grav", -6.0], "tesla": ["zap", -5.0], "rockets": ["rocket", -6.0],
	"solar": ["charge", -6.0],
}
const EXTRA_K := 0.7  # damage of each extra copy of the weapon (OVERDRIVE, Triple)
const NOVA_EVERY := 3.0  # OVERDRIVE level 5: seconds between Rocket Novas
const RECOIL := {"pulse": 2.5, "nova": 4.5, "drill": 3.0, "spark": 2.5, "cryo": 1.0, "goo": 4.0,
	"graviton": 4.5, "tesla": 2.0, "rockets": 4.0, "solar": 5.0}

static var _shots := 0  # Pulse: counts shots for its guaranteed crit
static var _tex := {}


## Weapon art (assets/guns/<name>.png) with mipmaps: it is drawn far smaller than painted.
static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var img := (load(GunData.DIR + name + ".png") as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_tex[name] = ImageTexture.create_from_image(img)
	return _tex[name]


## Seconds between shots of the equipped weapon this run.
static func interval(s: Dictionary) -> float:
	return float(GunData.gun(str(s.gun)).rate) * float(s.fire_interval) / BASE_INTERVAL


static func fire(p: Player, origin: Vector2, d: Vector2, target: Enemy) -> float:
	var s := Game.stats
	var id := str(s.gun)
	var lv := int(s.gun_lv)
	var g := GunData.gun(id)
	var prm := GunData.params(id, lv)
	var unit := _unit(p)
	var dmg := unit * float(g.dmg)
	var col := Color(str(g.color))
	# OVERDRIVE / power-ups add copies of the whole weapon: parallel barrels ("shots")
	# side by side and a fan ("spread"); every copy after the first hits for EXTRA_K
	var copies: Array = []  # [muzzle offset, direction]
	var n_par := int(s.shots)
	for k in n_par:
		copies.append([d.orthogonal() * (k - (n_par - 1) * 0.5) * 6.0, d])
	for k in int(s.spread) + (1 if p.has_buff("triple") else 0):
		copies.append([Vector2.ZERO, d.rotated(0.3 * (k + 1))])
		copies.append([Vector2.ZERO, d.rotated(-0.3 * (k + 1))])
	_shots += 1
	for i in copies.size():
		var o: Vector2 = origin + (copies[i][0] as Vector2)
		var sd: Vector2 = copies[i][1]
		var dk := dmg * (1.0 if i == 0 else EXTRA_K)
		var tgt := target if i == 0 else _target_near(o + sd * 90.0, 70.0)
		match str(g.kind):
			"pulse":
				var crit := _shots % int(prm.crit_every) == 0
				var b := _shot("shot_pulse", o, sd, float(g.speed), dk, 14.0, 3.5, 1.2)
				b.force_crit = crit
				if crit:
					b.base_len = 19.0
					b.modulate = Color(1.4, 1.25, 0.8)
			"nova":
				var n := int(prm.pellets)
				for k in n:
					var a := (float(k) / (n - 1) - 0.5) * float(prm.arc) + randf_range(-0.04, 0.04)
					var b := _shot("shot_nova", o, sd.rotated(a), float(g.speed) * randf_range(0.9, 1.1), dk, 10.0, 3.0, float(prm.life))
					b.push = float(prm.push)
			"drill":
				var b := _shot("bolt_drill", o + sd * 6.0, sd, float(g.speed), dk, 30.0, 4.5, 0.9)
				b.pierce = 99
				b.shred = float(prm.shred)
				b.shred_t = float(prm.shred_t)
				b.trail = col
			"spark":
				var b := _shot("shot_spark", o, sd, float(g.speed), dk, 10.0, 4.0, 1.4)
				b.hops = int(prm.hops)
				b.hop_r = float(prm.hop_r)
				b.bounces = int(prm.bounces) + int(s.ricochet)
				b.trail = col
				b.pop_tex = "hit_spark"
			"cryo":
				for k in int(prm.flakes):
					var a := randf_range(-0.5, 0.5) * float(prm.arc)
					var b := _shot("flake", o, sd.rotated(a), float(g.speed) * randf_range(0.8, 1.15), dk, 7.0, 4.5, float(prm.life) * randf_range(0.85, 1.1))
					b.pierce = 1 + int(Game.stats.pierce)
					b.chill = int(prm.chill)
					b.ice_t = GunData.ice_time(lv)
					b.ice_dps = unit * float(prm.ice_dps)
					b.spin = randf_range(-9.0, 9.0)
					b.drag = 1.6
			"goo":
				var to := o + sd * 110.0
				if tgt != null:
					to = tgt.global_position + tgt.velocity * 0.35
				var lob := GunFx.Lob.new()
				lob.from = o
				lob.to = to
				lob.dmg = dk
				lob.prm = prm
				lob.unit = unit
				Game.world.effects.add_child(lob)
			"graviton":
				var b := _shot("shot_grav", o + sd * 4.0, sd, float(g.speed), dk, 16.0, 6.0, float(prm.fuse))
				b.pierce = 99
				b.pull_r = float(prm.pull_r)
				b.boom_r = float(prm.boom_r)
				b.boom_dmg = unit * float(prm.boom_dmg)
				b.boom_tex = "hole"
				b.boom_col = col
				b.spin = 4.0
			"tesla":
				if tgt != null:
					GunFx.tesla(o, tgt, dk, prm)
			"rockets":
				var n := int(prm.rockets)
				var aims := _targets(o, n)
				for k in n:
					var a := (float(k) / maxf(1.0, n - 1.0) - 0.5) * 1.8
					var b := _shot("rocket", o, sd.rotated(a), 70.0, dk, 12.0, 4.0, 1.8)
					b.home = aims[k % aims.size()] if not aims.is_empty() else tgt
					b.accel = 420.0
					b.top_speed = float(g.speed)
					b.boom_r = float(prm.boom_r)
					b.boom_dmg = unit * float(prm.boom_k)
					b.boom_tex = "boom"
					b.boom_col = col
					b.smoke = true
			"solar":
				var beam := GunFx.Beam.new()
				beam.player = p
				beam.dir = sd
				beam.off = d.angle_to(sd)
				beam.dmg = dk
				beam.unit = unit
				beam.prm = prm
				Game.world.effects.add_child(beam)
				beam.global_position = o
	var snd: Array = SOUNDS[str(g.kind)]
	Sfx.play(str(snd[0]), 0.12, float(snd[1]))
	if str(g.kind) not in ["solar", "goo"]:
		var flash := AnimFx.spawn(Game.world.effects, "muzzle", "flash", origin, 0.24)
		flash.material = Art.shot_material(col)
		flash.create_tween().tween_property(flash, "modulate:a", 0.0, 0.06)
	Game.world.burst(origin, col.lightened(0.3), 3, 45.0, 0.15, 1.5, 0.0, d, 0.5)
	return float(RECOIL[str(g.kind)])


## One base hit of this run: ATTACK, blaster tier, the weapon's level, Rage.
static func _unit(p: Player) -> float:
	var s := Game.stats
	var unit := float(s.damage) * float(WeaponData.tier(int(s.weapon)).dmg) * GunData.level_mult(int(s.gun_lv))
	return unit * (2.0 if p.has_buff("rage") else 1.0)


## OVERDRIVE level 5: a star of 5 homing rockets bursts out of the astronaut.
static func rocket_nova(p: Player) -> void:
	var at := p.global_position + Vector2(0, Player.BODY_Y)
	var unit := _unit(p)
	var aims := _targets(at, 5)
	for k in 5:
		var b := _shot("rocket", at, Vector2.from_angle(-PI * 0.5 + TAU * k / 5.0), 60.0, unit * 1.2, 12.0, 4.0, 2.0)
		b.home = aims[k % aims.size()] if not aims.is_empty() else null
		b.accel = 380.0
		b.top_speed = 210.0
		b.boom_r = 18.0
		b.boom_dmg = unit * 0.7
		b.boom_tex = "boom"
		b.boom_col = Color("ff9a3a")
		b.smoke = true
	GunFx.flash(tex("boom"), at, 26.0, 0.25, 0.0, 1.6)
	Game.world.ring(at, 20.0, Color("ffb050"), 0.25, 2.5)
	Sfx.play("rocket", 0.1, -3.0)


static func _shot(art: String, pos: Vector2, d: Vector2, speed: float, dmg: float, length: float,
		hit_r: float, life: float) -> GunShot:
	var b := GunShot.new()
	b.art = art
	b.base_len = length
	b.dir = d
	b.speed = speed
	b.damage = dmg
	b.hit_r = hit_r
	b.life = life
	b.pierce = int(Game.stats.pierce)
	if b.pierce > 0:
		b.trail = Color("8ff4ff")
	Game.world.effects.add_child(b)
	b.global_position = pos
	return b


## The `n` aliens nearest to `from` (repeats when there are fewer): rocket targets.
static func _targets(from: Vector2, n: int) -> Array[Enemy]:
	var all: Array[Enemy] = []
	var reach := Game.world.aim_range()
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e != null and e.targetable and from.distance_to(e.global_position) <= reach:
			all.append(e)
	all.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return from.distance_squared_to(a.global_position) < from.distance_squared_to(b.global_position))
	return all.slice(0, n)


static func _target_near(at: Vector2, r: float) -> Enemy:
	var best: Enemy = null
	var bd := r
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e == null or not e.targetable:
			continue
		var dd := at.distance_to(e.global_position)
		if dd < bd:
			bd = dd
			best = e
	return best
