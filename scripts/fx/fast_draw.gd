class_name FastDraw
extends RefCounted
## Cheap stand-ins for CanvasItem.draw_circle / draw_arc in things redrawn every frame.
## In Godot 4.7 each draw_circle / draw_arc / draw_polyline call costs ~40-70 us of CPU
## (a draw_rect ~2 us): a few hazards, markers and telegraphs redrawn per frame ate a
## whole frame (tests/draw_cost_bench.tscn). These draw one textured quad instead, from
## textures built once (white, tinted by the colour): a disc, rings by thickness and
## arcs by thickness and span. Call them from _draw with the CanvasItem that draws.
## Rings / arcs bigger than BIG_R fall back to draw_arc (a texture would blur).

const SIZE := 32  # ring / arc texture radius in pixels
const DISC_SIZE := 64
const BIG_R := 72.0
const SPANS := 24  # arc spans are rounded to TAU / SPANS

static var _disc: Texture2D
static var _rings: Dictionary = {}  # thickness px -> Texture2D
static var _arcs: Dictionary = {}  # Vector2i(thickness px, span steps) -> Texture2D


## Filled circle.
static func disc(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	if r <= 0.0:
		return
	ci.draw_texture_rect(_disc_tex(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


## Circle outline of `width` centred on radius `r`.
static func ring(ci: CanvasItem, at: Vector2, r: float, col: Color, width := 1.0) -> void:
	if r <= 0.0:
		return
	if r > BIG_R:
		ci.draw_arc(at, r, 0.0, TAU, 64, col, width)
		return
	var outer := r + width * 0.5
	ci.draw_texture_rect(_ring_tex(_thick(width, outer)), Rect2(at - Vector2(outer, outer), Vector2(outer, outer) * 2.0), false, col)


## Arc from angle `a0` to `a1` (radians, like draw_arc). Pass the transform set with
## draw_set_transform (if any) as `base`: the arc is rotated inside it.
static func arc(ci: CanvasItem, at: Vector2, r: float, a0: float, a1: float, col: Color, width := 1.0,
		base := Transform2D.IDENTITY) -> void:
	var span := a1 - a0
	if r <= 0.0 or is_zero_approx(span):
		return
	if absf(span) >= TAU - 0.001:
		ring(ci, at, r, col, width)
		return
	if r > BIG_R:
		ci.draw_arc(at, r, a0, a1, 48, col, width)
		return
	if span < 0.0:
		a0 = a1
		span = -span
	var steps := clampi(roundi(span / TAU * SPANS), 1, SPANS - 1)
	var outer := r + width * 0.5
	var tex := _arc_tex(_thick(width, outer), steps)
	ci.draw_set_transform_matrix(base * Transform2D(a0, at))
	ci.draw_texture_rect(tex, Rect2(-Vector2(outer, outer), Vector2(outer, outer) * 2.0), false, col)
	ci.draw_set_transform_matrix(base)


## draw_polyline as separate draw_line segments (no joints, ~10x cheaper to redraw).
static func polyline(ci: CanvasItem, pts: PackedVector2Array, col: Color, width := 1.0) -> void:
	for i in pts.size() - 1:
		ci.draw_line(pts[i], pts[i + 1], col, width)


static func _thick(width: float, outer: float) -> int:
	return clampi(roundi(width / outer * SIZE), 1, SIZE)


static func _disc_tex() -> Texture2D:
	if _disc == null:
		_disc = _build(DISC_SIZE, -1.0, TAU)
	return _disc


static func _ring_tex(th: int) -> Texture2D:
	if not _rings.has(th):
		_rings[th] = _build(SIZE, float(SIZE - th), TAU)
	return _rings[th]


static func _arc_tex(th: int, steps: int) -> Texture2D:
	var key := Vector2i(th, steps)
	if not _arcs.has(key):
		_arcs[key] = _build(SIZE, float(SIZE - th), TAU * steps / SPANS)
	return _arcs[key]


## White (2 * size) square texture: alpha = the ring between `inner` and `size` pixels
## from the centre (inner < 0: a full disc), from angle 0 to `span`, antialiased.
static func _build(size: int, inner: float, span: float) -> Texture2D:
	var n := size * 2
	var data := PackedByteArray()
	data.resize(n * n * 2)
	var full := span >= TAU - 0.001
	var i := 0
	for y in n:
		var dy := y + 0.5 - size
		for x in n:
			var dx := x + 0.5 - size
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(size - d, 0.0, 1.0)
			if inner >= 0.0:
				a *= clampf(d - inner + 0.5, 0.0, 1.0)
			if not full and a > 0.0:
				var ang := fposmod(atan2(dy, dx), TAU)
				a *= clampf(minf(ang, span - ang) * d + 0.5, 0.0, 1.0)
			data[i] = 255
			data[i + 1] = int(a * 255.0)
			i += 2
	var img := Image.create_from_data(n, n, false, Image.FORMAT_LA8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
