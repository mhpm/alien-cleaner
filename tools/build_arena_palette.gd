extends Node
## Builds the Arena Editor palette presets (scenes/arena/palette/<category>/*.tscn):
## one small scene per ready-to-place component with tuned defaults. Run it again
## after changing a component's defaults:
##   godot --headless --path . res://tools/build_arena_palette.tscn
## (A scene, not --script, so the game's autoloads exist while the components load.)

const ROOT := "res://scenes/arena/palette/"


func _ready() -> void:
	var n := 0
	# ---- gameplay
	n += _save("gameplay/survivor", _survivor())
	n += _save("gameplay/alien_nest", _nest())
	for part in AndroidPart.Part.values():
		var p := AndroidPart.new()
		p.name = "AndroidPart"
		p.part = part
		p.part_id = "android_" + AndroidPart.ART[part]
		n += _save("gameplay/android_" + AndroidPart.ART[part], p)
	var chest := ArenaChest.new()
	chest.name = "Chest"
	n += _save("gameplay/chest", chest)
	var exit := ArenaExit.new()
	exit.name = "Exit"
	n += _save("gameplay/exit", exit)
	var tele := ArenaExit.new()
	tele.name = "Teleporter"
	tele.always_open = true
	n += _save("gameplay/teleporter_exit", tele)
	var door := ArenaDoor.new()
	door.name = "EnergyDoor"
	n += _save("gameplay/energy_door", door)
	var core := DefendCore.new()
	core.name = "DefendCore"
	core.object_id = "core"
	n += _save("gameplay/defend_core", core)
	# ---- spawners
	n += _save("spawners/enemy_spawner", _spawner("EnemySpawner", [["slime", 40.0], ["runner", 30.0], ["spitter", 20.0], ["big_red", 10.0]]))
	var horde := _spawner("HordeSpawner", [["slime", 60.0], ["runner", 40.0]])
	horde.spawn_count = 30
	horde.burst = 4
	horde.spawn_interval = 1.0
	horde.max_alive = 24
	horde.spawn_radius = 90.0
	n += _save("spawners/horde_spawner", horde)
	var snipers := _spawner("ShooterSpawner", [["spitter", 40.0], ["droid", 30.0], ["octo_wizard", 30.0]])
	snipers.spawn_count = 6
	snipers.max_alive = 4
	snipers.spawn_interval = 2.5
	n += _save("spawners/shooter_spawner", snipers)
	var elite := _spawner("EliteSpawner", [["big_red", 50.0], ["eyeclops", 50.0]])
	elite.spawn_count = 3
	elite.burst = 1
	elite.spawn_interval = 3.0
	elite.enemies[0].elite_chance = 1.0
	elite.enemies[1].elite_chance = 1.0
	n += _save("spawners/elite_spawner", elite)
	# ---- triggers
	n += _save("triggers/boss_trigger", _boss())
	n += _save("triggers/area_trigger", _trigger("AreaTrigger", ArenaTrigger.Action.REACH_LOCATION))
	var talk := _trigger("DialogueTrigger", ArenaTrigger.Action.MESSAGE)
	talk.message = "Movement detected ahead. Stay sharp, cleaner."
	n += _save("triggers/dialogue_trigger", talk)
	n += _save("triggers/wave_trigger", _trigger("WaveTrigger", ArenaTrigger.Action.START_WAVE))
	n += _save("triggers/spawner_trigger", _trigger("SpawnerTrigger", ArenaTrigger.Action.START_SPAWNERS))
	n += _save("triggers/door_trigger", _trigger("DoorTrigger", ArenaTrigger.Action.OPEN_DOOR))
	n += _save("triggers/hazard_trigger", _trigger("HazardTrigger", ArenaTrigger.Action.ACTIVATE_HAZARDS))
	var console := _trigger("Console", ArenaTrigger.Action.ACTIVATE)
	console.size = Vector2(40, 40)
	n += _save("triggers/console", console)
	# ---- hazards: [type, damage, interval, slow, size]
	var hazards := {
		"acid": [HazardArea.Type.ACID, 6.0, 0.6, 0.0, Vector2(96, 64)],
		"radiation": [HazardArea.Type.RADIATION, 3.0, 0.5, 10.0, Vector2(128, 96)],
		"alien_slime": [HazardArea.Type.ALIEN_SLIME, 0.0, 0.6, 55.0, Vector2(96, 64)],
		"electric_floor": [HazardArea.Type.ELECTRIC, 10.0, 0.4, 0.0, Vector2(96, 96)],
		"fire": [HazardArea.Type.FIRE, 9.0, 0.5, 0.0, Vector2(80, 48)],
		"vacuum": [HazardArea.Type.VACUUM, 2.0, 0.8, 0.0, Vector2(96, 96)],
	}
	for key: String in hazards:
		var d: Array = hazards[key]
		var h := HazardArea.new()
		h.name = key.to_pascal_case()
		h.type = d[0]
		h.damage = d[1]
		h.damage_interval = d[2]
		h.slow_percentage = d[3]
		h.size = d[4]
		n += _save("hazards/" + key, h)
	# ---- pickups: [kind, value]
	var pickups := {"health": ["heart", 1], "medkit": ["medkit", 1], "energy_core": ["power", 1],
		"upgrade": ["golden_carrot", 1], "coins": ["gold", 1], "gravity_well": ["magnet", 1], "xp_cache": ["xp", 30]}
	for key: String in pickups:
		var pk := ArenaPickup.new()
		pk.name = key.to_pascal_case()
		pk.kind = pickups[key][0]
		pk.value = pickups[key][1]
		n += _save("pickups/" + key, pk)
	print("ARENA PALETTE: %d scenes written" % n)
	get_tree().quit()


func _spawner(node_name: String, list: Array) -> EnemySpawner:
	var s := EnemySpawner.new()
	s.name = node_name
	var entries: Array[SpawnEntry] = []
	for e: Array in list:
		entries.append(SpawnEntry.make(e[0], e[1]))
	s.enemies = entries
	return s


func _survivor() -> ArenaSurvivor:
	var s := ArenaSurvivor.new()
	s.name = "Survivor"
	s.thanks_line = "You came for me! I thought I'd be alien food."
	s.reward = RewardData.new()
	s.reward.coins = 25
	return s


func _nest() -> AlienNest:
	var nest := AlienNest.new()
	nest.name = "AlienNest"
	nest.enemies = [SpawnEntry.make("slime", 60.0), SpawnEntry.make("runner", 40.0)] as Array[SpawnEntry]
	nest.destroy_reward = RewardData.new()
	nest.destroy_reward.xp = 20
	return nest


func _boss() -> BossTrigger:
	var b := BossTrigger.new()
	b.name = "BossTrigger"
	b.reward = RewardData.new()
	b.reward.coins = 100
	b.reward.heal = 0.3
	return b


func _trigger(node_name: String, action: ArenaTrigger.Action) -> ArenaTrigger:
	var t := ArenaTrigger.new()
	t.name = node_name
	t.action = action
	t.show_in_game = action in [ArenaTrigger.Action.REACH_LOCATION, ArenaTrigger.Action.ACTIVATE]
	return t


func _save(rel: String, node: Node) -> int:
	var path := ROOT + rel + ".tscn"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	node.free()
	if err != OK:
		push_error("palette: could not save %s (%s)" % [path, error_string(err)])
		return 0
	return 1
