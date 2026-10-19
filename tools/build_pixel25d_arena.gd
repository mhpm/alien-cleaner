extends Node
## Builds the pixel 2.5D prototype arena: scenes/arenas/arena_proto_pixel25d.tscn
## ("Pixel Lab 2.5D"), played by scenes/prototype_pixel25d.tscn (low-res render).
##   python tools/make_pixel25d_kit.py      (pieces from tools/pixel25d_kit_ref.webp)
## Every piece also sits in the editor palette: OBJECTS > "Pixel Lab · Walls", "· Lab"...
##   godot --headless --path . res://tools/build_pixel25d_arena.tscn
## 1 art pixel = 1 world unit. Walls are 3/4 blocks (cap + 42 px brick face) placed as
## y-sorted ArenaScenery with their feet on the floor: the astronaut walks behind the
## partition, the lower wall and the tall machines (they fade). Three rooms: the
## specimen lab (top), the storage bay with an alien breach (middle) and the office
## (bottom), watched by five SecurityCameras whose light cones sweep the floor.

const PATH := "res://scenes/arenas/arena_proto_pixel25d.tscn"
const KIT := "res://assets/decor/pixel_lab/"  # the pieces (Arena Editor kit "Pixel Lab")
const FLOOR_TEX := "res://assets/arena/pixel25d/floor.png"
## The camera in the editor palette (OBJECTS > Gameplay > Security Camera), made here too.
const PALETTE_CAMERA := "res://scenes/arena/palette/gameplay/security_camera.tscn"
const COLS := 20
const ROWS := 28
const TOP := 64.0  # feet of the upper wall (its cap and face rise above)
const SIDE := 32.0  # side walls
const FIRST_SIDE := TOP + 20.0  # first side-wall piece: its cap meets the upper wall's
const BOTTOM := FIRST_SIDE + 32.0 * 24  # feet of the lower wall (852)
const PARTITION := 360.0
const DOOR := Vector2(256, 384)  # doorway in the partition (x from, x to)
const RAILS := 624.0  # low rails between the storage bay and the office

var arena: Arena
var rng := RandomNumberGenerator.new()
var _paths: Dictionary = {}  # piece name -> res:// path inside the kit
var _floor_set: TileSet  # embedded in the arena scene (no .tres for the editor to keep stale)


func _ready() -> void:
	# the arena is now retouched by hand in the editor: never overwrite it (delete it
	# yourself first to start over). Additions go through tools/add_pixel25d_maze.py style
	# scripts that only append.
	if FileAccess.file_exists(PATH) and not "--force" in OS.get_cmdline_user_args():
		print("PIXEL 2.5D ARENA: %s exists and is edited by hand; not rebuilt (pass -- --force)" % PATH)
		get_tree().quit()
		return
	rng.seed = 25
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
	_floor()
	_walls()
	_lab()
	_storage()
	_office()
	_cameras()
	var spawn := PlayerSpawn.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(320, 800)
	_add(arena.get_layer("GameplayObjects"), spawn)
	_palette_camera()
	var packed := PackedScene.new()
	var err := packed.pack(arena)
	if err == OK:
		err = ResourceSaver.save(packed, PATH)
	print("PIXEL 2.5D ARENA: %s -> %s" % [error_string(err), PATH])
	arena.scene_file_path = PATH
	add_child(arena)
	var report := ArenaValidator.validate(arena)
	print("PIXEL 2.5D ARENA VALIDATION: " + report.summary())
	for i in report.issues:
		print("  ", ["INFO", "WARNING", "ERROR"][i.severity], "  ", i.message)
	arena.free()
	get_tree().quit()


