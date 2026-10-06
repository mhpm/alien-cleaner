extends Node
## Builds the Arena Editor's sample / test arena: scenes/arenas/arena_world_01_level_01.tscn
## "Quarantine Lab" (1 player spawn, bounds, 3 spawners, 2 nests, 2 survivors (one to
## escort), 1 android part, 1 hazard, 1 boss trigger, 3 objectives, 3 waves, 1 exit,
## plus props, decals, a dialogue trigger and an evacuation zone).
##   godot --headless --path . res://tools/build_test_arena.tscn
## Open the result in the editor to see every gizmo, or press PLAY ARENA.

const PATH := "res://scenes/arenas/arena_world_01_level_01.tscn"
const TILESET := "res://scenes/arena/terrain/arena_terrain.tres"
const COLS := 26
const ROWS := 34

var arena: Arena


func _ready() -> void:
	arena = Arena.new()
	arena.name = "Arena"
	arena.data = _data()
	for layer_name: String in Arena.LAYERS:
		_add(arena, _layer(layer_name))
	for layer_name: String in Arena.TERRAIN:
		_add(arena.get_node("Terrain"), _layer(layer_name))
	var bounds := ArenaBounds.new()
	bounds.name = Arena.BOUNDS
	bounds.size = Vector2(COLS, ROWS) * Arena.TILE
	_add(arena, bounds)
	_terrain()
	_objects()
	var packed := PackedScene.new()
	var err := packed.pack(arena)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
		err = ResourceSaver.save(packed, PATH)
	print("TEST ARENA: %s -> %s" % [error_string(err), PATH])
	arena.scene_file_path = PATH  # (so the android check skips this very file)
	add_child(arena)  # validation reads global positions
	var report := ArenaValidator.validate(arena)
	print("TEST ARENA VALIDATION: " + report.summary())
	for i in report.issues:
		print("  ", ["INFO", "WARNING", "ERROR"][i.severity], "  ", i.message)
	arena.free()
	get_tree().quit()


func _data() -> ArenaData:
	var d := ArenaData.new()
	d.arena_id = "w01_a01"
	d.display_name = "Quarantine Lab"
	d.description = "Sample arena of the Arena Editor: every component in one small lab."
	d.world_id = 1
	d.level_id = 1
	d.environment = "Alien Laboratory"
	d.difficulty = ArenaData.Difficulty.MEDIUM
	d.recommended_level = 1
	d.boss_id = "big_red_boss"
	d.start_delay = 3.0
	d.rewards = _reward(150, 0, 0.0)
	# objectives: one MAIN, two SIDE
	var main := ObjectiveData.new()
	main.objective_id = "clear_lab"
	main.type = ObjectiveData.Type.CLEAR_WAVES
	main.title = "Purge the lab (3 waves)"
	var nests := ObjectiveData.new()
	nests.objective_id = "nests"
	nests.type = ObjectiveData.Type.DESTROY
	nests.optional = true
	nests.reward = _reward(60, 0, 0.0)
	var crew := ObjectiveData.new()
	crew.objective_id = "crew"
	crew.type = ObjectiveData.Type.RESCUE
	crew.optional = true
	crew.reward = _reward(40, 0, 0.25)
	d.objectives = [main, nests, crew] as Array[ObjectiveData]
	# waves
	var w1 := WaveData.new()
	w1.wave_id = "w1"
	w1.title = "CONTAINMENT BREACH"
	w1.enemy_count = 14
	w1.reward = _reward(0, 20, 0.0)
	var w2 := WaveData.new()
	w2.wave_id = "w2"
	w2.title = "HOLD THE LINE"
	w2.completion = WaveData.Completion.SURVIVE_TIME
	w2.target = 30.0
	w2.reward = _reward(30, 0, 0.0)
	var w3 := WaveData.new()
	w3.wave_id = "w3"
	w3.title = "THE BIG ONE"
	w3.completion = WaveData.Completion.BOSS_DEFEATED
	w3.elite_count = 2
	w3.reward = _reward(0, 40, 0.0)
	d.waves = [w1, w2, w3] as Array[WaveData]
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
		tl.tile_set = load(TILESET)
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


