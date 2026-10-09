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
## middle of each room), "cores": n (world 5: n overheating ReactorCores, one in the
## middle of n rooms instead of the RoomKit pieces; venting them all = forge_cooled),
## "build": "forge" (world 5: no room paintings, ForgeMap builds halls, corridors, mazes
## and pits wall by wall from the forge kit on a "cells": [w, h] lattice; `rooms` are its
## areas and the aliens get a flow field to walk around the walls, flow_dir)}.

const SEAM := 6.0  # black gap between two rooms (world units)
const COOLED_HP := 0.75  # bosses' health once every reactor core is vented

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
var cores: Array[ReactorCore] = []
var core_cells := {}  # Vector2i -> true: rooms that get a reactor core
var vented := 0
var vats: Array[Enemy] = []  # world 6: SpecimenVats ("vats": n)
var vats_broken := 0
var forge: ForgeMap  # "build": "forge" / "kit"
var props: Array = []  # [node, solid rect]: furniture and cores (cleared with the ring)
var ring := Vector3.ZERO  # final fight arena cleared on a painted map: x, y, radius
var nav_cell := -1  # the astronaut's cell the flow field leads to
var flow_to := PackedVector2Array()


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
	if str(cfg.get("build", "")) in ["forge", "kit"]:
		return _setup_forge(cfg)
	var rs := LabRoomData.ROOM
	cell = rs + Vector2(SEAM, SEAM)
	zero_cell = Vector2i(int(cols / 2.0), 0) if has_zero else Vector2i(-1, -1)
	start_cell = Vector2i(int(cols / 2.0), rows - 1)
	_resize_arena(Vector2(cols * rs.x + (cols - 1) * SEAM, rows * rs.y + (rows - 1) * SEAM))
	_link_rooms(cfg.get("maze", -1.0))
	interior = str(cfg.get("interior", ""))
	_pick_core_rooms(int(cfg.get("cores", 0)))
	_lay_rooms()
	_build_collision()
	w.room.blockers = walls.duplicate()
	_hide_chests(int(cfg.get("chests", 8)), int(cfg.get("survivors", 5)))
	_build_counter()
	return self


# ---------------------------------------------------------------- building

## World 5: the map is a ForgeMap (no room grid); its areas stand in for the rooms.
func _setup_forge(cfg: Dictionary) -> Explore:
	set_id = str(cfg.get("set", "w5"))
	has_zero = false
	zero_cell = Vector2i(-1, -1)
	interior = str(cfg.get("interior", ""))
	forge = ForgeMap.new().generate(cfg, rng)

	_resize_arena(forge.size())
	start_cell = Vector2i(forge.start_leaf, 0)
	start = forge.cell_rect(forge.start_cell()).get_center()
	for li in forge.leaves.size():
		if forge.leaves[li].type == "solid":
			continue
		rooms.append([forge.leaf_rect(li), {"spots": forge.spots(li)}, Vector2i(li, 0)])

	walls = forge.solids()
	var n_cores := int(cfg.get("cores", 0))
	for i in forge.core_leaves.size():
		var r := forge.leaf_rect(forge.core_leaves[i])
		if i < n_cores:
			_place_core(r)
		else:
			_place_vat(r)
	_place_eggs(int(cfg.get("eggs", 0)))
	for f: Array in (forge.furnish if interior != "" else []):
		if str(f[1]) == "pattern":
			_furnish(forge.leaf_rect(int(f[0])), true)
		else:
			_furnish_one(forge.leaf_rect(int(f[0])))

	_build_collision()
	world.room.blockers = walls.duplicate()
	forge.make_nodes(self)

	_hide_chests(int(cfg.get("chests", 8)), int(cfg.get("survivors", 5)))
	_build_counter()
	return self


## World 6: a specimen vat in the middle of hall r (an anchored Enemy: shoot it down).
func _place_vat(r: Rect2) -> void:
	var at := r.get_center() + Vector2(0, 24)
	var v := world.spawn_enemy("specimen_vat", at, Game.enemy_mult(), 1.0, false, true)
	if v != null:
		vats.append(v)


## World 6: n egg clusters spread over the map (open cells, away from the start, the
## objectives and each other); they hatch octolings when the astronaut walks by.
func _place_eggs(n: int) -> void:
	if n <= 0:
		return
	Art.warm(Art.sets_for(["egg_cluster", "octoling"]))
	var cells: Array[Vector2i] = []
	for j in forge.h:
		for i in forge.w:
			var c := Vector2i(i, j)
			if forge.walkable(c) and not forge.machines.any(func(m: Array) -> bool: return m[0] == c):
				cells.append(c)
	cells.shuffle()
	var taken: Array[Vector2] = [start]
	for li in forge.core_leaves:
		taken.append(forge.leaf_rect(li).get_center())
	for c in cells:
		if n <= 0:
			break
		var p := forge.cell_rect(c).get_center() + Vector2(rng.randf_range(-24, 24), rng.randf_range(-16, 20))
		var ok := p.distance_to(start) > 260.0
		for q in taken:
			if q.distance_to(p) < 170.0:
				ok = false
		if not ok or not world.room.is_open(p, 18.0):
			continue
		taken.append(p)
		world.spawn_enemy("egg_cluster", p, Game.enemy_mult(), 1.0, false, true)
		n -= 1


