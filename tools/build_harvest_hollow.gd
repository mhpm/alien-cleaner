extends Node
## Builds world 10: scenes/arenas/arena_world_10_level_01.tscn "Harvest Hollow" — a farm
## village at dusk, raided by aliens out of the cornfields. Protect the Old Well (and the
## barn) while raiders march on them, find the villagers hiding round the hollow, walk
## little Pip home from the pond, burn the nests in the corn and face what landed in the
## crop circle north of the village. Only art the project already has: the Earth terrain
## and kits (assets/decor/earth/, assets/decor/farm/: corn and buildings).
##   godot --headless --path . res://tools/build_harvest_hollow.tscn

const PATH := "res://scenes/arenas/arena_world_10_level_01.tscn"
const Terrain := preload("res://addons/aliens_cleaner_arena_editor/editor/terrain_tileset_builder.gd")
const KIT := "res://assets/decor/earth/"
const FARM_KIT := "res://assets/decor/farm/"
const FARM := "res://assets/decor/earth/farm/farm_elements/image_%s.png"
const ANIMAL := "res://assets/decor/earth/farm/farm_elements/image_%s.png"
const FOLK := "res://assets/decor/earth/misc/%s.png"
const FARM_K := 0.33  # farm kit: units per art pixel (as in the Farm Invasion arena)
const FOLK_K := 0.5
const N := 80  # tiles a side
const T := 32.0
const GRASS := 5
const GRASS_COLS := 8
const T_WATER := 1
const T_PATH := 2
const T_INFESTED := 3
const CREEK := 66  # the creek row (south of the village)
const ROAD := 39  # the north-south dirt road (2 tiles: 39-40)
const SQUARE := Vector2(40, 44)  # village square: the Old Well
const CIRCLE := Vector2(40, 14)  # the crop circle
const POND := Vector2(16, 22)
const NESTS := [Vector2(68, 33), Vector2(70, 55), Vector2(70, 11)]
# corn kit pieces (assets/decor/farm/corn/corn_NN.png)
const YOUNG := [1, 2, 16, 19, 20, 21, 26, 39]
const MATURE := [3, 4, 13, 14, 15, 17, 23, 29, 30, 31]
const COBS := [5, 6, 7, 18, 22, 25, 27, 28]
const DRY := [10, 11, 12, 32, 33]
const STUMPS := [34, 46]
const DEBRIS := [35, 36, 37, 38, 50]
const WEEDS := [40, 41, 42, 43, 44, 45, 47, 48, 49, 51, 55, 57, 60, 61, 62, 63, 71, 72, 73, 74, 75, 76]
const FLOWERS := [52, 53, 54, 56, 58, 59, 64, 65, 66, 67, 68, 69, 70]

var arena: Arena
var rng := RandomNumberGenerator.new()
var kit := {}
var farm_kit := {}
var taken: Array[Vector2] = []
var keep_clear: Array[Rect2] = []


func _ready() -> void:
	rng.seed = 1010
	Terrain.sync()
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT + "kit.json"))
	for item: Dictionary in cfg.items:
		kit[str(item.file)] = item
	cfg = JSON.parse_string(FileAccess.get_file_as_string(FARM_KIT + "kit.json"))
	for item: Dictionary in cfg.items:
		farm_kit[str(item.file)] = item
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
	keep_clear.append(Rect2((ROAD - 0.5) * T, 0, 3 * T, N * T))  # the main road
	keep_clear.append(Rect2(14 * T, (SQUARE.y - 1) * T, 50 * T, 3 * T))  # east-west lane
	for x in range(0, N, 2):  # the creek
		keep_clear.append(Rect2(x * T - 32, _creek_y(x) * T - 30, 2 * T + 64, 2 * T + 60))
	keep_clear.append(Rect2((POND - Vector2(8, 6)) * T, Vector2(16, 12) * T))
	_clear(_cell(SQUARE), 200.0)
	_ground()
	_gameplay()
	_village()
	_fields()
	_wilds()
	var packed := PackedScene.new()
	var err := packed.pack(arena)
	if err == OK:
		err = ResourceSaver.save(packed, PATH)
	print("HARVEST HOLLOW: %s -> %s (%d objects)" % [error_string(err), PATH, arena.objects().size()])
	arena.scene_file_path = PATH
	add_child(arena)
	var report := ArenaValidator.validate(arena)
	print("HARVEST HOLLOW VALIDATION: " + report.summary())
	for i in report.issues:
		if int(i.severity) > 0:
			print("  ", ["INFO", "WARNING", "ERROR"][i.severity], "  ", i.message)
	get_tree().quit()


# ------------------------------------------------------------------ data

