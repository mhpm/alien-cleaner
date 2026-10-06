@tool
class_name AlienNest
extends ArenaObject
## A hive that births aliens while the astronaut is near, until it is shot down
## (an AlienNestBody enemy: bullets, auto-aim and the hit flash come for free).
## Destroying it fires "nest_destroyed" (DESTROY objectives, DESTROY_NESTS waves).

const COLOR := Color("c75bd6")
const ICON := "res://assets/sprites/hive_egg/walk_0.png"

@export_range(10.0, 5000.0, 10.0) var health := 260.0
## What it births (weighted).
@export var enemies: Array[SpawnEntry] = []:
	set(value):
		enemies = value
		queue_redraw()
@export_range(0.5, 30.0, 0.1) var spawn_interval := 4.0
@export_range(1, 30) var max_enemies := 4
@export_range(10.0, 200.0, 1.0) var spawn_radius := 40.0:
	set(value):
		spawn_radius = value
		queue_redraw()
## It only wakes up when the astronaut is this close.
@export_range(50.0, 1000.0, 5.0) var wake_range := 220.0:
	set(value):
		wake_range = value
		queue_redraw()
@export var destroy_reward: RewardData

var body: AlienNestBody
var _destroyed := false


func arena_layer() -> String:
	return "GameplayObjects"


func palette_icon() -> Texture2D:
	return ArenaArt.tex(ICON)


func palette_width() -> float:
	return 136.0 * 0.3


func activate(director: Node) -> void:
	director.spawner.spawn("alien_nest", global_position, false, true, func(e: Enemy) -> void:
		body = e as AlienNestBody
		body.entries = enemies
		body.interval = spawn_interval
		body.max_children = max_enemies
		body.spawn_radius = spawn_radius
		body.wake_range = wake_range
		body.service = director.spawner
		body.max_hp = health * director.spawner.hp_mult
		body.hp = body.max_hp
		body.destroyed.connect(func() -> void:
			_destroyed = true
			director.give(destroy_reward, global_position)
			director.fire("nest_destroyed", object_id, PackedStringArray(["nest"]))))


func is_resolved() -> bool:
	return _destroyed


func focus_point() -> Vector2:
	return body.global_position if is_instance_valid(body) else global_position


func validate_arena(report: ArenaReport, _arena: Arena) -> void:
	if enemies.is_empty():
		report.warning("Nest %s births nothing (empty enemy list)." % name, self)
	for e in enemies:
		if e == null or not EnemyData.TYPES.has(e.enemy_id):
			report.error("Nest %s lists an unknown enemy." % name, self)


func _draw_editor() -> void:
	draw_circle(Vector2.ZERO, wake_range, Color(COLOR, 0.03))
	_dashed_circle(wake_range, Color(COLOR, 0.45), 1.0, 48)
	_dashed_circle(spawn_radius, COLOR, 1.5)
	_standing(ArenaArt.tex(ICON), palette_width(), Color(1.15, 0.8, 1.35))
	_editor_label("NEST %d HP · every %.1fs" % [health, spawn_interval], Vector2(0, 10), COLOR)
	_id_caption(Vector2(0, 19), COLOR)
