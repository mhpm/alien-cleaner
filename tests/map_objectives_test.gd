extends Node
## The world objectives as Arena Editor objects (for maps made in the editor): a small
## arena in memory with an ArenaSeedTank, ArenaReactorCore, ArenaWarpCell, an
## ArenaAnchoredAlien vat and egg cluster and an ArenaBlocker, played with the real game:
## each comes alive (its game object, anchored aliens, solid feet, the blocker's box), and
## Explore's counters take them (add_tank / add_core / add_vat / add_warp_cell).
##   godot --headless --path . res://tests/map_objectives_test.tscn

const PATH := "user://map_objectives_test_arena.tscn"
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
	await _wait(0.5)
	var tanks := get_tree().get_nodes_in_group("seed_tanks")
	var cores := get_tree().get_nodes_in_group("reactor_cores")
	var cells := get_tree().get_nodes_in_group("warp_cells")
	_check(tanks.size() == 1 and (tanks[0] as Node2D).global_position.distance_to(_at("tank")) < 1.0, "the seed tank came alive where it was placed")
	_check(cores.size() == 1 and (cores[0] as Node2D).global_position.distance_to(_at("core")) < 1.0, "the reactor core came alive")
	_check(cells.size() == 1, "the warp cell came alive")
	var vat: Enemy = null
	var egg: Enemy = null
	for n in world.enemy_cache:
		var e := n as Enemy
		if e.type_id == "specimen_vat":
			vat = e
		elif e.type_id == "egg_cluster":
			egg = e
	_check(vat != null and vat.anchored and vat.global_position.distance_to(_at("vat")) < 1.0, "the specimen vat is an anchored alien where it was placed")
	_check(egg != null and egg.anchored, "the egg cluster too")
	var space := world.get_world_2d().direct_space_state
	for id in ["tank", "core", "blocker"]:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = _at(id) + Vector2(0, -4 if id != "blocker" else 0)
		q.collision_mask = 1
		_check(not space.intersect_point(q, 1).is_empty(), "%s is solid" % id)
	# Explore takes them into its counters
	var ex := Explore.new()
	ex.add_tank(tanks[0] as SeedTank)
	ex.add_core(cores[0] as ReactorCore)
	ex.add_warp_cell(cells[0] as WarpCell)
	ex.add_vat(vat)
	_check(ex.tanks.size() == 1 and ex.cores.size() == 1 and ex.warp_cells.size() == 1 and ex.vats.size() == 1,
		"Explore counts them (tanks, cores, cells, vats)")
	_check(ex.props.size() == 2, "the boss ring knows the tank and the core (%d)" % ex.props.size())
	ex.free()
	print("MAP OBJECTIVES TEST: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _at(id: String) -> Vector2:
	var o := world.arena.find_object(id)
	if o != null and o.is_inside_tree():
		return o.global_position
	return world.arena.global_position + (_spots[id] as Vector2)


var _spots := {"spawn": Vector2(600, 900), "tank": Vector2(300, 300), "core": Vector2(900, 300),
	"cell": Vector2(300, 700), "vat": Vector2(900, 700), "egg": Vector2(600, 500), "blocker": Vector2(600, 1100)}


func _save_arena() -> void:
	var arena := Arena.new()
	arena.name = "Arena"
	var data := ArenaData.new()
	data.arena_id = "map_objectives_test"
	data.start_delay = 0.5
	data.minimap = false
	data.waves_enabled = false
	arena.data = data
	for layer_name: String in Arena.LAYERS:
		var n: Node = TileMapLayer.new() if layer_name == "Walls" else Node2D.new()
		if n is Node2D and not n is TileMapLayer:
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
	for y in 40:
		for x in 40:
			fl.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	var bounds := ArenaBounds.new()
	bounds.name = Arena.BOUNDS
	bounds.size = Vector2(1280, 1280)
	_own(arena, arena, bounds)
	var gp := arena.get_node("GameplayObjects")
	var ps := PlayerSpawn.new()
	ps.name = "PlayerSpawn"
	ps.position = _spots.spawn
	_own(arena, gp, ps)
	var objs := {"tank": ArenaSeedTank.new(), "core": ArenaReactorCore.new(), "cell": ArenaWarpCell.new(),
		"vat": ArenaAnchoredAlien.new(), "egg": ArenaAnchoredAlien.new()}
	(objs.egg as ArenaAnchoredAlien).kind = ArenaAnchoredAlien.Kind.EGG_CLUSTER
	for id: String in objs:
		var o: ArenaObject = objs[id]
		o.name = id.capitalize()
		o.object_id = id
		o.position = _spots[id]
		_own(arena, gp, o)
	var b := ArenaBlocker.new()
	b.name = "Blocker"
	b.object_id = "blocker"
	b.size = Vector2(120, 40)
	b.position = _spots.blocker
	_own(arena, arena.get_node("Obstacles"), b)
	var packed := PackedScene.new()
	packed.pack(arena)
	ResourceSaver.save(packed, PATH)
	arena.free()


func _own(root: Node, parent: Node, n: Node) -> void:
	parent.add_child(n)
	n.owner = root


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
