@tool
class_name HazardArea
extends ArenaObject
## A dangerous patch of floor (rectangle centred on the node). Each type has its own
## animated look and feel; numbers are free to tune:
##   ACID       burns                      RADIATION  slow, steady damage, glows
##   ALIEN_SLIME sticky: slows a lot        ELECTRIC   cycles on/off with a warning flicker
##   FIRE       hard bursts of damage      VACUUM     pulls everything to its centre
## Cheap at runtime: one point-in-rect test per frame for the astronaut; aliens (if
## `affects_enemies`) only on damage ticks, from the 3x3-cell enemy grid.

enum Type { ACID, RADIATION, ALIEN_SLIME, ELECTRIC, FIRE, VACUUM }
const COLORS := [Color("a7f070"), Color("e8e04a"), Color("c75bd6"), Color("73eff7"), Color("ff7a2a"), Color("6f86b8")]
const WARN := 0.7  # ELECTRIC: seconds of flicker before it goes live

@export var type := Type.ACID:
	set(value):
		type = value
		queue_redraw()
@export var size := Vector2(96, 64):
	set(value):
		size = value.max(Vector2(8, 8)).round()
		queue_redraw()
## Health taken per tick (scaled by the arena's difficulty).
@export_range(0.0, 100.0, 0.5) var damage := 5.0
@export_range(0.1, 5.0, 0.05) var damage_interval := 0.6
## Speed lost while inside (0-90%).
@export_range(0.0, 90.0, 1.0) var slow_percentage := 0.0
## Seconds it stays on once active (0 = forever).
@export_range(0.0, 600.0, 1.0) var duration := 0.0
@export var active := true:
	set(value):
		active = value
		queue_redraw()
## Starts off until an ArenaTrigger (ACTIVATE_HAZARDS) switches it on.
@export var trigger_required := false
## ELECTRIC: seconds on / off (0 = always on).
@export_range(0.0, 20.0, 0.1) var cycle_on := 2.0
@export_range(0.0, 20.0, 0.1) var cycle_off := 1.5
## VACUUM: pull speed (world units / s).
@export_range(0.0, 200.0, 1.0) var pull := 45.0
@export var affects_enemies := true

var _director: Node
var _t := 0.0
var _tick := 0.0
var _on_for := 0.0
var _phase := 0.0  # cycle clock


func _ready() -> void:
	super._ready()
	set_physics_process(false)
	set_process(not Engine.is_editor_hint())


func arena_layer() -> String:
	return "Hazards"


func palette_editor_icon() -> String:
	return "Warning"


func palette_width() -> float:
	return size.x


func rect() -> Rect2:
	return Rect2(-size * 0.5, size)


## Puddles, fire and the vacuum are rounded blobs; the electric floor and radiation zone
## are rectangles (they read as man-made plates).
func is_round() -> bool:
	return type in [Type.ACID, Type.ALIEN_SLIME, Type.FIRE, Type.VACUUM]


## Inside the hazard's own shape (local point).
func covers(local: Vector2) -> bool:
	if not is_round():
		return rect().has_point(local)
	var q := local / (size * 0.5)
	return q.length() <= 1.0 + 0.08 * sin(q.angle() * 5.0 + hash(name) % 7)


