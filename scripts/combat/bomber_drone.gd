class_name BomberDrone
extends Node2D
## BOMBER DRONE upgrade (UpgradeData "bomber", Game.stats.bomber = level): an army-green
## bomber (kit bomber.png, no animation) that cruises in a wide slow ellipse around the
## astronaut, clear of the view, and bombs the THICKEST crowd near you (BomberBomb
## arcs down, BombBlast explosion from the kit frames). UpgradeData.BOMBER_LV:
##   1 a bomb on the biggest crowd every few seconds
##   2 CLUSTER: each blast scatters bomblets that pop around it
##   3 CARPET RUN: every 3rd drop it flies a pass over the crowd dropping a line of bombs
##   4 bigger blasts; a bomb that lands with no alien close stays as a proximity MINE
##   5 MEGA BOMB: every 4th drop is a huge nuke (the ringed blast frame), shakes the screen

const KIT := "res://assets/ui/upgrades/kit/"
const WIDTH := 24.0
const HOVER := 30.0
const CRUISE := Vector2(52.0, 34.0)  # wide slow ellipse around the astronaut (never over it)
const CRUISE_SPEED := 0.9
const REACH := 170.0  # how far from you it looks for a crowd
const CROWD_R := 40.0
const RUN_SPEED := 210.0
const RUN_LEN := 110.0
const RUN_STEP := 22.0  # one bomb every this many units of the carpet run
const BOMBLET_K := 0.45  # bomblet damage, share of the bomb's
const MEGA_EVERY := 4

var player: Player
var lv := 1
var body: Sprite2D
var shadow: Sprite2D
var ground := Vector2.ZERO
var t := 0.0
var cd := 1.5
var drops := 0
var state := "cruise"  # cruise, to_run, run, back
var run_a := Vector2.ZERO
var run_b := Vector2.ZERO
var run_left := 0.0


func setup(p: Player) -> void:
	player = p
	top_level = true
	ground = p.global_position + Vector2(CRUISE.x, 0.0)
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(0.95, 0.6)
	shadow.modulate.a = 0.5
	add_child(shadow)
	body = Sprite2D.new()
	body.texture = load(KIT + "bomber.png")
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.scale = Vector2.ONE * (WIDTH / float(body.texture.get_width()))
	add_child(body)


func set_level(n: int) -> void:
	if n > lv:
		Game.world.ring(body.global_position, 12.0, Color("ffb000"), 0.3, 2.0)
	lv = n


func _data() -> Dictionary:
	return UpgradeData.BOMBER_LV[clampi(lv, 1, UpgradeData.LEVELS) - 1]


func _cruise_spot() -> Vector2:
	var a := t * CRUISE_SPEED
	return player.global_position + Vector2(cos(a) * CRUISE.x, sin(a) * CRUISE.y)


func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		visible = false
		return
	visible = true
	t += delta
	var d := _data()
	match state:
		"cruise":
			ground = ground.lerp(_cruise_spot(), 1.0 - exp(-5.0 * delta))
			cd -= delta
			if cd <= 0.0:
				_drop(d)
		"to_run":
			ground = ground.move_toward(run_a, RUN_SPEED * 1.2 * delta)
			if ground.distance_to(run_a) < 2.0:
				state = "run"
				run_left = 0.0
		"run":
			var to := run_b
			ground = ground.move_toward(to, RUN_SPEED * delta)
			run_left -= RUN_SPEED * delta
			if run_left <= 0.0:
				run_left = RUN_STEP
				_bomb(d, ground, 0.3, 6.0, false)
			if ground.distance_to(to) < 2.0:
				state = "back"
		"back":
			ground = ground.move_toward(_cruise_spot(), RUN_SPEED * 1.1 * delta)
			if ground.distance_to(_cruise_spot()) < 4.0:
				state = "cruise"
	global_position = ground
	var bob := sin(t * 3.4) * 1.6
	body.position = Vector2(0, -HOVER + bob)
	shadow.scale = Vector2(0.95, 0.6) * (1.0 - bob * 0.03)


## Next drop: a bomb on the biggest crowd (or a carpet run / MEGA bomb on their turn).
func _drop(d: Dictionary) -> void:
	var crowd := _crowd()
	if crowd == Vector2.INF:
		cd = 0.3
		return
	drops += 1
	cd = float(d.cd)
	if lv >= 3 and drops % 3 == 0:
		# CARPET RUN: a pass straight over the crowd, bombs all along it
		var dir := (crowd - ground).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		run_a = crowd - dir * RUN_LEN * 0.5
		run_b = crowd + dir * RUN_LEN * 0.5
		state = "to_run"
		Sfx.play("alert", 0.1, -10.0)
		return
	var mega := lv >= 5 and drops % MEGA_EVERY == 0
	_bomb(d, crowd, 0.7 if mega else 0.6, 34.0, mega)


func _bomb(d: Dictionary, at: Vector2, time: float, arc: float, mega: bool) -> void:
	var b := BomberBomb.new()
	b.drone = self
	b.from = body.global_position
	b.ground_from = ground
	b.to = at
	b.time = time
	b.arc = arc
	b.radius = float(d.radius) * (2.2 if mega else 1.0)
	b.damage = float(Game.stats.damage) * float(d.dmg) * (2.2 if mega else 1.0)
	b.size = 15.0 if mega else 9.0
	b.mega = mega
	b.mine = lv >= 4 and not mega
	b.cluster = int(d.cluster)
	Game.world.effects.add_child(b)
	Sfx.play("dash", 0.2, -14.0)


## Explosion: hurts every alien in the radius, scatters bomblets (CLUSTER).
func blast(at: Vector2, r: float, dmg: float, mega: bool, cluster: int) -> void:
	BombBlast.spawn(at, r, mega)
	for e in Game.world.enemies_near(at, r):
		if e.targetable and at.distance_to(e.hit_center()) <= r + e.radius:
			e.take_damage(dmg, (e.global_position - at).normalized() * (1.0 if mega else 0.5))
	Sfx.play("explode", 0.15, -4.0 if mega else -9.0)
	Game.world.shake(5.0 if mega else 1.2)
	for i in cluster:
		var b := BomberBomb.new()
		b.drone = self
		b.from = at + Vector2(0, -4)
		b.ground_from = at
		b.to = at + Vector2.from_angle(TAU * i / cluster + randf() * 0.6) * randf_range(r * 0.9, r * 1.5)
		b.time = 0.35
		b.arc = 16.0
		b.radius = r * 0.5
		b.damage = dmg * BOMBLET_K
		b.size = 6.0
		Game.world.effects.add_child(b)


## Centre of the thickest crowd within REACH of the astronaut (INF if none).
func _crowd() -> Vector2:
	var best := Vector2.INF
	var best_n := 0
	var seen := 0
	for e in Game.world.enemies_near(player.global_position, REACH):
		if not e.targetable or e.global_position.distance_to(player.global_position) > REACH:
			continue
		seen += 1
		if seen > 14:
			break
		var n := 0
		var sum := Vector2.ZERO
		for o in Game.world.enemies_near(e.global_position, CROWD_R):
			if o.global_position.distance_to(e.global_position) < CROWD_R:
				n += 1
				sum += o.global_position
		if n > best_n:
			best_n = n
			best = sum / n
	return best
