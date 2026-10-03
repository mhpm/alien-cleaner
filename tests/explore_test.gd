extends Node
## World 1 EXPLORE prototype: the grid of painted rooms, its walls and chests are built;
## aliens never spawn inside a wall or furniture; standing next to a chest for
## ChestData.OPEN_TIME opens it and applies its perk.

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(5)
	var ex := w.explore
	_check(ex != null, "World 1 must build its Explore layer")
	if ex == null:
		_finish()
		return
	_check(w.room.room_w * w.room.room_h >= 1024.0 * 1536.0 * 1.8, "World 1 map must be about twice as big")
	_check(ex.rooms.size() == 12 and ex.walls.size() > 100, "3x4 rooms with walls and furniture")
	_check(ex.chests.size() == 8, "8 chests (got %d)" % ex.chests.size())
	_check(w.room.is_open(w.player.global_position), "Player starts in the open")
	for c in ex.chests:
		_check(w.room.is_open(c.global_position, 4.0), "Chest not inside a bulkhead")
	w.player.invuln = 99999.0
	# aliens spawned anywhere end up in the open
	for i in 40:
		var r: Rect2 = ex.walls[i % ex.walls.size()]
		var e := w.spawn_enemy("slime", r.get_center())
		_check(w.room.is_open(e.position), "Alien spawned inside a bulkhead")
	# open a chest
	var chest: SupplyChest = ex.chests[0]
	var before := Game.stats.duplicate()
	w.player.global_position = chest.global_position + Vector2(0, 6)
	await _frames(20)
	_check(not chest.opened and chest.progress > 0.0, "Chest fills while you stand by it")
	await _frames(int(ChestData.OPEN_TIME * 60.0) + 20)
	_check(chest.opened, "Chest opens after %.0f s" % ChestData.OPEN_TIME)
	_check(ex.opened == 1, "Counter counts it")
	var changed := false
	for k: String in before:
		if str(before[k]) != str(Game.stats[k]):
			changed = true
	_check(changed or str(ChestData.CHESTS[chest.kind].id) == "treasure", "Perk applied: " + str(ChestData.CHESTS[chest.kind].id))
	print("  opened %s -> %s" % [ChestData.CHESTS[chest.kind].name, ChestData.CHESTS[chest.kind].desc])
	# rescue a survivor: 10 s next to them (no level-up modal may pause the clock meanwhile)
	w.survival.process_mode = Node.PROCESS_MODE_DISABLED
	w.hud._close_overlay()
	get_tree().paused = false
	_check(ex.survivors.size() == 5, "5 survivors to rescue (got %d)" % ex.survivors.size())
	var sv: Survivor = ex.survivors[0]
	var dmg0 := float(Game.stats.damage)
	var spd0 := float(Game.stats.move_speed)
	w.player.global_position = sv.global_position + Vector2(0, 6)
	await _frames(int(SurvivorData.RESCUE_TIME * 0.5 * 60.0))
	_check(not sv.saved and sv.progress > 0.4, "Rescue fills while you stay")
	await _frames(int(SurvivorData.RESCUE_TIME * 0.5 * 60.0) + 30)
	_check(sv.saved and ex.rescued == 1, "Survivor rescued after %.0f s" % SurvivorData.RESCUE_TIME)
	print("  rescued %s -> %s" % [SurvivorData.CREW[sv.kind].name, SurvivorData.CREW[sv.kind].gift])
	await _frames(200)
	_check(not is_instance_valid(sv), "Rescued survivor beams out")
	await _maze_check()
	_finish()


## World 3: a maze of rooms (every room reachable through open doorways, not all open)
## with kit pieces in the middle, and nobody starts inside one.
func _maze_check() -> void:
	for n in get_children():
		n.queue_free()
	await _frames(3)
	Game.new_run(2)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(5)
	var ex := w.explore
	_check(ex != null and ex.set_id == "w3", "World 3 builds its explore map")
	if ex == null:
		return
	var all := ex.cols * (ex.rows - 1) + ex.rows * (ex.cols - 1)
	_check(ex.links.size() >= ex.cols * ex.rows - 1 and ex.links.size() < all, "Maze: tree plus some doorways (%d of %d)" % [ex.links.size(), all])
	var seen := {ex.start_cell: true}
	var todo: Array[Vector2i] = [ex.start_cell]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nb: Vector2i = c + d
			if not seen.has(nb) and nb.x >= 0 and nb.y >= 0 and nb.x < ex.cols and nb.y < ex.rows and ex.linked(c, nb):
				seen[nb] = true
				todo.append(nb)
	_check(seen.size() == ex.cols * ex.rows, "Every room reachable")
	var pieces := 0
	for n in w.room.spawned:
		if n is Sprite2D:
			pieces += 1
	_check(pieces > 10, "Kit pieces in the rooms (%d)" % pieces)
	_check(w.room.is_open(w.player.global_position), "World 3 start in the open")
	for c in ex.chests:
		_check(w.room.is_open(c.global_position, 2.0), "World 3 chest in the open")


func _finish() -> void:
	if failures.is_empty():
		print("EXPLORE_TEST: PASS (rooms, walls, chests, spawns, opening, perk, rescue, maze)")
	else:
		print("EXPLORE_TEST: FAIL ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