## One or two kit pieces in the middle of a small hall.
func _furnish_one(r: Rect2) -> void:
	var c := r.get_center() + Vector2(0, 20)
	var n := 2 if r.size.x >= 300.0 and rng.randf() < 0.5 else 1
	for i in n:
		var k: int = ForgeMap.SMALL_FURNITURE[rng.randi() % ForgeMap.SMALL_FURNITURE.size()]
		var at := c + Vector2((i - (n - 1) * 0.5) * 70.0, 0)
		_kit_piece(k, at, rng.randf() < 0.5)


func _physics_process(_delta: float) -> void:
	if forge == null or world.player == null:
		return
	var c := forge.cell_at(world.player.global_position)
	if c >= 0 and c != nav_cell and forge.blocked[c] == 0:
		nav_cell = c
		flow_to = forge.flow(c)


## Where an alien at `p` should head to reach the astronaut around the walls (ZERO: go
## straight, it is in the astronaut's cell or there is no map).
func flow_dir(p: Vector2) -> Vector2:
	if flow_to.is_empty():
		return Vector2.ZERO
	var c := forge.cell_at(p)
	if c < 0 or c == nav_cell:
		return Vector2.ZERO
	var t := flow_to[c]
	if t == Vector2.ZERO:
		return Vector2.ZERO
	return (t - p).normalized()

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
			if core_cells.has(c):
				_place_core(r)
			elif interior != "" and c != start_cell:
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


## Rooms for the reactor cores: spread out (never two side by side, if the grid allows
## it), never the start room, its neighbours nor ZONE ZERO.
func _pick_core_rooms(n: int) -> void:
	var cand: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if c != start_cell and c != zero_cell and c.distance_to(start_cell) > 1.0:
				cand.append(c)
	var best := {}
	for attempt in 30:  # a few shuffles, keep the one that fits the most
		cand.shuffle()
		var got := {}
		for c in cand:
			if got.size() >= n:
				break
			var close := false
			for o: Vector2i in got:
				if absi(o.x - c.x) + absi(o.y - c.y) < 2:
					close = true
			if not close:
				got[c] = true
		if got.size() > best.size():
			best = got
		if best.size() >= n:
			break
	for c in cand:  # still short: fill up with any room left
		if best.size() >= n:
			break
		best[c] = true
	core_cells = best


func _place_core(r: Rect2) -> void:
	var at := r.get_center() + Vector2(0, 5)
	var core := ReactorCore.new()
	core.position = at
	world.entities.add_child(core)
	world.room.spawned.append(core)
	cores.append(core)
	walls.append(ReactorCore.foot(at))
	props.append([core, ReactorCore.foot(at)])


## A RoomKit pattern in the middle of room `r` (sometimes mirrored, sometimes empty).
func _furnish(r: Rect2, always := false) -> void:
	if not always and rng.randf() < 0.15:
		return
	var pats := RoomKit.patterns(interior)
	var names := pats.keys()
	var pat: Array = pats[names[rng.randi() % names.size()]]
	var flip := -1.0 if rng.randf() < 0.5 else 1.0
	var c := r.get_center()
	for it: Array in pat:
		var k := int(it[0])
		_kit_piece(k, c + Vector2(float(it[1]) * flip, float(it[2])), flip < 0.0)


## Kit piece k standing with its bottom centre at `at` (y-sorted, its foot is solid).
func _kit_piece(k: int, at: Vector2, flip: bool) -> void:
	var s := Sprite2D.new()
	s.texture = RoomKit.tex(k, interior)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.centered = false
	var ts := s.texture.get_size()
	s.offset = Vector2(-ts.x * 0.5, -ts.y)
	s.scale = Vector2.ONE * RoomKit.scale(interior)
	s.flip_h = flip
	s.position = at
	world.entities.add_child(s)
	world.room.spawned.append(s)
	walls.append(RoomKit.foot(k, at, interior))
	props.append([s, RoomKit.foot(k, at, interior)])


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


