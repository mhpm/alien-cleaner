class_name Bar
extends Control
## Health bar with a white "damage lag" chunk and optional centered text.

var ratio := 1.0
var lag := 1.0
var fill := Color("b13e53")
var text := ""
var font_size := 12
var framed := true  # false: only the fill (drawn inside a painted trough)


func _process(delta: float) -> void:
	if lag > ratio:
		lag = move_toward(lag, ratio, delta * 0.7)
	else:
		lag = ratio
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var inner := r
	if framed:
		draw_rect(r, Color("1a1c2c"))
		inner = r.grow(-2.0)
		draw_rect(inner, Color("333c57"))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * lag, inner.size.y)), Color("f4f4f4"))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)), fill)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, 2.0)), fill.lightened(0.35))
	if text != "":
		var font := get_theme_default_font()
		var pos := Vector2(0.0, size.y * 0.5 + font_size * 0.36)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 4, Color("1a1c2c"))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color.WHITE)
