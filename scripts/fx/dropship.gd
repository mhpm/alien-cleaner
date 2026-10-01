class_name Dropship
extends Node2D
## A UFO crossing the screen low over the arena, beaming `drops` aliens down on its way
## (Survival "dropship" event). `spawn` is called with each ground spot.

const HOVER := 46.0  # how high over the ground it flies
const SCALE := 0.55

var from := Vector2.ZERO  # ground-level path
var to := Vector2.ZERO
var dur := 3.2
var drops := 6
var spawn: Callable
var t := 0.0
var dropped := 0
var beam_t := 0.0
var ufo: AnimatedSprite2D


func _ready() -> void:
	z_index = 5
	ufo = Art.make_anim("ufo", SCALE)
	ufo.play("walk")
	ufo.position = Vector2(0, -HOVER)
	ufo.flip_h = to.x < from.x
	add_child(ufo)
	position = from
	Sfx.play("charge", 0.0, -8.0)


func _process(delta: float) -> void:
	t += delta
	var k := clampf(t / dur, 0.0, 1.0)
	position = from.lerp(to, k)
	ufo.position = Vector2(0, -HOVER + sin(t * 5.0) * 3.0)
	ufo.rotation = sin(t * 5.0) * 0.06
	# drops spread over the middle 80% of the pass
	var due := clampi(floori((k - 0.1) / 0.8 * drops) + 1, 0, drops) if k >= 0.1 else 0
	while dropped < due:
		dropped += 1
		beam_t = 0.4
		spawn.call(global_position)
		Sfx.play("zap", 0.15, -12.0)
	beam_t -= delta
	queue_redraw()
	if t >= dur:
		queue_free()


func _draw() -> void:
	# the ship's shadow on the ground, and the tractor beam while it drops
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	if beam_t > 0.0:
		var a := clampf(beam_t / 0.4, 0.0, 1.0)
		var top := ufo.position.y + 8.0
		var poly := PackedVector2Array([Vector2(-7, top), Vector2(7, top), Vector2(20, 0), Vector2(-20, 0)])
		draw_colored_polygon(poly, Color(0.65, 1.0, 0.45, 0.35 * a))
		draw_line(Vector2(0, top), Vector2(0, 0), Color(0.9, 1.0, 0.8, 0.6 * a), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 22.0, Color(0.65, 1.0, 0.45, 0.3 * a))
		draw_set_transform(Vector2.ZERO)
