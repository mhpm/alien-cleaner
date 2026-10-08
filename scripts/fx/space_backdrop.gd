class_name SpaceBackdrop
extends Node2D
## Outer space behind a floating arena deck (world 4, Room.ART_ARENAS "space" with a "sky"):
## the sky picture drifting with parallax as the camera moves, twinkling stars, asteroids
## tumbling past (near ones bigger, brighter and faster), UFOs and shuttles flying by and
## the odd comet. It is a child of the Room drawn behind it (show_behind_parent), so all
## of it passes under the deck. `lights` (a sibling drawn over the deck) blinks the
## beacons listed in the arena's .json.

const KIT := "res://assets/ui/world/world_4/image_%03d.png"
const MENU := "res://assets/ui/main/image_%03d.png"
const ROCKS_S := [8, 10, 12, 15, 19, 21, 28, 29, 31, 32, 39, 45, 49, 52, 62, 63, 64, 68, 72, 75, 83, 134, 142, 145, 146, 147]
const ROCKS_M := [9, 14, 25, 36, 37, 40, 41, 44, 53, 54, 61, 65, 73, 76, 144]
const ROCKS_L := [27, 50, 51, 35, 136, 137]
const COMETS := [24, 26, 31]
const SKY_PARALLAX := 0.2
const ART_SCALE := 0.5  # kit px -> world (same as the deck)

var rect := Rect2()  # the arena art, world units
var sky: Texture2D
var pad := 0.0  # extra sky on each side, world units
var t := 0.0
var rocks: Array = []  # [Sprite2D, vel, spin]
var stars: Array = []  # [pos, phase, speed, size]
var flyers: Array = []  # [Node2D, vel, life, wobble]
var fly_t := 3.0
var comet_t := 2.0
var lights: Lights


func setup(art_rect: Rect2, sky_tex: Texture2D, sky_pad: float, beacons: Array) -> SpaceBackdrop:
	rect = art_rect
	sky = sky_tex
	pad = sky_pad
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in 150:
		stars.append([Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y)),
				rng.randf() * TAU, rng.randf_range(1.0, 3.5), rng.randf_range(0.8, 2.2)])
	# far dust first, big rocks last (drawn on top)
	for i in 34:
		_add_rock(ROCKS_S[rng.randi() % ROCKS_S.size()], rng, rng.randf_range(0.2, 0.5))
	for i in 14:
		_add_rock(ROCKS_M[rng.randi() % ROCKS_M.size()], rng, rng.randf_range(0.45, 0.8))
	for i in 5:
		_add_rock(ROCKS_L[rng.randi() % ROCKS_L.size()], rng, rng.randf_range(0.7, 1.0))
	lights = Lights.new()
	lights.beacons = beacons
	return self


func _add_rock(id: int, rng: RandomNumberGenerator, depth: float) -> void:
	var sp := Sprite2D.new()
	sp.texture = load(KIT % id)
	sp.position = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
	sp.scale = Vector2.ONE * ART_SCALE * lerpf(0.45, 1.1, depth)
	sp.rotation = rng.randf() * TAU
	var b := lerpf(0.4, 1.0, depth)
	sp.modulate = Color(b, b, b * 1.08)
	add_child(sp)
	var dir := Vector2.from_angle(rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0))
	rocks.append([sp, dir * lerpf(3.0, 14.0, depth), rng.randf_range(-0.3, 0.3) * lerpf(0.4, 1.0, depth)])


func _camera_centre() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	return cam.get_screen_center_position() if cam != null else rect.get_center()


func _process(delta: float) -> void:
	t += delta
	var area := rect.grow(60.0)
	for r: Array in rocks:
		var sp: Sprite2D = r[0]
		sp.position += (r[1] as Vector2) * delta
		sp.rotation += float(r[2]) * delta
		if not area.has_point(sp.position):  # wrap round
			sp.position.x = wrapf(sp.position.x, area.position.x, area.end.x)
			sp.position.y = wrapf(sp.position.y, area.position.y, area.end.y)
	_flybys(delta)
	queue_redraw()


