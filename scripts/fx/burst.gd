class_name Burst
extends Node2D
## Lightweight pixel particle burst: square particles with drag/gravity that fade out.

var parts: Array = []  # [pos, vel, life, max_life, size]
var color := Color.WHITE
var gravity := 0.0
var drag := 4.0


static func spawn(parent: Node, pos: Vector2, col: Color, count: int, speed: float,
		life := 0.45, size := 2.0, grav := 0.0, dir := Vector2.ZERO, spread := PI) -> Burst:
	var b := Burst.new()
	b.color = col
	b.gravity = grav
	b.position = pos
	for i in count:
		var a := randf() * TAU
		if dir != Vector2.ZERO:
			a = dir.angle() + randf_range(-spread, spread)
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.35, 1.0)
		var l := life * randf_range(0.6, 1.0)
		b.parts.append([Vector2.ZERO, v, l, l, size * randf_range(0.7, 1.25)])
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	var alive := false
	for p: Array in parts:
		p[2] = float(p[2]) - delta
		if float(p[2]) <= 0.0:
			continue
		alive = true
		var v: Vector2 = p[1]
		v = v * maxf(0.0, 1.0 - drag * delta) + Vector2(0.0, gravity * delta)
		p[1] = v
		p[0] = (p[0] as Vector2) + v * delta
	if not alive:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for p: Array in parts:
		var life: float = p[2]
		if life <= 0.0:
			continue
		var k := life / float(p[3])
		var sz := maxf(1.0, roundf(float(p[4]) * (0.4 + 0.6 * k)))
		var pos: Vector2 = p[0]
		draw_rect(Rect2((pos - Vector2(sz, sz) * 0.5).round(), Vector2(sz, sz)), Color(color, color.a * minf(1.0, k * 2.0)))
