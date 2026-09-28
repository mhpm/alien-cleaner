class_name Stain
extends Node2D
## Slime left on the floor (an alien's splat animation, or a tinted blob).
## Fades away LIFE seconds after it lands (or sparkles away when the room is CLEAN).

const LIFE := 2.0
const FADE := 0.5

var fading := false


func _ready() -> void:
	get_tree().create_timer(LIFE - FADE, false).timeout.connect(_fade_out)


func _fade_out() -> void:
	if fading or not is_inside_tree():
		return
	fading = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)


func setup(col: Color, s: float) -> void:
	var spr := Sprite2D.new()
	spr.texture = Art.tex("stain")
	spr.rotation = (randi() % 4) * PI * 0.5
	add_child(spr)
	modulate = Color(col, 0.7)
	scale = Vector2.ONE * s * randf_range(0.8, 1.2)


func setup_splat(art: String, s: float, flip: bool, tint: Color) -> void:
	var spr := Art.make_anim(art, s)
	spr.flip_h = flip
	spr.self_modulate = tint
	spr.play("splat")
	add_child(spr)


func clean() -> void:
	if fading:
		return
	fading = true
	var tw := create_tween()
	tw.tween_interval(randf_range(0.0, 0.5))
	tw.tween_callback(func() -> void:
		Burst.spawn(get_parent(), position + Vector2(0, -3), Color(1, 1, 1, 0.9), 6, 30.0, 0.5, 1.5, -20.0))
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
