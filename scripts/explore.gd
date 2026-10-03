class_name Explore
extends Node2D
## Exploration map of a survival stage (WorldData survival "explore": world 1). The arena
## is a grid of rooms (LabRoomData: walls on the edges, a doorway centred on each side)
## laid side by side with a thin black SEAM between them; floor bridges cross the seam at
## the doorways and the doorways on the map's outer edge are shut. ZONE ZERO (one
## painting) goes in the top middle; every other room is a lab put together from pieces
## (empty grown room + 4 corners of furniture, no two rooms alike). Solid areas (walls,
## furniture) collide and are Room.blockers, so aliens never spawn inside them. The run
## starts in the bottom middle room; SupplyChest loot hides on free spots. Child of the
## Room, drawn behind it (show_behind_parent): it replaces the arena floor.
## Config: {"grid": [cols, rows], "chests": n, "set": "lab" (room pieces of
## LabRoomData), "zero": true (ZONE ZERO in the top middle), "dark": true (DarkLights:
## power failing) | "alarms": true (only a few discreet red alarm lights), "maze": k
## (rooms joined by a random spanning tree plus share k of the other doorways: a maze of
## rooms; without it every doorway is open), "interior": "w3" (RoomKit pieces in the
## middle of each room)}.

const SEAM := 6.0  # black gap between two rooms (world units)

var world: GameWorld
var cols := 3
var rows := 3
var cell := Vector2.ZERO  # one room + seam
var rooms: Array = []  # [rect, room (LabRoomData), grid cell]
var layers: Array = []  # [texture, world rect] in draw order
var walls: Array[Rect2] = []  # every solid rect (world)
var plates: Array[Rect2] = []  # shut doorways drawn as plates (ZONE ZERO)
var bridges: Array[Rect2] = []  # floor across the seams at the doorways
var body: StaticBody2D
var chests: Array[SupplyChest] = []
var opened := 0
var start := Vector2.ZERO
var start_cell := Vector2i.ZERO
var zero_cell := Vector2i.ZERO
var counter: Label
var rescue_panel: RescuePanel  # RESCUE n/m with a figure per crew member
var survivors: Array[Survivor] = []
var saved_crew: Array[int] = []  # SurvivorData.CREW indices rescued, in order (pause menu)
var rescued := 0
var rng := RandomNumberGenerator.new()
var set_id := "lab"
var has_zero := true
var links := {}  # "x,y>x,y" of connected neighbour pairs (maze)
var interior := ""


func setup(w: GameWorld, cfg: Dictionary) -> Explore:
	world = w
	var g: Array = cfg.get("grid", [3, 3])
	cols = int(g[0])
	rows = int(g[1])
	rng.randomize()
	set_id = str(cfg.get("set", "lab"))
	has_zero = bool(cfg.get("zero", true))
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rs := LabRoomData.ROOM
	cell = rs + Vector2(SEAM, SEAM)
	zero_cell = Vector2i(int(cols / 2.0), 0) if has_zero else Vector2i(-1, -1)
	start_cell = Vector2i(int(cols / 2.0), rows - 1)
	_resize_arena(Vector2(cols * rs.x + (cols - 1) * SEAM, rows * rs.y + (rows - 1) * SEAM))
	_link_rooms(cfg.get("maze", -1.0))
	interior = str(cfg.get("interior", ""))
	_lay_rooms()
	_build_collision()
	w.room.blockers = walls.duplicate()
	_hide_chests(int(cfg.get("chests", 8)), int(cfg.get("survivors", 5)))
	_build_counter()
	return self


# ---------------------------------------------------------------- building

## The arena becomes exactly the room grid (walls, camera limits, spawns follow it).
func _resize_arena(sz: Vector2) -> void:
	var room := world.room
	room.room_w = sz.x
	room.room_h = sz.y
	room.cols = ceili(sz.x / Room.TILE)
	room.rows = ceili(sz.y / Room.TILE)
	room._build_walls()
	room.arena_bg = null  # a painted arena ("art") gives way to the rooms
	if room.floor_layer != null:
		room.floor_layer.visible = false
	room.queue_redraw()


func _lay_rooms() -> void:
	var mix := LabRoomData.combos(cols * rows, rng, set_id)
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var rm := LabRoomData.zero() if c == zero_cell else LabRoomData.lab(mix[y * cols + x], rng, set_id)
			var r := Rect2(Vector2(c) * cell, LabRoomData.ROOM)
			rooms.append([r, rm, c])
			for l: Array in rm.layers:
				layers.append([l[0], Rect2(r.position + (l[1] as Rect2).position, (l[1] as Rect2).size)])
			for s in rm.solids:
				walls.append(Rect2(r.position + s.position, s.size))
			if c == start_cell:
				start = r.position + (rm.start as Vector2)
			_doors(c, r, rm)
			if interior != "" and c != start_cell:
				_furnish(r)


