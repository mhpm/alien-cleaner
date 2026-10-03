class_name WorldSpace
extends Control
## Living backdrop of the world select: the wide spaceship window of
## tools/world_select_space_ref.webp (python tools/make_world_space_assets.py ->
## assets/ui/world/space/) scaled to cover any screen, with the kit pieces moving in the
## sky behind the window frame (fg.png = the picture with the opening cut out):
## a ringed planet, a far station and small planets bobbing, asteroids and belts drifting
## and spinning, ships crossing now and then, twinkling sparkles and shooting stars.
## Everything is placed in picture px inside the part of the window that is on screen,
## so narrow phones and tablets both get a full sky.

const DIR := "res://assets/ui/world/space/"
const SIZE := Vector2(1672, 941)
const FOCUS_X := 950.0  # picture x kept in the middle of the screen (galaxy core in view)
const SKY := Rect2(110, 82, 1460, 590)  # inside the window opening, clear of the frame
const SHIPS := ["ship_cruiser", "ship_fighter", "ship_dart", "ship_hauler", "ship_gunship", "ship_scout"]
const SHIP_SIZE := {"ship_cruiser": 1.0, "ship_hauler": 0.85, "ship_fighter": 0.75,
		"ship_gunship": 0.7, "ship_dart": 0.65, "ship_scout": 0.55}  # relative length
const ROCKS := ["rock_0", "rock_1", "rock_2", "rock_3", "rock_4", "rock_5", "rock_6", "rock_7", "rock_8", "rock_9"]
const STARS := ["star_0", "star_1", "star_2", "star_3", "star_4", "star_5", "star_6"]
const N_ROCKS := 7
const N_TWINKLES := 12

var view: Node2D  # picture px -> screen
var far: Node2D  # planets and station
var mid: Node2D  # asteroids
var near: Node2D  # ships, sparkles, shooting stars
var add_mat: CanvasItemMaterial
var vis := Rect2(Vector2.ZERO, SIZE)  # part of the picture on screen
var t := 0.0
var props: Array = []  # [Sprite2D, frac in the visible sky, bob amplitude, bob speed, phase]
var rocks: Array = []  # {spr, vel, spin}
var ships: Array = []  # {spr, vel, base_y, phase}
var twinkles: Array = []  # {spr, age, life, peak}
var comet: Line2D
var comet_head := Vector2.ZERO
var comet_vel := Vector2.ZERO
var comet_life := 0.0
var ship_t := 1.2
var comet_t := 3.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	view = Node2D.new()
	add_child(view)
	var bg := _spr(view, "bg.webp", Vector2.ZERO, 1.0)
	bg.centered = false
	far = _layer()
	mid = _layer()
	near = _layer()
	var fg := _spr(view, "fg.png", Vector2.ZERO, 1.0)
	fg.centered = false
	resized.connect(_fit)
	_fit()
	_build()


func _layer() -> Node2D:
	var n := Node2D.new()
	view.add_child(n)
	return n


