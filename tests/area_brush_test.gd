extends Node
## Area brush (Arena Editor OBJECTS > Brush: Area): fills a rectangle / ellipse with
## random copies of palette objects; checks count, spacing, size / opacity / tint ranges,
## round areas, determinism and that Player Spawns are never scattered.
##   godot --headless --path . res://tests/area_brush_test.tscn

const AreaBrush := preload("res://addons/aliens_cleaner_arena_editor/editor/area_brush.gd")
const Catalog := preload("res://addons/aliens_cleaner_arena_editor/editor/palette_catalog.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _cfg(seed: int) -> Dictionary:
	return {"count": 30, "min_dist": 12.0, "round": false, "avoid": false, "seed": seed,
		"size": [true, 50.0, 150.0], "opacity": [true, 40.0, 80.0],
		"tint": [true, Color(1, 0, 0), Color(0, 0, 1)], "flip": true, "rotation": [true, 20.0]}


func _ready() -> void:
	var arena := (load("res://scenes/arenas/arena_world_10_level_01.tscn") as PackedScene).instantiate() as Arena
	add_child(arena)
	var catalog = Catalog.new()
	catalog.rebuild()
	var grass: Array = catalog.in_category("Farm · Grass", "")
	check(grass.size() > 50, "the grass kit is in the palette (%d)" % grass.size())
	var picks := grass.slice(0, 4)
	var rect := Rect2(200, 200, 300, 200)
	var pairs := AreaBrush.generate(arena, picks, rect, _cfg(7))
	check(pairs.size() == 30, "30 copies in the area (%d)" % pairs.size())
	var inside := true
	var spaced := true
	var sizes_ok := true
	var alpha_ok := true
	var tint_ok := true
	var kinds := {}
	for i in pairs.size():
		var s := pairs[i][1] as ArenaScenery
		kinds[s.texture.resource_path] = true
		inside = inside and rect.has_point(s.position)
		var base: float = pairs[i][0].instantiate().width
		var k := s.width / base
		sizes_ok = sizes_ok and k > 0.45 and k < 1.55
		alpha_ok = alpha_ok and s.tint.a >= 0.39 and s.tint.a <= 0.81
		tint_ok = tint_ok and s.tint.g < 0.01 and absf(s.tint.r + s.tint.b - 1.0) < 0.02
		for j in i:
			if (pairs[j][1] as Node2D).position.distance_to(s.position) < 12.0:
				spaced = false
	check(inside, "every copy is inside the rectangle")
	check(spaced, "copies keep the minimum distance")
	check(sizes_ok, "random size between 50% and 150%")
	check(alpha_ok, "random opacity between 40% and 80%")
	check(tint_ok, "tint between red and blue")
	check(kinds.size() > 1, "the picked objects are mixed (%d kinds)" % kinds.size())
	var again := AreaBrush.generate(arena, picks, rect, _cfg(7))
	check(again.size() == pairs.size() and (again[5][1] as Node2D).position == (pairs[5][1] as Node2D).position, "same seed = same result")
	var cfg := _cfg(9)
	cfg.round = true
	cfg.count = 40
	var round_ok := true
	for p in AreaBrush.generate(arena, picks, rect, cfg):
		var d: Vector2 = ((p[1] as Node2D).position - rect.get_center()) / (rect.size * 0.5)
		round_ok = round_ok and d.length() <= 1.02
	check(round_ok, "round area keeps copies inside the ellipse")
	var spawn = catalog.entries.filter(func(e) -> bool: return e.name.begins_with("Player"))
	check(spawn.is_empty() or AreaBrush.generate(arena, spawn.slice(0, 1), rect, _cfg(3)).is_empty(), "Player Spawns are never scattered")
	print("AREA BRUSH TEST: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