func _data() -> ArenaData:
	var d := ArenaData.new()
	d.arena_id = "proto_pixel25d"
	d.display_name = "Pixel Lab 2.5D"
	d.description = "Prototype: pixel 2.5D lab with 3/4 walls, y-sorted props, security cameras and a low-res render."
	d.world_id = 1
	d.environment = "Pixel prototype"
	d.start_delay = 2.0
	d.minimap = false
	d.background = Color("0d0f1a")
	var w1 := WaveData.new()
	w1.wave_id = "w1"
	w1.title = "PIXEL PURGE"
	w1.spawn_mode = WaveData.SpawnMode.AROUND_PLAYER
	w1.horde = [SpawnEntry.make("slime", 60.0), SpawnEntry.make("runner", 40.0)] as Array[SpawnEntry]
	w1.horde_alive = 18
	w1.enemy_count = 30
	var w2 := WaveData.new()
	w2.wave_id = "w2"
	w2.title = "HOLD THE LAB"
	w2.spawn_mode = WaveData.SpawnMode.AROUND_PLAYER
	w2.horde = [SpawnEntry.make("slime", 40.0), SpawnEntry.make("runner", 30.0),
		SpawnEntry.make("spitter", 15.0), SpawnEntry.make("splitter", 15.0)] as Array[SpawnEntry]
	w2.horde_alive = 30
	w2.completion = WaveData.Completion.SURVIVE_TIME
	w2.target = 60.0
	d.waves = [w1, w2] as Array[WaveData]
	var main := ObjectiveData.new()
	main.objective_id = "clear"
	main.type = ObjectiveData.Type.CLEAR_WAVES
	main.title = "Clear the pixel lab"
	d.objectives = [main] as Array[ObjectiveData]
	return d


func _layer(layer_name: String) -> Node:
	if layer_name in Arena.TERRAIN or layer_name == "Walls":
		var tl := TileMapLayer.new()
		tl.name = layer_name
		tl.tile_set = _tileset()
		tl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return tl
	var n := Node2D.new()
	n.name = layer_name
	n.y_sort_enabled = bool(Arena.LAYERS.get(layer_name, {}).get("y_sort", false))
	return n


## 32 px pixel floor tiles (scale 1: one tile = Arena.TILE world units), shared by the layers.
func _tileset() -> TileSet:
	if _floor_set != null:
		return _floor_set
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	ts.add_physics_layer()  # empty: the floor never blocks (the validator reads layer 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(FLOOR_TEX)
	src.texture_region_size = Vector2i(32, 32)
	for y in 2:
		for x in 4:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	_floor_set = ts
	return ts


func _add(parent: Node, node: Node) -> Node:
	parent.add_child(node)
	node.owner = arena
	return node


## The drawn floor: mostly plain and scuffed plates, a few vents and cracks, goo near
## the walls and around the breach in the storage bay.
func _floor() -> void:
	var fl := arena.get_layer("Floor") as TileMapLayer
	for y in ROWS:
		for x in COLS:
			var t := Vector2i(0, 0) if rng.randf() < 0.55 else Vector2i(1, 0)
			var edge := x <= 1 or x >= COLS - 2 or y <= 2
			var r := rng.randf()
			if r < 0.012:
				t = Vector2i(2, 0)
			elif r < 0.035:
				t = Vector2i(0, 1)
			elif r < 0.07:
				t = Vector2i(2, 1)
			elif edge and r < 0.18:
				t = Vector2i(1, 1)
			fl.set_cell(Vector2i(x, y), 0, t)
	for c: Vector2i in [Vector2i(9, 15), Vector2i(10, 15), Vector2i(11, 15), Vector2i(10, 14), Vector2i(9, 16), Vector2i(10, 16)]:
		fl.set_cell(c, 0, Vector2i(1, 1))  # goo around the breach


func _tex(tex_name: String) -> Texture2D:
	if _paths.is_empty():
		for sub in DirAccess.get_directories_at(KIT):
			for f in DirAccess.get_files_at(KIT + sub):
				if f.ends_with(".png"):
					_paths[f.get_basename()] = KIT + sub + "/" + f
	return load(_paths[tex_name])


func _piece(tex: String, at: Vector2, foot := Vector2.ZERO, fade := false, flat := false, flip := false) -> ArenaScenery:
	var s := ArenaScenery.new()
	s.name = tex.to_pascal_case()
	s.pixel_art = true
	s.texture = _tex(tex)
	s.width = float(s.texture.get_width())
	s.flip_h = flip
	s.position = at
	s.footprint = foot
	s.blocks_bullets = foot != Vector2.ZERO
	s.fade_behind = fade
	s.flat = flat
	_add(arena.get_layer(s.arena_layer()), s)
	return s


