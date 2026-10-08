class_name SlimePuddle
extends Node2D
## Temporary toxic puddle left by the Slime King's landings. Hurts the player.

var radius := 16.0
var life := 6.0
var t := 0.0
var tick := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	tick -= delta
	var w := Game.world
	if w != null and tick <= 0.0 and not w.player.dead:
		var d := w.player.global_position - global_position
		if Vector2(d.x, d.y / 0.7).length() < radius:
			w.player.take_damage(5.0, Vector2.INF, true)
			tick = 0.5
	if randf() < delta * 3.0:
		Burst.spawn(get_parent(), position + Vector2(randf_range(-radius, radius) * 0.7, randf_range(-4, 4)),
				Color("a7f070"), 2, 10.0, 0.6, 1.5, -25.0)
	queue_redraw()


func clean() -> void:
	life = minf(life, t + 0.4)


func _draw() -> void:
	var fade := clampf((life - t) / 0.8, 0.0, 1.0) * clampf(t / 0.2, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
	FastDraw.disc(self, Vector2.ZERO, radius, Color(0.22, 0.72, 0.39, 0.75 * fade))
	FastDraw.disc(self, Vector2(-3, -2), radius * 0.6, Color(0.65, 0.94, 0.44, 0.5 * fade))
	FastDraw.ring(self, Vector2.ZERO, radius, Color(0.15, 0.44, 0.47, fade), 1.0)
