class_name BossFence
extends Node2D
## Electric fence that rings the final boss fight (Survival._send_final): pylons in a
## circle joined by crackling arcs. Nobody gets out: the astronaut is thrown back in
## with a shock (and a little damage), aliens are held inside. Rises when the boss
## arrives and powers down (`dissolve`) once it is cleaned.

const POSTS := 32
const ZAP_CD := 0.8
const ZAP_SHARE := 0.08  # a shock takes this share of max health
const COL := Color("5fe6ff")

var radius := 150.0
var t := 0.0
var rise := 0.0  # 0 -> 1 while the pylons come up
var zap_t := 0.0
var arc_t := 0.0
var arcs: Array[PackedVector2Array] = []
var dying := false


func setup(center: Vector2, r: float) -> BossFence:
	position = center
	radius = r
	z_index = 1
	return self


func _ready() -> void:
	Sfx.play("zap", 0.0, 2.0)
	Sfx.play("door", 0.0)
	_new_arcs()


## Is a point inside the fight? (the fence keeps `margin` clear of it)
func holds(p: Vector2, margin := 0.0) -> bool:
	return p.distance_to(global_position) <= radius - margin


func dissolve() -> void:
	if dying:
		return
	dying = true
	Sfx.play("zap", 0.0)
	for i in POSTS:
		Game.world.burst(_post(i), COL, 6, 50.0, 0.4, 2.0, -30.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _post(i: int) -> Vector2:
	return global_position + Vector2.from_angle(TAU * i / POSTS - PI * 0.5) * radius


func _physics_process(delta: float) -> void:
	t += delta
	rise = minf(1.0, rise + delta / 0.6)
	zap_t -= delta
	if dying:
		return
	var w := Game.world
	var c := global_position
	# the astronaut is thrown back in with a shock
	var p := w.player
	if not p.dead:
		var d := p.global_position - c
		var edge := radius - 7.0
		if d.length() > edge:
			var n := d.normalized()
			p.global_position = c + n * edge
			p.knock = -n * 190.0
			if zap_t <= 0.0:
				zap_t = ZAP_CD
				var at := c + n * radius
				var l := Lightning.new()
				l.a = at
				l.b = p.global_position + Vector2(0, Player.BODY_Y)
				l.color = COL
				w.effects.add_child(l)
				w.burst(at, COL, 10, 80.0, 0.3, 2.0)
				Sfx.play("zap", 0.05)
				w.shake(0.3)
				p.take_damage(float(Game.stats.max_hp) * ZAP_SHARE, Vector2.INF, true)
	# aliens (the boss and its minions) stay inside too
	for node in w.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		var de := e.global_position - c
		var lim := radius - e.radius * 0.8
		if de.length() > lim:
			e.global_position = c + de.normalized() * lim


func _process(delta: float) -> void:
	arc_t -= delta
	if arc_t <= 0.0:
		arc_t = 0.05
		_new_arcs()
	queue_redraw()


## Fresh jagged arcs between neighbouring pylons (they flicker every few frames).
func _new_arcs() -> void:
	arcs.clear()
	for i in POSTS:
		var a := _post(i) - global_position
		var b := _post((i + 1) % POSTS) - global_position
		var pts := PackedVector2Array()
		var perp := (b - a).orthogonal().normalized()
		var n := 6
		for k in n + 1:
			var off := 0.0 if k == 0 or k == n else randf_range(-4.0, 4.0)
			pts.append(a.lerp(b, float(k) / n) + perp * off + Vector2(0, -7))
		arcs.append(pts)


func _draw() -> void:
	var up := rise * rise
	# glowing ring on the floor
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 160, Color(COL, 0.10 * up), 10.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 160, Color(COL, 0.35 * up), 1.5)
	if rise >= 0.9:
		var flick := 0.7 + 0.3 * sin(t * 40.0)
		for pts in arcs:
			draw_polyline(pts, Color(COL, 0.35 * flick), 4.0)
			draw_polyline(pts, Color(COL, 0.9 * flick), 2.0)
			draw_polyline(pts, Color(1, 1, 1, 0.9 * flick), 1.0)
	# pylons
	for i in POSTS:
		var q := _post(i) - global_position
		var h := 10.0 * up
		draw_rect(Rect2(q + Vector2(-2.5, -h), Vector2(5, h)), Color("1a1c2c"))
		draw_rect(Rect2(q + Vector2(-1.5, -h), Vector2(3, h)), Color("566c86"))
		var glow := 0.6 + 0.4 * sin(t * 8.0 + i)
		draw_circle(q + Vector2(0, -h - 1.5), 3.2, Color(COL, 0.35 * glow * up))
		draw_circle(q + Vector2(0, -h - 1.5), 1.8, Color(1, 1, 1, glow * up))
