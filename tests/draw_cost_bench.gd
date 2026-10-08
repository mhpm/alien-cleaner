extends Node2D
## Which canvas primitives cost the most when redrawn every frame (see arena_perf_bench).

var mode := ""
var t := 0.0


func _ready() -> void:
	if mode != "":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	call_deferred("_run")


func _process(delta: float) -> void:
	t += delta
	if mode != "":
		queue_redraw()


func _draw() -> void:
	var c := Color(0.6, 1.0, 0.5, 0.4)
	match mode:
		"circles":
			for i in 100:
				draw_circle(Vector2(20 + i % 10 * 30, 40 + i / 10 * 30), 5.0 + sin(t + i), c)
		"arcs":
			for i in 100:
				draw_arc(Vector2(20 + i % 10 * 30, 40 + i / 10 * 30), 3.0 + sin(t + i), 0.0, TAU, 8, c, 1.0)
		"polygons":
			for i in 9:
				var pts := PackedVector2Array()
				for j in 28:
					var a := TAU * j / 28.0
					pts.append(Vector2(150, 300) + Vector2(cos(a), sin(a)) * (60.0 + 6.0 * sin(a * 3.0 + t)) * (1.0 - i * 0.05))
				draw_colored_polygon(pts, c)
		"tex_circles":
			for i in 100:
				var r := 5.0 + sin(t + i)
				draw_texture_rect(_disc(), Rect2(Vector2(20 + i % 10 * 30, 40 + i / 10 * 30) - Vector2(r, r), Vector2(r, r) * 2.0), false, c)
		"polyline16":
			for i in 100:
				var pts := PackedVector2Array()
				var at := Vector2(20 + i % 10 * 30, 40 + i / 10 * 30)
				var r := 3.0 + sin(t + i)
				for j in 13:
					pts.append(at + Vector2.from_angle(TAU * j / 12.0) * r)
				draw_polyline(pts, c, 1.0)
		"circle_aa_off":
			for i in 100:
				draw_circle(Vector2(20 + i % 10 * 30, 40 + i / 10 * 30), 5.0 + sin(t + i), c, true, -1.0, false)
		"fast_disc":
			for i in 100:
				FastDraw.disc(self, Vector2(20 + i % 10 * 30, 40 + i / 10 * 30), 5.0 + sin(t + i), c)
		"fast_ring":
			for i in 100:
				FastDraw.ring(self, Vector2(20 + i % 10 * 30, 40 + i / 10 * 30), 3.0 + sin(t + i) + i * 0.3, c, 1.0 + (i % 3))
		"fast_arc":
			for i in 100:
				FastDraw.arc(self, Vector2(20 + i % 10 * 30, 40 + i / 10 * 30), 8.0, t + i, t + i + 1.0 + (i % 5), c, 1.5)
		"lines":
			for i in 100:
				var at := Vector2(20 + i % 10 * 30, 40 + i / 10 * 30)
				draw_line(at, at + Vector2(10, 4 + sin(t + i)), c, 1.5)
		"quads":
			for i in 100:
				var at := Vector2(20 + i % 10 * 30, 40 + i / 10 * 30)
				var d := Vector2(10, 4 + sin(t + i))
				var n := d.orthogonal().normalized() * 0.75
				draw_primitive(PackedVector2Array([at - n, at + d - n, at + d + n, at + n]), PackedColorArray([c, c, c, c]), PackedVector2Array())
		"rects":
			for i in 100:
				draw_rect(Rect2(Vector2(20 + i % 10 * 30, 40 + i / 10 * 30), Vector2(3, 3)), c)


static var _disc_tex: Texture2D


static func _disc() -> Texture2D:
	if _disc_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(16.0 - d, 0.0, 1.0)))
		_disc_tex = ImageTexture.create_from_image(img)
	return _disc_tex


func _run() -> void:
	for m in ["", "circles", "fast_disc", "arcs", "fast_ring", "fast_arc", "lines", "polyline16", "rects"]:
		var nodes: Array = []
		if m != "":
			for k in 4:
				var n := (get_script() as GDScript).new() as Node2D
				n.mode = m
				add_child(n)
				nodes.append(n)
		await get_tree().create_timer(0.5).timeout
		var frames := 0
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < 1500000:
			await get_tree().process_frame
			frames += 1
		print("DRAW %-9s x4 nodes: frame=%.2fms" % [m if m != "" else "nothing", (Time.get_ticks_usec() - t0) / 1000.0 / frames])
		for n in nodes:
			n.queue_free()
	get_tree().quit()
