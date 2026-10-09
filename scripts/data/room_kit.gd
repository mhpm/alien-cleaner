class_name RoomKit
extends RefCounted
## Free-standing pieces placed in the middle of EXPLORE rooms (survival config
## "interior": set): wall sections, pillars, T / cross blocks, tanks, machines and crates
## cut from tools/<set>_kit_ref.webp (python tools/make_room_kit.py <set> ->
## assets/rooms/<set>/kit/k_NN.png, numbers in tools/<set>_kit_index.png). A PATTERN lays
## a few of them around the room's centre, always keeping corridors wide enough to fight
## in; pieces are y-sorted with the entities and their FOOT (bottom share of the picture)
## is solid.
##   w3  THE VOID labs (world 3): grey wall sections, tanks, crates
##   w5  THE FORGE (world 5): lava-lit walls, tesla coils, reactors, pipes, crates

## per set: SCALE (kit px -> world units, the same as the room paintings), FOOT
## (piece -> bottom share of its height that is solid) and PATTERNS (layouts around the
## room centre: [piece, x, y] = bottom centre in world units; rooms are 600 x 402 with
## furniture in the corners, so pieces stay within about ±150 x ±90 and leave >= 60
## units between them)
const KITS := {
	"w3": {
		"scale": 0.3205,
		"foot": {
			0: 0.45, 1: 0.45, 2: 0.45, 3: 0.45, 4: 0.45, 5: 0.45, 6: 0.45, 7: 0.45, 8: 0.45,
			9: 0.5, 10: 0.5, 11: 0.5, 12: 0.5, 13: 0.5, 14: 0.5, 15: 0.45, 16: 0.45, 17: 0.45, 18: 0.55,
			22: 0.45, 23: 0.7, 27: 0.7, 24: 0.6, 28: 0.6,
			29: 0.4, 30: 0.4, 31: 0.45, 32: 0.4, 33: 0.45, 34: 0.5, 35: 0.45, 36: 0.5, 37: 0.4, 38: 0.5,
		},
		"patterns": {
			"pillars": [[15, -85, -35], [16, 85, -35], [16, -85, 75], [15, 85, 75]],
			"split": [[2, -118, 5], [8, 118, 5]],
			"window": [[1, 0, -30], [35, -110, 75], [36, 110, 75]],
			"bends": [[9, -95, 60], [10, 95, -20]],
			"cross": [[14, 0, 35], [17, -130, -40], [17, 130, -40]],
			"tanks": [[29, -105, 40], [31, 105, 40], [37, 0, 95]],
			"supply": [[34, -70, 70], [33, 0, -45], [36, 75, 75], [30, 140, 0]],
			"tees": [[12, -95, 20], [13, 95, 20], [18, 0, 95]],
			"machine": [[32, 0, -15], [24, -150, 80], [28, 150, 80]],
			"rails": [[23, -90, 55], [27, 90, -25], [38, 0, 20]],
			"mixed": [[5, 95, -25], [11, -100, 70], [35, 20, 90]],
		},
	},
	"w5": {
		"scale": 0.3,
		"foot": {
			0: 0.45, 1: 0.45, 3: 0.4, 11: 0.4, 12: 0.5, 13: 0.5, 14: 0.5, 15: 0.5, 17: 0.45,
			18: 0.45, 19: 0.45, 20: 0.5, 21: 0.55, 22: 0.45, 25: 0.32, 26: 0.4, 27: 0.3, 28: 0.3,
			29: 0.3, 30: 0.4, 31: 0.35, 32: 0.35, 33: 0.35, 41: 0.5, 44: 0.5, 45: 0.5, 50: 0.5,
			51: 0.35, 52: 0.35, 53: 0.5, 54: 0.5,
		},
		"patterns": {
			"lava_wall": [[12, 0, -10], [3, -150, 85], [3, 150, 85]],
			"coils": [[25, -110, 45], [25, 110, 45], [31, 0, 95]],
			"gates": [[13, -120, 15], [13, 120, 15]],
			"blocks": [[20, -100, 25], [21, 105, 70]],
			"control": [[30, 0, -5], [44, -140, 85], [53, 140, 85]],
			"tanks": [[32, -95, -15], [51, 0, 75], [32, 95, -15]],
			"pipeline": [[45, 0, 15], [41, -140, 90], [54, 130, 90]],
			"bunker": [[17, -95, -15], [19, 95, 70]],
			"storage": [[44, -70, 25], [50, 45, -35], [53, 95, 75], [41, -135, -40]],
			"plant": [[26, -95, 40], [29, 105, 0], [52, 10, 95]],
			"cross": [[21, 0, 20], [33, -140, 80], [33, 140, 80]],
		},
	},
}

static var _tex: Dictionary = {}


static func kit(set_id: String) -> Dictionary:
	return KITS.get(set_id, KITS.w3)


static func patterns(set_id: String) -> Dictionary:
	return kit(set_id).patterns


static func scale(set_id: String) -> float:
	return float(kit(set_id).scale)


static func tex(k: int, set_id := "w3") -> Texture2D:
	var key := "%s/%d" % [set_id, k]
	if not _tex.has(key):
		var img := (load("res://assets/rooms/%s/kit/k_%02d.png" % [set_id, k]) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]


## Solid rect of piece `k` standing with its bottom centre at `at`.
static func foot(k: int, at: Vector2, set_id := "w3") -> Rect2:
	var sz := tex(k, set_id).get_size() * scale(set_id)
	var h := sz.y * float((kit(set_id).foot as Dictionary).get(k, 0.45))
	return Rect2(at.x - sz.x * 0.5, at.y - h, sz.x, h)