func _data() -> ArenaData:
	var d := ArenaData.new()
	d.arena_id = "w10_a01"
	d.display_name = "Harvest Hollow"
	d.description = "A farm village at dusk. The corn started walking: keep the Old Well standing, find the villagers and stop what landed in the crop circle."
	d.world_id = 10
	d.level_id = 1
	d.environment = "Earth - Farm"
	d.difficulty = ArenaData.Difficulty.MEDIUM
	d.boss_id = "zorp"
	d.start_delay = 4.0
	d.ambient = Color(1.0, 0.88, 0.76)  # harvest dusk
	d.background = Color(0.12, 0.2, 0.1)
	d.roaming = [SpawnEntry.make("slime", 50.0), SpawnEntry.make("runner", 30.0), SpawnEntry.make("comet_hopper", 20.0)] as Array[SpawnEntry]
	d.roaming_alive = 10
	d.roaming_rate = 0.5
	d.rewards = _reward(250, 0, 0.0)
	var well := _objective("well", ObjectiveData.Type.DEFEND, "Keep the Old Well standing")
	well.target_count = 210
	well.required_object_ids = PackedStringArray(["well"])
	var boss := _objective("circle", ObjectiveData.Type.BOSS, "Stop what landed in the circle")
	var folk := _objective("villagers", ObjectiveData.Type.RESCUE, "Find the hiding villagers")
	folk.optional = true
	folk.reward = _reward(80, 0, 0.3)
	var pip := _objective("pip", ObjectiveData.Type.ESCORT, "Walk Pip home from the pond")
	pip.optional = true
	pip.required_object_ids = PackedStringArray(["pip"])
	pip.reward = _reward(60, 0, 0.0)
	var nests := _objective("nests", ObjectiveData.Type.DESTROY, "Burn the nests in the corn")
	nests.optional = true
	nests.reward = _reward(50, 40, 0.0)
	var barn := _objective("barn", ObjectiveData.Type.DEFEND, "Save the barn")
	barn.target_count = 210
	barn.optional = true
	barn.required_object_ids = PackedStringArray(["barn"])
	barn.reward = _reward(60, 0, 0.0)
	var part := _objective("android", ObjectiveData.Type.COLLECT, "Find the android part")
	part.optional = true
	part.filter = "android"
	part.reward = _reward(80, 0, 0.0)
	d.objectives = [well, boss, folk, pip, nests, barn, part] as Array[ObjectiveData]
	var w1 := _wave("w1", "THE CORN IS MOVING!", 10.0)
	w1.horde = [SpawnEntry.make("slime", 60.0), SpawnEntry.make("runner", 40.0)] as Array[SpawnEntry]
	w1.enemy_count = 10
	w1.horde_rate = 1.0
	w1.completion = WaveData.Completion.SURVIVE_TIME
	w1.target = 50.0
	w1.reward = _reward(20, 30, 0.0)
	var w2 := _wave("w2", "ORCHARD AMBUSH", 18.0)
	w2.horde = [SpawnEntry.make("splitter", 40.0), SpawnEntry.make("slime", 60.0)] as Array[SpawnEntry]
	w2.enemy_count = 14
	w2.horde_rate = 1.4
	w2.completion = WaveData.Completion.SURVIVE_TIME
	w2.target = 45.0
	w2.reward = _reward(30, 40, 0.2)
	var w3 := _wave("w3", "HARVEST MOON RAID", 18.0)
	w3.horde = [SpawnEntry.make("slime", 30.0), SpawnEntry.make("runner", 30.0), SpawnEntry.make("spitter", 15.0),
		SpawnEntry.make("comet_hopper", 15.0), SpawnEntry.make("big_red", 10.0)] as Array[SpawnEntry]
	w3.enemy_count = 30
	w3.horde_rate = 2.0
	w3.horde_alive = 30
	w3.elite_count = 3
	w3.hp_mult = 1.2
	w3.completion = WaveData.Completion.SURVIVE_TIME
	w3.target = 70.0
	w3.reward = _reward(60, 50, 0.3)
	d.waves = [w1, w2, w3] as Array[WaveData]
	return d


func _objective(id: String, type: ObjectiveData.Type, title: String) -> ObjectiveData:
	var o := ObjectiveData.new()
	o.objective_id = id
	o.type = type
	o.title = title
	return o


## A raid: aliens come from its spawners at the edge of the map (they march on the well
## and the barn) and some around the astronaut; it lasts `target` seconds.
func _wave(id: String, title: String, delay: float) -> WaveData:
	var w := WaveData.new()
	w.wave_id = id
	w.title = title
	w.delay_before = delay
	w.spawn_mode = WaveData.SpawnMode.BOTH
	return w


func _reward(coins: int, xp: int, heal: float) -> RewardData:
	var r := RewardData.new()
	r.coins = coins
	r.xp = xp
	r.heal = heal
	return r


# ------------------------------------------------------------------ helpers

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


func _cell(c: Vector2) -> Vector2:
	return c * T


func _clear(p: Vector2, r: float) -> void:
	keep_clear.append(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0))


func _creek_y(x: float) -> float:
	return CREEK + sin(x * 0.13) * 1.6 + sin(x * 0.05 + 2.0) * 1.2


func _wet(p: Vector2) -> bool:
	var fl := arena.get_layer("Floor") as TileMapLayer
	return fl.get_cell_source_id(fl.local_to_map(fl.to_local(p))) == 8


func _free_spot(p: Vector2, spacing: float) -> bool:
	if _wet(p) or p.x < 20 or p.y < 30 or p.x > N * T - 20 or p.y > N * T - 8:
		return false
	for r in keep_clear:
		if r.has_point(p):
			return false
	for q in taken:
		if q.distance_squared_to(p) < spacing * spacing:
			return false
	return true


## Scenery from the Earth kit (kit.json gives size, collision, wind and fading).
func _piece(file: String, p: Vector2, flip := false, size_k := 1.0) -> ArenaScenery:
	var farm := file.begins_with("farm:")
	var item: Dictionary = farm_kit[file.trim_prefix("farm:")] if farm else kit[file]
	var s := _scenery((FARM_KIT + file.trim_prefix("farm:")) if farm else (KIT + file), float(item.width) * size_k, p, flip)
	s.sway = bool(item.sway)
	s.fade_behind = bool(item.fade)
	s.flat = bool(item.flat)
	s.bridge = bool(item.get("bridge", false))
	s.shadow = bool(item.get("shadow", false))
	if item.solid is Array:
		s.footprint = Vector2(float(item.solid[0]), float(item.solid[1])) * size_k
	var anim: Dictionary = item.get("anim", {})
	if not anim.is_empty():
		s.columns = int(anim.columns)
		s.rows = int(anim.rows)
		s.frame_count = int(anim.count)
		s.fps = float(anim.fps)
	return _put(s)


