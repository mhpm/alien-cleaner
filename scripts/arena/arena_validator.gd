class_name ArenaValidator
extends RefCounted
## Checks an Arena for problems. Arena-wide rules live here; each ArenaObject adds
## its own through `validate_arena` (so new components bring their own checks).
## Usable from the editor dock, tests and the arena runtime.
## An arena with errors is not production ready (the dock says so).

const REACH_CELL := 16.0


static func validate(arena: Arena) -> ArenaReport:
	var report := ArenaReport.new(arena)
	_structure(arena, report)
	_metadata(arena, report)
	var bounds := arena.get_bounds()
	if bounds == null:
		report.error("No Arena Bounds (add a \"Bounds\" ArenaBounds node).", arena)
	elif bounds.rotation != 0.0 or bounds.scale != Vector2.ONE:
		report.warning("Arena Bounds must not be rotated or scaled (use its size).", bounds)
	_terrain(arena, report)
	var objects := arena.objects()
	var spawns := objects.filter(func(o: ArenaObject) -> bool: return o is PlayerSpawn)
	if spawns.is_empty():
		report.error("No Player Spawn.", arena)
	var ids := {}
	for o in objects:
		var zone := o is ArenaTrigger or o is HazardArea or o is BossTrigger  # they check their own area
		if bounds != null and not zone and not o is EnemySpawner and not bounds.contains(o.global_position):
			if o is PlayerSpawn:
				report.error("Player Spawn is outside the arena bounds.", o)
			else:
				report.warning("%s is outside the arena bounds." % o.name, o)
		var want := o.arena_layer()
		var layer := arena.get_layer(want) if want != "" else null
		if layer != null and not layer.is_ancestor_of(o):
			report.info("%s is not in the %s layer." % [o.name, want], o)
		if not o.object_id.is_empty():
			if ids.has(o.object_id):
				report.error("object_id \"%s\" is used twice (%s and %s)." % [o.object_id, ids[o.object_id].name, o.name], o)
			else:
				ids[o.object_id] = o
		o.validate_arena(report, arena)
	if arena.data != null:
		_objectives(arena, report, objects)
		_waves(arena, report, objects)
		_boss(arena, report, objects)
	_android_elsewhere(arena, report, objects)
	if bounds != null and not spawns.is_empty():
		_reachability(arena, report, objects, bounds, spawns[0])
	report.info("%d objects placed." % objects.size(), arena)
	return report


static func _structure(arena: Arena, report: ArenaReport) -> void:
	for path in arena.missing_layers():
		if path == Arena.BOUNDS:
			continue  # reported with its own message
		report.warning("Missing layer \"%s\" (dock: Repair Structure)." % path, arena)


static func _metadata(arena: Arena, report: ArenaReport) -> void:
	if arena.data == null:
		report.error("The arena has no ArenaData (dock: Arena Settings).", arena)
		return
	if arena.data.arena_id.strip_edges().is_empty():
		report.warning("Arena ID is empty (dock: Arena Settings).", arena)
	if arena.data.display_name.strip_edges().is_empty():
		report.info("Arena has no display name.", arena)


static func _terrain(arena: Arena, report: ArenaReport) -> void:
	var floor_layer := arena.get_layer("Floor") as TileMapLayer
	if floor_layer != null and floor_layer.get_used_cells().is_empty():
		report.warning("The floor is not painted yet (TERRAIN > Floor).", floor_layer)
	var walls := arena.get_layer("Walls") as TileMapLayer
	if walls != null and walls.get_used_cells().is_empty():
		report.info("No walls painted: only the bounds keep everyone inside.", walls)
	for layer_name: String in Arena.TERRAIN + ["Walls"]:
		var layer := arena.get_layer(layer_name) as TileMapLayer
		if layer != null and layer.tile_set == null:
			report.warning("Terrain layer %s has no TileSet." % layer_name, layer)


static func _count(objects: Array[ArenaObject], cls: String) -> int:
	return objects.filter(func(o: ArenaObject) -> bool: return ArenaDirector.is_a(o, cls)).size()


