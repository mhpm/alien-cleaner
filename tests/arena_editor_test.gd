extends Node
## Arena Editor end-to-end test (run headless):
##   godot --headless --path . res://tests/arena_editor_test.tscn
## 1. Validation: the sample arena is clean; broken arenas report the right errors.
## 3. Open world: plays the Earth sample (arena_world_09_level_01): minimap, see-through
##    trees, roaming aliens and the leash that brings the horde along across the map.
## 2. Plays scenes/arenas/arena_world_01_level_01.tscn in ArenaWorld and walks through
##    it like a player would (shortcuts instead of aiming): wave 1, a rescue, an escort,
##    the nests, the hidden android part, the survive wave, the boss, the exit.
## Prints PASS / FAIL lines and quits with the number of failures.

const ARENA := "res://scenes/arenas/arena_world_01_level_01.tscn"

var fails := 0
var world: ArenaWorld
var director: ArenaDirector


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
		_skip_upgrades()
	return cond.call()


## Level-up choices pause the game: take the first card.
func _skip_upgrades() -> void:
	if world != null and world.hud.overlay_kind == "upgrade" and not world.hud._cards.is_empty():
		world.hud._on_pick(str(world.hud._cards[0].get_meta("id")))


func _teleport(p: Vector2) -> void:
	world.player.global_position = p
	world.player.velocity = Vector2.ZERO


func _kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not (e as Enemy).dead and not e is AlienNestBody and not (e as Enemy).is_boss:
			(e as Enemy).die()


