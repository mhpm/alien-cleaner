extends Node
## Builds the open-world sample: scenes/arenas/arena_world_09_level_01.tscn
## "Pinewood Outskirts" — back on Earth, a 96x96-tile countryside the aliens invaded:
## crossing roads, forests, a crash site, three nests to burn out, crew to rescue
## (one to escort), a hidden android part, aliens roaming the map, horde waves that
## come to you, a boss at the crash site, the minimap and see-through trees.
##   godot --headless --path . res://tools/build_earth_demo.tscn
## Only the user's Earth art: terrain tiles (tools/earth_terrain_ref.webp) and the decor
## kit assets/decor/earth/ (tools/earth_decor_ref.webp), via tools/make_earth_assets.py.

const PATH := "res://scenes/arenas/arena_world_09_level_01.tscn"
const Terrain := preload("res://addons/aliens_cleaner_arena_editor/editor/terrain_tileset_builder.gd")
const KIT := "res://assets/decor/earth/"
const N := 96  # tiles a side
const T := 32.0
const ROAD_H := 47  # the east-west road (one tile, rails on both sides)
const ROAD_V := 47  # the north-south road
const RIVER := 30  # the river row (crossed by two bridges)
const GRASS := 5
const ROADS := 6
const ROAD_COLS := 5  # the road atlas is 5 tiles wide; the others 8
const GRASS_COLS := 8
# terrains of the "Earth" terrain set (terrain.json): painted like the editor's Terrains tab
const T_WATER := 1
const T_PATH := 2
const T_INFESTED := 3

var arena: Arena
var rng := RandomNumberGenerator.new()
var kit := {}
var taken: Array[Vector2] = []  # placed things (spacing)
var keep_clear: Array[Rect2] = []  # roads and gameplay spots


func _ready() -> void:
	rng.seed = 2026
	Terrain.sync()
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT + "kit.json"))
	for item: Dictionary in cfg.items:
		kit[str(item.file).get_file().get_basename()] = item
	arena = Arena.new()
	arena.name = "Arena"
	arena.data = _data()
	for layer_name: String in Arena.LAYERS:
		_add(arena, _layer(layer_name))
	for layer_name: String in Arena.TERRAIN:
		_add(arena.get_node("Terrain"), _layer(layer_name))
	var bounds := ArenaBounds.new()
	bounds.name = Arena.BOUNDS
	bounds.size = Vector2(N, N) * T
	_add(arena, bounds)
	keep_clear.append(Rect2(0, ROAD_H * T - 24, N * T, T + 48))
	keep_clear.append(Rect2(ROAD_V * T - 24, 0, T + 48, N * T))
	for x in range(0, N, 2):  # the river's meander
		keep_clear.append(Rect2(x * T - 32, _river_y(x) * T - 30, 2 * T + 64, 3 * T + 60))
	keep_clear.append(Rect2(Vector2(20, 54) * T, Vector2(17, 13) * T))  # the lake
	_ground()
	_gameplay()
	_scenery()
	var packed := PackedScene.new()
	var err := packed.pack(arena)
	if err == OK:
		err = ResourceSaver.save(packed, PATH)
	print("EARTH DEMO: %s -> %s (%d objects)" % [error_string(err), PATH, arena.objects().size()])
	arena.scene_file_path = PATH
	add_child(arena)
	var report := ArenaValidator.validate(arena)
	print("EARTH DEMO VALIDATION: " + report.summary())
	for i in report.issues:
		if int(i.severity) > 0:
			print("  ", ["INFO", "WARNING", "ERROR"][i.severity], "  ", i.message)
	get_tree().quit()