## Farm kit piece by its number: width from its art (FARM_K), `solid` = footprint as a
## share of the width ([w, h]) or none.
func _farm(id: String, p: Vector2, solid := Vector2.ZERO, size_k := 1.0, flip := false) -> ArenaScenery:
	var path := FARM % id
	var tex: Texture2D = load(path)
	var s := _scenery(path, tex.get_width() * FARM_K * size_k, p, flip)
	s.shadow = true
	if solid != Vector2.ZERO:
		s.footprint = Vector2(s.width * solid.x, s.width * solid.y)
	return _put(s)


func _scenery(path: String, width: float, p: Vector2, flip: bool) -> ArenaScenery:
	var s := ArenaScenery.new()
	s.name = path.get_file().get_basename().to_pascal_case()
	s.texture = load(path)
	s.width = roundf(width * 2.0) * 0.5
	s.flip_h = flip
	s.position = p.round()
	return s


func _put(s: ArenaScenery) -> ArenaScenery:
	_add(arena.get_layer("Decorations" if s.flat else "Obstacles"), s)
	return s


## Scatter Earth-kit `files` round `center`.
func _patch(files: Array, center: Vector2, radius: float, count: int, spacing: float, size := Vector2(0.85, 1.15)) -> void:
	var tries := count * 30
	var placed := 0
	while placed < count and tries > 0:
		tries -= 1
		var p := center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius
		if not _free_spot(p, spacing):
			continue
		taken.append(p)
		_piece(files[rng.randi() % files.size()], p, rng.randf() < 0.5, rng.randf_range(size.x, size.y))
		placed += 1


# ------------------------------------------------------------------ ground

## Grass, then Godot terrains like the editor's Terrains tab: the creek, the duck pond,
## dirt lanes and the plaza, and blight round the nests.
func _ground() -> void:
	var fl := arena.get_layer("Floor") as TileMapLayer
	var weights := [1.0, 1.0, 0.5, 0.6, 0.4, 0.5, 0.06, 0.05, 0.04]
	for y in N:
		for x in N:
			fl.set_cell(Vector2i(x, y), GRASS, _atlas(rng.rand_weighted(PackedFloat32Array(weights))))
	var water: Array[Vector2i] = []
	for x in range(-1, N + 1):
		var cy := roundi(_creek_y(x))
		for dy in 2:
			water.append(Vector2i(x, cy + dy))
	for y in range(-5, 6):
		for x in range(-7, 8):
			if Vector2(x / 7.0, y / 5.0).length() <= 1.0 + sin(x * 1.1 + y * 0.7) * 0.1:
				water.append(Vector2i(POND) + Vector2i(x, y))
	fl.set_cells_terrain_connect(water, 0, T_WATER)
	var dirt: Array[Vector2i] = []
	var lane := func(a: Vector2, b: Vector2, wide: int) -> void:
		var steps := int(a.distance_to(b) * 2.0)
		for k in steps + 1:
			var p := a.lerp(b, float(k) / steps)
			for dx in wide:
				for dy in wide:
					var c := Vector2i(p.floor()) + Vector2i(dx, dy)
					if absf(c.y - _creek_y(c.x)) > 2.5:  # the bridges cross the water
						dirt.append(c)
	lane.call(Vector2(ROAD, N), Vector2(ROAD, 0), 2)
	lane.call(Vector2(14, SQUARE.y), Vector2(64, SQUARE.y), 2)
	lane.call(Vector2(20, SQUARE.y), Vector2(16, POND.y + 6), 2)
	lane.call(Vector2(66, CREEK - 4), Vector2(66, CREEK + 6), 2)
	lane.call(Vector2(46, SQUARE.y), Vector2(66, CREEK - 4), 2)
	for y in range(-6, 7):  # the plaza
		for x in range(-8, 9):
			if Vector2(x / 8.0, y / 6.0).length() <= 1.0:
				dirt.append(Vector2i(SQUARE) + Vector2i(x, y))
	fl.set_cells_terrain_connect(dirt, 0, T_PATH)
	var noise := FastNoiseLite.new()
	noise.seed = 10
	var blight: Array[Vector2i] = []
	for y in N:
		for x in N:
			var p := Vector2(x, y)
			for n: Vector2 in NESTS:
				if p.distance_to(n) < 3.2 + noise.get_noise_2d(x * 5.0, y * 5.0) * 1.6:
					blight.append(Vector2i(x, y))
	fl.set_cells_terrain_connect(blight, 0, T_INFESTED)


func _atlas(i: int) -> Vector2i:
	return Vector2i(i % GRASS_COLS, i / GRASS_COLS)


# ------------------------------------------------------------------ gameplay