## A run of wall pieces from x0 to x1 with their feet at `y` (the long ones first,
## the short one to finish; the last piece is pushed back so the run ends exactly at x1).
func _wall_run(x0: float, x1: float, y: float, fade: bool, shadow: bool) -> void:
	var longs := ["wall_a", "wall_c", "wall_b", "wall_d"]
	var x := x0
	var n := rng.randi_range(0, 3)
	while x1 - x > 0.5:
		var tex: String = longs[n % longs.size()] if x1 - x >= 76.0 else "wall_s"
		n += 1
		var w := float(_tex(tex).get_width())
		var left := minf(x, x1 - w)
		_piece(tex, Vector2(left + w * 0.5, y), Vector2(w, 12), fade)
		if shadow:
			var sx := left + 16.0
			while sx < left + w:
				_piece("wall_shadow", Vector2(sx, y + 8), Vector2.ZERO, false, true)
				sx += 32.0
		x = left + w


func _walls() -> void:
	var right := COLS * Arena.TILE - SIDE
	_wall_run(SIDE, right, TOP, false, true)
	_wall_run(SIDE, right, BOTTOM, true, false)
	var y := FIRST_SIDE
	while y <= BOTTOM:  # side walls: caps seen from above, the brick face where they end
		for sx: float in [SIDE * 0.5, COLS * Arena.TILE - SIDE * 0.5]:
			_piece("side_wall_end" if y >= BOTTOM else "side_wall", Vector2(sx, y), Vector2(32, 32), true)
		y += 32.0
	_wall_run(SIDE, DOOR.x, PARTITION, true, true)
	_wall_run(DOOR.y, right, PARTITION, true, true)
	# low rails between the storage bay and the office (bullets fly over them)
	for r: Array in [["rail_b", 112.0], ["rail_a", 206.0], ["rail_b", 528.0]]:
		var s := _piece(r[0], Vector2(r[1], RAILS), Vector2.ZERO, false)
		s.footprint = Vector2(s.width - 4.0, 8)
		s.blocks_bullets = false


## A standing prop: footprint at its base, fades when the astronaut walks behind it,
## a flat pixel shadow on the floor.
func _thing(tex: String, at: Vector2, flip := false) -> ArenaScenery:
	var s := _piece(tex, at, Vector2.ZERO, true, false, flip)
	s.footprint = Vector2(maxf(8.0, s.width - 6.0), clampf(s.width * 0.3, 6.0, 12.0))
	s.blocks_bullets = true
	var sh := "shadow_l" if s.width > 34.0 else ("shadow_m" if s.width > 18.0 else "shadow_s")
	_piece(sh, at + Vector2(3, 3), Vector2.ZERO, false, true)
	return s


func _decal(tex: String, at: Vector2, flip := false) -> void:
	_piece(tex, at, Vector2.ZERO, false, true, flip)


## Specimen lab: tubes and server racks along the wall, a broken tube leaking goo.
func _lab() -> void:
	_thing("tube_big", Vector2(70, 112))
	_thing("tube_tall", Vector2(118, 104))
	_thing("tube_mid", Vector2(152, 98))
	_thing("console_big", Vector2(262, 104))
	_thing("rack_a", Vector2(330, 98))
	_thing("rack_b", Vector2(356, 98))
	_thing("rack_c", Vector2(382, 98))
	_thing("terminal_a", Vector2(522, 98))
	_thing("tube_s", Vector2(560, 96))
	_thing("tube_s3", Vector2(588, 98))
	_thing("desk_lab", Vector2(170, 236))
	_thing("machine", Vector2(450, 230))
	_thing("cell_blue", Vector2(512, 250))
	_thing("tube_dark", Vector2(540, 258))
	_thing("pipe_drop", Vector2(84, 300))
	_decal("goo_e", Vector2(470, 286))
	_decal("goo_xs", Vector2(548, 276))
	_decal("vent_c", Vector2(300, 190))
	_decal("vent_a", Vector2(560, 180))
	for x: float in [282.0, 320.0, 358.0]:  # hazard marks across the doorway
		_decal(["hazard_a", "hazard_b", "hazard_c"][rng.randi_range(0, 2)], Vector2(x, PARTITION + 22))