func _data() -> ArenaData:
	var d := ArenaData.new()
	d.arena_id = "w09_a01"
	d.display_name = "Pinewood Outskirts"
	d.description = "Open-world sample: Earth countryside under alien invasion."
	d.world_id = 9
	d.level_id = 1
	d.environment = "Earth - Forest"
	d.difficulty = ArenaData.Difficulty.MEDIUM
	d.boss_id = "hive_queen"
	d.start_delay = 4.0
	d.ambient = Color(1.0, 0.96, 0.9)
	d.background = Color(0.1, 0.22, 0.14)
	d.roaming = [SpawnEntry.make("slime", 50.0), SpawnEntry.make("runner", 35.0), SpawnEntry.make("spitter", 15.0)] as Array[SpawnEntry]
	d.roaming_alive = 14
	d.roaming_rate = 0.7
	d.rewards = _reward(200, 0, 0.0)
	var nests := ObjectiveData.new()
	nests.objective_id = "burn_nests"
	nests.type = ObjectiveData.Type.DESTROY
	nests.title = "Burn out the 3 alien nests"
	var boss := ObjectiveData.new()
	boss.objective_id = "queen"
	boss.type = ObjectiveData.Type.BOSS
	boss.title = "Kill the queen at the crash site"
	var crew := ObjectiveData.new()
	crew.objective_id = "crew"
	crew.type = ObjectiveData.Type.RESCUE
	crew.optional = true
	crew.reward = _reward(60, 0, 0.3)
	var part := ObjectiveData.new()
	part.objective_id = "android"
	part.type = ObjectiveData.Type.COLLECT
	part.filter = "android"
	part.title = "Find the android's arm"
	part.optional = true
	part.reward = _reward(80, 0, 0.0)
	d.objectives = [nests, boss, crew, part] as Array[ObjectiveData]
	var w1 := WaveData.new()
	w1.wave_id = "w1"
	w1.title = "FIRST CONTACT"
	w1.spawn_mode = WaveData.SpawnMode.AROUND_PLAYER
	w1.horde = [SpawnEntry.make("slime", 60.0), SpawnEntry.make("runner", 40.0)] as Array[SpawnEntry]
	w1.enemy_count = 24
	w1.horde_rate = 2.0
	w1.reward = _reward(0, 25, 0.0)
	var w2 := WaveData.new()
	w2.wave_id = "w2"
	w2.title = "THE SWARM"
	w2.delay_before = 20.0
	w2.spawn_mode = WaveData.SpawnMode.AROUND_PLAYER
	w2.horde = [SpawnEntry.make("slime", 40.0), SpawnEntry.make("runner", 30.0), SpawnEntry.make("splitter", 15.0), SpawnEntry.make("spitter", 15.0)] as Array[SpawnEntry]
	w2.horde_rate = 3.0
	w2.horde_alive = 40
	w2.completion = WaveData.Completion.SURVIVE_TIME
	w2.target = 40.0
	w2.reward = _reward(40, 30, 0.2)
	d.waves = [w1, w2] as Array[WaveData]
	return d


func _reward(coins: int, xp: int, heal: float) -> RewardData:
	var r := RewardData.new()
	r.coins = coins
	r.xp = xp
	r.heal = heal
	return r


func _layer(layer_name: String) -> Node:
	if layer_name in Arena.TERRAIN or layer_name == "Walls":
		var tl := TileMapLayer.new()
		tl.name = layer_name
		tl.tile_set = load(Terrain.tileset_path())
		tl.scale = Vector2.ONE * Arena.TERRAIN_SCALE
		tl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		return tl
	var n := Node2D.new()
	n.name = layer_name
	n.y_sort_enabled = bool(Arena.LAYERS.get(layer_name, {}).get("y_sort", false))
	return n


func _add(parent: Node, node: Node) -> Node:
	parent.add_child(node)
	node.owner = arena
	return node


func _tile(layer: TileMapLayer, c: Vector2i, src: int, i: int, cols: int) -> void:
	layer.set_cell(c, src, Vector2i(i % cols, i / cols))


## River row at column x (a lazy meander).
func _river_y(x: float) -> float:
	return RIVER + sin(x * 0.11) * 2.2 + sin(x * 0.037 + 1.0) * 1.5


