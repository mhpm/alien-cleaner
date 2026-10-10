class_name HunterDrone
extends Node2D
## HUNTER DRONE upgrade (UpgradeData "hunter", Game.stats.hunter = level): a black
## shuriken drone that ORBITS the astronaut (ellipse ORBIT, ORBIT_SPEED; kit hunter.png
## upright, it does not turn on itself nor animate: the user's call) and cuts every
## alien it touches on its round (ORBIT_DMG of your damage, each alien every HIT_EVERY);
## from wherever it is it keeps THROWING its boomerang blades (HunterBlade): each flies a
## teardrop loop toward an alien and back, cutting everything on the way, and is thrown
## again as soon as it is caught, so it is always cutting. UpgradeData.HUNTER_LV:
##   1 one blade   2 twin blades in mirrored loops   3 three bigger blades in a fan
##   4 PINWHEEL: every 3rd throw 4 blades circle you as a buzzsaw, then fly out
##   5 WHIRLWIND: the drone throws ITSELF too (kit hunter_whirl.png) and every blade's far
##     end bursts in a slash wave; pinwheel every 2nd throw.

const KIT := "res://assets/ui/upgrades/kit/"
const WIDTH := 22.0  # drone width in world units
const HOVER := 24.0
const ORBIT := Vector2(44.0, 32.0)  # orbit radii around the astronaut (clear of the view)
const ORBIT_SPEED := 2.6  # rad/s around you
const ORBIT_HIT_R := 10.0
const ORBIT_DMG := 0.45
const HIT_EVERY := 0.35
const REST := 0.2  # pause between catching and the next throw
const SLASH_R := 24.0
const PINWHEEL_N := 4
const RED := Color("ff3b3b")

var player: Player
var lv := 1
var body: Sprite2D
var shadow: Sprite2D
var ground := Vector2.ZERO
var t := 0.0
var out: Array[HunterBlade] = []
var self_out := false  # level 5: the drone is flying its own loop
var wait := 0.8
var throws := 0
var orbit_a := 0.0
var hits := {}


func setup(p: Player) -> void:
	player = p
	top_level = true
	ground = p.global_position + Vector2(ORBIT.x, 0)
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(0.85, 0.6)
	shadow.modulate.a = 0.55
	add_child(shadow)
	body = Sprite2D.new()
	body.texture = load(KIT + "hunter.png")
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.scale = Vector2.ONE * (WIDTH / float(body.texture.get_width()))
	add_child(body)


func set_level(n: int) -> void:
	if n > lv:
		Game.world.ring(body.global_position, 12.0, RED, 0.3, 2.0)
	lv = n


func _data() -> Dictionary:
	return UpgradeData.HUNTER_LV[clampi(lv, 1, UpgradeData.LEVELS) - 1]


## Cuts the aliens the spinning drone touches on its orbit.
func _orbit_cut() -> void:
	var c := hand()
	for e in Game.world.enemies_near(c, ORBIT_HIT_R + 10.0):
		if not e.targetable or c.distance_to(e.hit_center()) > e.radius + ORBIT_HIT_R:
			continue
		var id := e.get_instance_id()
		if t - float(hits.get(id, -9.0)) < HIT_EVERY:
			continue
		hits[id] = t
		e.take_damage(float(Game.stats.damage) * ORBIT_DMG, (e.global_position - player.global_position).normalized() * 0.4)
		Game.world.burst(e.hit_center(), Color("ff4a4a"), 3, 60.0, 0.2, 1.5)
	if hits.size() > 200:
		hits.clear()


## Where the blades come back to: the drone, wherever it is on its orbit.
func hand() -> Vector2:
	return ground + Vector2(0, -HOVER)


