class_name LabRoomData
extends RefCounted
## Rooms of the EXPLORE map (world 1). Every room fills ROOM world units, has its walls
## on the edges and a doorway centred on each side, so any room joins any other; Explore
## lays them out in a grid with a thin black seam between them.
##
## Rooms are put together from pieces of a SET so that no two are the same (world 1 =
## "lab", world 2 = "w2", python tools/make_lab_pieces.py <set>):
##   tools/rooms/lab_1..5.webp (same frame, different furniture in the corners; 5 = open
##   doors) -> python tools/make_lab_pieces.py -> assets/rooms/lab/: base.webp (empty
##   room, grown: more floor), corner_<n>_<tl|tr|bl|br>.png (corner n of painting n),
##   door_<side>.png (shut door, for the map's edge), decal_<k>.png (floor dressing) and
##   pieces.json (positions, solid rects per corner, walls, doorway openings, free spots,
##   how many paintings).
## ZONE ZERO is one whole painting: tools/rooms/zone_zero.webp -> python
##   tools/make_lab_rooms.py -> assets/rooms/zone_zero.webp + .json.
## A room built here is {layers: [[texture, rect]], solids: [Rect2], spots: [Vector2],
## start: Vector2, openings: {side: Rect2}, shut: "art" | "plate"} in world units from the
## room's corner (layers drawn in order).

const ROOM := Vector2(600, 402)  # world units per room
const DOOR_W := 38.0  # doorway across the seam (world units)
const FLOOR := Color(0.47, 0.49, 0.56)  # floor colour of the bridges across the seams
const ROOMS := "res://assets/rooms/"
const ZERO := "res://assets/rooms/zone_zero"
const SIDES := ["top", "bottom", "left", "right"]
const CORNERS := ["tl", "tr", "bl", "br"]

static var _json: Dictionary = {}


static func _data(path: String) -> Dictionary:
	if not _json.has(path):
		_json[path] = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _json[path]


static func _rect(a: Array, k: Vector2) -> Rect2:
	return Rect2(Vector2(float(a[0]), float(a[1])) * k, Vector2(float(a[2]), float(a[3])) * k)


static func _pt(a: Array, k: Vector2) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) * k


static func _pieces(set_id: String) -> Dictionary:
	return _data(ROOMS + set_id + "/pieces.json")


## `n` corner combinations ([tl, tr, bl, br] painting numbers), all different.
static func combos(n: int, rng: RandomNumberGenerator, set_id := "lab") -> Array:
	var all: Array = []
	var p := int(_pieces(set_id).paintings)
	for a in p:
		for b in p:
			for c in p:
				for d in p:
					all.append([a + 1, b + 1, c + 1, d + 1])
	for i in range(all.size() - 1, 0, -1):  # shuffle with the map's rng
		var j := rng.randi_range(0, i)
		var tmp: Array = all[i]
		all[i] = all[j]
		all[j] = tmp
	return all.slice(0, n)


## A lab room with corners `combo` and a few floor decals.
static func lab(combo: Array, rng: RandomNumberGenerator, set_id := "lab") -> Dictionary:
	var dir := ROOMS + set_id + "/"
	var d := _pieces(set_id)
	var k := ROOM / _pt(d.size, Vector2.ONE)
	var layers: Array = [[load(dir + "base.webp"), Rect2(Vector2.ZERO, ROOM)]]
	var fl := _rect(d.floor, k)
	for i in rng.randi_range(3, 6):
		var tex: Texture2D = load(dir + "decal_%d.png" % rng.randi_range(0, int(d.decals) - 1))
		var sz := tex.get_size() * k
		var p := Vector2(rng.randf_range(fl.position.x, fl.end.x - sz.x), rng.randf_range(fl.position.y, fl.end.y - sz.y))
		layers.append([tex, Rect2(p, sz)])
	var solids: Array[Rect2] = []
	for a: Array in d.walls:
		solids.append(_rect(a, k))
	for i in 4:
		var c: String = CORNERS[i]
		var n := str(combo[i])
		var tex: Texture2D = load(dir + "corner_%s_%s.png" % [n, c])
		layers.append([tex, Rect2(_pt(d.corners[c].at, k), tex.get_size() * k)])
		for a: Array in d.corners[c].solid[n]:
			solids.append(_rect(a, k))
	var spots: Array[Vector2] = []
	for a: Array in d.spots:
		spots.append(_pt(a, k))
	var openings := {}
	for side: String in SIDES:
		openings[side] = _rect(d.openings[side], k)
	return {"layers": layers, "solids": solids, "spots": spots, "start": _pt(d.start, k),
		"openings": openings, "shut": "art", "set": set_id, "k": k, "floor": floor_color(set_id)}


## Floor colour of a set (the bridges across the seams).
static func floor_color(set_id: String) -> Color:
	var c: Array = _pieces(set_id).get("floor_color", [])
	return Color(float(c[0]), float(c[1]), float(c[2])) if c.size() == 3 else FLOOR


## The shut door of a lab room on `side`: [texture, rect].
static func lab_door(side: String, set_id := "lab") -> Array:
	var d := _pieces(set_id)
	var k := ROOM / _pt(d.size, Vector2.ONE)
	var tex: Texture2D = load(ROOMS + set_id + "/door_%s.png" % side)
	return [tex, Rect2(_pt(d.doors[side], k), tex.get_size() * k)]


## ZONE ZERO: the one painted room where the outbreak began.
static func zero() -> Dictionary:
	var d := _data(ZERO + ".json")
	var k := ROOM / _pt(d.size, Vector2.ONE)
	var solids: Array[Rect2] = []
	for a: Array in d.solid:
		solids.append(_rect(a, k))
	var spots: Array[Vector2] = []
	for a: Array in d.spots:
		spots.append(_pt(a, k))
	var w := float(d.wall)
	var sz := _pt(d.size, Vector2.ONE)
	var dx: Array = d.doors.x
	var dy: Array = d.doors.y
	var openings := {
		"top": _rect([dx[0], 0, float(dx[1]) - float(dx[0]), w], k),
		"bottom": _rect([dx[0], sz.y - w, float(dx[1]) - float(dx[0]), w], k),
		"left": _rect([0, dy[0], w, float(dy[1]) - float(dy[0])], k),
		"right": _rect([sz.x - w, dy[0], w, float(dy[1]) - float(dy[0])], k),
	}
	return {"layers": [[load(ZERO + ".webp"), Rect2(Vector2.ZERO, ROOM)]], "solids": solids, "spots": spots,
		"start": _pt(d.start, k), "openings": openings, "shut": "plate", "k": k}