## Grass (rare rocky / flowery tiles), then terrains painted with Godot's own terrain
## connect, exactly like the editor's Terrains tab: a meandering river, a lake, dirt trails
## to the nests and the infested ground round the crash site. Roads go on top.
func _ground() -> void:
	var fl := arena.get_layer("Floor") as TileMapLayer
	var weights := [1.0, 1.0, 0.5, 0.6, 0.4, 0.5, 0.06, 0.05, 0.04]
	for y in N:
		for x in N:
			_tile(fl, Vector2i(x, y), GRASS, rng.rand_weighted(PackedFloat32Array(weights)), GRASS_COLS)
	var water: Array[Vector2i] = []
	for x in range(-1, N + 1):
		var cy := roundi(_river_y(x))
		for dy in range(0, 3):
			water.append(Vector2i(x, cy + dy))
	for y in range(-6, 7):
		for x in range(-8, 9):
			if Vector2(x / 8.0, y / 6.0).length() <= 1.0 + sin(x * 1.3 + y) * 0.08:
				water.append(Vector2i(28 + x, 60 + y))
	fl.set_cells_terrain_connect(water, 0, T_WATER)
	var path: Array[Vector2i] = []
	var trail := func(a: Vector2, b: Vector2) -> void:
		var steps := int(a.distance_to(b) * 2.0)
		for k in steps + 1:
			var p := a.lerp(b, float(k) / steps)
			p += Vector2(sin(k * 0.21), cos(k * 0.17)) * 1.4 * sin(PI * k / steps)
			for d: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				path.append(Vector2i(p.floor()) + d)
	trail.call(Vector2(ROAD_V - 1, 72), Vector2(19, 72))
	trail.call(Vector2(ROAD_V + 1, 64), Vector2(79, 66))
	trail.call(Vector2(ROAD_V - 1, 20), Vector2(17, 21))
	fl.set_cells_terrain_connect(path, 0, T_PATH)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	var infested: Array[Vector2i] = []
	for y in range(0, 34):
		for x in range(60, N):
			if Vector2(x, y).distance_to(Vector2(76, 16)) < 9.0 + noise.get_noise_2d(x * 4.0, y * 4.0) * 4.0:
				infested.append(Vector2i(x, y))
	fl.set_cells_terrain_connect(infested, 0, T_INFESTED)
	# roads over everything (the river stays under the bridge on the road)
	for x in N:
		_tile(fl, Vector2i(x, ROAD_H), ROADS, 6, ROAD_COLS)
	var under_bridge := range(roundi(_river_y(ROAD_V)) - 1, roundi(_river_y(ROAD_V)) + 4)
	for y in N:
		if not y in under_bridge:
			_tile(fl, Vector2i(ROAD_V, y), ROADS, 0 if rng.randf() > 0.2 else 1, ROAD_COLS)
	_tile(fl, Vector2i(ROAD_V, ROAD_H), ROADS, 5, ROAD_COLS)


func _cell(c: Vector2) -> Vector2:
	return c * T


func _clear(p: Vector2, r: float) -> void:
	keep_clear.append(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0))