func _spr(parent: Node, id: String, pos: Vector2, s: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(DIR + id)
	sp.position = pos
	sp.scale = Vector2(s, s)
	parent.add_child(sp)
	return sp


## Scale the picture to cover the screen, keeping FOCUS_X in the middle when it can.
func _fit() -> void:
	if view == null or size.x <= 0.0:
		return
	var s := maxf(size.x / SIZE.x, size.y / SIZE.y)
	var pos := size * 0.5 - Vector2(FOCUS_X, SIZE.y * 0.5) * s
	pos.x = clampf(pos.x, size.x - SIZE.x * s, 0.0)
	pos.y = clampf(pos.y, size.y - SIZE.y * s, 0.0)
	view.scale = Vector2(s, s)
	view.position = pos
	vis = Rect2(-pos / s, size / s)
	for p: Array in props:
		(p[0] as Sprite2D).position = _at(p[1])


## The window's sky that is on screen.
func _sky() -> Rect2:
	var r := vis.intersection(SKY)
	return r if r.size.x > 10.0 else SKY


## A point of the visible sky by fractions (0..1).
func _at(f: Vector2) -> Vector2:
	var r := _sky()
	return r.position + r.size * f


func _build() -> void:
	# far: a ringed planet, the station, a small orange planet and a moon (gently bobbing)
	_prop("planet_ringed.png", Vector2(0.2, 0.2), 0.2, 4.0, 0.35)
	_prop("station.png", Vector2(0.84, 0.3), 0.15, 5.0, 0.5).modulate = Color(0.85, 0.85, 1.0)
	_prop("planet_orange.png", Vector2(0.86, 0.8), 0.13, 3.0, 0.3)
	_prop("moon.png", Vector2(0.1, 0.66), 0.22, 2.5, 0.6)
	for i in N_ROCKS:
		rocks.append(_new_rock(true))
	for i in N_TWINKLES:
		var sp := _spr(near, STARS[i % STARS.size()] + ".png", Vector2.ZERO, 0.0)
		sp.material = add_mat
		var tw := {"spr": sp, "age": 0.0, "life": 1.0, "peak": 0.3}
		_reset_twinkle(tw)
		tw.age = randf() * float(tw.life)
		twinkles.append(tw)
	comet = Line2D.new()
	comet.width = 3.0
	comet.material = add_mat
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.8, 1.0, 0.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.95))
	comet.gradient = g
	comet.visible = false
	near.add_child(comet)


func _prop(id: String, f: Vector2, s: float, bob: float, speed: float) -> Sprite2D:
	var sp := _spr(far, id, _at(f), s)
	props.append([sp, f, bob, speed, randf() * TAU])
	return sp


## An asteroid (or a small belt) entering from a side, or anywhere at the start.
func _new_rock(anywhere: bool, old: Sprite2D = null) -> Dictionary:
	var belt := randf() < 0.18
	var id := ("belt_%d" % (randi() % 2)) if belt else str(ROCKS.pick_random())
	var sp := old if old != null else Sprite2D.new()
	if old == null:
		mid.add_child(sp)
	sp.texture = load(DIR + id + ".png")
	var depth := randf_range(0.35, 1.0)  # far rocks: smaller, darker, slower
	var s := (0.16 if belt else 0.1) + depth * (0.16 if belt else 0.22)
	if not belt and id == "rock_0":
		s *= 0.6
	sp.scale = Vector2(s, s)
	sp.modulate = Color(0.55, 0.55, 0.7).lerp(Color.WHITE, depth)
	sp.rotation = randf() * TAU
	var r := _sky()
	var dir := 1.0 if randf() < 0.5 else -1.0
	var vel := Vector2(dir * randf_range(6.0, 16.0) * (0.5 + depth), randf_range(-3.0, 3.0))
	var pos := Vector2(r.position.x + randf() * r.size.x, r.position.y + randf() * r.size.y)
	if not anywhere:
		var half := sp.texture.get_size().x * s * 0.5
		pos.x = (vis.position.x - half - 10.0) if dir > 0.0 else (vis.end.x + half + 10.0)
	sp.position = pos
	return {"spr": sp, "vel": vel, "spin": randf_range(-0.35, 0.35) * (0.3 if belt else 1.0)}


func _reset_twinkle(tw: Dictionary) -> void:
	var sp: Sprite2D = tw.spr
	sp.position = _at(Vector2(randf(), randf()))
	sp.rotation = randf_range(-0.2, 0.2)
	tw.age = 0.0
	tw.life = randf_range(1.4, 3.2)
	tw.peak = randf_range(0.12, 0.32)
	sp.scale = Vector2.ZERO


func _spawn_ship() -> void:
	var id: String = SHIPS.pick_random()
	var sp := _spr(near, id + ".png", Vector2.ZERO, 1.0)
	var depth := randf_range(0.0, 1.0)  # near ships: bigger and faster
	var length := lerpf(55.0, 140.0, depth) * float(SHIP_SIZE[id])  # picture px
	var s := length / sp.texture.get_size().x
	sp.scale = Vector2(s, s)
	sp.modulate = Color(0.6, 0.6, 0.78).lerp(Color.WHITE, depth)
	var right := randf() < 0.6
	sp.flip_h = not right  # the art flies to the right
	var r := _sky()
	var y := r.position.y + r.size.y * randf_range(0.08, 0.92)
	var half := length * 0.5 + 20.0
	sp.position = Vector2(vis.position.x - half if right else vis.end.x + half, y)
	var speed := lerpf(40.0, 120.0, depth) * randf_range(0.85, 1.2)
	ships.append({"spr": sp, "vel": Vector2(speed if right else -speed, randf_range(-4.0, 4.0)),
			"base": y, "phase": randf() * TAU})