func _gameplay() -> void:
	var gp := arena.get_layer("GameplayObjects")
	var trig := arena.get_layer("Triggers")
	var start := _cell(Vector2(ROAD + 1, 75))
	var spawn := PlayerSpawn.new()
	spawn.name = "PlayerSpawn"
	spawn.position = start
	spawn.character = load("res://assets/characters/kid_astronaut/kid_astronaut.tres")
	_add(gp, spawn)
	_clear(start, 90.0)
	var talk := ArenaTrigger.new()
	talk.name = "Briefing"
	talk.action = ArenaTrigger.Action.MESSAGE
	talk.size = Vector2(160, 96)
	talk.position = start + Vector2(0, -30)
	talk.dialogue = _briefing()
	_add(trig, talk)
	# the Old Well and the barn: raiders march on them
	var well := DefendCore.new()
	well.name = "OldWell"
	well.object_id = "well"
	well.core_name = "the Old Well"
	well.look = load("res://assets/decor/farm/buildings/bld_40.png")
	well.look_width = 50.0
	well.health = 1200.0
	well.danger_radius = 56.0
	well.drain_per_alien = 5.0
	well.regen = 3.0
	well.lure_range = 760.0
	well.position = _cell(SQUARE)
	_add(gp, well)
	var barn := DefendCore.new()
	barn.name = "Barn"
	barn.object_id = "barn"
	barn.core_name = "the barn"
	barn.look = load("res://assets/decor/farm/buildings/bld_07.png")
	barn.look_width = 150.0
	barn.health = 800.0
	barn.danger_radius = 90.0
	barn.drain_per_alien = 4.0
	barn.regen = 2.0
	barn.lure_range = 480.0
	barn.position = _cell(Vector2(53, 36))
	_add(gp, barn)
	_clear(barn.position, 110.0)
	var square := ArenaTrigger.new()
	square.name = "VillageSquare"
	square.object_id = "square"
	square.action = ArenaTrigger.Action.REACH_LOCATION
	square.once = false
	square.show_in_game = true
	square.size = Vector2(220, 150)
	square.position = _cell(SQUARE) + Vector2(0, 20)
	_add(trig, square)
	# villagers hiding round the hollow (one has to be walked home)
	var folk := [
		["joe", "FARMER JOE", "image_019", 7, Vector2(70, 47), "", ["The corn... it BIT me!", "Over here, by the scarecrow!", "Mind the goo!"], "Thank ye! Take my lucky seeds."],
		["lulu", "BAKER LULU", "image_072", 10, Vector2(51, 57), "", ["My pies! They ate my PIES!", "Help, behind the stalls!"], "Have a warm bun, hero. You earned it!"],
		["may", "NURSE MAY", "image_049", 12, Vector2(8, 41), "", ["Psst! In the orchard!", "Anyone? I have bandages!"], "Hold still, let me patch you up."],
		["rose", "GRANNY ROSE", "image_017", 3, Vector2(25, 59), "", ["Shoo, you slimy things!", "Young one! Over by the pigs!"], "In my day aliens knocked first. Here, dear."],
		["tom", "BUILDER TOM", "image_075", 2, Vector2(59, 30), "", ["Stuck behind the silo!", "Hey! Up here by the silo!"], "I'll rig your blaster to fire faster. Go!"],
		["pip", "LITTLE PIP", "image_101", 4, Vector2(14, 29), "square", ["Mommy?! The goo ate my boat!", "I'm scared... help!"], "You'll take me home? Stay close!"],
	]
	for f: Array in folk:
		var s := ArenaSurvivor.new()
		s.name = str(f[1]).to_pascal_case()
		s.object_id = f[0]
		s.character_name = f[1]
		s.look = load(FOLK % f[2])
		s.crew = f[3]
		s.position = _cell(f[4])
		s.escort_to = f[5]
		s.dialogue = PackedStringArray(f[6])
		s.thanks_line = f[7]
		s.rescue_time = 6.0
		_add(gp, s)
		_clear(s.position, 50.0)
	# nests in the corn and the dark wood
	for i in NESTS.size():
		var p: Vector2 = _cell(NESTS[i])
		var nest := AlienNest.new()
		nest.name = "Nest%d" % (i + 1)
		nest.object_id = "nest_%d" % (i + 1)
		nest.position = p
		nest.health = 480.0
		nest.enemies = [SpawnEntry.make("slime", 50.0), SpawnEntry.make("runner", 30.0), SpawnEntry.make("splitter", 20.0)] as Array[SpawnEntry]
		nest.destroy_reward = _reward(15, 25, 0.0)
		_add(gp, nest)
		var goo := HazardArea.new()
		goo.name = "Blight%d" % (i + 1)
		goo.type = HazardArea.Type.ALIEN_SLIME
		goo.size = Vector2(120, 72)
		goo.slow_percentage = 45.0
		goo.damage = 2.0
		goo.position = p + Vector2(0, 60)
		_add(arena.get_layer("Hazards"), goo)
		_clear(p, 90.0)
	# the burning haystack by the east lane
	var fire := HazardArea.new()
	fire.name = "BurningHay"
	fire.type = HazardArea.Type.FIRE
	fire.size = Vector2(80, 48)
	fire.damage = 6.0
	fire.position = _cell(Vector2(58, 47))
	_add(arena.get_layer("Hazards"), fire)
	# raid spawners at the edges (aliens head for the village)
	var raids := [
		["w1", Vector2(77, 30), [["slime", 50.0], ["runner", 30.0], ["comet_hopper", 20.0]], 16],
		["w1", Vector2(77, 54), [["slime", 50.0], ["runner", 30.0], ["comet_hopper", 20.0]], 16],
		["w2", Vector2(2, 38), [["tentacle_plant", 30.0], ["splitter", 30.0], ["slime", 40.0]], 14],
		["w2", Vector2(2, 54), [["tentacle_plant", 30.0], ["splitter", 30.0], ["slime", 40.0]], 14],
		["w2", Vector2(14, 4), [["runner", 60.0], ["spitter", 40.0]], 10],
		["w3", Vector2(77, 42), [["big_red", 20.0], ["runner", 40.0], ["slime", 40.0]], 18],
		["w3", Vector2(3, 46), [["eyeclops", 20.0], ["splitter", 40.0], ["slime", 40.0]], 18],
		["w3", Vector2(58, 4), [["octo_wizard", 20.0], ["spitter", 30.0], ["runner", 50.0]], 16],
		["w3", Vector2(22, 76), [["slime", 50.0], ["runner", 50.0]], 14],
	]
	for i in raids.size():
		var r: Array = raids[i]
		var sp := EnemySpawner.new()
		sp.name = "Raid%s_%d" % [str(r[0]).to_upper(), i + 1]
		sp.wave_id = r[0]
		sp.position = _cell(r[1])
		var list: Array[SpawnEntry] = []
		for e: Array in r[2]:
			list.append(SpawnEntry.make(e[0], e[1]))
		sp.enemies = list
		sp.spawn_count = r[3]
		sp.spawn_interval = 1.6
		sp.burst = 2
		sp.max_alive = 10
		sp.spawn_radius = 70.0
		sp.min_player_distance = 120.0
		_add(arena.get_layer("EnemySpawners"), sp)
	# the crop circle: what landed there
	var near := ArenaTrigger.new()
	near.name = "CropCircleWarning"
	near.action = ArenaTrigger.Action.MESSAGE
	near.size = Vector2(300, 64)
	near.position = _cell(CIRCLE + Vector2(0.5, 11))
	near.dialogue = _circle_talk()
	_add(trig, near)
	var boss := BossTrigger.new()
	boss.name = "CropCircle"
	boss.object_id = "crop_circle"
	boss.boss_id = "zorp"
	boss.trigger_size = Vector2(300, 220)
	boss.position = _cell(CIRCLE) + Vector2(16, 60)
	boss.boss_offset = Vector2(0, -120)
	boss.fence_radius = 250.0
	boss.intro_text = "COMMANDER ZORP"
	boss.reward = _reward(150, 0, 0.4)
	_add(trig, boss)
	_clear(_cell(CIRCLE), 300.0)
	var exit := ArenaExit.new()
	exit.name = "NorthRoad"
	exit.position = _cell(Vector2(ROAD + 1, 2.5))
	_add(gp, exit)
	_clear(exit.position, 70.0)
	var part := AndroidPart.new()
	part.name = "AndroidLegModule"
	part.object_id = "android_leg"
	part.part = AndroidPart.Part.LEG_MODULE
	part.part_id = "android_leg_w10"
	part.position = _cell(Vector2(72, 75))
	part.reward = _reward(40, 0, 0.0)
	_add(gp, part)
	_clear(part.position, 60.0)
	var chest := ArenaChest.new()
	chest.name = "HiddenChest"
	chest.chest = 5
	chest.position = _cell(Vector2(6, 8))
	_add(gp, chest)
	_clear(chest.position, 50.0)
	for pk: Array in [["medkit", Vector2(44, 40)], ["heart", Vector2(12, 50)], ["heart", Vector2(64, 72)], ["magnet", Vector2(66, 20)]]:
		var pick := ArenaPickup.new()
		pick.name = str(pk[0]).capitalize() + str(get_child_count())
		pick.kind = pk[0]
		pick.position = _cell(pk[1])
		_add(arena.get_layer("Pickups"), pick)