static func _objectives(arena: Arena, report: ArenaReport, objects: Array[ArenaObject]) -> void:
	var list := arena.data.objectives.filter(func(o: ObjectiveData) -> bool: return o != null)
	if list.is_empty():
		report.warning("No objectives: the arena can only be lost (dock: MISSIONS).", arena)
		return
	if not list.any(func(o: ObjectiveData) -> bool: return not o.optional):
		report.error("No MAIN objective: the arena can never be won.", arena)
	if list.size() > 4:
		report.info("%d objectives: the HUD reads best with 3-4." % list.size(), arena)
	var seen := {}
	for od: ObjectiveData in list:
		var tag := "Objective \"%s\"" % od.objective_id
		if seen.has(od.objective_id):
			report.error("%s: objective_id used twice." % tag, arena)
		seen[od.objective_id] = true
		for id in od.required_object_ids:
			if arena.find_object(id) == null:
				report.error("%s references missing object \"%s\"." % [tag, id], arena)
		if od.target_count > 0 or not od.required_object_ids.is_empty():
			continue
		var cls: String = ObjectiveData.OBJECT_CLASSES.get(od.type, "")
		match od.type:
			ObjectiveData.Type.COLLECT:
				if _count(objects, "AndroidPart") + _count(objects, "ArenaChest") == 0:
					report.error("%s (COLLECT): there is nothing to collect." % tag, arena)
			ObjectiveData.Type.BOSS:
				if _count(objects, "BossTrigger") == 0 and not arena.data.waves.any(func(w: WaveData) -> bool: return w != null and not w.boss_id.is_empty()):
					report.error("%s (BOSS): no BossTrigger and no wave brings a boss." % tag, arena)
			ObjectiveData.Type.CLEAR_WAVES:
				if arena.data.waves.is_empty():
					report.error("%s (CLEAR_WAVES): the arena has no waves." % tag, arena)
			ObjectiveData.Type.ESCORT:
				if not objects.any(func(o: ArenaObject) -> bool: return o is ArenaSurvivor and not (o as ArenaSurvivor).escort_to.is_empty()):
					report.error("%s (ESCORT): no survivor has escort_to set." % tag, arena)
			_:
				if not cls.is_empty() and _count(objects, cls) == 0:
					report.error("%s (%s): no %s in the arena." % [tag, ObjectiveData.Type.keys()[od.type], cls], arena)


static func _waves(arena: Arena, report: ArenaReport, objects: Array[ArenaObject]) -> void:
	var i := 0
	for w: WaveData in arena.data.waves:
		i += 1
		if w == null:
			report.error("Wave %d is empty (null)." % i, arena)
			continue
		var spawners := objects.filter(func(o: ArenaObject) -> bool: return o is EnemySpawner and (o as EnemySpawner).wave_id == w.wave_id)
		var horde := w.spawn_mode != WaveData.SpawnMode.SPAWNERS
		if horde and w.horde.is_empty():
			report.error("Wave %d (%s): spawn mode %s but its horde list is empty." % [i, w.wave_id, WaveData.SpawnMode.keys()[w.spawn_mode]], arena)
		if horde and w.completion == WaveData.Completion.ALL_ENEMIES_DEAD and (w.enemy_count == 0 or w.spawn_mode == WaveData.SpawnMode.BOTH):
			report.error("Wave %d (%s): an endless horde never lets ALL_ENEMIES_DEAD finish (set enemy_count, AROUND_PLAYER)." % [i, w.wave_id], arena)
		var around := w.spawn_mode == WaveData.SpawnMode.AROUND_PLAYER
		if not around and spawners.is_empty() and w.boss_id.is_empty() and w.completion == WaveData.Completion.ALL_ENEMIES_DEAD:
			report.error("Wave %d (%s): no spawner has this wave_id and no boss: it ends at once." % [i, w.wave_id], arena)
		if not around and w.completion == WaveData.Completion.ALL_ENEMIES_DEAD and w.enemy_count == 0 \
				and spawners.any(func(o: ArenaObject) -> bool: return (o as EnemySpawner).spawn_count == 0):
			report.error("Wave %d (%s): an endless spawner (count 0) never lets ALL_ENEMIES_DEAD finish." % [i, w.wave_id], arena)
		if w.completion == WaveData.Completion.SURVIVE_TIME and w.target <= 0.0:
			report.error("Wave %d (%s): SURVIVE_TIME needs a target (seconds)." % [i, w.wave_id], arena)
		if w.completion == WaveData.Completion.BOSS_DEFEATED and w.boss_id.is_empty():
			if objects.any(func(o: ArenaObject) -> bool: return o is BossTrigger):
				report.info("Wave %d (%s) ends when a BossTrigger's boss falls." % [i, w.wave_id], arena)
			else:
				report.error("Wave %d (%s): BOSS_DEFEATED, but it brings no boss and there is no BossTrigger." % [i, w.wave_id], arena)
		if not w.boss_id.is_empty() and not EnemyData.TYPES.has(w.boss_id):
			report.error("Wave %d: unknown boss \"%s\"." % [i, w.boss_id], arena)


static func _boss(arena: Arena, report: ArenaReport, objects: Array[ArenaObject]) -> void:
	var id := arena.data.boss_id
	if id.is_empty():
		return
	var via_trigger := objects.any(func(o: ArenaObject) -> bool: return o is BossTrigger and (o as BossTrigger).boss_id == id)
	var via_wave := arena.data.waves.any(func(w: WaveData) -> bool: return w != null and w.boss_id == id)
	if not via_trigger and not via_wave:
		report.error("Arena boss \"%s\" has no BossTrigger and no wave that brings it." % id, arena)


## Android part ids must be unique in the whole game: look into the other arena scenes.
static func _android_elsewhere(arena: Arena, report: ArenaReport, objects: Array[ArenaObject]) -> void:
	var mine := {}
	for o in objects:
		if o is AndroidPart and not (o as AndroidPart).part_id.is_empty():
			mine[(o as AndroidPart).part_id] = o
	if mine.is_empty():
		return
	var dir := DirAccess.open("res://scenes/arenas/")
	if dir == null:
		return
	for file in dir.get_files():
		var path := "res://scenes/arenas/" + file
		if not file.ends_with(".tscn") or path == arena.scene_file_path:
			continue
		var text := FileAccess.get_file_as_string(path)
		for pid: String in mine:
			if text.contains("part_id = \"%s\"" % pid):
				report.error("Android part \"%s\" is also in %s (ids must be unique)." % [pid, file], mine[pid])