func _process(delta: float) -> void:
	t += delta
	for p: Array in props:
		var sp: Sprite2D = p[0]
		sp.position = _at(p[1]) + Vector2(0.0, sin(t * float(p[3]) + float(p[4])) * float(p[2]))
	# asteroids drift and spin; when one leaves the view a new one comes in from a side
	for rk: Dictionary in rocks:
		var sp: Sprite2D = rk.spr
		sp.position += (rk.vel as Vector2) * delta
		sp.rotation += float(rk.spin) * delta
		var half := sp.texture.get_size().x * sp.scale.x * 0.5 + 30.0
		if sp.position.x < vis.position.x - half or sp.position.x > vis.end.x + half:
			var nr := _new_rock(false, sp)
			rk.vel = nr.vel
			rk.spin = nr.spin
	# ships cross every few seconds (now and then two in a row)
	ship_t -= delta
	if ship_t <= 0.0:
		_spawn_ship()
		ship_t = randf_range(0.6, 1.4) if randf() < 0.25 else randf_range(3.0, 6.5)
	for i in range(ships.size() - 1, -1, -1):
		var sh: Dictionary = ships[i]
		var sp: Sprite2D = sh.spr
		sp.position.x += (sh.vel as Vector2).x * delta
		sh.base = float(sh.base) + (sh.vel as Vector2).y * delta
		sp.position.y = float(sh.base) + sin(t * 1.6 + float(sh.phase)) * 2.0
		sp.rotation = sin(t * 1.1 + float(sh.phase)) * 0.025
		var glow := 0.92 + 0.08 * sin(t * 30.0 + float(sh.phase))  # engines flicker
		sp.self_modulate = Color(glow, glow, glow * 1.05)
		var half := sp.texture.get_size().x * sp.scale.x * 0.5 + 40.0
		if sp.position.x > vis.end.x + half or sp.position.x < vis.position.x - half:
			sp.queue_free()
			ships.remove_at(i)
	# sparkles: grow, turn a little and fade, then pop up elsewhere
	for tw: Dictionary in twinkles:
		tw.age = float(tw.age) + delta
		var k := float(tw.age) / float(tw.life)
		if k >= 1.0:
			_reset_twinkle(tw)
			continue
		var sp: Sprite2D = tw.spr
		var a := sin(k * PI)
		sp.scale = Vector2.ONE * float(tw.peak) * a
		sp.modulate.a = a
		sp.rotation += delta * 0.4
	_update_comet(delta)


## A shooting star now and then, diagonally down across the visible sky.
func _update_comet(delta: float) -> void:
	if comet_life > 0.0:
		comet_life -= delta
		comet_head += comet_vel * delta
		var tail := comet_head - comet_vel.normalized() * 70.0
		comet.points = PackedVector2Array([tail, comet_head])
		comet.modulate.a = clampf(comet_life * 3.0, 0.0, 1.0)
		if comet_life <= 0.0:
			comet.visible = false
		return
	comet_t -= delta
	if comet_t > 0.0:
		return
	comet_t = randf_range(4.0, 9.0)
	var r := _sky()
	var left := randf() < 0.5
	comet_head = r.position + Vector2(r.size.x * (randf_range(0.0, 0.4) if left else randf_range(0.6, 1.0)), r.size.y * randf_range(0.0, 0.35))
	comet_vel = Vector2(1.0 if left else -1.0, randf_range(0.35, 0.6)).normalized() * randf_range(260.0, 360.0)
	comet_life = randf_range(0.55, 0.8)
	comet.visible = true