func _gameplay() -> void:
	var gp := arena.get_layer("GameplayObjects")
	var start := _cell(Vector2(ROAD_V + 0.5, 86))
	var spawn := PlayerSpawn.new()
	spawn.name = "PlayerSpawn"
	spawn.position = start
	_add(gp, spawn)
	_clear(start, 90.0)
	var talk := ArenaTrigger.new()
	talk.name = "Briefing"
	talk.action = ArenaTrigger.Action.MESSAGE
	talk.size = Vector2(160, 96)
	talk.position = start + Vector2(0, -40)
	talk.speaker = "COMMAND"
	talk.message = "Welcome home, cleaner. They landed in Pinewood. Burn their nests, find the crew, then kill the queen at the crash site, north-east."
	_add(arena.get_layer("Triggers"), talk)
	# three nests, each with a spawner that wakes up when you get close
	var nest_spots := [Vector2(16, 20), Vector2(18, 72), Vector2(80, 66)]
	for i in nest_spots.size():
		var p: Vector2 = _cell(nest_spots[i])
		var nest := AlienNest.new()
		nest.name = "Nest%d" % (i + 1)
		nest.object_id = "nest_%d" % (i + 1)
		nest.position = p
		nest.health = 420.0
		nest.enemies = [SpawnEntry.make("slime", 60.0), SpawnEntry.make("runner", 40.0)] as Array[SpawnEntry]
		nest.destroy_reward = _reward(15, 20, 0.0)
		_add(gp, nest)
		var guard := EnemySpawner.new()
		guard.name = "NestGuard%d" % (i + 1)
		guard.position = p + Vector2(0, 40)
		guard.wave_id = ""
		guard.auto_start = true
		guard.activation_range = 360.0
		guard.spawn_count = 12
		guard.max_alive = 6
		guard.spawn_interval = 2.0
		guard.enemies = [SpawnEntry.make("spitter", 40.0), SpawnEntry.make("runner", 60.0)] as Array[SpawnEntry]
		_add(arena.get_layer("EnemySpawners"), guard)
		_clear(p, 80.0)
	# crew: two to rescue, one to escort back to the evacuation point by the start
	var crew := [[1, Vector2(30, 40), ""], [7, Vector2(66, 82), ""], [3, Vector2(10, 50), "evac"]]
	for i in crew.size():
		var s := ArenaSurvivor.new()
		s.name = "Survivor%d" % (i + 1)
		s.object_id = "crew_%d" % (i + 1)
		s.crew = crew[i][0]
		s.position = _cell(crew[i][1])
		s.escort_to = crew[i][2]
		s.rescue_time = 7.0
		s.thanks_line = "I hid in the woods for days. Get me out of here!" if crew[i][2] != "" else "They came from the sky... thank you!"
		_add(gp, s)
		_clear(s.position, 60.0)
	var evac := ArenaTrigger.new()
	evac.name = "EvacPoint"
	evac.object_id = "evac"
	evac.action = ArenaTrigger.Action.REACH_LOCATION
	evac.once = false
	evac.size = Vector2(128, 96)
	evac.position = start + Vector2(120, 0)
	_add(arena.get_layer("Triggers"), evac)
	var part := AndroidPart.new()
	part.name = "AndroidLeftArm"
	part.object_id = "android_arm"
	part.part = AndroidPart.Part.LEFT_ARM
	part.part_id = "android_left_arm_w9"
	part.position = _cell(Vector2(8, 8))
	part.reward = _reward(40, 0, 0.0)
	_add(gp, part)
	_clear(part.position, 50.0)
	# crash site: the queen
	var site := _cell(Vector2(76, 18))
	var boss := BossTrigger.new()
	boss.name = "CrashSite"
	boss.object_id = "crash_site"
	boss.boss_id = "hive_queen"
	boss.trigger_size = Vector2(320, 260)
	boss.position = site + Vector2(0, 80)
	boss.boss_offset = Vector2(0, -140)
	boss.fence_radius = 260.0
	boss.intro_text = "THE HIVE QUEEN"
	boss.reward = _reward(120, 0, 0.4)
	_add(arena.get_layer("Triggers"), boss)
	_clear(site, 230.0)
	var exit := ArenaExit.new()
	exit.name = "Extraction"
	exit.position = _cell(Vector2(ROAD_V + 0.5, 4))
	_add(gp, exit)
	_clear(exit.position, 70.0)
	var acid := HazardArea.new()
	acid.name = "ToxicSpill"
	acid.type = HazardArea.Type.ALIEN_SLIME
	acid.size = Vector2(160, 96)
	acid.slow_percentage = 50.0
	acid.position = site + Vector2(-200, 200)
	_add(arena.get_layer("Hazards"), acid)
	var heal := ArenaPickup.new()
	heal.name = "Medkit"
	heal.kind = "medkit"
	heal.position = _cell(Vector2(ROAD_V - 3, ROAD_H - 3))
	_add(arena.get_layer("Pickups"), heal)


