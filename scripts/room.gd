class_name Room
extends Node2D
## Spaceship room: the painted frame (assets/room/room_bg.webp from tools/make_room_assets.py)
## plus props from a 10x14 ASCII layout. Builds collisions, runs the environmental
## hazards (toxic slime, electric floor) and the exit door.
## Layout legend: . floor  v vent/grate  # crate (## = big crate)  T crystal planter
##                c canister  B explosive barrel  t toxic slime  z electric floor

const TILE := 16
const COLS := 10
const ROWS := 14
const W := 160.0
const H := 224.0
const DOOR_L := 64.0
const DOOR_R := 96.0
const ART := "res://assets/room/"
## painted art -> world: interior px (60,330)-(897,1490) is the 160x224 room
const ART_ORIGIN := Vector2(60, 330)
const ART_SCALE := Vector2(160.0 / 837.0, 224.0 / 1160.0)
const ART_SIZE := Vector2(957, 1644)
## world rect of the door opening in the painted wall
const DOOR_RECT := Rect2(64.0, -34.4, 32.5, 29.6)
const DOOR_LIGHT := Rect2(66.4, -43.3, 28.7, 3.4)

var grid: Array = []
var toxic: Dictionary = {}  # Vector2i -> splat texture
var electric: Array[Vector2i] = []
var decor: Array = []  # [cell, texture]
var spawned: Array[Node] = []
var door_open := false
var door_k := 0.0
var door_shape: CollisionShape2D
var elec_t := 0.0
var elec_state := 0  # 0 off, 1 warning, 2 live
var tick := 0.0
var anim_t := 0.0
var bg: Texture2D
var tex_grate: Texture2D
var tex_vent: Texture2D
var tex_splats: Array[Texture2D] = []


func _ready() -> void:
	bg = load(ART + "room_bg.webp")
	tex_grate = load(ART + "prop_grate.png")
	tex_vent = load(ART + "prop_vent.png")
	for i in 3:
		tex_splats.append(load(ART + "prop_splat%d.png" % (i + 1)))
	_build_walls()


static func art_to_world(p: Vector2) -> Vector2:
	return (p - ART_ORIGIN) * ART_SCALE


## World-space rect covered by the painted room art (used to frame the camera).
static func art_rect() -> Rect2:
	var tl := art_to_world(Vector2.ZERO)
	return Rect2(tl, ART_SIZE * ART_SCALE)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for r: Rect2 in [
		Rect2(-16, -80, 16, 336), Rect2(W, -80, 16, 336), Rect2(-16, H, W + 32, 16),
		Rect2(-16, -16, DOOR_L + 16, 16), Rect2(DOOR_R, -16, W - DOOR_R + 16, 16),
		Rect2(DOOR_L - 8, -80, 8, 64), Rect2(DOOR_R, -80, 8, 64), Rect2(DOOR_L - 8, -88, DOOR_R - DOOR_L + 16, 8),
	]:
		_wall_rect(body, r)
	door_shape = _wall_rect(body, Rect2(DOOR_L, -16, DOOR_R - DOOR_L, 16))


func _wall_rect(body: StaticBody2D, r: Rect2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)
	return cs


func build(layout: Array, entities: Node2D) -> void:
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()
	spawned.clear()
	toxic.clear()
	electric.clear()
	decor.clear()
	grid = layout
	door_open = false
	door_k = 0.0
	door_shape.set_deferred("disabled", false)
	elec_t = 0.0
	elec_state = 0
	var used: Dictionary = {}
	for y in ROWS:
		var row: String = grid[y]
		for x in COLS:
			var cell := Vector2i(x, y)
			if used.has(cell):
				continue
			match row[x]:
				"#":
					var big := x + 1 < COLS and row[x + 1] == "#"
					if big:
						used[Vector2i(x + 1, y)] = true
						_add_solid(entities, "crate", Vector2(x * TILE + 16, y * TILE + 16), Vector2(32, 13), 32.0)
					else:
						_add_solid(entities, "crate", Vector2(x * TILE + 8, y * TILE + 16), Vector2(16, 12), 19.0)
				"T":
					_add_solid(entities, "planter", Vector2(x * TILE + 8, y * TILE + 16), Vector2(16, 12), 19.0)
				"c":
					_add_solid(entities, "canister", Vector2(x * TILE + 8, y * TILE + 15), Vector2(12, 9), 13.0)
				"B":
					var b := Barrel.new()
					b.position = Vector2(x * TILE + 8, y * TILE + 14)
					entities.add_child(b)
					spawned.append(b)
				"t":
					toxic[cell] = tex_splats[(x * 7 + y * 3) % tex_splats.size()]
				"z":
					electric.append(cell)
				"v":
					decor.append([cell, tex_vent if (x + y) % 2 == 0 else tex_grate])
	queue_redraw()