## Storage bay: crate stacks on both sides, the alien breach in the middle (hole, goo,
## rubble), pipes and a goo trench.
func _storage() -> void:
	_thing("crate_big", Vector2(78, 440))
	_thing("crate_a", Vector2(116, 448))
	_thing("box_a", Vector2(70, 486))
	_thing("box_b", Vector2(104, 494))
	_thing("box_s", Vector2(132, 500))
	_thing("box_xs", Vector2(150, 506))
	_thing("crate_c", Vector2(520, 440))
	_thing("tank_pair", Vector2(566, 452))
	_thing("case", Vector2(500, 486))
	_thing("barrel", Vector2(592, 500))
	_thing("crate_blue", Vector2(540, 506))
	_thing("pipe_bend", Vector2(232, 560))
	_thing("pipe_tall", Vector2(420, 556))
	_decal("goo_b", Vector2(300, 500))
	_decal("goo_c", Vector2(352, 520))
	_decal("goo_a", Vector2(318, 470))
	_decal("goo_s", Vector2(270, 520))
	_decal("goo_xs2", Vector2(370, 470))
	_decal("rubble", Vector2(372, 506))
	_decal("rocks", Vector2(286, 474))
	_decal("rocks_s", Vector2(362, 538))
	var x := 40.0
	while x < COLS * Arena.TILE - 40.0:  # the goo trench across the bay
		_decal("trench", Vector2(x + 66.0, 596))
		x += 133.0


## Office: desks and terminals, plants by the lower wall, lockers.
func _office() -> void:
	_thing("locker_a", Vector2(48, 700))
	_thing("locker_b", Vector2(70, 700))
	_thing("desk_pc", Vector2(140, 700))
	_thing("desk_papers", Vector2(196, 704))
	_thing("desk_cups", Vector2(444, 704))
	_thing("terminal_b", Vector2(500, 700))
	_thing("printer", Vector2(546, 700))
	_thing("toolbox", Vector2(590, 712))
	_thing("plant_a", Vector2(56, 836))
	_thing("plant_b", Vector2(150, 836))
	_thing("plant_c", Vector2(490, 836))
	_thing("plant_d", Vector2(584, 836))
	_decal("grate_red", Vector2(420, 790))
	_decal("vent_x", Vector2(220, 780))


## The palette preset: a dome camera on a wall, looking down, calling runners and slimes.
func _palette_camera() -> void:
	var cam := _camera("cam_dome", 90.0, false, 24.0, 140.0)
	cam.name = "SecurityCamera"
	var packed := PackedScene.new()
	var err := packed.pack(cam)
	if err == OK:
		err = ResourceSaver.save(packed, PALETTE_CAMERA)
	print("PALETTE CAMERA: %s -> %s" % [error_string(err), PALETTE_CAMERA])
	cam.free()


func _camera(tex: String, facing: float, flip: bool, mount: float, reach: float) -> SecurityCamera:
	var cam := SecurityCamera.new()
	cam.pixel_art = true
	cam.texture = _tex(tex)
	cam.width = float(cam.texture.get_width())
	cam.flip_h = flip
	cam.facing_deg = facing
	cam.mount_height = mount
	cam.view_range = reach
	cam.alarm_squad = [SpawnEntry.make("runner", 60.0), SpawnEntry.make("slime", 40.0)] as Array[SpawnEntry]
	return cam


## Five cameras: two over the lab, one over the bay, two on the side walls.
func _cameras() -> void:
	var cams := [
		# [texture, feet, facing, flip, mount height, range]
		["cam_dome", Vector2(206, TOP + 1), 90.0, false, 24.0, 150.0],
		["cam_dome", Vector2(450, TOP + 1), 90.0, false, 24.0, 150.0],
		["cam_dome", Vector2(500, PARTITION + 1), 90.0, false, 24.0, 140.0],
		["cam_mount", Vector2(SIDE + 6, 560), 0.0, true, 34.0, 140.0],
		["cam_wall", Vector2(COLS * Arena.TILE - SIDE - 8, 760), 180.0, false, 34.0, 140.0],
	]
	for i in cams.size():
		var c: Array = cams[i]
		var cam := _camera(c[0], c[2], c[3], c[4], c[5])
		cam.name = "SecurityCamera%d" % (i + 1)
		cam.object_id = "cam_%d" % (i + 1)
		cam.position = c[1]
		_add(arena.get_layer(cam.arena_layer()), cam)
