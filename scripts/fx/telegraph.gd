class_name Telegraph
extends Node2D
## Warning shape drawn on the floor before an attack lands (every alien and boss uses
## this one, through GameWorld.telegraph_circle / telegraph_line or directly).
##   "circle"  a squashed ring that fills up from the centre
##   "line"    an AIM LANE: a soft tapered strip (narrow at the shooter, full width at
##             the end) with glowing dashed edges, chevrons marching along it, a charge
##             that fills from the shooter outwards and an arrowhead at the tip; in the
##             last moment it flashes hot, so the timing can be read at a glance.

const CHEVRON_GAP := 14.0
const FLASH_AT := 0.8  # share of `dur` after which the lane flashes "about to fire"

var kind := "circle"
var radius := 20.0
var dir := Vector2.RIGHT
var length := 100.0
var width := 12.0
var dur := 1.0
var t := 0.0
var color := Color(1.0, 0.25, 0.3)


func _ready() -> void:
	DarkLights.glow(self)  # warnings stay readable in the dark (unshaded)
	if kind == "line":
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # glows over the floor
		material = m


func _process(delta: float) -> void:
	t += delta
	if t >= dur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / dur, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * 26.0)
	if kind == "circle":
		# FastDraw / draw_line: draw_circle, draw_arc and draw_polyline are slow to redraw
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.75))
		FastDraw.disc(self, Vector2.ZERO, radius, Color(color, 0.12 + 0.1 * pulse))
		FastDraw.disc(self, Vector2.ZERO, radius * k, Color(color, 0.3))
		FastDraw.ring(self, Vector2.ZERO, radius, Color(color, 0.9), 1.5)
	else:
		_draw_lane(k)


## Lane along +x (rotated to `dir`): everything is drawn in its own frame.
func _draw_lane(k: float) -> void:
	draw_set_transform(Vector2.ZERO, dir.angle())
	var appear := clampf(t / 0.12, 0.0, 1.0)  # quick grow-in
	var ln := length * (0.35 + 0.65 * ease(appear, 0.4))
	var hot := k >= FLASH_AT
	var flash := 1.0 if hot and fmod(t, 0.1) < 0.05 else 0.0
	var w0 := width * 0.35  # narrow at the shooter...
	var w1 := width * 0.5  # ...full width at the far end (half widths)
	var w0h := w0 * 0.5
	var head := minf(width * 1.1, ln * 0.3)  # arrowhead length
	var body := ln - head
	# soft body: transparent at the shooter, stronger towards the tip
	var a := 0.16 + 0.1 * flash
	_quad(Vector2(0, -w0h), Vector2(body, -w1), Vector2(body, w1), Vector2(0, w0h),
			Color(color, 0.02), Color(color, a), Color(color, a), Color(color, 0.02))
	# the charge filling from the shooter outwards
	var fill := body * ease(k, 0.6)
	var wf := lerpf(w0h, w1, fill / maxf(body, 1.0))
	_quad(Vector2(0, -w0h * 0.55), Vector2(fill, -wf * 0.55), Vector2(fill, wf * 0.55), Vector2(0, w0h * 0.55),
			Color(color, 0.05), Color(color, 0.35 + 0.25 * flash), Color(color, 0.35 + 0.25 * flash), Color(color, 0.05))
	# glowing dashed edges
	var edge := Color(color.lightened(0.3), 0.55 + 0.35 * flash)
	draw_dashed_line(Vector2(4, -w0h), Vector2(body, -w1), edge, 1.0, 5.0)
	draw_dashed_line(Vector2(4, w0h), Vector2(body, w1), edge, 1.0, 5.0)
	# chevrons marching towards the tip (brighter once the charge has passed them)
	var march := fmod(t * 60.0, CHEVRON_GAP)
	var x := 8.0 + march
	while x < body - 4.0:
		var hw := lerpf(w0h, w1, x / maxf(body, 1.0)) * 0.6
		var lit := x <= fill
		var c := Color(color.lightened(0.45), (0.75 if lit else 0.3) * clampf(x / 20.0, 0.0, 1.0))
		draw_line(Vector2(x - hw * 0.7, -hw), Vector2(x, 0), c, 1.5)
		draw_line(Vector2(x, 0), Vector2(x - hw * 0.7, hw), c, 1.5)
		x += CHEVRON_GAP
	# arrowhead at the tip
	var tip := PackedVector2Array([Vector2(body, -w1 * 1.35), Vector2(ln, 0), Vector2(body, w1 * 1.35)])
	draw_colored_polygon(tip, Color(color, 0.25 + 0.3 * flash + 0.15 * float(k > 0.5)))
	var tip_col := Color(color.lightened(0.4), 0.9)
	for i in 3:
		draw_line(tip[i], tip[(i + 1) % 3], tip_col, 1.5)
	# a hot spark at the shooter's end while it charges
	FastDraw.disc(self, Vector2.ZERO, 2.5 + 1.5 * sin(t * 30.0), Color(color.lightened(0.6), 0.8))


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	draw_polygon(PackedVector2Array([a, b, c, d]), PackedColorArray([ca, cb, cc, cd]))
