@tool
extends RefCounted
## Random decoration painter. Scatters the chosen decoration entries (floor decals and
## harmless props only: never gameplay objects) inside an area of the arena. Fully
## deterministic: the same entries, area, settings and seed give the same layout.
## Keeps `min_distance` from everything already placed and off painted walls.
## Returns the new nodes; the plugin adds them in one undoable action, grouped under
## "Scatter_<seed>" nodes so a layout can be removed as a whole.

## PropData kinds that are pure decoration (no loot, hatching, turrets, bursting tanks).
const SAFE_KINDS := ["", "spark"]


static func allowed(entry) -> bool:
	if entry.kind == "decal" or entry.kind == "scenery":
		return true
	if entry.kind == "prop":
		return str(PropData.PROPS[entry.prop_id].get("kind", "")) in SAFE_KINDS
	return false


## cfg: entries (Array), area (Rect2, arena space), density (items per 100x100),
## min_distance, seed, random_flip, random_rotation (decals).
static func generate(arena: Arena, cfg: Dictionary) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var entries: Array = cfg.entries
	if entries.is_empty():
		return out
	var area: Rect2 = cfg.area
	var b := arena.get_bounds()
	if b != null:
		area = area.intersection(Rect2(b.position, b.size).grow(-6.0))
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.seed)
	var want := int(area.get_area() / 10000.0 * float(cfg.density))
	var min_d := float(cfg.min_distance)
	var taken: Array[Vector2] = []
	for o in arena.objects():
		taken.append(arena.to_local(o.global_position))
	var walls := arena.get_layer("Walls") as TileMapLayer
	var tries := want * 25
	while out.size() < want and tries > 0:
		tries -= 1
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y)).round()
		var entry = entries[rng.randi() % entries.size()]
		var flip := rng.randf() < 0.5
		var rot := rng.randf() * TAU
		if taken.any(func(q: Vector2) -> bool: return q.distance_to(p) < min_d):
			continue
		if walls != null and walls.get_cell_source_id(walls.local_to_map(walls.to_local(arena.to_global(p)))) != -1:
			continue
		var node: Node2D = entry.instantiate()
		node.position = p
		if node is ArenaScenery:
			if bool(cfg.random_flip):
				(node as ArenaScenery).flip_h = flip
			# a little size variety so a forest does not look stamped
			(node as ArenaScenery).width = roundf((node as ArenaScenery).width * (0.85 + 0.3 * fmod(rot, 1.0)))
		if node is ArenaDecal:
			if bool(cfg.random_flip):
				(node as ArenaDecal).flip_h = flip
			if bool(cfg.random_rotation):
				node.rotation = rot
		taken.append(p)
		out.append(node)
	return out
