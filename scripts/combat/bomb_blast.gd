class_name BombBlast
extends Sprite2D
## The BOMBER DRONE's explosion: plays the kit frames bomber_boom_0..6 (a MEGA bomb plays
## up to 7, the one with the ground ring) once, sized to the blast radius, then frees itself.

const KIT := "res://assets/ui/upgrades/kit/"
const FPS := 22.0
const CANVAS_PER_R := 3.4  # frame canvas width per unit of blast radius

static var frames: Array[Texture2D] = []

var last := 6
var t := 0.0


static func spawn(at: Vector2, r: float, mega: bool) -> void:
	if frames.is_empty():
		for i in 8:
			frames.append(load(KIT + "bomber_boom_%d.png" % i))
	var b := BombBlast.new()
	b.last = 7 if mega else 6
	b.texture = frames[0]
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.scale = Vector2.ONE * (r * CANVAS_PER_R / float(frames[0].get_width()))
	b.offset = Vector2(0, -frames[0].get_height() * 0.18)  # the fireball sits on the ground
	Game.world.effects.add_child(b)
	b.global_position = at


func _process(delta: float) -> void:
	t += delta
	var i := int(t * FPS)
	if i > last:
		queue_free()
		return
	texture = frames[i]
	if i == last:
		modulate.a = 1.0 - (t * FPS - i)