## The final boss fight (Survival._send_final): nothing solid inside its fence. Walls,
## furniture, machinery, pits and vats within (c, r) go; a ForgeMap rebuilds that part of
## the map as open floor, a painted map gets a disc of floor drawn over it. Reactor cores
## stay counted but are put away.
func clear_ring(c: Vector2, r: float) -> void:
	var hits := func(q: Rect2) -> bool: return (c.clamp(q.position, q.end) - c).length() < r + 6.0
	var gone: Array = []
	for p: Array in props:
		if hits.call(p[1]):
			gone.append(p)
			var n: Node = p[0]
			if is_instance_valid(n):
				if n is ReactorCore:
					(n as ReactorCore).visible = false
					n.process_mode = Node.PROCESS_MODE_DISABLED
				else:
					n.queue_free()
	for p: Array in gone:
		props.erase(p)
	for n in world.enemy_cache:  # vats, egg clusters: anything rooted to the floor
		var e := n as Enemy
		if is_instance_valid(e) and not e.dead and e.anchored and e.global_position.distance_to(c) < r + 45.0:
			vats.erase(e)  # its art reaches past its feet
			e.dead = true
			e.remove_from_group("enemies")
			e.queue_free()
	if forge != null:
		forge.clear_circle(c, r)
		walls = forge.solids()
		for p: Array in props:
			walls.append(p[1])
		nav_cell = -1  # the flow field follows the new floor
	else:
		walls = walls.filter(func(q: Rect2) -> bool: return not hits.call(q))
		ring = Vector3(c.x, c.y, r)
		queue_redraw()
	body.queue_free()
	_build_collision()
	world.room.blockers = walls.duplicate()
	if counter != null:
		_refresh_counter()


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
	if not cores.is_empty():
		counter.text += "    CORES %d/%d" % [vented, cores.size()]
	if not vats.is_empty():
		counter.text += "    VATS %d/%d" % [vats_broken, vats.size()]
	if rescue_panel != null:
		rescue_panel.set_count(rescued)


func chest_opened(_c: SupplyChest) -> void:
	opened += 1
	_refresh_counter()
	if opened == chests.size():
		world.hud.banner("ALL CHESTS FOUND!", Color("ffcd75"), 26, 1.4)


func core_vented(_c: ReactorCore) -> void:
	vented += 1
	_refresh_counter()
	if forge_cooled():
		world.hud.banner("FORGE COOLED! BOSSES -%d%% HP" % roundi((1.0 - COOLED_HP) * 100.0), ReactorCore.COOL, 22, 1.8)
		world.hud.tint_flash(ReactorCore.COOL, 0.3, 0.7)
	else:
		world.hud.banner("CORE STABILIZED %d/%d" % [vented, cores.size()], ReactorCore.COOL, 22, 1.0)


func vat_broken(_v: Enemy) -> void:
	vats_broken += 1
	_refresh_counter()
	if vault_purged():
		world.hud.banner("VAULT PURGED! NO BOSS BACKUP", Color("5fe8ff"), 22, 1.8)
		world.hud.tint_flash(Color("5fe8ff"), 0.3, 0.7)
		Game.add_coins(30 * vats.size())
		world.popup_text(world.player.global_position + Vector2(0, -30), "+%d COINS" % (30 * vats.size()), Color("ffcd75"), 13)
	else:
		world.hud.banner("VAT DESTROYED %d/%d" % [vats_broken, vats.size()], Color("5fe8ff"), 22, 1.0)


## Every specimen vat broken (false on maps without vats): the final boss fights alone.
func vault_purged() -> bool:
	return not vats.is_empty() and vats_broken >= vats.size()


## Every reactor core vented (false on maps without cores).
func forge_cooled() -> bool:
	return not cores.is_empty() and vented >= cores.size()


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
	if forge != null:
		draw_rect(Rect2(Vector2.ZERO, Vector2(world.room.room_w, world.room.room_h)), ForgeMap.VOID)
		return  # ForgeMap's chunks draw the rest
	draw_rect(Rect2(Vector2.ZERO, Vector2(world.room.room_w, world.room.room_h)), Color.BLACK)  # seams
	for l: Array in layers:
		draw_texture_rect(l[0], l[1], false)
	for b in bridges:
		draw_rect(b, LabRoomData.floor_color(set_id))
	for p in plates:
		_draw_shutter(p)
	if ring.z > 0.0:
		_draw_ring_floor()


## Painted maps: the cleared final-fight ring is a disc of floor (the room floor art).
func _draw_ring_floor() -> void:
	var tex: Texture2D = null
	for rm: Array in rooms:
		if rm[2] != zero_cell and not (rm[1].layers as Array).is_empty():
			tex = rm[1].layers[0][0]
			break
	var c := Vector2(ring.x, ring.y)
	var r := ring.z + 8.0
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var n := 48
	for i in n:
		var d := Vector2.from_angle(TAU * i / n)
		pts.append(c + d * r)
		uvs.append(Vector2(0.5, 0.5) + d * Vector2(0.3, 0.2))  # the middle of a room: plain floor
	if tex != null:
		draw_colored_polygon(pts, Color.WHITE, uvs, tex)
	else:
		draw_colored_polygon(pts, LabRoomData.floor_color(set_id))


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