func _run() -> void:
	_validation_tests()
	await _play_test()
	await _open_world_test()
	print("ARENA EDITOR TEST: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	get_tree().quit(fails)


# ---------------------------------------------------------------- validation

func _validation_tests() -> void:
	# arenas saved before ArenaData existed keep their metadata
	if ResourceLoader.exists("res://scenes/arenas/arena_world_05_level_01.tscn"):
		var old := (load("res://scenes/arenas/arena_world_05_level_01.tscn") as PackedScene).instantiate() as Arena
		check(old.data != null and old.data.arena_id == "w05_a01" and old.data.world_id == 5, "an arena in the old format migrates its metadata into ArenaData")
		old.free()
	var sample := (load(ARENA) as PackedScene).instantiate() as Arena
	add_child(sample)
	var r := ArenaValidator.validate(sample)
	check(not r.has_errors(), "sample arena validates without errors (%s)" % r.summary())
	check(sample.objects("EnemySpawner").size() == 4 and sample.objects("AlienNest").size() == 2 \
			and sample.objects("ArenaSurvivor").size() == 2 and sample.objects("AndroidPart").size() == 1 \
			and sample.objects("HazardArea").size() == 1 and sample.objects("BossTrigger").size() == 1 \
			and sample.objects("ArenaExit").size() == 1 and sample.data.objectives.size() == 3 and sample.data.waves.size() == 3,
			"sample arena has every required component")
	# break it in several ways
	sample.get_layer("GameplayObjects").get_node("PlayerSpawn").free()
	var spawner := sample.objects("EnemySpawner")[0] as EnemySpawner
	spawner.position = Vector2(-500, -500)
	sample.data.objectives[1].required_object_ids = PackedStringArray(["ghost_nest"])
	(sample.objects("ArenaSurvivor")[1] as ArenaSurvivor).escort_to = "nowhere"
	var walls := sample.get_layer("Walls") as TileMapLayer
	sample.data.boss_id = "hive_queen"
	r = ArenaValidator.validate(sample)
	var text := "\n".join(r.issues.map(func(i: Dictionary) -> String: return i.message))
	check(text.contains("No Player Spawn"), "detects a missing Player Spawn")
	check(text.contains("is outside the arena"), "detects a spawner outside the arena")
	check(text.contains("missing object \"ghost_nest\""), "detects an objective pointing at a missing object")
	check(text.contains("escorts to \"nowhere\""), "detects a broken escort target")
	check(text.contains("hive_queen") and text.contains("no BossTrigger"), "detects a boss without a BossTrigger")
	sample.free()
	# a walled-in exit is unreachable
	var boxed := (load(ARENA) as PackedScene).instantiate() as Arena
	add_child(boxed)
	walls = boxed.get_layer("Walls") as TileMapLayer
	var exit_cell := walls.local_to_map(walls.to_local(boxed.objects("ArenaExit")[0].global_position))
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if absi(dx) == 3 or absi(dy) == 3:
				walls.set_cell(exit_cell + Vector2i(dx, dy), 3, Vector2i(0, 0))
	r = ArenaValidator.validate(boxed)
	check(r.issues.any(func(i: Dictionary) -> bool: return str(i.message).contains("unreachable") and int(i.severity) == ArenaReport.Severity.ERROR),
			"detects an unreachable exit")
	boxed.free()


# ---------------------------------------------------------------- playing

func _play_test() -> void:
	var parts_before := Game.android_parts.duplicate()
	ArenaSession.arena_path = ARENA
	ArenaSession.test = true
	ArenaSession.invincible = true
	var host := (load(ArenaSession.PLAY_SCENE) as PackedScene).instantiate()
	add_child(host)
	world = host.get_child(0) as ArenaWorld
	check(world != null and world.arena != null, "ArenaWorld loaded the arena")
	check(await _until(func() -> bool: return world.director != null and world.director.objectives != null, 5.0), "arena started (director, objectives)")
	director = world.director
	world.survival.choosing = true  # no level-up interruptions during the run
	check(director.objectives.states.size() == 3, "3 objectives on the HUD")
	check(world.arena.get_layer("Obstacles").get_child_count() == 0 and world.entities.get_children().any(func(n: Node) -> bool: return n is ArenaProp),
			"props moved into the y-sorted entities")
	check(director.objects_of("AlienNest").all(func(o: ArenaObject) -> bool: return is_instance_valid((o as AlienNest).body)), "nests came alive")
	# wave 1: the spawners send their aliens; clean them
	check(await _until(func() -> bool: return director.waves.state == "run", 8.0), "wave 1 started")
	check(await _until(func() -> bool: return get_tree().get_nodes_in_group("enemies").size() > 2, 6.0), "spawners sent aliens")
	var cleared := await _until(func() -> bool:
		_kill_all()
		return director.waves.index >= 1, 40.0)
	check(cleared, "wave 1 cleared by cleaning its aliens")
	# rescue the scientist
	var sci := director.find("crew_scientist") as ArenaSurvivor
	_teleport(sci.survivor.global_position + Vector2(0, -6))
	sci.survivor.progress = 0.97
	check(await _until(func() -> bool: return sci.is_resolved(), 3.0), "scientist rescued")
	# rescue + escort the medic to the evacuation pad
	var medic := director.find("crew_medic") as ArenaSurvivor
	_teleport(medic.survivor.global_position + Vector2(0, -6))
	medic.survivor.progress = 0.97
	check(await _until(func() -> bool: return medic._escorting, 3.0), "medic rescued and following")
	var evac := director.find("evac") as ArenaTrigger
	_teleport(evac.global_position)
	medic.survivor.global_position = evac.global_position + Vector2(10, 0)
	check(await _until(func() -> bool: return medic.is_resolved(), 3.0), "medic escorted to the evac zone")
	var crew_state = director.objectives.states[2]
	check(crew_state.done, "SIDE objective: rescue crew completed")
	# destroy both nests
	for o in director.objects_of("AlienNest"):
		var nest := o as AlienNest
		if is_instance_valid(nest.body):
			nest.body.take_damage(999999.0)
	check(await _until(func() -> bool: return director.objectives.states[1].done, 3.0), "SIDE objective: nests destroyed")
	# hidden android part
	var part := director.find("core_part") as AndroidPart
	_teleport(part.global_position)
	check(await _until(func() -> bool: return part.is_resolved(), 3.0), "android part collected")
	check(Game.android_parts.has("android_core_w1"), "android part recorded in Game.android_parts")
	# wave 2 survive: fast-forward its clock
	check(await _until(func() -> bool: return director.waves.state == "run" and director.waves.index == 1, 20.0), "wave 2 (survive) started")
	director.waves._t = 29.5
	check(await _until(func() -> bool: return director.waves.index >= 2, 4.0), "wave 2 survived")
	# wave 3: walk into the reactor room, the boss lands
	check(await _until(func() -> bool: return director.waves.state == "run" and director.waves.index == 2, 15.0), "wave 3 started")
	var trigger := director.find("reactor_room") as BossTrigger
	_teleport(trigger.global_position)
	check(await _until(func() -> bool: return is_instance_valid(trigger.boss), 8.0), "boss trigger brought the boss")
	check(world.survival.fence != null, "arena locked by the boss fence")
	trigger.boss.die()
	var ok := await _until(func() -> bool:
		_kill_all()
		return trigger.is_resolved() and director.objectives.states[0].done, 20.0)
	check(ok, "boss defeated, wave 3 and the MAIN objective done")
	# extraction
	var exit := director.objects_of("ArenaExit")[0] as ArenaExit
	check(await _until(func() -> bool: return exit.is_open(), 3.0), "exit opened after the MAIN objectives")
	_teleport(exit.global_position)
	check(await _until(func() -> bool: return director.finished, 3.0), "reaching the exit wins the arena")
	check(await _until(func() -> bool: return world.hud.overlay_kind == "arena_result", 4.0), "result screen shown")
	get_tree().paused = false
	host.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.android_parts == parts_before and not Game.playground_active, "test run left the saved progress untouched")