func _cast(who: String, face: Texture2D, col: Color, side: DialogueSpeaker.Side, voice: float) -> DialogueSpeaker:
	var s := DialogueSpeaker.new()
	s.name = who
	s.portrait = face
	s.color = col
	s.side = side
	s.voice = voice
	return s


func _line(speaker: int, text: String, effect := DialogueLine.Effect.NORMAL, size := 1) -> DialogueLine:
	var l := DialogueLine.new()
	l.speaker = speaker
	l.text = text
	l.effect = effect
	l.size = size
	return l


func _briefing() -> DialogueData:
	var d := DialogueData.new()
	d.pause_game = true
	d.cast = [_cast("ELDER BRAM", load(FOLK % "image_107"), Color("ffcd75"), DialogueSpeaker.Side.LEFT, 0.7),
		_cast("CADET", load("res://assets/characters/concepts/boy_001.png"), Color("73eff7"), DialogueSpeaker.Side.RIGHT, 1.3)] as Array[DialogueSpeaker]
	d.lines = [
		_line(0, "A star fell on the north field last night... and then the corn started walking."),
		_line(1, "Walking corn? That's not corn, grandpa. That's GLOOP.", DialogueLine.Effect.NORMAL),
		_line(0, "It's heading for the Old Well! Without water, Harvest Hollow is done!", DialogueLine.Effect.SHOUT, 2),
		_line(1, "Then nothing touches that well. Where are your people?"),
		_line(0, "Hiding all over the hollow. And little Pip ran off to the duck pond...", DialogueLine.Effect.WHISPER),
		_line(1, "I'll bring everyone home. Keep the lanterns lit!"),
	] as Array[DialogueLine]
	return d


func _circle_talk() -> DialogueData:
	var d := DialogueData.new()
	d.cast = [_cast("CADET", load("res://assets/characters/concepts/boy_001.png"), Color("73eff7"), DialogueSpeaker.Side.LEFT, 1.3)] as Array[DialogueSpeaker]
	d.lines = [
		_line(0, "A perfect circle... and the wheat is still warm.", DialogueLine.Effect.THINK),
		_line(0, "Something BIG is parked in there.", DialogueLine.Effect.THINK),
	] as Array[DialogueLine]
	return d


