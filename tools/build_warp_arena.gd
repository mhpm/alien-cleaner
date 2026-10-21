extends "res://tools/arena_map_builder.gd"
## Builds world 7's map ONCE as an Arena Editor scene:
##   scenes/arenas/arena_world_07_level_01.tscn  "Warp Nexus"
## The warp-gate station (tools/arena_map_builder.gd does the maze): the user's WARP NEXUS
## kit (assets/decor/warp_nexus/, python tools/make_warp_kit.py) - striped runs butting
## post to post and glowing columns on a 128 x 128 lattice (roomy corridors, still a
## maze), the floor world 7 already had - dressed with the great WARP GATE in the biggest
## hall, tanks, dish, reactor tower and command desk in the hall corners, blast doors,
## lockers and crates along the walls, barrier walls as cover in the big halls, asteroid
## rocks drifting in the pits that open onto space, chevrons and hatches on the floor, and
## the 5 WARP CELLS in the farthest corners (dead ends first). World 7 plays it as its map
## (WorldData "explore": {"map": ...}); its waves and boss stay in WorldData. The scene
## belongs to the user once made: it refuses to overwrite it.
##   godot --headless --path . res://tools/build_warp_arena.tscn [-- --force] [-- --seed=N] [-- --out=<res path>]

const WARP_CELLS := 5
const CELL_GAP := 420.0  # warp cells this far apart at least
const GATE := "gate/warp_gate.png"
const ROCKS := ["rocks/rock_small.png", "rocks/rock_round.png", "rocks/rock_long.png", "rocks/pebble.png",
	"rocks/rock_a.png", "rocks/pebble_b.png", "rocks/rock_b.png", "rocks/pebble_c.png"]


func _configure() -> void:
	path = "res://scenes/arenas/arena_world_07_level_01.tscn"
	tag = "WARP"
	kit_dir = "res://assets/decor/warp_nexus/"
	layout = {"set": "w5", "maze": 0.4, "mazes": 3}  # w5: corner machinery spots all round the halls
	cells = [16, 13]
	seed_value = 7070
	mod_w = 128.0  # one run = one cell side (4 floor tiles)
	mod_h = 128.0  # one column = one cell down: corridors ~83 / ~89 clear
	mods_x = 1
	mods_y = 1
	floor_src = 15  # terrain.json "Warp floor" (the floor world 7 already had)
	floor_cols = 6
	floor_tiles = 18
	plain = 0.0  # every tile of that floor is a plain one
	runs = ["walls/run_0.png", "walls/run_1.png", "walls/run_2.png", "walls/run_3.png", "walls/run_4.png",
		"walls/run_5.png", "walls/run_6.png"]
	run_weights = [3.0, 2.0, 2.0, 2.0, 2.0, 1.5, 1.5]
	columns = []
	for n in 14:
		columns.append("walls/column_%d.png" % n)
	corner_big = ["tanks/core_tank.png", "tanks/twin_tanks.png", "tanks/specimen_tank.png", "machines/dish.png",
		"machines/reactor_tower.png", "machines/command_desk.png", "machines/generator_block.png",
		"machines/teleporter.png", "storage/shelves.png", "storage/crate_stack.png", "machines/antenna_tower.png"]
	along_wall = ["machines/blast_door.png", "machines/door_tall.png", "machines/door_plain.png",
		"machines/server_rack.png", "machines/server_cubes.png", "machines/machine_block.png", "machines/locker_cap.png",
		"storage/cabinet.png", "storage/hazard_locker.png", "storage/locker_small.png", "storage/hazard_crate.png",
		"storage/battery_pack.png", "storage/olive_box.png", "storage/cube_glow.png", "tanks/glass_tank.png",
		"tanks/canister_tank.png", "tanks/twin_canister.png", "tanks/small_tank.png", "pipes/pipe_mid.png",
		"pipes/pipe_bar.png", "lights/beacon_pod.png"]
	along_side = ["storage/cabinet.png", "storage/hazard_locker.png", "storage/locker_small.png",
		"storage/hazard_crate.png", "storage/battery_pack.png", "storage/olive_box.png", "storage/cube_glow.png",
		"storage/canisters.png", "tanks/glass_tank.png", "tanks/canister_tank.png", "tanks/small_tank.png",
		"tanks/slim_tank.png", "machines/server_cubes.png", "machines/locker_cap.png", "lights/beacon_pod.png",
		"storage/mini_cell.png", "storage/post_box.png"]
	pots = ["storage/mini_cell.png", "storage/mini_cell_b.png", "storage/post_box.png", "storage/post_box_b.png",
		"storage/canisters.png", "storage/cube_blue.png", "storage/cube_light.png", "tanks/tiny_tank.png",
		"tanks/slim_tank.png", "tanks/thin_tank.png"]
	centrepieces = ["gate/warp_pad.png", "gate/warp_pad_round.png", "machines/reactor_tower.png",
		"tanks/twin_tanks.png", "machines/antenna_tower.png", "storage/forklift.png", "pipes/pipe_rack.png"]
	islands = ["barriers/mini_half.png", "barriers/mini_grate.png", "barriers/mini_plain.png", "barriers/mini_fan.png",
		"barriers/mini_light.png", "barriers/mini_screen.png", "barriers/mini_vent.png", "barriers/mini_grill.png",
		"barriers/mini_speaker.png", "barriers/barrier_panel.png", "barriers/barrier_fan_short.png",
		"barriers/barrier_monitor.png", "storage/olive_crate.png", "storage/olive_case.png", "pipes/pipe_long.png",
		"pipes/pipe_short.png"]
	floor_bits = ["floor/chevron_left.png", "floor/chevron_right.png", "floor/hatch_wheel.png", "floor/hatch_wheel_b.png",
		"floor/grate.png", "floor/grate_b.png", "floor/light_panel.png", "floor/plate_glass.png", "floor/plate_crack.png",
		"floor/plate_broken.png"]
	lamps = ["lights/tube_light.png"]