func _piece(name: String, p: Vector2, flip := false, size_k := 1.0) -> ArenaScenery:
	var item: Dictionary = kit[name]
	var s := ArenaScenery.new()
	s.name = name.to_pascal_case()
	s.texture = load(KIT + str(item.file))
	s.width = roundf(float(item.width) * size_k)
	s.sway = bool(item.sway)
	s.fade_behind = bool(item.fade)
	s.flat = bool(item.flat)
	s.bridge = bool(item.get("bridge", false))
	s.shadow = bool(item.get("shadow", false))
	if item.solid is Array:
		s.footprint = Vector2(float(item.solid[0]), float(item.solid[1]))
	s.flip_h = flip
	s.position = p.round()
	_add(arena.get_layer("Decorations" if s.flat else "Obstacles"), s)
	return s


func _wet(p: Vector2) -> bool:
	var fl := arena.get_layer("Floor") as TileMapLayer
	var c := fl.local_to_map(fl.to_local(p))
	return fl.get_cell_source_id(c) == 8


func _free_spot(p: Vector2, spacing: float) -> bool:
	if _wet(p):
		return false
	if p.x < 20 or p.y < 30 or p.x > N * T - 20 or p.y > N * T - 8:
		return false
	for r in keep_clear:
		if r.has_point(p):
			return false
	for q in taken:
		if q.distance_squared_to(p) < spacing * spacing:
			return false
	return true


## Scatter `names` around `center` (radius) at `spacing`.
func _patch(names: Array, center: Vector2, radius: float, count: int, spacing: float) -> void:
	var tries := count * 30
	var placed := 0
	while placed < count and tries > 0:
		tries -= 1
		var p := center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius
		if not _free_spot(p, spacing):
			continue
		taken.append(p)
		_piece(names[rng.randi() % names.size()], p, rng.randf() < 0.5, rng.randf_range(0.85, 1.15))
		placed += 1