# ------------------------------------------------------------------ village

func _village() -> void:
	var sq := _cell(SQUARE)
	# houses round the square (farm kit Buildings, tools/farm_buildings_ref.webp)
	var home := _bld(1, sq + Vector2(-330, -200), false, 1.25)
	_clear(home.position + Vector2(0, -40), 110.0)
	for h: Array in [[2, Vector2(-560, -60), false], [5, Vector2(-170, -330), true], [3, Vector2(380, 150), true],
			[4, Vector2(-480, 230), false], [6, Vector2(150, -330), false]]:
		var cottage := _bld(h[0], sq + h[1], h[2], 1.1)
		_clear(cottage.position + Vector2(0, -30), 80.0)
	_bld(48, _cell(Vector2(58.5, 35)))  # silo
	_bld(49, _cell(Vector2(48.5, 34)))  # water tower
	_bld(50, sq + Vector2(-330, 270), false, 1.3)  # windmill
	_bld(51, Vector2((ROAD + 1) * T, sq.y + 262))  # lantern gate over the road into the village
	# market stalls south-east of the square
	for k in 3:
		_bld([39, 47, 37][k], sq + Vector2(110 + k * 76, 300))
	_bld(44, sq + Vector2(80, 330))
	_bld(53, sq + Vector2(330, 320))
	_clear(sq + Vector2(190, 280), 90.0)
	for k in 3:  # villagers who stayed, waving from the square
		_piece("farm:villagers/boy_animated.png", sq + Vector2(-140 + k * 60, 130 - (k % 2) * 30), k == 1)
	_bld(54, sq + Vector2(130, 130))  # hay cart
	_farm("036", home.position + Vector2(110, 40))  # mailbox
	_farm("034", sq + Vector2(-160, 40))  # signpost at the crossroads
	_farm("034", sq + Vector2(170, -40), Vector2.ZERO, 1.0, true)
	for i in 8:  # lanterns round the plaza
		var a := TAU * i / 8.0 + 0.2
		var p := sq + Vector2(cos(a) * 250, sin(a) * 185)
		if absf(p.x - (ROAD + 1) * T) > 40 and absf(p.y - sq.y) > 30:
			_farm("017", p, Vector2(0.3, 0.12))
	_bld(36, sq + Vector2(70, 40))  # trough by the well
	for k in 4:
		_bld([44, 45, 46, 44][k], sq + Vector2(-110 + k * 18, -70 + (k % 2) * 8))
	for k in 4:
		_bld([43, 53, 38, 43][k], sq + Vector2(90 + k * 30, -80))
	# flowers and sunflowers by the farmhouse, a fence round its garden
	for k in 7:
		_farm("028", home.position + Vector2(-80 + k * 24, 60))
	for k in 4:
		_farm(["018", "040", "041", "037"][k], home.position + Vector2(-70 + k * 46, 82))
	for k in 2:
		_bld(21, home.position + Vector2(-262 + k * 70, 52))
	# round the barn: hay
	var barn := _cell(Vector2(53, 36))
	for k in 6:
		_bld([41, 52, 42, 52, 41, 42][k], barn + Vector2(-110 + k * 38, 70 + (k % 2) * 14))
	for k in 3:
		_bld([41, 42, 52][k], _cell(Vector2(58, 47)) + Vector2(-40 + k * 40, -30))  # the burning stack
	# the animal yard south-west of the square: stables, coop, duck pen and the sheep fold
	var yard := Rect2(_cell(Vector2(20, 54)), Vector2(10, 7) * T)
	for k in 3:
		_bld([14, 15, 16][k], yard.position + Vector2(45 + k * 112, 70))
	for k in 3:
		_bld([17, 18, 30][k], yard.position + Vector2(55 + k * 118, 205))
	for k in 3:  # sheep in the fold
		_farm(["060", "064", "060"][k], yard.position + Vector2(265 + k * 22, 185 + (k % 2) * 8), Vector2.ZERO, 0.6, k == 1)
	for k in 5:  # hens and chicks about the yard
		_farm(["056", "059", "062", "058", "066"][k], yard.position + Vector2(rng.randf_range(20, yard.size.x - 20), rng.randf_range(110, 135)), Vector2.ZERO, 0.75, rng.randf() < 0.5)
	keep_clear.append(yard.grow(30))
	_farm("054", sq + Vector2(-50, 90))  # the farm dog
	_farm("067", home.position + Vector2(60, 70))  # the cat
	# the elder waits by the well
	var elder := _scenery(FOLK % "image_107", 57 * FOLK_K, sq + Vector2(-60, 20), false)
	elder.shadow = true
	_put(elder)
	# the kitchen garden: a little corn patch and a flower bed
	for row in 3:
		for col in 4:
			var g := home.position + Vector2(-262 + col * 24, -50 + row * 26) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-2, 2))
			_corn((MATURE + COBS)[rng.randi() % (MATURE.size() + COBS.size())], g)
	for k in 6:
		_corn(FLOWERS[k % FLOWERS.size()], home.position + Vector2(-270 + k * 18, 32))


## Farm building piece n (assets/decor/farm/buildings/bld_NN.png): size and collision
## from kit.json, no shadow.
func _bld(n: int, p: Vector2, flip := false, size_k := 1.0) -> ArenaScenery:
	return _piece("farm:buildings/bld_%02d.png" % n, p, flip, size_k)


