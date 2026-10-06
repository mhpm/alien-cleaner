@tool
class_name DefendCore
extends ArenaObject
## Something to protect (DEFEND objectives): a reactor the aliens gnaw at. Every alien
## inside `danger_radius` drains `drain_per_alien` health per second (looked up in the
## enemy grid around it, no searching). At 0 it blows up and reports "core_destroyed".
## Heals slowly while no alien is near. `look` = its own picture (a village well, a
## house...; empty = the reactor). `lure_range` > 0 = raiders: aliens within it that
## are not busy with the astronaut march on it (Enemy.lure) until he comes close.

const COLOR := Color("ffcd75")
const ART := "l:112"
const WIDTH := 52.0

@export_range(10.0, 5000.0, 10.0) var health := 400.0
@export_range(10.0, 200.0, 1.0) var danger_radius := 48.0:
	set(value):
		danger_radius = value
		queue_redraw()
@export_range(0.0, 100.0, 0.5) var drain_per_alien := 6.0
@export_range(0.0, 50.0, 0.5) var regen := 2.0
## Shown when it falls ("THE WELL DESTROYED!"); "" = CORE.
@export var core_name := ""
## Its own picture standing on the spot; empty = the reactor.
@export var look: Texture2D:
	set(value):
		look = value
		queue_redraw()
@export_range(16.0, 400.0, 1.0) var look_width := WIDTH:
	set(value):
		look_width = value
		queue_redraw()
## Aliens this close (and not near the astronaut) go for it instead. 0 = none.
@export_range(0.0, 2000.0, 10.0) var lure_range := 0.0:
	set(value):
		lure_range = value
		queue_redraw()

var _director: Node
var _hp := 0.0
var _t := 0.0
var _hit := 0.0
var _dead := false
var _body: StaticBody2D
var _lure_t := 0.0


func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_physics_process(false)


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return look if look != null else PropData.tex(ART)


func palette_width() -> float:
	return look_width if look != null else WIDTH


func activate(director: Node) -> void:
	_director = director
	_hp = health
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(palette_width() * 0.8, 14)
	cs.shape = shape
	cs.position = Vector2(0, -7)
	_body.add_child(cs)
	add_child(_body)
	reparent(director.world.entities)
	set_physics_process(true)


func ratio() -> float:
	return _hp / health


func is_resolved() -> bool:
	return _dead


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	var w: GameWorld = _director.world
	if lure_range > 0.0:
		_lure_t -= delta
		if _lure_t <= 0.0:
			_lure_t = 0.4
			_lure(w)
	var c := Vector2i((global_position / GameWorld.GRID_CELL).floor())
	var reach := int(ceil(danger_radius / GameWorld.GRID_CELL))
	var n := 0
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for e in w.enemy_grid.get(c + Vector2i(dx, dy), []):
				if is_instance_valid(e) and (e as Enemy).global_position.distance_to(global_position) < danger_radius:
					n += 1
	if n > 0:
		_hp -= drain_per_alien * n * delta
		_hit = 0.15
		if randf() < delta * 6.0:
			w.burst(global_position + Vector2(randf_range(-16, 16), -20), Color("ff5566"), 2, 40.0, 0.3, 1.5)
		if _hp <= 0.0:
			_explode()
			return
	else:
		_hp = minf(health, _hp + regen * delta)
	_hit = maxf(0.0, _hit - delta)
	queue_redraw()


## Raiders: aliens in `lure_range` that the astronaut is not fighting turn on it.
func _lure(w: GameWorld) -> void:
	var p := w.player.global_position
	for n in w.enemy_cache:
		var e := n as Enemy
		if e == null or e.dead or e.is_boss or e.lure != null:
			continue
		if e.global_position.distance_to(global_position) < lure_range and e.global_position.distance_to(p) > Enemy.LURE_BREAK * 1.5:
			e.lure = self


func _explode() -> void:
	_dead = true
	var w: GameWorld = _director.world
	w.explosion(global_position + Vector2(0, -14), 60.0, 80.0, 0.0)
	w.hud.banner("%s DESTROYED!" % (core_name.to_upper() if not core_name.is_empty() else "CORE"), Color("ff5566"), 30, 1.2)
	if _body != null:
		_body.queue_free()
	_director.fire("core_destroyed", object_id)
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_editor()
		return
	var tex := palette_icon()
	var tint := Color(0.3, 0.3, 0.35) if _dead else (Color(1.6, 0.8, 0.8) if _hit > 0.0 else Color.WHITE)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, danger_radius, Color(1.0, 0.3, 0.3, 0.05 + 0.05 * pulse))
	draw_arc(Vector2.ZERO, danger_radius, 0.0, TAU, 48, Color(1.0, 0.4, 0.4, 0.35), 1.0)
	draw_set_transform(Vector2.ZERO)
	_standing(tex, palette_width(), tint)
	if not _dead:
		var k := ratio()
		var top := -_height() - 8.0
		draw_rect(Rect2(-18, top, 36, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-18, top, 36 * k, 4), COLOR if k > 0.35 else Color("ff5566"))


func _height() -> float:
	var tex := palette_icon()
	return palette_width() * tex.get_height() / tex.get_width() if tex != null else 38.0


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	var b := arena.get_bounds()
	if b != null and not b.contains(global_position):
		report.error("Core %s is outside the arena." % name, self)


func _draw_editor() -> void:
	draw_circle(Vector2.ZERO, danger_radius, Color(1.0, 0.3, 0.3, 0.06))
	_dashed_circle(danger_radius, Color(1.0, 0.4, 0.4, 0.8), 1.5)
	if lure_range > 0.0:
		_dashed_circle(lure_range, Color(1.0, 0.6, 0.3, 0.5), 1.0, 64)
	_standing(palette_icon(), palette_width())
	_editor_label("DEFEND %s %d HP" % [core_name.to_upper() if not core_name.is_empty() else "CORE", health], Vector2(0, 10), COLOR)
	_id_caption(Vector2(0, 18), COLOR)