## UFOs and shuttles crossing now and then (behind the deck), and comets.
func _flybys(delta: float) -> void:
	fly_t -= delta
	if fly_t <= 0.0:
		fly_t = randf_range(4.0, 9.0)
		var node: Node2D
		var speed := randf_range(40.0, 70.0)
		if randf() < 0.55:
			var ufo := Art.make_anim("ufo", randf_range(0.28, 0.4))
			ufo.play("walk")
			node = ufo
		else:
			var sp := Sprite2D.new()
			sp.texture = load(MENU % (59 if randf() < 0.5 else 58))
			sp.scale = Vector2.ONE * randf_range(0.22, 0.32)
			node = sp
			speed *= 0.7
		var cam := _camera_centre()
		var right := randf() < 0.5
		var y := clampf(cam.y + randf_range(-260.0, 260.0), rect.position.y + 20.0, rect.end.y - 20.0)
		node.position = Vector2((cam.x - 260.0) if right else (cam.x + 260.0), y)
		if node is Sprite2D:
			(node as Sprite2D).flip_h = not right
		node.modulate = Color(0.85, 0.85, 0.95)
		add_child(node)
		flyers.append([node, Vector2(speed if right else -speed, randf_range(-6.0, 6.0)), 520.0 / speed, randf() * TAU])
	var i := 0
	while i < flyers.size():
		var f: Array = flyers[i]
		var n: Node2D = f[0]
		f[2] = float(f[2]) - delta
		n.position += (f[1] as Vector2) * delta + Vector2(0, sin(t * 2.5 + float(f[3])) * 8.0 * delta)
		n.rotation = sin(t * 2.5 + float(f[3])) * 0.08
		if float(f[2]) <= 0.0:
			n.queue_free()
			flyers.remove_at(i)
		else:
			i += 1
	comet_t -= delta
	if comet_t <= 0.0:
		comet_t = randf_range(2.0, 5.0)
		var sp := Sprite2D.new()
		sp.texture = load(MENU % COMETS[randi() % COMETS.size()])
		var a := randf_range(0.3, 0.7) + (PI if randf() < 0.3 else 0.0)
		sp.rotation = a
		sp.scale = Vector2.ONE * randf_range(0.35, 0.55)
		var cam := _camera_centre()
		sp.position = cam + Vector2(randf_range(-220.0, 120.0), randf_range(-340.0, 100.0))
		add_child(sp)
		var tw := sp.create_tween().set_parallel()
		tw.tween_property(sp, "position", sp.position + Vector2.from_angle(a) * 260.0, 0.9)
		tw.tween_property(sp, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(sp.queue_free)


func _draw() -> void:
	# the sky drifts a little with the camera (it is far away)
	var off := ((_camera_centre() - rect.get_center()) * SKY_PARALLAX).clamp(-Vector2(pad, pad), Vector2(pad, pad))
	draw_texture_rect(sky, Rect2(rect.position - Vector2(pad, pad) + off, rect.size + Vector2(pad, pad) * 2.0), false)
	for s: Array in stars:
		var k := 0.5 + 0.5 * sin(t * float(s[2]) + float(s[1]))
		if k < 0.55:
			continue
		var p: Vector2 = s[0] + off
		var r := float(s[3]) * k
		var c := Color(0.85, 0.9, 1.0, (k - 0.55) * 2.0)
		draw_rect(Rect2(p - Vector2(r, 0.3), Vector2(r * 2.0, 0.6)), c)
		draw_rect(Rect2(p - Vector2(0.3, r), Vector2(0.6, r * 2.0)), c)


## Blinking beacon lights over the deck (antenna tips, gate lamps, pillar lights).
class Lights:
	extends Node2D
	var beacons: Array = []  # world positions
	var t := 0.0

	func _ready() -> void:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		for i in beacons.size():
			var p: Vector2 = beacons[i]
			var k := clampf(sin(t * 2.2 + i * 1.7) * 1.6, 0.0, 1.0)
			if k <= 0.0:
				continue
			FastDraw.disc(self, p, 9.0 * k, Color(1.0, 0.2, 0.15, 0.18 * k))
			FastDraw.disc(self, p, 4.0 * k, Color(1.0, 0.35, 0.25, 0.4 * k))
			FastDraw.disc(self, p, 1.6, Color(1.0, 0.8, 0.7, 0.8 * k))