# ------------------------------------------------------------------ fields

func _fields() -> void:
	var nests: Array[Vector2] = []
	for n: Vector2 in NESTS:
		nests.append(_cell(n))
	# corn round the crop circle (the circle and the road stay open)
	_cornfield(Rect2(_cell(Vector2(25, 5)), Vector2(30, 19) * T), _cell(CIRCLE), 9.5 * T, nests)
	_circle_pattern()
	# the east cornfields with their nests, withered round the blight
	_cornfield(Rect2(_cell(Vector2(60, 24)), Vector2(17, 16) * T), Vector2.INF, 0.0, nests)
	_cornfield(Rect2(_cell(Vector2(60, 47)), Vector2(17, 13) * T), Vector2.INF, 0.0, nests)
	# young corn coming up between them
	for row in 3:
		for col in 11:
			var p := _cell(Vector2(61, 41.6)) + Vector2(col * 24 + (row % 2) * 12, row * 24)
			if _free_spot(p, 0.0):
				_corn(YOUNG[rng.randi() % YOUNG.size()], p)
	# the crop circle: crystals and debris round the landing
	var c := _cell(CIRCLE)
	for i in 8:
		_piece("alien_invasion/crystals_%d.png" % (i % 7 + 1), c + Vector2.from_angle(TAU * i / 8.0 + 0.3) * rng.randf_range(220, 260), rng.randf() < 0.5)
	for i in 3:
		_piece("alien_invasion/ship_debris_%d.png" % (i + 1), c + Vector2.from_angle(TAU * i / 3.0 + 1.0) * 150.0, i % 2 == 0)
	# the SE farmstead across the creek: hay where the android part hides
	var yard := _cell(Vector2(70, 74))
	for k in 10:
		var p := yard + Vector2(rng.randf_range(-170, 170), rng.randf_range(-60, 60))
		if _free_spot(p, 34.0):
			taken.append(p)
			_bld([41, 52, 42][k % 3], p)
	_bld(9, yard + Vector2(-200, -20))
	_bld(10, yard + Vector2(-60, -60))
	_bld(54, yard + Vector2(150, 40), true)


## Corn piece n of the farm kit (assets/decor/farm/corn/, tools/corn_sheet_ref.webp).
func _corn(n: int, p: Vector2, size_k := 1.0) -> ArenaScenery:
	return _piece("farm:corn/corn_%02d.png" % n, p, rng.randf() < 0.5, size_k * rng.randf_range(0.92, 1.08))


## A cornfield in rows with lanes between them: young corn and weeds on the edges,
## tall corn with tassels and cobs inside, withered stalks and stumps near the nests
## (`blight`), husks and loose cobs dropped in the lanes. `hole` (a circle) stays open.
func _cornfield(r: Rect2, hole: Vector2, hole_r: float, blight: Array[Vector2]) -> void:
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		row += 1
		if row % 4 == 0:  # a lane between the rows
			for k in int(r.size.x / 70.0):
				var q := Vector2(r.position.x + rng.randf_range(0, r.size.x), y)
				if (hole == Vector2.INF or q.distance_to(hole) > hole_r) and _free_spot(q, 0.0) and rng.randf() < 0.5:
					_corn(DEBRIS[rng.randi() % DEBRIS.size()], q)
			y += 24.0
			continue
		var x := r.position.x + (row % 2) * 11.0
		while x < r.end.x:
			var p := Vector2(x + rng.randf_range(-4, 4), y + rng.randf_range(-3, 3))
			x += 23.0
			if hole != Vector2.INF and p.distance_to(hole) < hole_r:
				continue
			if not _free_spot(p, 0.0) or rng.randf() < 0.1:
				continue
			var edge := minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))
			if hole != Vector2.INF:
				edge = minf(edge, p.distance_to(hole) - hole_r)
			var sick := INF
			for b: Vector2 in blight:
				sick = minf(sick, p.distance_to(b))
			var n: int
			if sick < 150.0:
				n = DRY[rng.randi() % DRY.size()] if rng.randf() < 0.85 else STUMPS[rng.randi() % 2]
			elif edge < 36.0:
				n = YOUNG[rng.randi() % YOUNG.size()] if rng.randf() < 0.7 else WEEDS[rng.randi() % WEEDS.size()]
			else:
				var roll := rng.randf()
				n = MATURE[rng.randi() % MATURE.size()] if roll < 0.62 else (COBS[rng.randi() % COBS.size()] if roll < 0.92 else YOUNG[rng.randi() % YOUNG.size()])
			_corn(n, p)
		y += 21.0
	# weeds and wild flowers along the field's edge
	for k in int((r.size.x + r.size.y) / 30.0):
		var t := rng.randf()
		var q: Vector2 = [Vector2(r.position.x + t * r.size.x, r.position.y - 14), Vector2(r.position.x + t * r.size.x, r.end.y + 8),
			Vector2(r.position.x - 14, r.position.y + t * r.size.y), Vector2(r.end.x + 12, r.position.y + t * r.size.y)][k % 4]
		if _free_spot(q, 0.0):
			_corn((WEEDS + FLOWERS)[rng.randi() % (WEEDS.size() + FLOWERS.size())], q)