## Solid prop standing on the floor: `foot` = bottom-centre, sprite scaled to `width`.
func _add_solid(entities: Node2D, prop: String, foot: Vector2, box: Vector2, width: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = foot
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = box
	cs.shape = shape
	cs.position = Vector2(0, -box.y * 0.5)
	body.add_child(cs)
	var shadow := Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(width / 11.0, 1.2)
	shadow.position = Vector2(0, -1)
	body.add_child(shadow)
	var spr := Sprite2D.new()
	spr.texture = load(ART + "prop_%s.png" % prop)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var s := width / spr.texture.get_width()
	spr.scale = Vector2(s, s)
	spr.centered = false
	spr.offset = Vector2(-spr.texture.get_width() * 0.5, -spr.texture.get_height())
	body.add_child(spr)
	entities.add_child(body)
	spawned.append(body)


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + 8, c.y * TILE + 8)


func spawn_points(n: int, avoid: Vector2) -> Array[Vector2]:
	var free: Array[Vector2] = []
	for y in range(1, 9):
		var row: String = grid[y]
		for x in COLS:
			if row[x] == "." or row[x] == "v":
				var p := cell_center(Vector2i(x, y))
				if p.distance_to(avoid) > 80.0:
					free.append(p)
	free.shuffle()
	var out: Array[Vector2] = []
	for i in n:
		out.append(free[i % free.size()] + Vector2(randf_range(-3, 3), randf_range(-3, 3)))
	return out


func open_door() -> void:
	door_open = true
	door_shape.set_deferred("disabled", true)


func is_toxic(p: Vector2) -> bool:
	return toxic.has(cell_at(p))


func is_live_electric(p: Vector2) -> bool:
	return elec_state == 2 and electric.has(cell_at(p))


func _physics_process(delta: float) -> void:
	anim_t += delta
	var w := Game.world
	if not electric.is_empty():
		elec_t += delta
		match elec_state:
			0:
				if elec_t > 2.2:
					elec_state = 1
					elec_t = 0.0
			1:
				if elec_t > 0.7:
					elec_state = 2
					elec_t = 0.0
					tick = 1.0
					Sfx.play("zap", 0.1, -6.0)
					for c in electric:
						w.burst(cell_center(c), Color("73eff7"), 4, 50.0, 0.3, 1.5)
			2:
				if elec_t > 0.6:
					elec_state = 0
					elec_t = 0.0
	if door_open:
		door_k = minf(1.0, door_k + delta * 3.0)
	if not toxic.is_empty() and randf() < delta * 5.0:
		var keys := toxic.keys()
		var c: Vector2i = keys[randi() % keys.size()]
		w.burst(cell_center(c) + Vector2(randf_range(-5, 5), randf_range(-4, 4)), Color("a7f070"), 1, 6.0, 0.7, 2.0, -20.0)
	tick += delta
	if tick >= 0.3:
		tick = 0.0
		_hazard_tick()
	queue_redraw()