func _key(a: Vector2i, b: Vector2i) -> String:
	if b.x < a.x or b.y < a.y:
		var t := a
		a = b
		b = t
	return "%d,%d>%d,%d" % [a.x, a.y, b.x, b.y]


func linked(a: Vector2i, b: Vector2i) -> bool:
	return links.has(_key(a, b))


## Which neighbouring rooms share an open doorway. maze < 0: all of them. Otherwise a
## random spanning tree (every room reachable) plus share `maze` of the remaining pairs.
func _link_rooms(maze: Variant) -> void:
	var k := float(maze)
	var pairs: Array = []
	for y in rows:
		for x in cols:
			if x < cols - 1:
				pairs.append([Vector2i(x, y), Vector2i(x + 1, y)])
			if y < rows - 1:
				pairs.append([Vector2i(x, y), Vector2i(x, y + 1)])
	if k < 0.0:
		for p: Array in pairs:
			links[_key(p[0], p[1])] = true
		return
	# randomized DFS from the start room
	var seen := {start_cell: true}
	var stack: Array[Vector2i] = [start_cell]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var next: Array[Vector2i] = []
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < cols and n.y < rows and not seen.has(n):
				next.append(n)
		if next.is_empty():
			stack.pop_back()
			continue
		var n2: Vector2i = next[rng.randi() % next.size()]
		links[_key(c, n2)] = true
		seen[n2] = true
		stack.append(n2)
	for p: Array in pairs:
		if not linked(p[0], p[1]) and rng.randf() < k:
			links[_key(p[0], p[1])] = true


## A RoomKit pattern in the middle of room `r` (sometimes mirrored, sometimes empty).
func _furnish(r: Rect2) -> void:
	if rng.randf() < 0.15:
		return
	var names := RoomKit.PATTERNS.keys()
	var pat: Array = RoomKit.PATTERNS[names[rng.randi() % names.size()]]
	var flip := -1.0 if rng.randf() < 0.5 else 1.0
	var c := r.get_center()
	for it: Array in pat:
		var k := int(it[0])
		var at := c + Vector2(float(it[1]) * flip, float(it[2]))
		var s := Sprite2D.new()
		s.texture = RoomKit.tex(k)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.centered = false
		var ts := s.texture.get_size()
		s.offset = Vector2(-ts.x * 0.5, -ts.y)
		s.scale = Vector2.ONE * RoomKit.SCALE
		s.flip_h = flip < 0.0
		s.position = at
		world.entities.add_child(s)
		world.room.spawned.append(s)
		walls.append(RoomKit.foot(k, at))


## Seams and doorways of room `c`: towards a linked right / bottom neighbour a floor
## bridge crosses the seam (solid elsewhere); every side without a linked neighbour (the
## map's edge, or a maze wall) has its doorway shut.
func _doors(c: Vector2i, r: Rect2, rm: Dictionary) -> void:
	var half := LabRoomData.DOOR_W * 0.5
	var mid := r.get_center()
	if c.x < cols - 1:
		if linked(c, c + Vector2i.RIGHT):
			bridges.append(Rect2(r.end.x - 2.0, mid.y - half, SEAM + 4.0, half * 2.0))
			walls.append(Rect2(r.end.x, r.position.y, SEAM, mid.y - half - r.position.y))
			walls.append(Rect2(r.end.x, mid.y + half, SEAM, r.end.y - mid.y - half + SEAM))
		else:
			walls.append(Rect2(r.end.x, r.position.y, SEAM, r.size.y + SEAM))
	if c.y < rows - 1:
		if linked(c, c + Vector2i.DOWN):
			bridges.append(Rect2(mid.x - half, r.end.y - 2.0, half * 2.0, SEAM + 4.0))
			walls.append(Rect2(r.position.x, r.end.y, mid.x - half - r.position.x, SEAM))
			walls.append(Rect2(mid.x + half, r.end.y, r.end.x - mid.x - half + SEAM, SEAM))
		else:
			walls.append(Rect2(r.position.x, r.end.y, r.size.x + SEAM, SEAM))
	var shut := {
		"top": c.y == 0 or not linked(c, c + Vector2i.UP),
		"bottom": c.y == rows - 1 or not linked(c, c + Vector2i.DOWN),
		"left": c.x == 0 or not linked(c, c + Vector2i.LEFT),
		"right": c.x == cols - 1 or not linked(c, c + Vector2i.RIGHT),
	}
	for side: String in shut:
		if not shut[side]:
			continue
		var o: Rect2 = rm.openings[side]
		walls.append(Rect2(r.position + o.position, o.size))
		if rm.shut == "art" and set_id == "lab":  # only the lab set has shut-door art
			var door := LabRoomData.lab_door(side, set_id)
			layers.append([door[0], Rect2(r.position + (door[1] as Rect2).position, (door[1] as Rect2).size)])
		else:
			plates.append(Rect2(r.position + o.position, o.size))