func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		visible = false
		return
	visible = true
	t += delta
	orbit_a += ORBIT_SPEED * delta
	var spot := player.global_position + Vector2(cos(orbit_a) * ORBIT.x, sin(orbit_a) * ORBIT.y)
	ground = ground.lerp(spot, 1.0 - exp(-12.0 * delta))
	global_position = ground
	show_behind_parent = sin(orbit_a) < 0.0  # behind the astronaut on the far half
	var bob := sin(t * 4.0) * 1.5
	body.position = Vector2(0, -HOVER + bob)
	body.visible = not self_out
	shadow.visible = not self_out
	if not self_out:
		_orbit_cut()
	if out.is_empty() and not self_out:
		wait -= delta
		if wait <= 0.0:
			_throw()


func _throw() -> void:
	var d := _data()
	var from := hand()
	var target := _nearest(from, float(d.len) * 1.25)
	if target == null:
		wait = 0.15
		return
	throws += 1
	var aim := (target.hit_center() - from).normalized()
	var n := int(d.blades)
	var pin := int(d.pinwheel)
	if pin > 0 and throws % pin == 0:
		# PINWHEEL: a buzzsaw ring around the astronaut, then each blade loops out
		for i in PINWHEEL_N:
			var b := _blade(d, Vector2.from_angle(TAU * i / PINWHEEL_N), 1.0 if i % 2 == 0 else -1.0)
			b.ring_time = float(d.ring)
			b.ring_a = TAU * i / PINWHEEL_N
		Sfx.play("charge", 0.1, -8.0)
	else:
		for i in n:
			var spread := 0.0 if n == 1 else (i - (n - 1) * 0.5) * (0.5 if n == 2 else 0.45)
			var swing := 1.0 if (i + throws) % 2 == 0 else -1.0  # loops alternate sides each throw
			_blade(d, aim.rotated(spread), swing)
	if lv >= 5:  # WHIRLWIND: the drone throws itself along the aim
		_blade(d, aim, -1.0 if n % 2 == 1 else 1.0, true)
		self_out = true
	Sfx.play("dash", 0.15, -9.0)


func _blade(d: Dictionary, dir: Vector2, swing: float, whirl := false) -> HunterBlade:
	var b := HunterBlade.new()
	b.drone = self
	b.dir = dir
	b.length = float(d.len)
	b.width = float(d.len) * 0.42 * swing
	b.time = float(d.time)
	b.size = float(d.size)
	b.hit_r = float(d.size) * 0.7
	b.damage = float(Game.stats.damage) * float(d.dmg)
	b.split = lv >= 5
	if whirl:  # the drone itself, whirling
		b.tex = load(KIT + "hunter_whirl.png")
		b.size = WIDTH * 1.5
		b.hit_r = 15.0
		b.length *= 0.85
		b.set_meta("drone", true)
	Game.world.effects.add_child(b)
	b.global_position = hand()
	out.append(b)
	return b


func catch_blade(b: HunterBlade) -> void:
	out.erase(b)
	if b.has_meta("drone"):
		self_out = false
		Game.world.ring(hand(), 10.0, RED, 0.2, 1.5)
	if out.is_empty():
		wait = REST


## Level 5: a blade at the far end of its loop bursts in a red slash wave.
func slash_wave(at: Vector2, dir: Vector2) -> void:
	Game.world.ring(at, SLASH_R, RED, 0.25, 2.5)
	Game.world.burst(at, Color("ff6a5a"), 8, 90.0, 0.25, 1.8, 0.0, dir, 1.2)
	var dmg := float(Game.stats.damage) * float(_data().dmg)
	for e in Game.world.enemies_near(at, SLASH_R):
		if e.targetable and at.distance_to(e.hit_center()) <= SLASH_R + e.radius:
			e.take_damage(dmg, dir * 0.4)


func _exit_tree() -> void:
	for b in out:
		if is_instance_valid(b):
			b.queue_free()


func _nearest(from: Vector2, reach: float) -> Enemy:
	var best: Enemy = null
	var best_d := reach
	for e in Game.world.enemies_near(from, reach):
		if not e.targetable:
			continue
		var dd := from.distance_to(e.hit_center())
		if dd < best_d:
			best_d = dd
			best = e
	return best