func _hazard_tick() -> void:
	var w := Game.world
	var p := w.player
	if not p.dead:
		if is_toxic(p.global_position):
			p.take_damage(6.0, Vector2.INF, true)
		if is_live_electric(p.global_position):
			p.take_damage(12.0, Vector2.INF, true)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null or not e.targetable:
			continue
		if is_toxic(e.global_position):
			e.take_damage(6.0, Vector2.ZERO)
			w.burst(e.global_position, Color("a7f070"), 3, 25.0, 0.3, 1.5, -30.0)
		elif is_live_electric(e.global_position):
			e.take_damage(18.0, Vector2.ZERO)
			e.stun(0.4)
			var l := Lightning.new()
			l.a = e.global_position + Vector2(0, 2)
			l.b = e.hit_center()
			w.effects.add_child(l)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(-300, -400, 760, 1100), Color("0a0d1a"))
	draw_texture_rect(bg, art_rect(), false)
	if grid.is_empty():
		return
	# floor decor (vents / grates)
	for d: Array in decor:
		var c: Vector2i = d[0]
		var tex: Texture2D = d[1]
		var r := Rect2(Vector2(c * TILE) + Vector2(1, 2), Vector2(14, 14.0 * tex.get_height() / tex.get_width()))
		draw_texture_rect(tex, r, false)
	# toxic slime: glowing painted splats
	for c: Vector2i in toxic:
		var tex: Texture2D = toxic[c]
		var glow := 0.85 + sin(anim_t * 3.0 + c.x + c.y) * 0.15
		var sz := Vector2(22, 22.0 * tex.get_height() / tex.get_width())
		var pos := cell_center(c) - sz * 0.5
		draw_circle(cell_center(c), 9.0, Color(0.45, 0.95, 0.25, 0.18 * glow))
		draw_texture_rect(tex, Rect2(pos, sz), false, Color(glow + 0.2, glow + 0.2, glow))
	# electric floor: grate + warning frame + arcs when live
	for c in electric:
		var pos := Vector2(c * TILE)
		draw_texture_rect(tex_grate, Rect2(pos + Vector2(1, 3), Vector2(14, 11)), false)
		var warn := elec_state == 1 and fmod(elec_t, 0.2) < 0.1
		var col := Color("ffcd75") if warn or elec_state == 2 else Color(1.0, 0.8, 0.3, 0.45)
		draw_rect(Rect2(pos + Vector2(0.5, 0.5), Vector2(15, 15)), col, false, 1.0)
		if elec_state == 2:
			draw_rect(Rect2(pos, Vector2(16, 16)), Color(0.45, 0.94, 0.97, 0.3))
			for i in 2:
				var pts := PackedVector2Array()
				var a := pos + Vector2(randf_range(0, 16), 0)
				for j in 5:
					pts.append(a + Vector2(randf_range(-3, 3), j * 4.0))
				draw_polyline(pts, Color(1, 1, 1, 0.9), 1.0)
	_draw_door()


func _draw_door() -> void:
	# painted art shows the door open (green chevrons); slide panels over it when closed
	var r := DOOR_RECT
	var half := r.size.x * 0.5
	var pw := half * (1.0 - door_k)
	if pw > 0.3:
		var panel := Color("3b4256")
		var edge := Color("1a1d29")
		for side in 2:
			var x := r.position.x if side == 0 else r.end.x - pw
			var pr := Rect2(x, r.position.y, pw, r.size.y)
			draw_rect(pr, panel)
			draw_rect(Rect2(pr.position, Vector2(pw, 1.5)), Color("5b647c"))
			draw_rect(pr, edge, false, 0.6)
			# hazard stripes along the seam
			var sx := pr.end.x - 3.0 if side == 0 else pr.position.x
			var y := r.position.y + 1.0
			while y < r.end.y - 2.0:
				draw_rect(Rect2(sx, y, 3.0, 2.0), Color("e0a82e"))
				y += 4.0
			for k in 3:
				draw_rect(Rect2(pr.position.x + 2.0, r.position.y + 7.0 + k * 7.0, maxf(0.0, pw - 6.0), 0.8), Color("2a2f3f"))
	var light := Color("a7f070") if door_open else Color("ff4d5a")
	if not door_open and fmod(anim_t, 1.0) < 0.5:
		light = light.darkened(0.45)
	draw_rect(DOOR_LIGHT, light)
