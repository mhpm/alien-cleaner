class_name WalkMask
extends RefCounted
## Where an alien may appear in an arena: the floor the astronaut can WALK to. Built once
## when the arena starts (ArenaWorld) as a grid of Arena.TILE cells:
##   * a cell counts only if a terrain layer has a tile there (no tile = the void between
##     rooms, outside the map),
##   * its centre is not inside something solid (walls, props, water, the bounds),
##   * and it is reached from the player spawn by a flood fill whose steps never cross a
##     solid (a ray between the two cell centres). Doors don't stop the fill: a room
##     behind a closed door is still somewhere aliens may come from later.
## Room.is_open / open_near ask it (Room.walk_mask), so every spawner, wave, horde, leash,
## nest or camera alarm that places aliens through them keeps them on reachable floor.

var origin := Vector2.ZERO  # world position of cell (0, 0)
var cell := Arena.TILE
var cols := 0
var rows := 0
var _ok := PackedByteArray()  # 1 = reachable floor
var _cells: PackedVector2Array = []  # centres of the reachable cells (for nearest())
var reachable := 0
## Per cell: bits 0-3 = the step right / left / down / up was tested, bits 4-7 = it is
## open (no solid between the two centres). Kept for flow().
var _edges := PackedByteArray()
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## `arena`: the playing Arena (its terrain gives the floor), `bounds`: the room in world
## units, `start`: the player spawn. Physics must already hold the arena's bodies.
## `flow_edges`: also test every step between two reachable cells, for flow() (survival
## worlds on an arena map: the aliens' way round the walls); costs more rays.
func build(arena: Arena, bounds: Rect2, start: Vector2, space: PhysicsDirectSpaceState2D, flow_edges := false) -> WalkMask:
	origin = bounds.position
	cols = maxi(1, ceili(bounds.size.x / cell))
	rows = maxi(1, ceili(bounds.size.y / cell))
	_ok.resize(cols * rows)
	_ok.fill(0)
	_edges.resize(cols * rows)
	_edges.fill(0)
	var layers: Array[TileMapLayer] = []
	for layer_name: String in Arena.TERRAIN:
		var l := arena.get_layer(layer_name) as TileMapLayer
		if l != null and l.get_used_cells().size() > 0:
			layers.append(l)
	if layers.is_empty():  # no painted floor at all: nothing to restrict
		_ok.fill(1)
		reachable = cols * rows
		return self
	var stand := PackedByteArray()
	stand.resize(cols * rows)
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1 | PropData.LAYER_BODIES_ONLY
	for y in rows:
		for x in cols:
			var p := centre(x, y)
			if not _has_tile(layers, p):
				continue
			query.position = p
			if _solid_hits(space.intersect_point(query, 4)):
				continue
			stand[y * cols + x] = 1
	var from := _cell_of(start)
	if from.x < 0 or stand[from.y * cols + from.x] == 0:
		from = _nearest_standing(stand, start)
	if from.x < 0:
		return self
	var queue: Array[Vector2i] = [from]
	_ok[from.y * cols + from.x] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for k in 4:
			var n := c + DIRS[k]
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			var i := n.y * cols + n.x
			if stand[i] == 0 or (_ok[i] == 1 and not flow_edges):
				continue
			if not _step_open(space, c, k) or _ok[i] == 1:
				continue
			_ok[i] = 1
			queue.append(n)
	reachable = queue.size()
	for c in queue:
		_cells.append(centre(c.x, c.y))
	return self


## Can one walk from cell c one step in DIRS[k]: tested once per pair, cached both ways.
func _step_open(space: PhysicsDirectSpaceState2D, c: Vector2i, k: int) -> bool:
	var i := c.y * cols + c.x
	if _edges[i] & (1 << k):
		return (_edges[i] & (16 << k)) != 0
	var n := c + DIRS[k]
	var j := n.y * cols + n.x
	var back := k ^ 1  # right <-> left, down <-> up
	var open := not _blocked(space, centre(c.x, c.y), centre(n.x, n.y))
	_edges[i] |= (1 << k) | ((16 << k) if open else 0)
	_edges[j] |= (1 << back) | ((16 << back) if open else 0)
	return open


## Way around the walls to `goal`: for every reachable cell, the centre of the next cell
## on a shortest walk to the goal's cell (Vector2.ZERO = the goal's cell or unreachable).
## Index with cell_index().
func flow(goal: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(cols * rows)
	var g := _cell_of(goal)
	if g.x < 0 or _ok[g.y * cols + g.x] == 0:  # a goal on something solid (a seed tank's foot)
		g = _cell_of(nearest(goal))
	if g.x < 0 or _ok[g.y * cols + g.x] == 0:
		return out
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	seen[g.y * cols + g.x] = 1
	var queue: Array[Vector2i] = [g]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var ci := c.y * cols + c.x
		for k in 4:
			if (_edges[ci] & (16 << k)) == 0:
				continue
			var n := c + DIRS[k]
			var ni := n.y * cols + n.x
			if seen[ni] == 1 or _ok[ni] == 0:
				continue
			seen[ni] = 1
			out[ni] = centre(c.x, c.y)
			queue.append(n)
	return out


## Index of the cell under `p` in flow()'s array (-1 outside).
func cell_index(p: Vector2) -> int:
	var c := _cell_of(p)
	return c.y * cols + c.x if c.x >= 0 else -1


func centre(x: int, y: int) -> Vector2:
	return origin + Vector2((x + 0.5) * cell, (y + 0.5) * cell)


## True when `p` is on floor the astronaut can walk to.
func has(p: Vector2) -> bool:
	var c := _cell_of(p)
	return c.x >= 0 and _ok[c.y * cols + c.x] == 1


## The reachable cell centre closest to `p` (`p` itself if there is no floor at all).
func nearest(p: Vector2) -> Vector2:
	var best := p
	var best_d := INF
	for q in _cells:
		var d := q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = q
	return best


func _cell_of(p: Vector2) -> Vector2i:
	var x := floori((p.x - origin.x) / cell)
	var y := floori((p.y - origin.y) / cell)
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func _nearest_standing(stand: PackedByteArray, p: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in rows:
		for x in cols:
			if stand[y * cols + x] == 1:
				var d := centre(x, y).distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)
	return best


static func _has_tile(layers: Array[TileMapLayer], p: Vector2) -> bool:
	for l in layers:
		if l.get_cell_source_id(l.local_to_map(l.to_local(p))) != -1:
			return true
	return false


## A solid between two neighbouring cell centres (doors don't count: they open later).
func _blocked(space: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1 | PropData.LAYER_BODIES_ONLY)
	for _i in 4:
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return false
		if not _is_door(hit.collider):
			return true
		var ex := q.exclude
		ex.append(hit.rid)
		q.exclude = ex
	return true


func _solid_hits(hits: Array[Dictionary]) -> bool:
	for h in hits:
		if not _is_door(h.collider):
			return true
	return false


static func _is_door(o: Object) -> bool:
	var n := o as Node
	while n != null:
		if n is ArenaDoor:
			return true
		if n is Arena:
			return false
		n = n.get_parent()
	return false
