extends "res://tools/arena_map_builder.gd"
## Builds world 8's map ONCE as an Arena Editor scene:
##   scenes/arenas/arena_world_08_level_01.tscn  "Biodome"
## The greenhouse station (tools/arena_map_builder.gd does the work): a ForgeMap maze of
## halls and corridors with the user's BIODOME kit (assets/decor/biodome/, python
## tools/make_biodome_kit.py) - straight runs and columns, two columns stacked down each
## cell (roomy corridors, still a maze), machines and tanks in the hall corners, consoles,
## lockers and planters along the walls, garden islands - and the 5 Seed Tanks, 8 random
## Chests, 5 Survivors and the Player Spawn. World 8 plays it as its map (WorldData
## "explore": {"map": ...}); its waves and boss stay in WorldData. The scene belongs to the
## user once made: it refuses to overwrite it.
##   godot --headless --path . res://tools/build_biodome_arena.tscn [-- --force] [-- --seed=N] [-- --out=<res path>]

const TANKS := 5


func _configure() -> void:
	path = "res://scenes/arenas/arena_world_08_level_01.tscn"
	tag = "BIODOME"
	kit_dir = "res://assets/decor/biodome/"
	layout = {"set": "w8", "maze": 0.4, "mazes": 3, "tanks": TANKS}
	cells = [18, 14]
	seed_value = 8080
	mod_w = 96.0  # the art's own run: 3 floor tiles
	mod_h = 64.0  # the art's own column: 2 floor tiles
	mods_x = 1  # cross corridors ~75 clear
	mods_y = 2  # two columns stacked: the corridors running across get ~86 clear
	floor_src = 14  # terrain.json "Biodome floor"
	floor_cols = 12
	floor_tiles = 24
	plain = 0.72
	runs = ["walls/wall_0.png", "walls/wall_1.png", "walls/wall_2.png", "walls/wall_3.png", "walls/wall_4.png"]
	run_weights = [3.0, 2.0, 3.0, 2.0, 1.2]
	columns = ["walls/column_0.png", "walls/column_1.png", "walls/column_2.png", "walls/column_3.png", "walls/column_4.png"]
	column_weights = [3.0, 2.0, 3.0, 2.0, 0.6]
	corner_big = ["tanks/tank_big.png", "tanks/tank_tube.png", "machines/server_rack.png", "machines/hydro_rack.png",
		"machines/console_bank.png", "machines/capsule.png", "plants/vine_column.png", "plants/palm_box.png"]
	along_wall = ["machines/console_a.png", "machines/console_b.png", "machines/console_c.png", "machines/terminal.png",
		"machines/terminal_vine.png", "machines/analyzer.png", "machines/printer.png", "machines/holo_sign.png",
		"storage/locker.png", "storage/locker_tall.png", "storage/locker_narrow.png", "storage/crate.png",
		"storage/crate_screen.png", "storage/canister.png", "storage/cylinder.png", "storage/medkit.png",
		"planters/planter_flowers.png", "planters/planter_wide.png", "planters/planter_low.png", "planters/planter_small.png",
		"planters/planter_rail.png", "planters/planter_long.png", "furniture/bench.png", "machines/canister_vine.png",
		"tanks/tank_tube.png", "machines/hydro_rack.png"]
	pots = ["plants/pot_purple.png", "plants/pot_palm.png", "plants/pot_tall.png", "plants/pot_pink.png",
		"plants/pot_bush.png", "plants/pot_fern.png", "plants/pot_blossom.png", "plants/pot_leafy.png",
		"plants/pot_small_fern.png", "plants/pot_tiny_purple.png", "plants/pot_tiny_green.png", "plants/pot_tiny_violet.png",
		"plants/pot_hanging.png", "plants/pot_round.png", "plants/pot_cascade.png"]
	centrepieces = ["tanks/dome.png", "plants/palm_box.png", "plants/bush_box.png", "plants/purple_box.png",
		"plants/vine_pillar.png", "tanks/tank_big.png", "machines/hydro_rack.png", "planters/planter_corner_palm.png"]
	islands = ["planters/planter_long.png", "planters/planter_rail.png", "planters/planter_wide.png",
		"furniture/bench.png", "planters/planter_flowers.png", "tanks/tank_tube.png", "machines/hydro_rack.png"]
	floor_bits = ["floor/vent_round.png", "floor/grate.png", "floor/fan_vent.png"]
	lamps = ["furniture/lamp.png", "furniture/bollard.png"]


func _data() -> ArenaData:
	var d := super._data()
	d.arena_id = "w08_a01"
	d.display_name = "Biodome"
	d.description = "World 8's map: the greenhouse station on an asteroid. Defend the 5 seed tanks. Played by world 8 (WorldData 'explore': {'map': ...}): its waves and the BLOOM COLOSSUS come from WorldData; the waves here stay off."
	d.world_id = 8
	d.level_id = 1
	d.environment = "Biodome"
	d.difficulty = ArenaData.Difficulty.HARD
	return d


## A seed tank in the middle of each objective hall.
func _objective(n: int, _at: Vector2) -> Node2D:
	var t := ArenaSeedTank.new()
	t.name = "SeedTank%d" % (n + 1)
	t.object_id = "tank_%d" % (n + 1)
	t.art = rng.randi() % 8
	return t
