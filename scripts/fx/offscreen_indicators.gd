class_name OffscreenIndicators
extends Node2D
## Big rooms: a small arrow at the screen edge for every alien out of view, in the
## alien's colour (elites gold, bosses red and bigger), so nobody sneaks up unseen.
## Survival supply crates out of view get a gold arrow too.

const MAX_ARROWS := 40

var camera: Camera2D
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var w := Game.world
	if camera == null or w == null or not w.follow_cam:
		return
	var size := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - size * 0.5, size)
	# keep clear of the top bar and the screen edges
	var inner := view.grow_individual(-7.0, -30.0, -7.0, -10.0)
	var shown := 0
	for n in w.enemy_cache:
		if not is_instance_valid(n):  # freed since the cache was refreshed
			continue
		var e := n as Enemy
		if e == null or e.dead:
			continue
		# a big horde: past MAX_ARROWS only bosses and elites still get one (the rest
		# would pile up on the same edge anyway and cost a polygon each)
		if shown >= MAX_ARROWS and not e.is_boss and not e.elite:
			continue
		if view.has_point(e.global_position):
			continue
		shown += 1
		var col: Color = e.def.color
		var s := 3.2
		if e.is_boss:
			col = Color("ff5566")
			s = 5.0
		elif e.elite:
			col = Color("ffcd75")
			s = 4.0
		_arrow(view, inner, e.hit_center(), col, s, e.phase)
	# EXPLORE chests and survivors get no arrows: finding them is the point of exploring
	if w.survival != null:
		for c in w.survival.crates:
			if is_instance_valid(c):
				_arrow(view, inner, (c as Node2D).global_position + Vector2(0, -6), Color("ffcd75"), 4.2, 0.0, true)


func _arrow(view: Rect2, inner: Rect2, p: Vector2, col: Color, s: float, phase: float, box := false) -> void:
	if view.grow(-2.0).has_point(p):
		return
	var c := inner.get_center()
	var d := p - c
	if d.length() < 0.01:
		return
	# where the line centre -> target leaves the inner rect
	var k := INF
	if d.x != 0.0:
		k = minf(k, (inner.size.x * 0.5) / absf(d.x))
	if d.y != 0.0:
		k = minf(k, (inner.size.y * 0.5) / absf(d.y))
	var at := c + d * minf(k, 1.0)
	var dir := d.normalized()
	var pulse := 0.75 + sin(t * 8.0 + phase) * 0.25
	var side := dir.orthogonal()
	var tip := at + dir * s
	var pts := PackedVector2Array([tip, at - dir * s * 0.6 + side * s, at - dir * s * 0.6 - side * s])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	var inner_pts := PackedVector2Array()
	for q in pts:
		inner_pts.append(at + (q - at) * 0.72)
	draw_colored_polygon(inner_pts, Color(col, pulse))
	if box:
		# a little crate icon behind the arrow
		var bc := at - dir * s * 2.2
		draw_rect(Rect2(bc - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bc - Vector2(1.8, 1.8), Vector2(3.6, 3.6)), Color(col, pulse))