## Flood fill from the Player Spawn over a 16-unit grid of the bounds, blocked by
## painted wall tiles (with collision) and props. Doors count as open (they can open).
static func _reachability(arena: Arena, report: ArenaReport, objects: Array[ArenaObject], bounds: ArenaBounds, spawn: ArenaObject) -> void:
	var r := bounds.global_rect()
	var cols := ceili(r.size.x / REACH_CELL)
	var rows := ceili(r.size.y / REACH_CELL)
	if cols * rows > 1100000:
		return
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)
	var rects: Array[Rect2] = []
	var bridges: Array[Rect2] = []
	for o in objects:
		if o is ArenaScenery and (o as ArenaScenery).bridge:
			bridges.append((o as ArenaScenery).cover_rect())
	var mark := func(p: Vector2) -> void:
		var q := Vector2i(((p - r.position) / REACH_CELL).floor())
		if q.x >= 0 and q.y >= 0 and q.x < cols and q.y < rows:
			blocked[q.y * cols + q.x] = 1
	# terrain with collision (walls, water...): the real polygons, sampled every 8 units;
	# the cells a bridge opens (same rule as ArenaScenery.open_terrain) are left free
	for layer_name: String in Arena.TERRAIN + ["Walls"]:
		var layer := arena.get_layer(layer_name) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var opened := {}
		for br in bridges:
			var a := layer.local_to_map(layer.to_local(br.position))
			var b := layer.local_to_map(layer.to_local(br.end))
			for y in range(a.y, b.y + 1):
				for x in range(a.x, b.x + 1):
					opened[Vector2i(x, y)] = true
		var ts := Vector2(layer.tile_set.tile_size)
		for c in layer.get_used_cells():
			if opened.has(c):
				continue
			var td := layer.get_cell_tile_data(c)
			if td == null or td.get_collision_polygons_count(0) == 0:
				continue
			var polys: Array[PackedVector2Array] = []
			for k in td.get_collision_polygons_count(0):
				polys.append(td.get_collision_polygon_points(0, k))
			var center := layer.map_to_local(c)
			var steps := 8
			for sy in steps:
				for sx in steps:
					var local := Vector2((sx + 0.5) / steps - 0.5, (sy + 0.5) / steps - 0.5) * ts
					if polys.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(local, poly)):
						mark.call(layer.to_global(center + local))
	for o in objects:
		if o is ArenaProp and PropData.PROPS.has((o as ArenaProp).prop_id):
			var box: Vector2 = PropData.PROPS[(o as ArenaProp).prop_id].box
			rects.append(Rect2(o.global_position - Vector2(box.x * 0.5, box.y), box).grow(-1.0))
		elif o is ArenaScenery and (o as ArenaScenery).footprint.x > 0.0:
			var fp := (o as ArenaScenery).footprint
			rects.append(Rect2(o.global_position - Vector2(fp.x * 0.5, fp.y), fp).grow(-1.0))
	for rect in rects:
		var a := ((rect.position - r.position) / REACH_CELL).floor()
		var b := ((rect.end - r.position) / REACH_CELL).ceil()
		for y in range(maxi(0, int(a.y)), mini(rows, int(b.y))):
			for x in range(maxi(0, int(a.x)), mini(cols, int(b.x))):
				blocked[y * cols + x] = 1
	var start := Vector2i(((spawn.global_position - r.position) / REACH_CELL).floor())
	start = start.clamp(Vector2i.ZERO, Vector2i(cols - 1, rows - 1))
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	var queue: Array[Vector2i] = [start]
	seen[start.y * cols + start.x] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			var k := n.y * cols + n.x
			if seen[k] == 1 or blocked[k] == 1:
				continue
			seen[k] = 1
			queue.append(n)
	for o in objects:
		var goal := o is ArenaExit or o is ArenaSurvivor or o is AndroidPart or o is AlienNest or o is ArenaChest or o is DefendCore \
				or (o is ArenaTrigger and (o as ArenaTrigger).action in [ArenaTrigger.Action.REACH_LOCATION, ArenaTrigger.Action.ACTIVATE])
		if not goal:
			continue
		var cell := Vector2i(((o.global_position - r.position) / REACH_CELL).floor())
		if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
			continue
		var ok := false
		for dy in range(-2, 3):  # standing next to it is enough
			for dx in range(-2, 3):
				var q := cell + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < cols and q.y < rows and seen[q.y * cols + q.x] == 1:
					ok = true
		if not ok:
			if o is ArenaExit:
				report.error("Exit %s is unreachable from the Player Spawn." % o.name, o)
			else:
				report.warning("%s is unreachable from the Player Spawn (walled in?)." % o.name, o)
