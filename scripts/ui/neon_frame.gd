class_name NeonFrame
extends Control
## Pixel-art neon panel drawn in code (no textures, so it takes any colour): chamfered
## corners, a stepped glow outside, a dark gradient fill, a bright border, a thin inner
## line and light "bracket" accents on the corners. Lines are drawn without
## antialiasing on a PX grid so it reads as chunky pixel art at any screen size.
## Used by the upgrade screen (Hud.show_upgrades).

const PX := 2.0  # one art pixel in UI units

var color := Color("41a6f6")
var fill_top := Color("18214a")
var fill_bottom := Color("0b1029")
var cut := 10.0  # chamfer size
var glow := 3  # glow rings outside the border
var inner := true  # thin second line inside the border
var brackets := true  # bright ticks on the chamfers
var notches := false  # little tabs on the top and bottom edges (big panels)
var pulse := false  # glow breathes (highlighted item)
var pad := 0.0  # draw this far outside the control's rect (frame around container margins)
var t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if pulse:
		t += delta
		queue_redraw()


func _snap(v: float) -> float:
	return roundf(v / PX) * PX


## Chamfered outline `inset` units inside the control (negative = outside).
func _outline(inset: float) -> PackedVector2Array:
	var x0 := _snap(inset - pad)
	var y0 := _snap(inset - pad)
	var x1 := _snap(size.x - inset + pad)
	var y1 := _snap(size.y - inset + pad)
	var c := maxf(_snap(cut - inset * 0.4), PX)
	return PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c), Vector2(x1, y1 - c),
		Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c), Vector2(x0, y0 + c),
	])


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q


func _draw() -> void:
	var k := 1.0
	if pulse:
		k = 0.75 + sin(t * 5.0) * 0.25
	# stepped glow outside the border
	for i in glow:
		var a := (0.30 - i * 0.08) * k
		draw_polyline(_closed(_outline(-(i + 1) * PX)), Color(color, a), PX, false)
	# dark gradient fill
	var body := _outline(PX)
	var cols := PackedColorArray()
	for v in body:
		cols.append(fill_top.lerp(fill_bottom, clampf((v.y + pad) / maxf(size.y + pad * 2.0, 1.0), 0.0, 1.0)))
	draw_polygon(body, cols)
	# faint scanlines across the fill
	var y := _snap(cut - pad)
	while y < size.y + pad - cut:
		draw_rect(Rect2(_snap(PX * 3 - pad), y, _snap(size.x + pad * 2.0 - PX * 6), 1.0), Color(color, 0.035))
		y += PX * 3
	# borders
	draw_polyline(_closed(_outline(0.0)), color.lightened(0.2), PX, false)
	if inner:
		draw_polyline(_closed(_outline(PX * 3)), Color(color, 0.45), 1.0, false)
	if brackets:
		# bright ticks along each chamfer and a short run along the edges
		var o := _outline(0.0)
		var hi := color.lightened(0.65)
		for i in [1, 3, 5, 7]:
			var a := o[i]
			var b := o[(i + 1) % 8]
			draw_line(a, b, hi, PX, false)
			var into := (a - o[i - 1]).normalized()
			draw_line(a, a - into * PX * 5, hi, PX, false)
			var outof := (o[(i + 2) % 8] - b).normalized()
			draw_line(b, b + outof * PX * 5, hi, PX, false)
	if notches:
		var w := _snap(size.x * 0.18)
		var cx := _snap(size.x * 0.5)
		for yy: float in [_snap(-pad), _snap(size.y + pad) - PX]:
			var top := yy < size.y * 0.5
			draw_rect(Rect2(cx - w * 0.5, yy - (PX if top else 0.0), w, PX * 2), color.lightened(0.4))
			draw_rect(Rect2(cx - PX * 2, yy - (PX * 3 if top else -PX), PX * 4, PX * 2), Color.WHITE)