func _build_collision() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for r in walls:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.get_center()
		body.add_child(cs)


## One chest per room at most (none in the starting room) and survivors hiding on other
## free spots, never two in the same room and never next to a chest.
func _hide_chests(n: int, n_survivors: int) -> void:
	var spots: Array[Vector2] = []
	var spare: Array = []  # [room index, spot] left for survivors
	for i in rooms.size():
		var rm: Array = rooms[i]
		if rm[2] == start_cell:
			continue
		var list: Array = (rm[1] as Dictionary).spots.duplicate()
		if list.is_empty():
			continue
		list.shuffle()
		spots.append((rm[0] as Rect2).position + (list.pop_back() as Vector2))
		for p: Vector2 in list:
			spare.append([i, (rm[0] as Rect2).position + p])
	spots.shuffle()
	var kinds := ChestData.pick(mini(n, spots.size()), rng)
	for i in kinds.size():
		var ch := SupplyChest.new()
		ch.kind = kinds[i]
		ch.position = world.room.open_near(spots[i])
		world.entities.add_child(ch)
		world.room.spawned.append(ch)
		chests.append(ch)
	spare.shuffle()
	var used := {}
	var crew: Array = range(SurvivorData.CREW.size())
	crew.shuffle()
	for s: Array in spare:
		if survivors.size() >= n_survivors:
			break
		if used.has(s[0]):
			continue
		var p := world.room.open_near(s[1])
		var close := false
		for ch in chests:
			if ch.position.distance_to(p) < 70.0:
				close = true
		if close:
			continue
		used[s[0]] = true
		var sv := Survivor.new()
		sv.kind = int(crew[survivors.size() % crew.size()])
		sv.position = p
		world.entities.add_child(sv)
		world.room.spawned.append(sv)
		survivors.append(sv)


func _build_counter() -> void:
	counter = UiTheme.label("", 11, Color("ffcd75"))
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	counter.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	counter.add_theme_constant_override("outline_size", 5)
	counter.position = Vector2(10, 58)
	counter.size = Vector2(200, 14)
	world.hud.safe.add_child(counter)
	if not survivors.is_empty():
		rescue_panel = RescuePanel.new().setup(survivors.size())
		rescue_panel.position = Vector2(6, 73)
		world.hud.safe.add_child(rescue_panel)
	_refresh_counter()


func _refresh_counter() -> void:
	counter.text = "CHESTS %d/%d" % [opened, chests.size()]
	if rescue_panel != null:
		rescue_panel.set_count(rescued)


func chest_opened(_c: SupplyChest) -> void:
	opened += 1
	_refresh_counter()
	if opened == chests.size():
		world.hud.banner("ALL CHESTS FOUND!", Color("ffcd75"), 26, 1.4)


func survivor_saved(s: Survivor) -> void:
	rescued += 1
	saved_crew.append(s.kind)
	_refresh_counter()
	rescue_panel.pop()
	if rescued == survivors.size():
		world.hud.banner("ALL CREW RESCUED!", Color("a7f070"), 26, 1.6)
		Game.add_coins(25 * survivors.size())
		world.popup_text(world.player.global_position + Vector2(0, -30), "+%d COINS" % (25 * survivors.size()), Color("ffcd75"), 13)
	else:
		world.hud.banner("CREW RESCUED %d/%d" % [rescued, survivors.size()], Color("a7f070"), 22, 0.9)


func _exit_tree() -> void:
	if counter != null and is_instance_valid(counter):
		counter.queue_free()
	if rescue_panel != null and is_instance_valid(rescue_panel):
		rescue_panel.queue_free()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(world.room.room_w, world.room.room_h)), Color.BLACK)  # seams
	for l: Array in layers:
		draw_texture_rect(l[0], l[1], false)
	for b in bridges:
		draw_rect(b, LabRoomData.floor_color(set_id))
	for p in plates:
		_draw_shutter(p)


## A shut blast door on the map edge: dark plate with hazard stripes.
func _draw_shutter(r: Rect2) -> void:
	draw_rect(r, Color("1a2030"))
	var long := r.size.x > r.size.y
	var n := maxi(2, int((r.size.x if long else r.size.y) / 6.0))
	for i in n:
		var k := float(i) / n
		var seg: Rect2
		if long:
			seg = Rect2(r.position + Vector2(r.size.x * k, r.size.y * 0.3), Vector2(r.size.x / n, r.size.y * 0.4))
		else:
			seg = Rect2(r.position + Vector2(r.size.x * 0.3, r.size.y * k), Vector2(r.size.x * 0.4, r.size.y / n))
		draw_rect(seg, Color("ffcd3a") if i % 2 == 0 else Color("1a1c2c"))
	draw_rect(r, Color("6f86b8"), false, 1.0)
