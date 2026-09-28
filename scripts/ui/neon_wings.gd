class_name NeonWings
extends Control
## Three slanted pixel bars beside a title ("speed wings"), pointing outwards.

var color := Color("73eff7")
var flip := false  # true = right-hand wing


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(44, 26)


func _draw() -> void:
	var p := NeonFrame.PX
	for i in 3:
		var y := p * (1 + i * 4)
		var len := size.x - i * p * 5
		var x0 := size.x - len if not flip else 0.0
		var slant := p * 3.0
		# parallelogram leaning away from the title
		var pts := PackedVector2Array()
		if not flip:
			pts = [Vector2(x0 + slant, y), Vector2(size.x, y), Vector2(size.x - slant, y + p * 2), Vector2(x0, y + p * 2)]
		else:
			pts = [Vector2(0, y), Vector2(len - slant, y), Vector2(len, y + p * 2), Vector2(slant, y + p * 2)]
		draw_colored_polygon(pts, Color(color, 1.0 - i * 0.22))
		draw_polyline(PackedVector2Array([pts[0], pts[1]]), Color(color.lightened(0.6), 1.0 - i * 0.22), 1.0, false)