## Organic outline (local points) of a round hazard, stable for its name.
func _outline(scale_k := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var seed_k := float(hash(name) % 7)
	for i in 28:
		var a := TAU * i / 28.0
		var r := 1.0 + 0.08 * sin(a * 5.0 + seed_k) + 0.05 * sin(a * 3.0 - seed_k * 0.7)
		pts.append(Vector2(cos(a), sin(a)) * size * 0.5 * r * scale_k)
	return pts


func activate(director: Node) -> void:
	_director = director
	if trigger_required:
		active = false
	set_physics_process(true)


func set_active(on: bool) -> void:
	active = on
	_on_for = 0.0
	_phase = 0.0
	if on and _director != null:
		_director.world.ring(global_position, maxf(size.x, size.y) * 0.5, COLORS[type], 0.4, 2.0)
		Sfx.play("alert", 0.0, -8.0)


## Live right now (ELECTRIC goes on and off).
func is_live() -> bool:
	if not active:
		return false
	if type == Type.ELECTRIC and cycle_on > 0.0 and cycle_off > 0.0:
		return fmod(_phase, cycle_on + cycle_off) < cycle_on
	return true


func _warning() -> bool:
	if not active or type != Type.ELECTRIC or cycle_off <= 0.0:
		return false
	var c := fmod(_phase, cycle_on + cycle_off)
	return c > cycle_on + cycle_off - WARN


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not active:
		return
	_phase += delta
	_on_for += delta
	if duration > 0.0 and _on_for >= duration:
		active = false
		return
	if not is_live():
		return
	var w: GameWorld = _director.world
	var p := w.player
	var inside := not p.dead and covers(to_local(p.global_position))
	if inside:
		if slow_percentage > 0.0:
			p.slow_down(1.0 - slow_percentage / 100.0, 0.15)
		if type == Type.VACUUM:
			var to := global_position - p.global_position
			if to.length() > 3.0:
				p.move_and_collide(to.normalized() * pull * delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = damage_interval
	if inside and damage > 0.0:
		p.take_damage(damage * _director.spawner.dmg_mult, global_position if type == Type.FIRE else Vector2.INF, true)
		w.burst(p.global_position + Vector2(0, -8), COLORS[type], 6, 40.0, 0.3, 1.5, -40.0)
	if affects_enemies:
		_hurt_aliens(w)


func _hurt_aliens(w: GameWorld) -> void:
	var r := Rect2(global_position - size * 0.5, size)
	var c0 := Vector2i((r.position / GameWorld.GRID_CELL).floor())
	var c1 := Vector2i((r.end / GameWorld.GRID_CELL).floor())
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			for n in w.enemy_grid.get(Vector2i(cx, cy), []):
				var e := n as Enemy
				if not is_instance_valid(e) or e.dead or e.is_boss or not covers(to_local(e.global_position)):
					continue
				if damage > 0.0:
					e.take_damage(damage * 1.5, Vector2.ZERO)
				if slow_percentage > 0.0:
					e.slow_t = maxf(e.slow_t, damage_interval)
				if type == Type.VACUUM:
					e.knock += (global_position - e.global_position).normalized() * pull


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	var b := arena.get_bounds()
	if b != null and not b.global_rect().intersects(Rect2(global_position - size * 0.5, size)):
		report.error("Hazard %s is outside the arena bounds." % name, self)
	if trigger_required and object_id.is_empty():
		report.error("Hazard %s waits for a trigger but has no object_id." % name, self)
	if damage <= 0.0 and slow_percentage <= 0.0 and type != Type.VACUUM:
		report.info("Hazard %s does nothing (no damage, no slow)." % name, self)


# ---------------------------------------------------------------- looks

func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_hazard(0.6)
		_draw_editor()
		return
	if not active:
		return
	_draw_hazard(1.0)


func _draw_hazard(k: float) -> void:
	var r := rect()
	var c: Color = COLORS[type]
	var live := is_live() or Engine.is_editor_hint()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	match type:
		Type.ACID, Type.ALIEN_SLIME:
			draw_colored_polygon(_outline(1.06), Color(c.darkened(0.6), 0.35 * k))  # wet rim
			draw_colored_polygon(_outline(), Color(c.darkened(0.45), 0.6 * k))
			draw_colored_polygon(_outline(0.7), Color(c.darkened(0.25), 0.35 * k))
			var n := int(r.size.x * r.size.y / 260.0)
			for i in n:  # blobs that wobble and bubbles that pop
				var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
				if not covers(p * 1.12):
					continue
				var s := rng.randf_range(3.0, 8.0) * (1.0 + 0.15 * sin(_t * 3.0 + i))
				draw_circle(p, s, Color(c, 0.35 * k))
				var life := fmod(_t * rng.randf_range(0.4, 0.9) + rng.randf(), 1.0)
				draw_arc(p + Vector2(0, -life * 4.0), 1.0 + life * 2.5, 0.0, TAU, 8, Color(c.lightened(0.4), (1.0 - life) * 0.8 * k), 1.0)
		Type.RADIATION:
			var pulse := 0.5 + 0.5 * sin(_t * 2.5)
			draw_rect(r, Color(c, (0.12 + 0.1 * pulse) * k))
			_stripes(r, c, k)
			var rad := minf(r.size.x, r.size.y) * 0.28
			for i in 3:  # trefoil
				var a := _t * 0.4 + TAU * i / 3.0
				draw_arc(Vector2.ZERO, rad * 0.6, a - 0.5, a + 0.5, 10, Color(c, 0.75 * k), rad * 0.7)
			draw_circle(Vector2.ZERO, rad * 0.18, Color(c, 0.85 * k))
		Type.ELECTRIC:
			var on := is_live()
			var warn := _warning() and fmod(_t * 12.0, 1.0) < 0.5
			draw_rect(r, Color(c, (0.2 if on else (0.12 if warn else 0.04)) * k))
			var step := 16.0
			var x := r.position.x
			while x <= r.end.x:
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(c, (0.45 if on else 0.15) * k), 1.0)
				x += step
			var y := r.position.y
			while y <= r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(c, (0.45 if on else 0.15) * k), 1.0)
				y += step
			if on and not Engine.is_editor_hint():
				var arc := RandomNumberGenerator.new()
				arc.seed = int(_t * 20.0) + hash(name)
				for i in 3:
					var a := Vector2(arc.randf_range(r.position.x, r.end.x), arc.randf_range(r.position.y, r.end.y))
					var pts := PackedVector2Array([a])
					for j in 4:
						a += Vector2(arc.randf_range(-10, 10), arc.randf_range(-10, 10))
						pts.append(a.clamp(r.position, r.end))
					draw_polyline(pts, Color(0.85, 1.0, 1.0, 0.9), 1.5)
			draw_rect(r, Color(c, 0.7 * k), false, 1.5)
		Type.FIRE:
			draw_colored_polygon(_outline(), Color(0.35, 0.08, 0.02, 0.45 * k))
			var n := int(r.size.x / 7.0) * maxi(1, int(r.size.y / 24.0))
			for i in n:
				var base := Vector2(rng.randf_range(r.position.x + 3, r.end.x - 3), rng.randf_range(r.position.y + 8, r.end.y))
				if not covers(base):
					continue
				var h := rng.randf_range(6.0, 14.0) * (0.75 + 0.35 * sin(_t * 9.0 + i * 1.7))
				var wdt := rng.randf_range(2.5, 4.5)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-wdt, 0), base + Vector2(sin(_t * 7.0 + i) * 2.0, -h), base + Vector2(wdt, 0)]), Color(c, 0.85 * k))
				draw_colored_polygon(PackedVector2Array([base + Vector2(-wdt * 0.5, 0), base + Vector2(0, -h * 0.55), base + Vector2(wdt * 0.5, 0)]), Color(1.0, 0.85, 0.3, 0.9 * k))
		Type.VACUUM:
			draw_colored_polygon(_outline(), Color(0.02, 0.02, 0.06, 0.6 * k))
			var rad := minf(r.size.x, r.size.y) * 0.5
			for i in 5:  # spiralling arms
				var a := -_t * 2.0 + TAU * i / 5.0
				var pts := PackedVector2Array()
				for j in 12:
					var f := j / 11.0
					pts.append(Vector2.from_angle(a + f * 2.4) * rad * (1.0 - f * 0.9))
				draw_polyline(pts, Color(c.lightened(0.3), 0.55 * k), 1.5)
			for i in 10:  # streaks falling in
				var life := fmod(_t * 0.8 + rng.randf(), 1.0)
				var dir := Vector2.from_angle(rng.randf() * TAU)
				draw_line(dir * rad * (1.0 - life), dir * rad * maxf(0.0, 1.0 - life - 0.12), Color(1, 1, 1, 0.6 * (1.0 - life) * k), 1.0)
			draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.9 * k))
			draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 16, Color(c, 0.8 * k), 1.0)
	if is_round():
		var line := _outline()
		line.append(line[0])
		draw_polyline(line, Color(c, 0.5 * k), 1.0)


func _stripes(r: Rect2, c: Color, k: float) -> void:
	var w := 4.0
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), Color(0.1, 0.1, 0.1, 0.6 * k))
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), Color(0.1, 0.1, 0.1, 0.6 * k))
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(Vector2(x, r.position.y), Vector2(minf(w, r.end.x - x), w)), Color(c, 0.8 * k))
		draw_rect(Rect2(Vector2(x, r.end.y - w), Vector2(minf(w, r.end.x - x), w)), Color(c, 0.8 * k))
		x += w * 2.0


func _draw_editor() -> void:
	var c: Color = COLORS[type]
	if is_round():
		var line := _outline()
		line.append(line[0])
		draw_polyline(line, c, 1.5)
	else:
		_zone(rect(), c)
	var info := "%s · %s dmg/%.1fs" % [Type.keys()[type].replace("_", " "), str(damage), damage_interval]
	if slow_percentage > 0.0:
		info += " · slow %d%%" % slow_percentage
	if trigger_required:
		info += " · TRIGGER"
	_editor_label(info, Vector2(0, rect().position.y - 3), c)
	_id_caption(Vector2(0, rect().end.y + 9), c)