## The crop circle's own pattern: a ring of tall corn with four gaps, trampled stalks
## lying round the landing spot and withered corn at its rim.
func _circle_pattern() -> void:
	var c := _cell(CIRCLE)
	for i in 44:
		var a := TAU * i / 44.0
		if fmod(a + PI / 8.0, PI / 2.0) < 0.3:
			continue  # the spokes
		_corn(MATURE[i % MATURE.size()], c + Vector2(cos(a) * 150, sin(a) * 120))
	for i in 18:
		var a := TAU * i / 18.0 + 0.1
		_corn(DEBRIS[i % DEBRIS.size()], c + Vector2(cos(a), sin(a) * 0.8) * rng.randf_range(60, 110))
	for i in 24:
		var a := TAU * i / 24.0
		_corn(DRY[i % DRY.size()], c + Vector2(cos(a), sin(a) * 0.8) * 250.0)


# ------------------------------------------------------------------ wilds

func _wilds() -> void:
	var big_trees := ["trees/image_004.png", "trees/image_005.png", "trees/image_008_2.png", "trees/image_003_2_2.png"]
	var pines := ["trees/pine_tall_1.png", "trees/pine_small_1.png", "trees/pine_small_2.png", "trees/pine_small_3.png", "trees/pine_berries.png"]
	# the orchard west of the square: apple trees in rows
	for row in 5:
		for col in 4:
			var p := _cell(Vector2(5 + col * 3.6, 36 + row * 3.8)) + Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8))
			if _free_spot(p, 40.0):
				taken.append(p)
				_farm(["071", "073", "072"][(row + col) % 3], p, Vector2(0.45, 0.12), 1.15)
	for k in 5:
		_farm(["049", "027", "022"][k % 3], _cell(Vector2(rng.randf_range(5, 18), rng.randf_range(37, 54))), Vector2(0.6, 0.2))
	# the dark wood north-east (a nest in it) and the treeline round the map
	_patch(pines + ["forest/dead_tree_1.png", "forest/dead_tree_2.png"], _cell(Vector2(70, 10)), 300.0, 34, 40.0)
	_patch(["alien_invasion/infested_tree_1.png", "alien_invasion/infested_tree_2.png", "alien_invasion/infested_tree_3.png"], _cell(NESTS[2]), 150.0, 5, 50.0)
	for k in 420:
		var t := rng.randf_range(0.0, N * T)
		var p: Vector2 = [Vector2(t, rng.randf_range(30, 80)), Vector2(t, N * T - rng.randf_range(10, 50)),
			Vector2(rng.randf_range(20, 70), t), Vector2(N * T - rng.randf_range(20, 70), t)][k % 4]
		if _free_spot(p, 40.0):
			taken.append(p)
			var pool := big_trees if k % 3 > 0 else pines
			_piece(pool[rng.randi() % pool.size()], p, rng.randf() < 0.5, rng.randf_range(0.8, 1.1))
	# groves between the farms
	for c: Vector2 in [Vector2(26, 28), Vector2(50, 27), Vector2(8, 60), Vector2(16, 72), Vector2(30, 73),
			Vector2(50, 73), Vector2(34, 58), Vector2(50, 61), Vector2(4, 30), Vector2(76, 64), Vector2(58, 18)]:
		_patch(big_trees + pines, _cell(c), 170.0, 11, 48.0, Vector2(0.75, 1.0))
	# the duck pond: a dock, reeds, ducks
	var pond := _cell(POND)
	_piece("fences/dock_steps.png", pond + Vector2(0, 160))
	for k in 3:
		_farm(["061", "068", "061"][k], pond + Vector2(-120 + k * 110, 175 + (k % 2) * 12))
	_farm("098", pond + Vector2(-60, 200))  # Pip's "boat"
	# bridges over the creek: the main road and the farmstead lane
	for bx: float in [ROAD + 1.0, 67.0]:
		var top := roundf(_creek_y(floorf(bx))) - 0.6
		var tex: Texture2D = load(KIT + "water/bridge_5.png")
		var b := _scenery(KIT + "water/bridge_5.png", roundf(4.2 * T * tex.get_width() / tex.get_height()), Vector2(bx * T, (top + 4.0) * T), false)
		b.flat = true
		b.bridge = true
		_put(b)
	# undergrowth, rocks, logs, flowers
	var mid := Vector2(N, N) * T * 0.5
	_patch(["plants/bush_flowers.png", "plants/bushes_flowers.png", "plants/bush_yellow.png", "plants/bush_tiny.png", "plants/fern.png"], mid, N * T * 0.7, 70, 30.0)
	_patch(["rocks/rocks_big_1.png", "rocks/rock_mossy.png", "rocks/rock_small.png", "rocks/rocks_moss_small.png"], mid, N * T * 0.7, 26, 50.0)
	_patch(["forest/log_mossy_2.png", "forest/stump_old.png", "forest/branches.png"], mid, N * T * 0.7, 14, 60.0)
	var patches := []
	for i in 10:
		patches.append("farm:terrain/patches/patch_%02d.png" % (i + 1))
	var flowers := []
	for i in 58:
		flowers.append("farm:terrain/plants/plant_%02d.png" % (i + 1))
	_patch(patches, mid, N * T * 0.7, 45, 90.0)
	_patch(flowers, mid, N * T * 0.7, 220, 22.0)
	for i in 200:
		var p := Vector2(rng.randf_range(20, N * T - 20), rng.randf_range(20, N * T - 20))
		if not _wet(p) and not keep_clear[0].has_point(p):
			_piece(["plants/grass_tuft_1.png", "plants/grass_tuft_2.png", "plants/grass_tuft_3.png", "plants/grass_flowers.png", "rocks/pebbles.png"][rng.randi() % 5], p, rng.randf() < 0.5)