## Ship plates (a few vents), a lab-tile strip down the middle, a wall border and a
## short wall block that splits the lower half, contamination near the corners.
func _terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var fl := arena.get_layer("Floor") as TileMapLayer
	for y in ROWS:
		for x in COLS:
			var i := rng.randi_range(0, 97) if rng.randf() > 0.02 else rng.randi_range(98, 107)
			fl.set_cell(Vector2i(x, y), 0, Vector2i(i % 12, i / 12))
	for y in range(4, ROWS - 4):
		fl.set_cell(Vector2i(12, y), 1, Vector2i(y % 11, 0))
		fl.set_cell(Vector2i(13, y), 1, Vector2i((y + 5) % 11, 0))
	var walls := arena.get_layer("Walls") as TileMapLayer
	for x in COLS:
		walls.set_cell(Vector2i(x, -1), 3, Vector2i(x % 4, 0))
		walls.set_cell(Vector2i(x, ROWS), 3, Vector2i(x % 4, 1))
	for y in ROWS:
		walls.set_cell(Vector2i(-1, y), 3, Vector2i(y % 4, 2))
		walls.set_cell(Vector2i(COLS, y), 3, Vector2i(y % 4, 3))
	for c: Array in [[-1, -1, 0], [COLS, -1, 1], [-1, ROWS, 2], [COLS, ROWS, 3]]:
		walls.set_cell(Vector2i(c[0], c[1]), 3, Vector2i(c[2], 4))
	for x in range(3, 9):  # a wall block on the left: cover from the horde
		walls.set_cell(Vector2i(x, 21), 3, Vector2i(x % 4, 0))
	var env := arena.get_layer("Environment") as TileMapLayer
	for i in 14:
		var c := Vector2i(rng.randi_range(0, 5) if i % 2 == 0 else rng.randi_range(COLS - 6, COLS - 1), rng.randi_range(0, ROWS - 1))
		var k := rng.randi_range(0, 16)  # the contamination atlas has 17 tiles (6 per row)
		env.set_cell(c, 4, Vector2i(k % 6, k / 6))


