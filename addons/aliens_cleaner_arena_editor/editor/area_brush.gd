@tool
extends RefCounted
## OBJECTS > Brush "Area": the copies a dragged rectangle (or the ellipse inside it) gets
## of the picked palette objects, at random spots, each with the random looks the user
## ticked: size, opacity, tint (between two colours), flip and rotation. Deterministic
## for a given seed. Returns [entry, node] pairs; the placement tool adds them in one
## undoable action, each into its own layer.

## cfg: count, min_dist, round, avoid (keep min_dist from objects already there), seed,
## size [on, min %, max %], opacity [on, min %, max %], tint [on, Color a, Color b],
## flip, rotation [on, max degrees].
static func generate(arena: Arena, entries: Array, rect: Rect2, cfg: Dictionary) -> Array:
	var out := []
	if entries.is_empty():
		return out
	var b := arena.get_bounds()
	if b != null:
		rect = rect.intersection(Rect2(b.position, b.size))
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.seed)
	var want := int(cfg.count)
	var min_d := float(cfg.min_dist)
	var taken: Array[Vector2] = []
	if bool(cfg.avoid):
		var reach := rect.grow(min_d)
		for o in arena.objects():
			var p := arena.to_local(o.global_position)
			if reach.has_point(p):
				taken.append(p)
	var walls := arena.get_layer("Walls") as TileMapLayer
	var tries := want * 40
	while out.size() < want and tries > 0:
		tries -= 1
		var p := _spot(rng, rect, bool(cfg.round))
		if min_d > 0.0 and taken.any(func(q: Vector2) -> bool: return q.distance_squared_to(p) < min_d * min_d):
			continue
		if walls != null and walls.get_cell_source_id(walls.local_to_map(walls.to_local(arena.to_global(p)))) != -1:
			continue
		var entry = entries[rng.randi() % entries.size()]
		var node: Node2D = entry.instantiate()
		if node == null:
			continue
		if node is PlayerSpawn:  # only one per arena: never scattered
			node.free()
			continue
		node.position = p
		_style(node, rng, cfg)
		taken.append(p)
		out.append([entry, node])
	return out


static func _spot(rng: RandomNumberGenerator, rect: Rect2, round_area: bool) -> Vector2:
	if not round_area:
		return Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y)).round()
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf())
	return (rect.get_center() + Vector2(cos(a), sin(a)) * r * rect.size * 0.5).round()


## The random looks the user ticked. Scenery and decals have their own width / tint /
## flip; anything else is scaled, modulated and mirrored as a node.
static func _style(node: Node2D, rng: RandomNumberGenerator, cfg: Dictionary) -> void:
	var size_k := 1.0
	if bool(cfg.size[0]):
		size_k = rng.randf_range(float(cfg.size[1]), float(cfg.size[2])) / 100.0
	var col := Color.WHITE
	if bool(cfg.tint[0]):
		col = (cfg.tint[1] as Color).lerp(cfg.tint[2] as Color, rng.randf())
		col.a = 1.0
	if bool(cfg.opacity[0]):
		col.a = rng.randf_range(float(cfg.opacity[1]), float(cfg.opacity[2])) / 100.0
	var flip := bool(cfg.flip) and rng.randf() < 0.5
	if bool(cfg.rotation[0]):
		node.rotation_degrees = roundf(rng.randf_range(-float(cfg.rotation[1]), float(cfg.rotation[1])))
	if node is ArenaScenery:
		var s := node as ArenaScenery
		s.width = roundf(s.width * size_k * 2.0) * 0.5
		s.footprint *= size_k
		s.tint = col
		if flip:
			s.flip_h = not s.flip_h
	elif node is ArenaDecal:
		var d := node as ArenaDecal
		d.width = roundf(d.width * size_k)
		d.tint = col
		if flip:
			d.flip_h = not d.flip_h
	else:
		node.scale = Vector2(-size_k if flip else size_k, size_k)
		node.modulate = col