func _data() -> ArenaData:
	var d := super._data()
	d.arena_id = "w07_a01"
	d.display_name = "Warp Nexus"
	d.description = "World 7's map: the station that holds the warp gate. Take the 5 warp cells in the far corners to charge the gate. Played by world 7 (WorldData 'explore': {'map': ...}): its waves and the WARP OVERSEER come from WorldData; the waves here stay off."
	d.world_id = 7
	d.level_id = 1
	d.environment = "Space Station"
	d.difficulty = ArenaData.Difficulty.HARD
	return d


## The great warp gate in the middle of the biggest hall (not the start), before the
## corners and the dressing (it keeps them off its spot).
func _corners() -> void:
	var best := -1
	var best_area := 0
	for li in fm.leaves.size():
		var leaf: Dictionary = fm.leaves[li]
		var r: Rect2i = leaf.rect
		if str(leaf.type) in ["solid", "maze", "corridor"] or li == fm.start_leaf or r.size.x < 3 or r.size.y < 3:
			continue
		if r.size.x * r.size.y > best_area:
			best_area = r.size.x * r.size.y
			best = li
	if best >= 0:
		var at := leaf_rect(best).get_center() + Vector2(0, _height(GATE) * 0.5)
		_piece(GATE, at)
		for k in 3:  # keep the dressing off the gate and its steps
			busy.append(at + Vector2((k - 1) * 50.0, -30.0))
		busy.append(at + Vector2(0, 30))
		print("WARP: the warp gate stands in hall %d (%dx%d cells)" % [best, fm.leaves[best].rect.size.x, fm.leaves[best].rect.size.y])
	super._corners()


## Spawn, chests and survivors, then the warp cells (before the dressing keeps off them).
func _gameplay() -> void:
	super._gameplay()
	_warp_cells()


## Asteroid rocks drifting in the pits that open onto space.
func _extra() -> void:
	var rocks := 0
	for j in fm.h:
		for i in fm.w:
			if fm.pit[j * fm.w + i] != 1:
				continue
			var cr := cell_rect(Vector2i(i, j))
			for k in rng.randi_range(1, 3):
				var p := cr.position + Vector2(rng.randf_range(20, cw - 20), rng.randf_range(30, ch - 10))
				_piece(_pick(ROCKS), p, rng.randf() < 0.5)
				rocks += 1
	print("WARP: %d rocks in the pits" % rocks)


## The 5 warp cells in the walkable cells farthest (walking) from the start, maze cells
## first, spread out, away from the other gameplay spots (like Explore._place_warp_cells).
func _warp_cells() -> void:
	var far := fm.distances(fm.start_cell())
	var cand: Array = []
	for c: Vector2i in far:
		var li := fm.region[fm.idx(c)]
		var in_maze := li >= 0 and str(fm.leaves[li].type) == "maze"
		cand.append([int(far[c]) + (6 if in_maze else 0), c])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var taken: Array[Vector2] = []
	for it: Array in cand:
		if taken.size() >= WARP_CELLS:
			break
		var c: Vector2i = it[1]
		if fm.machines.any(func(m: Array) -> bool: return m[0] == c):
			continue
		var p := cell_rect(c).get_center() + Vector2(0, 12)
		if taken.any(func(q: Vector2) -> bool: return q.distance_to(p) < CELL_GAP) or not _clear_of_busy(p):
			continue
		var wc := ArenaWarpCell.new()
		wc.name = "WarpCell%d" % (taken.size() + 1)
		wc.object_id = "warp_cell_%d" % (taken.size() + 1)
		_place(wc, p)
		taken.append(p)
	print("WARP: %d warp cells" % taken.size())
