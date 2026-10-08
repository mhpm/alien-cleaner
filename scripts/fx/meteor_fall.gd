class_name MeteorFall
extends Node2D
## One meteor of a METEOR SHOWER (Survival "meteor" event): after `warn` seconds (the
## Telegraph circle is already on the floor) an asteroid from the world-4 kit streaks
## down from the sky and slams into `position`; `on_land` does the damage.

const KIT := "res://assets/ui/world/world_4/image_%03d.png"
const ROCKS := [9, 14, 25, 36, 40, 44, 53, 61, 73, 144]
const FALL := 0.45
const FROM := Vector2(-110, -240)  # where it comes from, relative to the impact

var warn := 1.2
var on_land: Callable
var t := 0.0
var rock: Sprite2D


func _ready() -> void:
	z_index = 6
	rock = Sprite2D.new()
	rock.texture = load(KIT % ROCKS[randi() % ROCKS.size()])
	rock.scale = Vector2.ONE * 0.45
	rock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rock.visible = false
	add_child(rock)


func _process(delta: float) -> void:
	t += delta
	if t < warn:
		return
	var k := clampf((t - warn) / FALL, 0.0, 1.0)
	rock.visible = true
	rock.position = FROM * (1.0 - k * k)
	rock.rotation += delta * 8.0
	queue_redraw()
	if k >= 1.0:
		on_land.call(global_position)
		queue_free()


func _draw() -> void:
	if not rock.visible:
		return
	# a burning trail behind the rock
	var dir := -FROM.normalized()
	for i in 6:
		var p := rock.position - dir * (8.0 + i * 9.0)
		FastDraw.disc(self, p, 7.0 - i, Color(1.0, 0.55 - i * 0.06, 0.2, 0.55 - i * 0.08))