func _scenery() -> void:
	var trees := ["oak_green", "oak_yellow", "pine_tall_1", "pine_tall_2", "pine_small_1", "pine_small_2",
		"pine_small_3", "oak_small", "pine_berries"]
	# forests: dense patches, autumn and blossom groves, and a treeline round the map
	for i in 14:
		var c := Vector2(rng.randf_range(4, N - 4), rng.randf_range(4, N - 4)) * T
		_patch(trees, c, rng.randf_range(160, 300), rng.randi_range(14, 26), 36.0)
	_patch(["oak_autumn", "oak_yellow", "tree_yellow_small"], _cell(Vector2(20, 88)), 200.0, 14, 40.0)
	_patch(["cherry_blossom", "bush_flowers", "bushes_flowers"], _cell(Vector2(72, 86)), 160.0, 10, 40.0)
	for k in 170:
		var side := k % 4
		var t := rng.randf_range(0.0, N * T)
		var p: Vector2 = [Vector2(t, rng.randf_range(30, 90)), Vector2(t, N * T - rng.randf_range(10, 60)),
			Vector2(rng.randf_range(20, 80), t), Vector2(N * T - rng.randf_range(20, 80), t)][side]
		if _free_spot(p, 32.0):
			taken.append(p)
			_piece(trees[rng.randi() % trees.size()], p, rng.randf() < 0.5, rng.randf_range(0.9, 1.2))
	# undergrowth, rocks and forest floor
	_patch(["bush_flowers", "bushes_flowers", "bush_yellow", "bush_tiny", "bush_flowers_2", "fern"], Vector2(N, N) * T * 0.5, N * T * 0.7, 90, 28.0)
	_patch(["rocks_big_1", "rocks_big_2", "rocks_big_3", "rock_mossy", "rock_small", "rock_mossy_big", "rocks_moss_small"], Vector2(N, N) * T * 0.5, N * T * 0.7, 45, 44.0)
	_patch(["log_mossy_1", "log_mossy_2", "log_mossy_3", "stump_old", "branches", "dead_tree_1", "dead_tree_2"], Vector2(N, N) * T * 0.5, N * T * 0.7, 30, 44.0)
	for i in 240:  # grass tufts and pebbles lie flat
		var p := Vector2(rng.randf_range(20, N * T - 20), rng.randf_range(20, N * T - 20))
		if not keep_clear.slice(0, 2).any(func(r: Rect2) -> bool: return r.has_point(p)) and not _wet(p):
			_piece(["grass_tuft_1", "grass_tuft_2", "grass_tuft_3", "grass_tuft_4", "grass_tuft_5", "grass_tuft_6", "grass_flowers", "pebbles"][rng.randi() % 8], p, rng.randf() < 0.5)
	# bridges over the river: on the road and further west
	for bx: float in [ROAD_V + 0.5, 20.5]:
		var top := roundf(_river_y(floorf(bx))) - 0.6  # water rows + their shores
		var b := _piece("bridge_1", Vector2(bx * T, (top + 4.6) * T), false)
		b.width = roundf(4.6 * T * b.texture.get_width() / b.texture.get_height())  # spans the river
		b.bridge = true
	# cliffs and a waterfall in the north-west
	_piece("waterfall_2", _cell(Vector2(14, 14)))
	for p: Vector2 in [Vector2(6, 22), Vector2(24, 10), Vector2(30, 20)]:
		_piece(["cliff_1", "cliff_3", "cliff_4", "cliff_6"][rng.randi() % 4], _cell(p))
	for i in 6:
		_piece("plateau_%d" % rng.randi_range(1, 9), _cell(Vector2(rng.randf_range(58, 68), rng.randf_range(76, 84))))
	# along the roads: barriers, cones, a roadblock at the crossroads
	_piece("roadblock", _cell(Vector2(ROAD_V + 0.5, ROAD_H - 2)))
	for x in range(6, N, 12):
		if absi(x - ROAD_V) > 3:
			_piece(["barrier_concrete", "barrier_hazard", "barrier_red"][rng.randi() % 3], Vector2(x * T, (ROAD_H + 2) * T + 8))
	for i in 8:
		_piece("traffic_cone", _cell(Vector2(rng.randf_range(30, 64), ROAD_H + 1.6)))
	for x in range(4, N, 15):
		_piece("guardrail_long", Vector2(x * T, (ROAD_H - 1) * T + 4))
	# military camp by the start
	var cp := _cell(Vector2(ROAD_V - 9, 80))
	_piece("camp_tent", cp)
	_piece("camp_awning", cp + Vector2(110, 10))
	_piece("campfire", cp + Vector2(60, 70))
	_piece("cooking_tripod", cp + Vector2(84, 66))
	_piece("radio_tower", cp + Vector2(-70, -10))
	_piece("floodlight", cp + Vector2(180, -20))
	_piece("generator_1", cp + Vector2(190, 50))
	_piece("radio_desk", cp + Vector2(140, 80))
	_piece("satellite_dish", cp + Vector2(-60, 70))
	for k in 4:
		_piece(["crate_wood", "crate_green_1", "crate_green_2", "crate_stack"][k], cp + Vector2(-20 + k * 34, 120))
	for k in 3:
		_piece("sandbags", cp + Vector2(-40 + k * 50, -60))
	_piece("jerrycan_1", cp + Vector2(200, 92))
	_piece("jerrycan_3", cp + Vector2(214, 96))
	# the crash site: the ship, its debris, crystals and infested trees
	var site := _cell(Vector2(76, 16))
	_piece("crashed_ship", site + Vector2(-10, -30))
	_piece("alien_hive_roots", site + Vector2(110, 40))
	for i in 5:
		_piece("ship_debris_%d" % (i + 1), site + Vector2.from_angle(TAU * i / 5.0 + 0.6) * rng.randf_range(130, 190), i % 2 == 0)
	for i in 9:
		_piece("crystals_%d" % (i % 7 + 1), site + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(90, 220), rng.randf() < 0.5)
	for i in 4:
		_piece("infested_tree_%d" % (i % 3 + 1), site + Vector2.from_angle(TAU * i / 4.0 + 0.2) * rng.randf_range(230, 270))
