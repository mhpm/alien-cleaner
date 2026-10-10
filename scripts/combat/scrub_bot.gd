class_name ScrubBot
extends Node2D
## Scrub-Bots upgrade (UpgradeData "orbiters", Game.stats.orbiters = level): a round
## cleaning drone with 4 orange plasma pods that hovers at the astronaut's shoulder.
## Each volley every pod that faces an alien fires a ScrubShot at a DIFFERENT alien
## (UpgradeData.SCRUB_LV "pods"); from level 3 the shots pop in a small blast; from level 4
## it does a SPIN SCRUB every few seconds: it spins (kit scrub_spin_0..7) spraying a spiral
## of orbs all around you; at level 5 two spirals and the spin shoves close aliens away.
## Art: kit scrub.png (resting), scrub_spin_<n>.png, scrub_orb.png (tools/helper_drone_ref.webp).

const KIT := "res://assets/ui/upgrades/kit/"
const REST_TEX := preload("res://assets/ui/upgrades/kit/scrub.png")
const WIDTH := 20.0  # drone width in world units
const HOVER := 24.0  # height over its shadow
const SHOULDER := Vector2(-32.0, 4.0)  # where it hovers, a bit away from the astronaut
const RANGE := 160.0
const SPIN_TIME := 0.75
const SPIN_FPS := 14.0
const SPIN_PUSH_R := 46.0
const POD_OUT := 0.42  # pod distance from the centre, as a share of WIDTH

var player: Player
var lv := 1
var body: Sprite2D
var shadow: Sprite2D
var spin_tex: Array[Texture2D] = []
var ground := Vector2.ZERO
var t := 0.0
var fire_t := 0.8
var spin_cd := 3.0
var spin_t := 0.0
var spin_a := 0.0
var spin_fired := 0
var last_side := 1.0


func setup(p: Player) -> void:
	player = p
	top_level = true
	ground = p.global_position + SHOULDER
	for i in 8:
		spin_tex.append(load(KIT + "scrub_spin_%d.png" % i))
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(0.8, 0.6)
	shadow.modulate.a = 0.55
	add_child(shadow)
	body = Sprite2D.new()
	body.texture = REST_TEX
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(body)
	_size_body()
	_pop()


func set_level(n: int) -> void:
	if n > lv:
		_pop()
	lv = n


func _pop() -> void:
	Game.world.ring(body.global_position, 11.0, Color("ffb347"), 0.3, 2.0)
	body.scale *= 1.3
	var k := body.scale / 1.3
	body.create_tween().tween_property(body, "scale", k, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _size_body() -> void:
	# the spin frames carry swirl rings around the drone: keep the drone the same size
	var w := WIDTH if body.texture == REST_TEX else WIDTH * 1.25
	body.scale = Vector2.ONE * (w / body.texture.get_width())


func _data() -> Dictionary:
	return UpgradeData.SCRUB_LV[clampi(lv, 1, UpgradeData.LEVELS) - 1]


func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		visible = false
		return
	visible = true
	t += delta
	var d := _data()
	# hover on the shoulder away from where the astronaut aims
	if absf(player.aim_dir.x) > 0.3:
		last_side = -signf(player.aim_dir.x)
	var spot := player.global_position + Vector2(SHOULDER.x * -last_side, SHOULDER.y)
	ground = ground.lerp(spot, 1.0 - exp(-7.0 * delta))
	global_position = ground
	show_behind_parent = false
	var bob := sin(t * 4.2) * 1.6
	body.position = Vector2(0, -HOVER + bob)
	shadow.scale = Vector2(0.8, 0.6) * (1.0 - bob * 0.04)
	if spin_t > 0.0:
		_spin(delta, d)
		return
	body.rotation = sin(t * 2.0) * 0.08
	_volley(delta, d)
	if int(d.spin_every) > 0:
		spin_cd -= delta
		if spin_cd <= 0.0 and _nearest(body.global_position, RANGE, []) != null:
			_start_spin()


## Each pod that has an alien to aim at fires at a different one.
func _volley(delta: float, d: Dictionary) -> void:
	fire_t -= delta
	if fire_t > 0.0:
		return
	var from := body.global_position
	var taken: Array[Enemy] = []
	for i in int(d.pods):
		var e := _nearest(from, RANGE, taken)
		if e == null:
			break
		taken.append(e)
	if taken.is_empty():
		fire_t = 0.15
		return
	fire_t = float(d.rate)
	for e in taken:
		var aim := (e.hit_center() - from).normalized()
		_fire(_pod(aim), aim, d)
	Sfx.play("shoot", 0.3, -12.0)
	body.scale *= 1.1
	var k := body.scale / 1.1
	body.create_tween().tween_property(body, "scale", k, 0.12)


## World position of the pod facing a direction (pods point up, down, left, right).
func _pod(aim: Vector2) -> Vector2:
	var p := Vector2(signf(aim.x), 0.0) if absf(aim.x) > absf(aim.y) else Vector2(0.0, signf(aim.y))
	return body.global_position + p * WIDTH * POD_OUT


func _fire(at: Vector2, dir: Vector2, d: Dictionary) -> void:
	var s := ScrubShot.new()
	s.dir = dir
	s.damage = float(Game.stats.damage) * 0.6
	s.blast_r = float(d.blast)
	Game.world.effects.add_child(s)
	s.global_position = at
	Game.world.burst(at, Color("ffb347"), 2, 30.0, 0.15, 1.5, 0.0, dir, 0.6)


func _start_spin() -> void:
	spin_t = SPIN_TIME
	spin_a = randf() * TAU
	spin_fired = 0
	Sfx.play("charge", 0.1, -8.0)


## SPIN SCRUB: spins through its frames and sprays a spiral of orbs all around.
func _spin(delta: float, d: Dictionary) -> void:
	spin_t -= delta
	var k := 1.0 - spin_t / SPIN_TIME
	body.texture = spin_tex[int(k * SPIN_TIME * SPIN_FPS) % spin_tex.size()]
	body.rotation = 0.0
	_size_body()
	var total := int(d.spin_orbs)
	var arms := 2 if lv >= 5 else 1
	var due := int(k * total)
	while spin_fired < mini(due, total):
		var a := spin_a + TAU * float(spin_fired) / total * 1.5
		for arm in arms:
			var dir := Vector2.from_angle(a + PI * arm)
			_fire(body.global_position + dir * WIDTH * POD_OUT, dir, d)
		spin_fired += 1
	if lv >= 5 and int(t * 10.0) != int((t - delta) * 10.0):
		Game.world.ring(player.global_position, SPIN_PUSH_R, Color("ffb347"), 0.2, 1.5)
		for e in Game.world.enemies_near(player.global_position, SPIN_PUSH_R):
			if e.targetable and not e.is_boss and not e.anchored and e.global_position.distance_to(player.global_position) < SPIN_PUSH_R:
				e.push((e.global_position - player.global_position).normalized() * 90.0)
	if spin_t <= 0.0:
		spin_cd = float(d.spin_every)
		body.texture = REST_TEX
		_size_body()
		Sfx.play("pop", 0.1, -8.0)


func _nearest(from: Vector2, reach: float, skip: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	var best_d := reach
	for e in Game.world.enemies_near(from, reach):
		if not e.targetable or skip.has(e):
			continue
		var dd := from.distance_to(e.hit_center())
		if dd < best_d:
			best_d = dd
			best = e
	return best