# ---------------------------------------------------------------- open world

func _open_world_test() -> void:
	ArenaSession.arena_path = "res://scenes/arenas/arena_world_09_level_01.tscn"
	ArenaSession.test = true
	ArenaSession.invincible = true
	var host := (load(ArenaSession.PLAY_SCENE) as PackedScene).instantiate()
	add_child(host)
	world = host.get_child(0) as ArenaWorld
	check(await _until(func() -> bool: return world.director != null and world.director.objectives != null, 6.0), "open world: arena started")
	director = world.director
	world.survival.choosing = true
	var mm := world.hud.safe.find_child("Minimap", true, false) as Control
	check(mm != null and mm.size.x > 40.0, "open world: minimap shown (%s)" % (str(mm.size) if mm else "none"))
	check(director.find_child("SceneryFader", true, false) != null, "open world: see-through scenery fader running")
	var trees := world.entities.get_children().filter(func(n: Node) -> bool: return n is ArenaScenery)
	check(trees.size() > 200, "open world: %d scenery pieces sorted with the entities" % trees.size())
	check(await _until(func() -> bool: return director.horde._mine.size() >= 4, 12.0), "open world: roaming aliens arrive around the explorer")
	# run to the far side of the map: the roaming horde must follow (leash)
	var far := Vector2(300, 2800)
	_teleport(far)
	world.camera.global_position = far
	await _wait(1.6)
	var near := 0
	for en: Enemy in director.horde._mine.keys():
		if is_instance_valid(en) and en.global_position.distance_to(far) < 600.0:
			near += 1
	check(near >= 3, "open world: the horde was walked back near the explorer (%d near)" % near)
	# the river blocks, the bridge on the road lets you across (walk north for 1.5 s)
	for o in director.horde._mine.keys():
		if is_instance_valid(o):
			(o as Enemy).die()
	# (same meander as tools/build_earth_demo.gd)
	var river_top := func(x_tile: float) -> float:
		return roundf(30.0 + sin(x_tile * 0.11) * 2.2 + sin(x_tile * 0.037 + 1.0) * 1.5) * 32.0
	var walk_north := func(x_tile: float) -> float:
		_teleport(Vector2(x_tile * 32.0, river_top.call(floorf(x_tile)) + 3.0 * 32.0 + 60.0))
		Input.action_press("move_up")
		await _wait(2.0)
		Input.action_release("move_up")
		return world.player.global_position.y
	var blocked_y: float = await walk_north.call(60.5)
	check(blocked_y > river_top.call(60.0), "open world: the river blocks the way (stopped at y %d)" % blocked_y)
	var bridge_y: float = await walk_north.call(47.5)
	check(bridge_y < river_top.call(47.0) - 8.0, "open world: the bridge crosses the river (reached y %d)" % bridge_y)
	# a tree fades when walked behind
	var tree: ArenaScenery = null
	for t in trees:
		if (t as ArenaScenery).fade_behind:
			tree = t
			break
	_teleport(tree.global_position + Vector2(0, -12))
	check(await _until(func() -> bool: return tree.sprite.modulate.a < 0.6, 2.0), "open world: a tree goes see-through with the astronaut behind it")
	get_tree().paused = false
	host.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