func _objects() -> void:
	var gp := arena.get_layer("GameplayObjects")
	var spawn := PlayerSpawn.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(416, 960)
	_add(gp, spawn)
	# spawners: wave 1 (left), wave 2 (right, endless while you hold), wave 3 elites (top)
	_add(arena.get_layer("EnemySpawners"), _spawner("SpawnerWest", Vector2(176, 336), "w1", 7, [["slime", 60.0], ["runner", 40.0]]))
	var east := _spawner("SpawnerEast", Vector2(656, 400), "w2", 0, [["slime", 40.0], ["runner", 30.0], ["spitter", 20.0], ["droid", 10.0]])
	east.max_alive = 14
	east.spawn_interval = 1.4
	_add(arena.get_layer("EnemySpawners"), east)
	var west2 := _spawner("SpawnerWestBreach", Vector2(176, 336), "w1", 7, [["runner", 70.0], ["spitter", 30.0]])
	west2.position = Vector2(656, 240)
	west2.name = "SpawnerNorthEast"
	_add(arena.get_layer("EnemySpawners"), west2)
	var top := _spawner("SpawnerElite", Vector2(416, 176), "w3", 4, [["big_red", 50.0], ["eyeclops", 50.0]])
	top.burst = 1
	top.spawn_interval = 4.0
	_add(arena.get_layer("EnemySpawners"), top)
	# nests
	for n: Array in [["nest_a", Vector2(144, 560)], ["nest_b", Vector2(704, 640)]]:
		var nest := AlienNest.new()
		nest.name = "Nest" + str(n[0]).right(1).to_upper()
		nest.object_id = n[0]
		nest.position = n[1]
		nest.enemies = [SpawnEntry.make("slime", 70.0), SpawnEntry.make("runner", 30.0)] as Array[SpawnEntry]
		nest.destroy_reward = _reward(10, 15, 0.0)
		_add(gp, nest)
	# survivors: one to rescue, one to escort to the evacuation zone
	var sci := ArenaSurvivor.new()
	sci.name = "SurvivorScientist"
	sci.object_id = "crew_scientist"
	sci.crew = 1
	sci.character_name = "DR. VEGA"
	sci.dialogue = PackedStringArray(["IN HERE!", "THE SAMPLES GOT OUT!", "HURRY!"])
	sci.thanks_line = "The specimens broke containment. Find the android core, it can seal the lab!"
	sci.position = Vector2(720, 880)
	sci.reward = _reward(20, 0, 0.0)
	_add(gp, sci)
	var medic := ArenaSurvivor.new()
	medic.name = "SurvivorMedic"
	medic.object_id = "crew_medic"
	medic.crew = 3
	medic.rescue_time = 6.0
	medic.escort_to = "evac"
	medic.thanks_line = "Get me to the evac pad, I'll patch you up!"
	medic.position = Vector2(96, 112)
	_add(gp, medic)
	var evac := ArenaTrigger.new()
	evac.name = "EvacZone"
	evac.object_id = "evac"
	evac.action = ArenaTrigger.Action.REACH_LOCATION
	evac.once = false
	evac.size = Vector2(96, 64)
	evac.position = Vector2(416, 1024)
	_add(arena.get_layer("Triggers"), evac)
	# android part, hidden in the top right corner
	var part := AndroidPart.new()
	part.name = "AndroidCore"
	part.object_id = "core_part"
	part.part = AndroidPart.Part.CORE
	part.part_id = "android_core_w1"
	part.position = Vector2(784, 96)
	part.reward = _reward(50, 0, 0.0)
	_add(gp, part)
	# acid spill across the middle
	var acid := HazardArea.new()
	acid.name = "AcidSpill"
	acid.type = HazardArea.Type.ACID
	acid.size = Vector2(160, 64)
	acid.position = Vector2(416, 624)
	_add(arena.get_layer("Hazards"), acid)
	# boss: walking into the reactor room (top) brings BIG RED
	var boss := BossTrigger.new()
	boss.name = "BossTrigger"
	boss.object_id = "reactor_room"
	boss.boss_id = "big_red_boss"
	boss.trigger_size = Vector2(320, 96)
	boss.position = Vector2(416, 288)
	boss.boss_offset = Vector2(0, -150)
	boss.fence_radius = 220.0
	boss.intro_text = "BIG RED AWAKENS"
	boss.reward = _reward(80, 0, 0.3)
	_add(arena.get_layer("Triggers"), boss)
	var talk := ArenaTrigger.new()
	talk.name = "Briefing"
	talk.action = ArenaTrigger.Action.MESSAGE
	talk.size = Vector2(192, 64)
	talk.position = Vector2(416, 896)
	talk.speaker = "MISSION CONTROL"
	talk.message = "Quarantine Lab is crawling. Purge it, save the crew, then get to the exit up north."
	_add(arena.get_layer("Triggers"), talk)
	var exit := ArenaExit.new()
	exit.name = "Exit"
	exit.position = Vector2(416, 64)
	_add(gp, exit)
	# props and decals
	var props := [["crate", Vector2(96, 448)], ["crate_big", Vector2(128, 448)], ["console", Vector2(560, 112)],
		["canister", Vector2(272, 112)], ["tube", Vector2(720, 304)], ["generator", Vector2(96, 784)],
		["robot", Vector2(304, 832)], ["barrier", Vector2(528, 752)], ["lamp_post", Vector2(48, 1040)], ["lamp_post", Vector2(784, 1040)]]
	for p: Array in props:
		var prop := ArenaProp.new()
		prop.name = str(p[0]).to_pascal_case()
		prop.prop_id = p[0]
		prop.position = p[1]
		_add(arena.get_layer("Obstacles"), prop)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var splats := ["res://assets/room/prop_splat1.png", "res://assets/room/prop_splat2.png", "res://assets/room/prop_splat3.png"]
	for i in 10:
		var d := ArenaDecal.new()
		d.name = "Splat"
		d.texture = load(splats[i % 3])
		d.width = rng.randf_range(16, 30)
		d.flip_h = rng.randf() < 0.5
		d.position = Vector2(rng.randf_range(40, 790), rng.randf_range(40, 1040)).round()
		_add(arena.get_layer("Decorations"), d)


func _spawner(node_name: String, at: Vector2, wave: String, count: int, list: Array) -> EnemySpawner:
	var s := EnemySpawner.new()
	s.name = node_name
	s.position = at
	s.wave_id = wave
	s.spawn_count = count
	s.spawn_radius = 64.0
	var entries: Array[SpawnEntry] = []
	for e: Array in list:
		entries.append(SpawnEntry.make(e[0], e[1]))
	s.enemies = entries
	return s
