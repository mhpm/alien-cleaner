class_name RoomKit
extends RefCounted
## Free-standing pieces placed in the middle of EXPLORE rooms (world 3, config
## "interior": "w3"): wall sections, pillars, T / cross blocks, tanks and crates from
## tools/w3_kit_ref.webp (python tools/make_room_kit.py -> assets/rooms/w3/kit/k_NN.png,
## numbers in tools/w3_kit_index.png). A PATTERN lays a few of them around the room's
## centre, always keeping corridors wide enough to fight in; pieces are y-sorted with the
## entities and their FOOT (bottom share of the picture) is solid.

const SCALE := 0.3205  # kit px -> world units (same scale as the room paintings)

## piece -> bottom share of its height that is solid
const FOOT := {
	0: 0.45, 1: 0.45, 2: 0.45, 3: 0.45, 4: 0.45, 5: 0.45, 6: 0.45, 7: 0.45, 8: 0.45,
	9: 0.5, 10: 0.5, 11: 0.5, 12: 0.5, 13: 0.5, 14: 0.5, 15: 0.45, 16: 0.45, 17: 0.45, 18: 0.55,
	22: 0.45, 23: 0.7, 27: 0.7, 24: 0.6, 28: 0.6,
	29: 0.4, 30: 0.4, 31: 0.45, 32: 0.4, 33: 0.45, 34: 0.5, 35: 0.45, 36: 0.5, 37: 0.4, 38: 0.5,
}

## Layouts around the room centre: [piece, x, y] = bottom centre in world units.
## Rooms are 600 x 402 and their corners are full of furniture, so pieces stay within
## about ±150 x ±90 and leave >= 60 units between them.
const PATTERNS := {
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
}

static var _tex: Dictionary = {}


static func tex(k: int) -> Texture2D:
	if not _tex.has(k):
		var img := (load("res://assets/rooms/w3/kit/k_%02d.png" % k) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_tex[k] = ImageTexture.create_from_image(img)
	return _tex[k]


## Solid rect of piece `k` standing with its bottom centre at `at`.
static func foot(k: int, at: Vector2) -> Rect2:
	var sz := tex(k).get_size() * SCALE
	var h := sz.y * float(FOOT.get(k, 0.45))
	return Rect2(at.x - sz.x * 0.5, at.y - h, sz.x, h)
