extends Node
## Placed aliens (AlienPack + AlienMind): builds a small test arena in memory (waves OFF,
## an ELIMINATE mission) and plays it with the real game:
##   guard     calm until it sees the astronaut in front of it: "?" then "!" (hunts)
##   friends   the guard's call wakes the calm alien next to it
##   sleeper   does not notice him a little away, wakes when he is very close
##   patrol    walks its path while calm
##   near      appears only when he walks within its activation radius
##   trigger   appears when a START_SPAWNERS trigger fires
##   alarm     appears when a camera alarm is raised
##   lost      an alerted alien that loses him searches, then goes home calm
##   hurt      a shot alerts a calm alien
##   eliminate the mission counts every placed alien and completes when all are dead
## No wave ever plays. (The astronaut holds fire: these checks count the aliens.)
##   godot --headless --path . res://tests/alien_pack_test.tscn

const PATH := "user://alien_pack_test_arena.tscn"
const FLOOR := "res://assets/arena/pixel25d/floor.png"

var failures := 0
var world: ArenaWorld


func _ready() -> void:
	_save_arena()
	ArenaSession.arena_path = PATH
	ArenaSession.invincible = true
	var host := (load(ArenaSession.PLAY_SCENE) as PackedScene).instantiate()
	add_child(host)
	world = host.get_child(0) as ArenaWorld
	await _until(func() -> bool: return world.director != null and world.director.objectives != null, 6.0)
	world.survival.choosing = true
	world.player.fire_t = 1e9
	var d := world.director
	await _wait(0.6)
	_check(d.waves.state == "done" and d.waves.total() == 0, "waves are off: none play (state %s)" % d.waves.state)
	var guard := _pack("guard")
	var buddy := _pack("buddy")
	var sleeper := _pack("sleeper")
	var patrol := _pack("patrol")
	var near := _pack("near")
	var trig := _pack("trig")
	var alarm := _pack("alarm")
	_check(guard.members.size() == 1 and patrol.members.size() == 2 and sleeper.members.size() == 1, "ON_START packs are there")
	_check(near.members.is_empty() and trig.members.is_empty() and alarm.members.is_empty(), "the other packs wait")
	var target := d.objectives.states[0].target
	_check(target == 11, "ELIMINATE counts every placed alien (%d of 11)" % target)
	# calm: far away, nobody notices
	_go(Vector2(320, 900))
	var p0 := patrol.members[0].global_position
	await _wait(3.0)
	_check(_state(guard) == AlienMind.State.CALM and _state(sleeper) == AlienMind.State.CALM, "calm while the astronaut is far")
	_check(patrol.members[0].global_position.distance_to(p0) > 20.0, "the patrol walks its path")
	# guard sees him in front: ? then !
	_go(Vector2(320, 300))  # 100 below the guard, inside its view
	await _wait(0.3)
	await _shot("noticed")
	_check(_state(guard) in [AlienMind.State.SUSPICIOUS, AlienMind.State.ALERT], "the guard notices ('?')")
	await _wait(1.0)
	await _shot("hunting")
	_check(_state(guard) == AlienMind.State.ALERT, "then hunts ('!')")
	_check(_state(buddy) == AlienMind.State.ALERT, "and its call brings the calm alien next to it")
	# lost: far beyond give_up -> search -> home
	_go(Vector2(1100, 1100))
	await _until(func() -> bool: return _state(guard) in [AlienMind.State.SEARCH, AlienMind.State.RETURN], 5.0)
	_check(_state(guard) in [AlienMind.State.SEARCH, AlienMind.State.RETURN], "losing him, it searches (%s)" % _name(guard))
	await _until(func() -> bool: return _state(guard) == AlienMind.State.CALM, 14.0)
	_check(_state(guard) == AlienMind.State.CALM, "then goes home and calms down (%s)" % _name(guard))
	# sleeper: a little away it keeps sleeping, very close it wakes
	var sp := sleeper.members[0].global_position
	_go(sp + Vector2(0, 60))
	await _wait(1.0)
	await _shot("sleeper")
	_check(_state(sleeper) == AlienMind.State.CALM, "the sleeper sleeps on 60 away")
	_go(sp + Vector2(0, 14))
	await _wait(1.2)
	_check(_state(sleeper) == AlienMind.State.ALERT, "and wakes up right next to him (%s)" % _name(sleeper))
	# hurt alerts
	var pm := patrol.members[1]
	_go(Vector2(1100, 1100))
	await _wait(0.2)
	pm.take_damage(1.0)
	_check(pm.mind.is_alert(), "a shot alerts a calm alien")
	# activation by distance, trigger, alarm
	_go(near.global_position + Vector2(0, 100))
	await _wait(1.5)
	_check(near.members.size() == 2, "the NEAR pack appears when he walks close (%d)" % near.members.size())
	_go(Vector2(1100, 1100))
	(d.find("trig_zone") as ArenaTrigger).call("_fire")
	await _wait(1.2)
	_check(trig.members.size() == 2, "the TRIGGER pack appears (%d)" % trig.members.size())
	d.fire("alarm_raised", "cam_x", PackedStringArray(["alarm"]))
	await _wait(1.2)
	_check(alarm.members.size() == 2, "the ALARM pack comes in (%d)" % alarm.members.size())
	_check(alarm.members.all(func(e: Enemy) -> bool: return e.mind.is_alert()), "alarm reinforcements arrive hunting")
	# eliminate them all
	for pack in [guard, buddy, sleeper, patrol, near, trig, alarm]:
		for e in (pack as AlienPack).members.duplicate():
			if is_instance_valid(e) and not e.dead:
				e.take_damage(99999.0)
	await _wait(1.5)
	var st := d.objectives.states[0]
	_check(st.done, "ELIMINATE done when every placed alien is dead (%d/%d)" % [int(st.progress), st.target])
	_check(world.survival != null and d.waves.state == "done", "still no waves at the end")
	ArenaSession.arena_path = ""
	print("ALIEN PACK TEST: %s" % ("PASS" if failures == 0 else "FAILED (%d)" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _save_arena() -> void:
	var arena := Arena.new()
	arena.name = "Arena"
	var data := ArenaData.new()
	data.arena_id = "pack_test"
	data.start_delay = 0.5
	data.minimap = false
	data.waves_enabled = false
	var w := WaveData.new()  # kept, but switched off: must never play
	w.spawn_mode = WaveData.SpawnMode.AROUND_PLAYER
	w.horde = [SpawnEntry.make("slime", 1.0)] as Array[SpawnEntry]
	w.enemy_count = 40
	data.waves = [w] as Array[WaveData]
	var o := ObjectiveData.new()
	o.objective_id = "purge"
	o.type = ObjectiveData.Type.ELIMINATE
	data.objectives = [o] as Array[ObjectiveData]
	arena.data = data
	for layer_name: String in Arena.LAYERS:
		var n: Node
		if layer_name == "Walls":
			n = TileMapLayer.new()
		else:
			n = Node2D.new()
			(n as Node2D).y_sort_enabled = bool(Arena.LAYERS[layer_name].get("y_sort", false))
		n.name = layer_name
		_own(arena, arena, n)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load(FLOOR)
	src.texture_region_size = Vector2i(32, 32)
	src.create_tile(Vector2i(0, 0))
	ts.add_source(src, 0)
	for layer_name: String in Arena.TERRAIN:
		var tl := TileMapLayer.new()
		tl.name = layer_name
		tl.tile_set = ts
		_own(arena, arena.get_node("Terrain"), tl)
	var fl := arena.get_node("Terrain/Floor") as TileMapLayer
	for y in 38:
		for x in 38:
			fl.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	var bounds := ArenaBounds.new()
	bounds.name = Arena.BOUNDS
	bounds.size = Vector2(38, 38) * Arena.TILE
	_own(arena, arena, bounds)
	var spawn := PlayerSpawn.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(320, 900)
	_own(arena, arena.get_node("GameplayObjects"), spawn)
	_add(arena, "guard", "slime", Vector2(320, 200), AlienMind.Kind.GUARD, 1)
	_add(arena, "buddy", "slime", Vector2(380, 200), AlienMind.Kind.WANDER, 1).wander_radius = 20.0
	_add(arena, "sleeper", "runner", Vector2(900, 300), AlienMind.Kind.SLEEP, 1)
	var pt := _add(arena, "patrol", "slime", Vector2(600, 700), AlienMind.Kind.PATROL, 2)
	pt.patrol_points = PackedVector2Array([Vector2(-120, 0), Vector2(120, 0)])
	var near := _add(arena, "near", "slime", Vector2(150, 600), AlienMind.Kind.GUARD, 2)
	near.appear = AlienPack.Appear.PLAYER_NEAR
	near.activation_radius = 140.0
	var trig := _add(arena, "trig", "runner", Vector2(900, 900), AlienMind.Kind.WANDER, 2)
	trig.appear = AlienPack.Appear.TRIGGER
	var alarm := _add(arena, "alarm", "slime", Vector2(700, 1000), AlienMind.Kind.GUARD, 2)
	alarm.appear = AlienPack.Appear.ALARM
	alarm.arrive_alert = true
	var t := ArenaTrigger.new()
	t.name = "TrigZone"
	t.object_id = "trig_zone"
	t.action = ArenaTrigger.Action.START_SPAWNERS
	t.targets = PackedStringArray(["trig"])
	t.position = Vector2(1100, 300)
	_own(arena, arena.get_node("Triggers"), t)
	var packed := PackedScene.new()
	packed.pack(arena)
	ResourceSaver.save(packed, PATH)
	arena.free()


func _add(arena: Arena, id: String, alien: String, at: Vector2, kind: int, n: int) -> AlienPack:
	var p := AlienPack.new()
	p.name = id.capitalize()
	p.object_id = id
	p.enemy_id = alien
	p.position = at
	p.routine = kind
	p.count = n
	p.facing_deg = 90.0
	p.call_radius = 100.0
	_own(arena, arena.get_node("GameplayObjects"), p)
	return p


func _own(arena: Arena, parent: Node, n: Node) -> void:
	parent.add_child(n)
	n.owner = arena


func _pack(id: String) -> AlienPack:
	return world.director.find(id) as AlienPack


func _state(pack: AlienPack) -> int:
	var e := pack.members[0] if not pack.members.is_empty() else null
	return e.mind.state if e != null and e.mind != null else -1


func _name(pack: AlienPack) -> String:
	var s := _state(pack)
	return AlienMind.State.keys()[s] if s >= 0 else "none"


func _go(at: Vector2) -> void:
	world.player.global_position = at
	world.camera.reset_smoothing()


## In a window (not headless): user://alien_pack_<tag>.png
func _shot(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://alien_pack_%s.png" % tag)


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func _until(cond: Callable, secs: float) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1
