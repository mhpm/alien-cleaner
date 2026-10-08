@tool
class_name ArenaExit
extends ArenaObject
## Extraction portal. Closed (a dim pad) until every MAIN objective is done, unless
## `always_open`; then it powers up and the guide arrow points at it. Stepping in wins
## the arena. Without an exit the arena is won the moment the MAIN objectives are done.

const COLOR := Color("a7f070")
const PORTAL := "res://assets/sprites/enviroment/enviroment_elements/enviroment_142.png"
const REACH := 16.0

@export var always_open := false

var _director: Node
var _open := false
var _k := 0.0
var _t := 0.0


func _ready() -> void:
	super._ready()
	set_process(false)


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return ArenaArt.tex(PORTAL)


func palette_width() -> float:
	return 44.0


func activate(director: Node) -> void:
	_director = director
	set_process(true)
	if always_open:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	if _director != null:
		_director.world.ring(global_position, 30.0, COLOR, 0.5, 3.0)
		Sfx.play("door", 0.0)


func is_open() -> bool:
	return _open


func is_resolved() -> bool:
	return not _open  # the guide arrow only cares once it is open


func _process(delta: float) -> void:
	_t += delta
	_k = move_toward(_k, 1.0 if _open else 0.25, delta * 1.5)
	queue_redraw()
	var p: Player = _director.world.player
	if _open and not p.dead and p.global_position.distance_to(global_position) < REACH:
		set_process(false)
		_director.exit_reached(self)


func _draw() -> void:
	var tex := ArenaArt.tex(PORTAL)
	var k := 1.0 if Engine.is_editor_hint() else _k
	var pulse := 0.8 + sin(_t * 5.0) * 0.2
	var flat := Transform2D(0.0, Vector2(1.0, 0.5), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(flat)
	FastDraw.disc(self, Vector2.ZERO, 30.0 * k, Color(0.45, 1.0, 0.55, 0.18 * pulse))
	for i in 3:
		var a := _t * (2.0 + i) + i * 2.0
		FastDraw.arc(self, Vector2.ZERO, (16.0 + i * 6.0) * k, a, a + PI * 1.2, Color(0.65, 1.0, 0.6, 0.7 * pulse * k), 1.5, flat)
	draw_set_transform(Vector2.ZERO)
	if tex != null:
		var sz := Vector2(44.0, 44.0 * tex.get_height() / tex.get_width())
		draw_texture_rect(tex, Rect2(Vector2(-sz.x * 0.5, -sz.y + 6.0), sz), false, Color(1, 1, 1, maxf(k, 0.45)))
	if Engine.is_editor_hint():
		_editor_label("EXIT" + (" (open)" if always_open else " · after MAIN objectives"), Vector2(0, 16), COLOR)
		_id_caption(Vector2(0, 24), COLOR)


func validate_arena(report: ArenaReport, arena: Arena) -> void:
	var b := arena.get_bounds()
	if b != null and not b.contains(global_position, 8.0):
		report.error("Exit %s is outside the arena." % name, self)
