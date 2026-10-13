class_name HeartSparkles
extends CPUParticles2D
## Tiny hearts that float up and fade (the girl's HEART SHOT): a short burst on her when
## the next heart is ready, and a steady glow on an alien while it is charmed (Charm).
## Art: assets/guns/shot_heart.png (HeartShotAbility.heart_tex).
## It times itself (_process): no outside timers or callbacks hold it, so it can be freed
## with its owner (an alien dying mid-burst) at any moment.

const SIZE := 3.2  # world units across one little heart
const RISE := -38.0  # gravity: they float up
const GLOW := Color(1.0, 0.75, 0.9)

var emit_left := INF  # seconds it keeps emitting (INF = until stop())
var fade_left := -1.0  # > 0: no longer emitting, freed when the last hearts are gone


## A burst of `amount` hearts around `at` (local to `parent`) for `secs`, then it frees itself.
static func burst(parent: Node2D, at: Vector2, secs := 0.8, amount := 12, radius := 10.0) -> HeartSparkles:
	var p := HeartSparkles.new()
	p._setup(amount, radius)
	p.emit_left = secs
	p.position = at
	parent.add_child(p)
	return p


## A steady glow of hearts around `at` until stop() is called.
static func aura(parent: Node2D, at: Vector2, radius := 7.0) -> HeartSparkles:
	var p := HeartSparkles.new()
	p._setup(5, radius)
	p.position = at
	parent.add_child(p)
	return p


## Stops emitting and frees itself once the last hearts have faded.
func stop() -> void:
	emit_left = 0.0


func _process(delta: float) -> void:
	if fade_left > 0.0:
		fade_left -= delta
		if fade_left <= 0.0:
			queue_free()
		return
	emit_left -= delta
	if emit_left <= 0.0:
		emitting = false
		fade_left = lifetime


func _setup(amount_: int, radius: float) -> void:
	texture = HeartShotAbility.heart_tex()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	amount = amount_
	lifetime = 0.8
	explosiveness = 0.15
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = radius
	direction = Vector2.UP
	spread = 50.0
	initial_velocity_min = 8.0
	initial_velocity_max = 22.0
	gravity = Vector2(0, RISE)
	var k := SIZE / maxf(1.0, texture.get_width())
	scale_amount_min = k * 0.6
	scale_amount_max = k
	color = GLOW
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	color_ramp = fade
	z_index = 2
	emitting = true
