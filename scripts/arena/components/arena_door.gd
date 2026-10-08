@tool
class_name ArenaDoor
extends ArenaObject
## An energy barrier that blocks bodies until it opens: by an ArenaTrigger (OPEN_DOOR),
## when the wave `open_on_wave` is cleared or when the objective `open_on_objective` is
## done. Lets you gate parts of the arena behind progress.

const COLOR := Color("41a6f6")

## Width x thickness, centred on the node (rotate the node for vertical doors).
@export var size := Vector2(64, 8):
	set(value):
		size = value.max(Vector2(8, 4)).round()
		queue_redraw()
@export var open_on_wave := ""
@export var open_on_objective := ""
@export var starts_open := false

var _body: StaticBody2D
var _open := false
var _t := 0.0
var _fade := 1.0


func _ready() -> void:
	super._ready()
	set_process(not Engine.is_editor_hint())


func arena_layer() -> String:
	return "GameplayObjects"


func palette_editor_icon() -> String:
	return "Lock"


func palette_width() -> float:
	return size.x


func activate(director: Node) -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	_body.add_child(cs)
	add_child(_body)
	director.event_fired.connect(_on_event)
	if starts_open:
		open()


func _on_event(kind: String, subject: String, _tags: PackedStringArray) -> void:
	if (kind == "wave_cleared" and subject == open_on_wave and not open_on_wave.is_empty()) \
			or (kind == "objective_completed" and subject == open_on_objective and not open_on_objective.is_empty()):
		open()


func open() -> void:
	if _open:
		return
	_open = true
	if _body != null:
		_body.queue_free()
		_body = null
	if Game.world != null and not starts_open:
		Sfx.play("door", 0.0)
		Game.world.burst(global_position, COLOR, 18, 70.0, 0.4, 2.0)


func is_resolved() -> bool:
	return _open


func _process(delta: float) -> void:
	_t += delta
	if _open and _fade > 0.0:
		_fade = maxf(0.0, _fade - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var editor := Engine.is_editor_hint()
	var k := 1.0 if editor else _fade
	var half := size * 0.5
	for sx: float in [-1.0, 1.0]:  # pylons
		draw_rect(Rect2(Vector2(sx * half.x - 3.0, -half.y - 6.0), Vector2(6, size.y + 8.0)), Color(0.15, 0.18, 0.28))
		draw_rect(Rect2(Vector2(sx * half.x - 2.0, -half.y - 5.0), Vector2(4, 3)), COLOR if not _open else Color(0.3, 0.4, 0.5))
	if k > 0.0:
		draw_rect(Rect2(-half, size), Color(COLOR, 0.25 * k))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_t * 15.0)
		for i in 3:
			var pts := PackedVector2Array()
			for j in 7:
				pts.append(Vector2(-half.x + size.x * j / 6.0, rng.randf_range(-half.y, half.y)))
			FastDraw.polyline(self, pts, Color(0.75, 0.95, 1.0, 0.85 * k), 1.0)
	if editor:
		var gate := "trigger"
		if not open_on_wave.is_empty():
			gate = "after wave " + open_on_wave
		elif not open_on_objective.is_empty():
			gate = "after " + open_on_objective
		_editor_label("DOOR · " + gate, Vector2(0, half.y + 9), COLOR)
		_id_caption(Vector2(0, half.y + 17), COLOR)


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	if object_id.is_empty() and open_on_wave.is_empty() and open_on_objective.is_empty() and not starts_open:
		report.warning("Door %s can never open (no object_id for triggers, no wave or objective)." % name, self)
	if not open_on_objective.is_empty() and arena.data != null and not arena.data.objectives.any(func(o: ObjectiveData) -> bool: return o != null and o.objective_id == open_on_objective):
		report.error("Door %s waits for missing objective \"%s\"." % [name, open_on_objective], self)
