class_name InfTentacle
extends Node2D
## Infected mode helper attack: a tentacle / claw of the mutation phase (MutationData
## tentacles) bursts out of the floor under an alien after a short warning, hurts and
## stuns everything around it, then sinks back.

const WARN := 0.28
const RISE := 0.1
const HOLD := 0.22
const SINK := 0.18
const HEIGHT := 20.0  # world units at full height
const RADIUS := 14.0

var tex: Texture2D
var damage := 20.0
var sprite: Sprite2D
var t := 0.0
var struck := false
var full := 1.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())  # grows from its base
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.flip_h = randf() < 0.5
	full = HEIGHT / float(tex.get_height())
	sprite.scale = Vector2(full, 0.0)
	add_child(sprite)
	Game.world.telegraph_circle(global_position, RADIUS * 0.8, WARN)


func _process(delta: float) -> void:
	t += delta
	var k := t - WARN
	if k < 0.0:
		return
	if k < RISE:
		sprite.scale = Vector2(full, full * (k / RISE) * 1.15)  # overshoots a little
	elif k < RISE + HOLD:
		if not struck:
			_strike()
		var w := (k - RISE) / HOLD
		sprite.scale = Vector2(full, full * lerpf(1.15, 1.0, minf(w * 3.0, 1.0)))
		sprite.rotation = sin(k * 30.0) * 0.06
	elif k < RISE + HOLD + SINK:
		sprite.scale = Vector2(full, full * (1.0 - (k - RISE - HOLD) / SINK))
	else:
		queue_free()


func _strike() -> void:
	struck = true
	var w := Game.world
	w.add_stain(global_position, Infected.GOO, 1.0)
	w.burst(global_position + Vector2(0, -4), Infected.MAGENTA, 8, 80.0, 0.35, 2.0, 120.0, Vector2.UP, 0.8)
	w.shake(0.1)
	Sfx.play("land", 0.15, -10.0)
	for n in w.enemy_cache:
		if not is_instance_valid(n):  # freed since the cache was refreshed
			continue
		var e := n as Enemy
		if e == null or not e.targetable:
			continue
		if e.global_position.distance_to(global_position) < RADIUS + e.radius:
			e.take_damage(damage, Vector2.UP)
			e.stun(0.6)
